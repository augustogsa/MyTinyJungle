"""BioCLIP on onnxruntime (no torch): image and text encoders exported by export_onnx.py, CLIP preprocessing."""
import io, json, os
import numpy as np, onnxruntime as ort
from PIL import Image
from cliptok import Tokenizer


class Clip:
    def __init__(self, d, threads=4, text=True):
        o = ort.SessionOptions(); o.intra_op_num_threads = threads; o.inter_op_num_threads = 1
        o.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        self.d, self.o = d, o
        p = json.load(open(os.path.join(d, "preprocess.json")))
        self.size, self.mean, self.std = p["size"], np.array(p["mean"], np.float32), np.array(p["std"], np.float32)
        vis = os.path.join(d, "visual.int8.onnx")
        self.visual = ort.InferenceSession(vis if os.path.exists(vis) else os.path.join(d, "visual.onnx"), o, providers=["CPUExecutionProvider"])
        self.tok = Tokenizer()
        self._text = None

    def prep(self, im):
        s = self.size
        im = im.convert("RGB")
        w, h = im.size
        f = s / min(w, h)
        im = im.resize((max(s, round(w * f)), max(s, round(h * f))), Image.BICUBIC)
        w, h = im.size
        l, t = int(round((w - s) / 2)), int(round((h - s) / 2))
        a = (np.asarray(im.crop((l, t, l + s, t + s)), np.float32) / 255 - self.mean) / self.std
        return a.transpose(2, 0, 1)

    def images(self, ims, batch=8):
        out = []
        for i in range(0, len(ims), batch):
            x = np.stack([self.prep(im) for im in ims[i:i + batch]])
            out.append(self.visual.run(None, {"pixels": x})[0])
        return np.concatenate(out) if out else np.zeros((0, 512), np.float32)

    def image_bytes(self, bs):
        return self.images([Image.open(io.BytesIO(b)) for b in bs])

    def texts(self, texts, batch=64):
        if self._text is None:
            self._text = ort.InferenceSession(os.path.join(self.d, "text.onnx"), self.o, providers=["CPUExecutionProvider"])
        out = [self._text.run(None, {"tokens": self.tok(texts[i:i + batch])})[0] for i in range(0, len(texts), batch)]
        return np.concatenate(out)

    def drop_text(self):
        self._text = None  # the text encoder is only needed when the species list changes


def species_texts(s):
    sci, fam = s.get("scientific") or "", s.get("family") or ""
    t = [f"a photo of {sci}.", f"a photo of Plantae {fam} {sci}.", f"a photo of {s.get('en', '')}, {sci}, a plant."]
    return t + [f"a photo of {a}." for a in (s.get("aliases") or [])[:3]]


def species_embeddings(clip, sp):
    """ids, unit text embeddings, houseplant prior (outdoor species start lower)."""
    ids, embs, outdoor = [], [], []
    for s in sp:
        if not s.get("scientific"):
            continue
        e = clip.texts(species_texts(s)).mean(0)
        embs.append(e / np.linalg.norm(e)); ids.append(s["id"]); outdoor.append(bool(s.get("outdoor")))
    return ids, np.array(embs, np.float32), np.array(outdoor)
