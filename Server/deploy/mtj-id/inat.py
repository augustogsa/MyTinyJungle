"""iNaturalist reference photos for the plant ID kNN index: real phone photos (rooms, distance, dim light,
gardens) next to the Wikimedia ones in refs.npz. CC licences only; observations used by Server/eval are skipped.
  inat.py fetch <species.json> <cache> <eval identify.json>   # up to 24 photos per species, resumable
  inat.py embed <cache> <onnx_dir> <out>                      # -> <out>/inat.npz + <out>/inat.json (credits)
"""
import glob, json, os, sys, time, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor
import numpy as np


def fetch_all(sp, cache, evalj):
    skip = {c["source"].rsplit("/", 1)[1] for c in evalj if "inaturalist" in c.get("source", "")}
    os.makedirs(cache, exist_ok=True)
    def get(u):
        for _ in range(4):
            try: return urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "mtj-refs/1.0 (support@simpleappscompany.com)"}), timeout=30).read()
            except Exception: time.sleep(3)
    def name(s):
        sci = (s.get("scientific") or "").replace("×", "").replace(" spp.", "").replace(" hybrids", "")
        if "'" in sci or "(" in sci: return None
        return " ".join(sci.split()[:2]) or None
    def one(s):
        n = name(s)
        d = f"{cache}/{s['id']}"
        if not n or os.path.exists(d + "/done"): return
        os.makedirs(d, exist_ok=True); got, meta = 0, []
        for q in ({"quality_grade": "research"}, {"captive": "true"}):
            if got >= 24: break
            u = "https://api.inaturalist.org/v1/observations?" + urllib.parse.urlencode({"taxon_name": n, "photo_license": "cc-by,cc0,cc-by-sa,cc-by-nc,cc-by-nc-sa", "per_page": "40", "order_by": "votes", **q})
            r = get(u); time.sleep(1.1)
            if not r: continue
            for o in json.loads(r)["results"]:
                if got >= 24: break
                if str(o["id"]) in skip or not o.get("photos") or not o.get("taxon"): continue
                if not o["taxon"]["name"].lower().startswith(n.split()[0].lower()): continue
                if q.get("captive") and o.get("num_identification_agreements", 0) < 1: continue
                p = o["photos"][0]; b = get(p["url"].replace("square", "small"))
                if not b: continue
                open(f"{d}/{o['id']}.jpg", "wb").write(b); got += 1
                meta.append({"obs": o["id"], "author": o["user"]["login"], "licence": p["license_code"]})
        json.dump(meta, open(d + "/meta.json", "w")); open(d + "/done", "w").close(); print(s["id"], got, flush=True)

    with ThreadPoolExecutor(6) as ex:
        list(ex.map(one, sp))


def embed_all(cache, onnx, out):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from PIL import Image, ImageOps
    from clipnx import Clip
    clip = Clip(onnx, threads=8)
    ids, emb, credits = [], [], {}
    for d in sorted(glob.glob(f"{cache}/*/done")):
        d = os.path.dirname(d); f = f"{d}/emb.npy"; sid = os.path.basename(d)
        if not os.path.exists(f):
            ims = []
            for x in sorted(glob.glob(f"{d}/*.jpg")):
                try:
                    ims.append(ImageOps.exif_transpose(Image.open(x)).convert("RGB"))
                except Exception:
                    pass
            np.save(f, (clip.images(ims) if ims else np.zeros((0, 768), np.float32)).astype(np.float16))
        e = np.load(f); ids += [sid] * len(e); emb.append(e)
        credits[sid] = json.load(open(f"{d}/meta.json"))
    np.savez(f"{out}/inat.npz", ids=np.array(ids), emb=np.concatenate(emb))
    json.dump(credits, open(f"{out}/inat.json", "w"))
    print("inat refs", len(ids))


if __name__ == "__main__":
    if sys.argv[1] == "fetch":
        fetch_all(json.load(open(sys.argv[2])), sys.argv[3], json.load(open(sys.argv[4])))
    else:
        embed_all(sys.argv[2], sys.argv[3], sys.argv[4])
