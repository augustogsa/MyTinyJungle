# MTJ plant ID: BioCLIP-2 (MIT, imageomics/bioclip-2) on onnxruntime, int8 image encoder, CPU, 127.0.0.1 only.
#   species = zero-shot text (houseplant prior + owners' corrections) blended with kNN over a reference photo
#             index (/refs/refs.npz from refs.py, /refs/learned.npz from confirmed corrections);
#   scene   = zero-shot probabilities for categorical scene fields (pot, medium, room, light, stage, fake plant).
# Text embeddings are computed once per species list and kept on disk (/refs/text-cache.npz), so restarts are warm.
# POST /        {photo} -> {candidates:[{id,score}], scene:{field:{value:prob}}}
#               {photos:[...]} -> {results:[{candidates, scene}]}   (one batched pass, e.g. shelf crops)
# POST /learn   {photo, id, ref}  -> adds one corrected photo to learned.npz
# POST /prior   {boost:{id:x}, _outdoor?:x} -> per-species prior from confirmed corrections (+ outdoor prior)
import base64, hashlib, io, json, os, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import numpy as np
from PIL import Image
from clipnx import Clip, species_texts

REFS, SPECIES = os.environ.get("MTJ_ID_REFS", "/refs"), os.environ.get("MTJ_ID_SPECIES", "/species/species.json")
MODEL = os.environ.get("MTJ_ID_MODEL", f"{REFS}/model")
clip = Clip(MODEL, threads=int(os.environ.get("THREADS", "4")))
lock = threading.Lock()
state = {"key": None, "refs_key": None, "ids": [], "emb": None, "prior": None, "outdoor": None, "ref_ids": None, "ref_emb": None}
P = {"alpha": 0.5, "k": 20, "temp": 20.0, "text_temp": 60.0}  # replaced by /refs/params.json (refs.py tune)

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


def mt(f):
    return os.path.getmtime(f) if os.path.exists(f) else 0


def unit(x):
    return x / np.linalg.norm(x, axis=-1, keepdims=True)


def text_cache(sp):
    """Species + scene text embeddings, cached on disk by the exact prompts and model."""
    texts = [species_texts(s) for s in sp if s.get("scientific")]
    scene = [list(v.values()) for v in SCENE.values()]
    key = hashlib.sha256(json.dumps([MODEL, mt(f"{MODEL}/text.onnx"), texts, scene]).encode()).hexdigest()[:16]
    f = f"{REFS}/text-cache.npz"
    if os.path.exists(f):
        z = np.load(f)
        if str(z["key"]) == key:
            return z["species"], z["scene"]
    flat = [t for ts in texts for t in ts]
    e = clip.texts(flat)
    out, i = [], 0
    for ts in texts:
        out.append(unit(e[i:i + len(ts)].mean(0))); i += len(ts)
    se = unit(clip.texts([t for ts in scene for t in ts]))
    clip.drop_text()
    try:
        np.savez(f + ".tmp.npz", key=key, species=np.array(out, np.float32), scene=se.astype(np.float32)); os.replace(f + ".tmp.npz", f)
    except OSError:
        pass
    return np.array(out, np.float32), se.astype(np.float32)


def load():
    key = (mt(SPECIES), mt(f"{REFS}/prior.json"))
    if key != state["key"]:
        sp = json.load(open(SPECIES))
        boost = json.load(open(f"{REFS}/prior.json")) if key[1] else {}
        ids, genus, gen, outdoor = [], [], [], []
        for s in sp:
            sci = (s.get("scientific") or "").replace("×", "").split()
            if not sci:
                continue
            ids.append(s["id"]); genus.append(sci[0].lower() if len(sci) == 1 else ""); gen.append(sci[0].lower()); outdoor.append(bool(s.get("outdoor")))
        semb, scemb = text_cache(sp)
        outdoor = np.array(outdoor)
        prior = np.where(outdoor, float(boost.get("_outdoor", -0.7)), 0.0) + np.array([float(boost.get(i, 0.0)) for i in ids])
        scene, i = {}, 0
        for f, v in SCENE.items():
            scene[f] = (list(v), scemb[i:i + len(v)]); i += len(v)
        state.update(key=key, ids=ids, genus=genus, gen=gen, emb=semb, prior=prior, scene=scene, refs_key=None)
    rk = (mt(f"{REFS}/refs.npz"), mt(f"{REFS}/learned.npz"), mt(f"{REFS}/params.json"))
    if rk != state["refs_key"]:
        if rk[2]:
            P.update(json.load(open(f"{REFS}/params.json")))
        rid, remb = [], []
        for f in ("refs.npz", "learned.npz"):
            if os.path.exists(f"{REFS}/{f}"):
                z = np.load(f"{REFS}/{f}")
                if z["emb"].shape[1] == state["emb"].shape[1]:  # an index built with another model is ignored
                    rid += [str(x) for x in z["ids"]]; remb.append(z["emb"].astype(np.float32))
        index = {s: i for i, s in enumerate(state["ids"])}
        keep = [i for i, s in enumerate(rid) if s in index]
        state.update(refs_key=rk, ref_ids=np.array([index[rid[i]] for i in keep]) if keep else None,
                     ref_emb=np.concatenate(remb)[keep] if keep else None)


