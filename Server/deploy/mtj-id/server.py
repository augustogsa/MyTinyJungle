# MTJ plant ID: BioCLIP (MIT, imageomics/bioclip) over our own species list. CPU, 127.0.0.1 only.
#   species = zero-shot text prompts (with a houseplant prior) blended with kNN over a reference photo index
#             (/refs/refs.npz from refs.py, plus /refs/learned.npz from owners' confirmed corrections);
#   scene   = zero-shot probabilities for categorical scene fields (pot, medium, room, light, stage, fake plant).
# POST /        {photo}               -> {candidates:[{id,score}], scene:{field:{value:prob}}}
# POST /learn   {photo, id, ref}      -> adds one corrected photo to learned.npz
# POST /prior   {boost:{id:x}}        -> per-species prior from confirmed corrections
import base64, io, json, os, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import numpy as np, torch, open_clip
from PIL import Image

torch.set_num_threads(4)
model, _, pre = open_clip.create_model_and_transforms("hf-hub:imageomics/bioclip")
tok = open_clip.get_tokenizer("hf-hub:imageomics/bioclip")
model.eval()
lock = threading.Lock()
SPECIES, REFS = "/species/species.json", "/refs"
state = {"mtime": 0, "refs_mtime": 0, "ids": [], "emb": None, "prior": None, "ref_ids": None, "ref_emb": None}
# Tuned on the reference photos by leave-one-out (refs.py tune), never on the eval set.
P = {"alpha": 0.6, "k": 10, "temp": 30.0, "text_temp": 100.0}

SCENE = {
    "material": {"plastic": "a plant in a plastic pot", "terracotta": "a plant in a terracotta clay pot", "ceramic_glazed": "a plant in a glazed ceramic pot",
                 "glass": "a plant in a glass vase", "metal": "a plant in a metal pot", "basket_cachepot": "a plant in a woven basket planter",
                 "nursery": "a plant in a thin black plastic nursery pot", "self_watering": "a plant in a self-watering pot with a water gauge",
                 "hanging": "a plant in a hanging planter", "none": "a plant growing in the ground"},
    "medium": {"soil": "a plant in dark potting soil", "chunky": "a plant in chunky bark aroid mix", "cactus": "a cactus in gritty sandy soil",
               "leca": "a plant in round brown clay pebbles", "pon": "a plant in small mineral granules", "sphagnum": "a plant in sphagnum moss",
               "water": "a plant cutting with roots standing in a glass of water", "mounted": "an orchid mounted on a piece of bark",
               "terrarium": "small plants inside a closed glass terrarium", "ground": "a plant growing in a garden bed"},
    "room": {"living": "a plant in a living room", "bedroom": "a plant in a bedroom", "bathroom": "a plant in a bathroom", "kitchen": "a plant in a kitchen",
             "office": "a plant on an office desk", "balcony": "a plant on a balcony", "outdoor": "a plant outdoors in a garden"},
    "source": {"window": "a plant by a sunny window", "grow_light": "a plant under an LED grow light", "lamp": "a plant under a desk lamp", "outdoor": "a plant in outdoor daylight"},
    "intensity": {"low": "a plant in a dim dark room", "medium": "a plant in soft medium light", "bright_indirect": "a plant in bright indirect light", "direct": "a plant in harsh direct sunlight"},
    "stage": {"seedling": "a tiny seedling sprout", "juvenile": "a young small plant", "mature": "a large mature plant"},
    "artificial": {"yes": "an artificial plastic fake plant", "no": "a real living plant"},
}


def norm(e):
    return e / e.norm(dim=-1, keepdim=True)


with torch.no_grad():
    scene_emb = {f: (list(v), norm(model.encode_text(tok(list(v.values()))))) for f, v in SCENE.items()}


def mt(f):
    return os.path.getmtime(f) if os.path.exists(f) else 0


