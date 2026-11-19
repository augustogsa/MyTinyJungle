#!/usr/bin/env python3
"""Builds the plant ID reference index: CC/PD Wikimedia Commons photos per species -> BioCLIP image embeddings.

  refs.py fetch  <species.json> <cache>       # downloads ≤480 px thumbnails + credits (resumable)
  refs.py embed  <species.json> <cache> <out> <onnx_dir>  # <out>/refs.npz (ids, emb float16) + refs.json (credits)
  refs.py tune   <species.json> <cache> <out> <onnx_dir>  # leave-one-out on the reference photos -> <out>/params.json

Eval photos (Server/eval/identify.json) and near-duplicates of them (cosine ≥ 0.95) are never indexed, so the
eval stays held out. Run by Server/deploy/mtj-id-refs.sh (on any machine with the deps; the result is synced
to /var/lib/mtj-db/models/refs on the VPS and picked up by mtj-id without a restart).
"""
import io, json, os, re, sys, time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "eval"))
from commons import search, get  # noqa: E402

PER = int(os.environ.get("PER", "30"))
EVAL = Path(__file__).resolve().parents[2] / "eval" / "identify.json"


def queries(s):
    sci = re.sub(r"[×x] ", "", s.get("scientific") or "").strip()
    base = re.sub(r"'.*?'|\(.*?\)", "", sci).strip()
    qs = []
    cv = re.findall(r"'(.*?)'", sci)
    if cv:
        qs.append(f"{base} {cv[0]}")
    qs.append(base)
    if s.get("en"):
        qs.append(f"{s['en']} plant")
    return qs


def fetch(species, cache):
    from PIL import Image
    held = {c["source"] for c in json.load(open(EVAL))} if EVAL.exists() else set()
    sp = json.load(open(species))

    def one(s):
        d = cache / s["id"]
        meta = d / "meta.json"
        got = json.loads(meta.read_text()) if meta.exists() else []
        if len(got) >= PER or (meta.exists() and (d / ".done").exists()):
            return
        d.mkdir(parents=True, exist_ok=True)
        seen = {g["title"] for g in got}
        for q in queries(s):
            if len(got) >= PER:
                break
            try:
                rs = search(q, 80)
            except Exception:
                continue
            for r in rs:
                if len(got) >= PER or r["title"] in seen or r["title"] in held:
                    continue
                seen.add(r["title"])
                f = d / f"{len(got):03d}.jpg"
                try:
                    im = Image.open(io.BytesIO(get(r["thumb"]))).convert("RGB")
                    im.thumbnail((480, 480))
                    im.save(f, quality=85)
                except Exception:
                    continue
                got.append({**r, "file": f.name})
        meta.write_text(json.dumps(got, ensure_ascii=False))
        (d / ".done").touch()  # searched to exhaustion at this PER
        print(s["id"], len(got), flush=True)

    with ThreadPoolExecutor(4) as ex:
        list(ex.map(one, sp))


def clip(onnx):
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from clipnx import Clip
    return Clip(str(onnx), threads=int(os.environ.get("THREADS", "8")))


def embed(species, cache, out, onnx):
    """Reference embeddings with the same ONNX encoder mtj-id serves with (so queries and refs match)."""
    import numpy as np
    from PIL import Image
    c = clip(onnx)
    evdir = EVAL.parent
    held = c.images([Image.open(evdir / x["file"]) for x in json.load(open(EVAL))]) if EVAL.exists() else np.zeros((0, 1))
    ids, embs, credits = [], [], {}
    for s in json.load(open(species)):
        d = cache / s["id"]
        if not (d / "meta.json").exists():
            continue
        ok = [m for m in json.loads((d / "meta.json").read_text()) if (d / m["file"]).exists()]
        if not ok:
            continue
        e = c.images([Image.open(d / m["file"]) for m in ok], batch=16)
        keep = (e @ held.T).max(axis=1) < 0.95 if len(held) else np.ones(len(e), bool)
        for m, v, k in zip(ok, e, keep):
            if k:
                ids.append(s["id"]); embs.append(v)
                credits.setdefault(s["id"], []).append({"title": m["title"], "author": m["author"], "licence": m["licence"]})
    out.mkdir(parents=True, exist_ok=True)
    np.savez(out / "refs.tmp.npz", ids=np.array(ids), emb=np.array(embs, dtype=np.float16))
    os.replace(out / "refs.tmp.npz", out / "refs.npz")
    (out / "refs.json").write_text(json.dumps(credits, ensure_ascii=False))
    print(f"{len(ids)} reference photos for {len(credits)} species", flush=True)


def tune(species, cache, out, onnx):
    """Grid search of the kNN/text blend by leave-one-out over the reference photos. A held-out photo never
    sees references by the same Commons author (photo series) or near-duplicates, so the score is honest."""
    import numpy as np
    c = clip(onnx)
    from clipnx import species_embeddings
    ids, temb, outdoor = species_embeddings(c, json.load(open(species)))
    prior = np.where(outdoor, -0.7, 0.0)
    index = {s: i for i, s in enumerate(ids)}
    z = np.load(out / "refs.npz"); rid = np.array([index.get(str(x), -1) for x in z["ids"]]); remb = z["emb"].astype(np.float32)
    credits = json.loads((out / "refs.json").read_text())
    authors, seen = [], {}
    for x in z["ids"]:
        x = str(x); i = seen.get(x, 0); seen[x] = i + 1
        authors.append(credits[x][i]["author"])
    authors = np.array(authors)
    ok = rid >= 0
    rid, remb, authors = rid[ok], remb[ok], authors[ok]
    rng = np.random.default_rng(7)
    q = rng.choice(len(rid), size=min(2500, len(rid)), replace=False)
    sims = remb[q] @ remb.T
    for n, i in enumerate(q):
        sims[n, (authors == authors[i]) & (rid == rid[i])] = -9
        sims[n, sims[n] > 0.95] = -9
        sims[n, i] = -9
    tl = remb[q] @ temb.T
    best = None
    for tt in (40.0, 60.0, 100.0):
        text = np.exp(tt * tl + prior - (tt * tl + prior).max(1, keepdims=True)); text /= text.sum(1, keepdims=True)
        for k in (5, 10, 20, 40):
            top = np.argsort(-sims, axis=1)[:, :k]
            ts = np.take_along_axis(sims, top, 1)
            for temp in (10.0, 20.0, 40.0, 80.0):
                w = np.exp(temp * (ts - ts[:, :1]))
                knn = np.zeros_like(text)
                for n in range(len(q)):
                    np.add.at(knn[n], rid[top[n]], w[n])
                knn /= knn.sum(1, keepdims=True)
                for a in (0.3, 0.5, 0.6, 0.7, 0.8, 0.9):
                    p = a * knn + (1 - a) * text
                    r = np.argsort(-p, axis=1)[:, :3]
                    t1 = (r[:, 0] == rid[q]).mean(); t3 = (r == rid[q][:, None]).any(1).mean()
                    sc = t1 + 0.5 * t3
                    if best is None or sc > best[0]:
                        best = (sc, {"alpha": a, "k": k, "temp": temp, "text_temp": tt}, t1, t3)
    (out / "params.json").write_text(json.dumps(best[1]))
    print("leave-one-out top-1 %.3f top-3 %.3f" % (best[2], best[3]), best[1], flush=True)


if __name__ == "__main__":
    cmd, species, cache = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
    if cmd == "fetch":
        fetch(species, cache)
    elif cmd == "embed":
        embed(species, cache, Path(sys.argv[4]), Path(sys.argv[5]))
    else:
        tune(species, cache, Path(sys.argv[4]), Path(sys.argv[5]))