def species_probs(e):
    t = P["text_temp"] * e @ state["emb"].T + state["prior"]
    text = np.exp(t - t.max()); text /= text.sum()
    if state["ref_emb"] is None:
        return text
    sims = state["ref_emb"] @ e
    k = min(int(P["k"]), len(sims))
    top = np.argpartition(-sims, k - 1)[:k]
    top = top[np.argsort(-sims[top])]
    w = np.exp(P["temp"] * (sims[top] - sims[top[0]]))
    knn = np.zeros(len(state["ids"])); np.add.at(knn, state["ref_ids"][top], w); knn /= knn.sum()
    return P["alpha"] * knn + (1 - P["alpha"]) * text


def ranked(p, n=5):
    """Top n; a genus-only entry ("Hoya") yields the lead to a species of that genus scoring at least 40% of it,
    since the species carries the more exact care."""
    top = list(np.argsort(-p)[: n + 3])
    g = state["genus"][top[0]]
    if g:
        for j, i in enumerate(top[1:], 1):
            if state["gen"][i] == g and not state["genus"][i] and p[i] >= 0.4 * p[top[0]]:
                top.insert(0, top.pop(j)); break
    return top[:n]


def scene_probs(e):
    out = {}
    for f, (labels, te) in state["scene"].items():
        z = 100.0 * te @ e; p = np.exp(z - z.max()); p /= p.sum()
        out[f] = {l: round(float(x), 3) for l, x in zip(labels, p)}
    return out


def answer(e):
    p = species_probs(e)
    return {"candidates": [{"id": state["ids"][i], "score": round(float(p[i]), 4)} for i in ranked(p)], "scene": scene_probs(e)}


def decode(b64):
    return base64.b64decode(b64)


class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def reply(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)

    def do_GET(self):
        self.reply(200, {"status": "ok", "model": os.path.basename(json.load(open(f"{MODEL}/preprocess.json")).get("model", "")),
                         "species": len(state["ids"]), "refs": 0 if state["ref_emb"] is None else len(state["ref_emb"])})

    def do_POST(self):
        try:
            n = int(self.headers.get("Content-Length", "0"))
            if n > 12_000_000:
                return self.reply(413, {"error": "too_large"})
            body = json.loads(self.rfile.read(n))
            with lock:
                load()
                if self.path == "/prior":
                    boost = {k: float(v) for k, v in body.get("boost", {}).items()}
                    if "_outdoor" in body:
                        boost["_outdoor"] = max(-1.5, min(0.0, float(body["_outdoor"])))
                    tmp = f"{REFS}/prior.json.tmp"
                    json.dump(boost, open(tmp, "w")); os.replace(tmp, f"{REFS}/prior.json"); load()
                    return self.reply(200, {"ok": True})
            if "photos" in body:
                photos = body["photos"][:16]
                es = clip.image_bytes([decode(p) for p in photos])
                with lock:
                    return self.reply(200, {"results": [answer(e) for e in es]})
            e = clip.image_bytes([decode(body["photo"])])[0]
            with lock:
                if self.path == "/learn":
                    if body.get("id") not in state["ids"]:
                        return self.reply(400, {"error": "unknown_species"})
                    f = f"{REFS}/learned.npz"
                    ids, emb, refs = [], np.zeros((0, len(e)), np.float16), []
                    if os.path.exists(f):
                        z = np.load(f)
                        if z["emb"].shape[1] == len(e):
                            ids, emb, refs = list(z["ids"]), z["emb"], list(z["refs"])
                    if body.get("ref") in refs:
                        return self.reply(200, {"ok": True})
                    np.savez(f + ".tmp.npz", ids=np.array(ids + [body["id"]]), emb=np.concatenate([emb, e[None].astype(np.float16)]), refs=np.array(refs + [body.get("ref", "")]))
                    os.replace(f + ".tmp.npz", f); load()
                    return self.reply(200, {"ok": True})
                return self.reply(200, answer(e))
        except Exception as ex:
            self.reply(400, {"error": str(ex)[:200]})


with lock:
    load()
ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8080"))), H).serve_forever()