def load():
    t = (mt(SPECIES), mt(f"{REFS}/prior.json"))
    if t != state["mtime"]:
        sp = json.load(open(SPECIES))
        boost = json.load(open(f"{REFS}/prior.json")) if t[1] else {}
        ids, prior, embs, genus, epithet = [], [], [], [], []
        with torch.no_grad():
            for s in sp:
                sci = s.get("scientific") or ""
                if not sci:
                    continue
                fam = s.get("family") or ""
                texts = [f"a photo of {sci}.", f"a photo of Plantae {fam} {sci}.", f"a photo of {s.get('en','')}, {sci}, a plant."]
                texts += [f"a photo of {a}." for a in (s.get("aliases") or [])[:3]]
                embs.append(norm(norm(model.encode_text(tok(texts))).mean(dim=0)))
                ids.append(s["id"]); genus.append(sci.replace("×", "").split()[0].lower() if len(sci.replace("×", "").split()) == 1 else "")
                epithet.append(sci.replace("×", "").split()[0].lower())
                prior.append((0.0 if not s.get("outdoor") else -0.7) + boost.get(s["id"], 0.0))  # owners mostly photograph houseplants
        state.update(mtime=t, ids=ids, genus=genus, gen=epithet, emb=torch.stack(embs), prior=torch.tensor(prior), refs_mtime=None)
    rt = (mt(f"{REFS}/refs.npz"), mt(f"{REFS}/learned.npz"), mt(f"{REFS}/params.json"))
    if rt != state["refs_mtime"]:
        if rt[2]:
            P.update(json.load(open(f"{REFS}/params.json")))
        rid, remb = [], []
        for f in ("refs.npz", "learned.npz"):
            if os.path.exists(f"{REFS}/{f}"):
                z = np.load(f"{REFS}/{f}")
                rid += [str(x) for x in z["ids"]]; remb.append(z["emb"].astype(np.float32))
        index = {s: i for i, s in enumerate(state["ids"])}
        keep = [i for i, s in enumerate(rid) if s in index]
        state.update(refs_mtime=rt, ref_ids=torch.tensor([index[rid[i]] for i in keep], dtype=torch.long) if keep else None,
                     ref_emb=torch.from_numpy(np.concatenate(remb)[keep]) if keep else None)


def species_probs(e):
    text = (P["text_temp"] * e @ state["emb"].T + state["prior"]).softmax(dim=-1)[0]
    if state["ref_emb"] is None:
        return text
    sims = (e @ state["ref_emb"].T)[0]
    k = min(P["k"], len(sims))
    top = sims.topk(k)
    w = torch.exp(P["temp"] * (top.values - top.values[0]))
    knn = torch.zeros(len(state["ids"])).index_add_(0, state["ref_ids"][top.indices], w)
    knn = knn / knn.sum()
    return P["alpha"] * knn + (1 - P["alpha"]) * text


def ranked(p, n=5):
    """Top n; a genus-only entry ("Hoya") yields the lead to a species of that genus scoring at least 40% of it,
    since the species carries the more exact care."""
    top = [int(i) for i in p.topk(n + 3).indices]
    g = state["genus"][top[0]]
    if g:
        for j, i in enumerate(top[1:], 1):
            if state["gen"][i] == g and not state["genus"][i] and p[i] >= 0.4 * p[top[0]]:
                top.insert(0, top.pop(j))
                break
    return top[:n]


def scene_probs(e):
    out = {}
    for f, (labels, te) in scene_emb.items():
        p = (100.0 * e @ te.T).softmax(dim=-1)[0]
        out[f] = {l: round(float(x), 3) for l, x in zip(labels, p)}
    return out


def embed(b64):
    img = Image.open(io.BytesIO(base64.b64decode(b64))).convert("RGB")
    with torch.no_grad():
        return norm(model.encode_image(pre(img).unsqueeze(0)))


class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def reply(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)

    def do_GET(self):
        self.reply(200, {"status": "ok", "species": len(state["ids"]), "refs": 0 if state["ref_emb"] is None else len(state["ref_emb"])})

    def do_POST(self):
        try:
            n = int(self.headers.get("Content-Length", "0"))
            if n > 3_000_000:
                return self.reply(413, {"error": "too_large"})
            body = json.loads(self.rfile.read(n))
            with lock:
                load()
                if self.path == "/prior":
                    tmp = f"{REFS}/prior.json.tmp"
                    json.dump({k: float(v) for k, v in body.get("boost", {}).items()}, open(tmp, "w")); os.replace(tmp, f"{REFS}/prior.json")
                    load()
                    return self.reply(200, {"ok": True})
                e = embed(body["photo"])
                if self.path == "/learn":
                    if body.get("id") not in state["ids"]:
                        return self.reply(400, {"error": "unknown_species"})
                    f = f"{REFS}/learned.npz"
                    ids, emb, refs = [], np.zeros((0, e.shape[1]), np.float16), []
                    if os.path.exists(f):
                        z = np.load(f); ids, emb, refs = list(z["ids"]), z["emb"], list(z["refs"])
                    if body.get("ref") in refs:
                        return self.reply(200, {"ok": True})
                    np.savez(f + ".tmp.npz", ids=np.array(ids + [body["id"]]), emb=np.concatenate([emb, e.numpy().astype(np.float16)]), refs=np.array(refs + [body.get("ref", "")]))
                    os.replace(f + ".tmp.npz", f); load()
                    return self.reply(200, {"ok": True})
                p = species_probs(e)
                top = ranked(p)
                sc = scene_probs(e)
            self.reply(200, {"candidates": [{"id": state["ids"][i], "score": round(float(p[i]), 4)} for i in top], "scene": sc})
        except Exception as ex:
            self.reply(400, {"error": str(ex)[:200]})


load()
ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
