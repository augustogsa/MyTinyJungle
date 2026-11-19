# MTJ plant ID: BioCLIP (MIT, imageomics/bioclip) zero-shot over our own species list. CPU, 127.0.0.1 only.
import base64, io, json, os, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import torch, open_clip
from PIL import Image

torch.set_num_threads(4)
model, _, pre = open_clip.create_model_and_transforms("hf-hub:imageomics/bioclip")
tok = open_clip.get_tokenizer("hf-hub:imageomics/bioclip")
model.eval()
lock = threading.Lock()
state = {"mtime": 0, "ids": [], "emb": None}

def species_file():
    return "/species/species.json"

def load():
    f = species_file()
    t = os.path.getmtime(f)
    if t == state["mtime"]:
        return
    sp = json.load(open(f))
    ids, prior, embs = [], [], []
    with torch.no_grad():
        for s in sp:
            sci = s.get("scientific") or ""
            if not sci:
                continue
            fam = s.get("family") or ""
            texts = [f"a photo of {sci}.", f"a photo of Plantae {fam} {sci}.", f"a photo of {s.get('en','')}, {sci}, a plant."]
            texts += [f"a photo of {a}." for a in (s.get("aliases") or [])[:3]]
            e = model.encode_text(tok(texts))
            e = (e / e.norm(dim=-1, keepdim=True)).mean(dim=0)
            embs.append(e / e.norm())
            ids.append(s["id"])
            prior.append(0.0 if not s.get("outdoor") else -0.7)  # owners mostly photograph houseplants
    state.update(mtime=t, ids=ids, emb=torch.stack(embs), prior=torch.tensor(prior))

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def reply(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        self.reply(200, {"status": "ok", "species": len(state["ids"])})
    def do_POST(self):
        try:
            n = int(self.headers.get("Content-Length", "0"))
            if n > 3_000_000:
                return self.reply(413, {"error": "too_large"})
            body = json.loads(self.rfile.read(n))
            img = Image.open(io.BytesIO(base64.b64decode(body["photo"]))).convert("RGB")
            with lock:
                load()
                with torch.no_grad():
                    e = model.encode_image(pre(img).unsqueeze(0))
                    e = e / e.norm(dim=-1, keepdim=True)
                    p = (100.0 * e @ state["emb"].T + state["prior"]).softmax(dim=-1)[0]
                top = p.topk(5)
            self.reply(200, {"candidates": [{"id": state["ids"][i], "score": round(float(s), 4)} for s, i in zip(top.values, top.indices)]})
        except Exception as ex:
            self.reply(400, {"error": str(ex)[:200]})

load()
ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
