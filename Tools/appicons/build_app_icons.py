#!/usr/bin/env python3
"""Tiny Jungle app icons: Assets/Brand/AppIconSources/<id>.* -> 1024x1024, mascot centred
exactly (bounding box of mascot + prop), padded with the art's own cream. Writes AppIcon
(main) and AppIcon-<id> alternates plus AppIconPreview-<id> images for the picker."""
import json, pathlib
import numpy as np
from PIL import Image

MAIN = "monstera"
IDS = ["monstera","sprout","hug","potted","cherish","cactus","trailing","terrarium","watering","seedling","explorer","pruner","basket","journal"]
root = pathlib.Path(__file__).resolve().parents[2]
src = root / "Assets/Brand/AppIconSources"
xc = root / "MyTinyJungle/Assets.xcassets"
out = xc / "AppIcons"; out.mkdir(exist_ok=True)
(out / "Contents.json").write_text(json.dumps({"info":{"author":"xcode","version":1}}, indent=2))

def master(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.int16)
    edge = np.concatenate([a[:8].reshape(-1,3), a[-8:].reshape(-1,3), a[:,:8].reshape(-1,3), a[:,-8:].reshape(-1,3)])
    bg = np.median(edge, axis=0)
    diff = np.abs(a - bg).max(axis=2)
    border = np.zeros(diff.shape, bool); border[:70]=border[-70:]=True; border[:, :70]=border[:, -70:]=True
    a[border & (diff > 14)] = bg.astype(np.int16)        # strip corner marks
    diff = np.abs(a - bg).max(axis=2)
    ys, xs = np.where(diff > 34)                          # subject, not the floor shadow
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    side = int(max(x1 - x0, y1 - y0) / 0.80)
    p = np.pad(a, ((side, side), (side, side), (0, 0)), mode="edge").astype(np.uint8)
    l, t = int(round(cx)) - side // 2 + side, int(round(cy)) - side // 2 + side
    return Image.fromarray(p[t:t+side, l:l+side]).resize((1024, 1024), Image.LANCZOS)

def icon_set(folder, png):
    folder.mkdir(exist_ok=True)
    for f in folder.glob("*.png"): f.unlink()
    png.save(folder / "icon.png")
    (folder / "Contents.json").write_text(json.dumps({"images":[{"filename":"icon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}, indent=2))

for i in IDS:
    img = master(next(src.glob(f"{i}.*")))
    if i == MAIN:
        d = xc / "AppIcon.appiconset"
        for f in d.glob("*.png"): f.unlink()
        img.save(d / "AppIcon.png")
    else:
        icon_set(out / f"AppIcon-{i}.appiconset", img)
    pv = out / f"AppIconPreview-{i}.imageset"; pv.mkdir(exist_ok=True)
    img.resize((360, 360), Image.LANCZOS).save(pv / "preview.png")
    (pv / "Contents.json").write_text(json.dumps({"images":[{"filename":"preview.png","idiom":"universal"}],"info":{"author":"xcode","version":1}}, indent=2))
print(" ".join("AppIcon-" + i for i in IDS if i != MAIN))
