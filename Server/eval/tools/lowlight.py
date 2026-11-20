#!/usr/bin/env python3
"""Builds the dark and flash slices of identify.json from existing eval photos (deterministic):
  dark-*:  exposure cut to ~15-25%, shot noise, slight blur (an evening room, no lamp)
  flash-*: phone torch: hot centre, fast fall-off to a near-black background, clipped highlights
Each derived photo keeps its source's credit (see CREDITS.md).   python3 eval/tools/lowlight.py"""
import json, random
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

E = Path(__file__).resolve().parent.parent
cases = [c for c in json.load(open(E / "identify.json")) if not c["file"].split("/")[1].startswith(("dark-", "flash-"))]
rng = random.Random(7); nrs = np.random.default_rng(7)
pick = rng.sample(cases, 40)
out = []
for i, c in enumerate(pick):
    im = Image.open(E / c["file"]).convert("RGB"); a = np.asarray(im, np.float32) / 255
    name = c["file"].split("/")[1]
    if i % 2 == 0:
        k = rng.uniform(0.15, 0.25)
        b = a * k + nrs.normal(0, 0.012, a.shape)
        b = Image.fromarray((np.clip(b, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
        f = f"identify/dark-{name}"
    else:
        h, w = a.shape[:2]; y, x = np.mgrid[0:h, 0:w]
        r = np.hypot((x - w / 2) / (w / 2), (y - h / 2) / (h / 2))
        light = np.clip(1.9 * np.exp(-(r / 0.55) ** 2), 0.03, None)[..., None]
        b = Image.fromarray((np.clip(a * light, 0, 1) * 255).astype(np.uint8))
        f = f"identify/flash-{name}"
    b.save(E / f, quality=88)
    out.append({"file": f, "expect": c["expect"], "source": c["source"], "slice": "dark" if i % 2 == 0 else "flash"})
json.dump(cases + out, open(E / "identify.json", "w"), indent=1, ensure_ascii=False)
print(len(cases) + len(out))
