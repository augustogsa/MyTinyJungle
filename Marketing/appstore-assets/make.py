#!/usr/bin/env python3
"""App Store Product Page art: header (5244x2950) and search results (5244x2950), per locale.
   python3 Marketing/appstore-assets/make.py"""
import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../Tools/appstore'))
from PIL import Image, ImageDraw, ImageFilter
R = os.path.join(os.path.dirname(__file__), '../..')
OUT = os.path.dirname(os.path.abspath(__file__))
import importlib.util
spec = importlib.util.spec_from_file_location('fr', f'{R}/Tools/appstore/frame.py')
src = open(f'{R}/Tools/appstore/frame.py').read().split('for loc, src in SRC.items():')[0]
fr = {'__file__': f'{R}/Tools/appstore/frame.py'}; exec(src, fr)
HERO = Image.open(f'{R}/Assets/AppStore/retention/hero.png').convert('RGB')
BG = HERO.getpixel((20, 20))
HEAD = json.load(open(f'{R}/Tools/appstore/headlines.json'))

# Header: hero art, scaled to 86% and lifted so the mascot sits above the bottom third.
W, H = 5244, 2950
k = 0.86 * W / HERO.width
art = HERO.resize((int(HERO.width * k), int(HERO.height * k)), Image.LANCZOS)
hd = Image.new('RGB', (W, H), BG); hd.paste(art, ((W - art.width) // 2, int(H * 0.04)))
hd.save(f'{OUT}/header.png', optimize=True)

# Search results: headline left, Erty, phone with the real Lock Screen on the right.
erty = HERO.crop((1150, 300, 2650, 1800))
for loc, raw in (('en-US', 'en-US'), ('pt-BR', 'pt-BR'), ('pt-PT', 'pt-BR')):
    W2, H2 = 3840, 2160
    c = Image.new('RGB', (W2, H2), BG)
    d = ImageDraw.Draw(c); f = fr['font'](150)
    lines = HEAD[loc][0].split('\n')
    while max(d.textlength(l, font=f) for l in lines) > 1820: f = fr['font'](f.size - 6)
    y = H2 // 2 - int(f.size * 1.2)
    for l in lines: d.text((200, y), l, font=f, fill=fr['INK']); y += int(f.size * 1.2)
    e = erty.resize((int(erty.width * 0.42), int(erty.height * 0.42)), Image.LANCZOS)
    # Clean alpha: key out the hero's cream background (no box, no halo), soften the edge.
    import numpy as np
    a = np.asarray(e).astype(int); bg = np.array(e.getpixel((5, 5)))
    diff = np.abs(a - bg).sum(axis=2)
    m = Image.fromarray(np.clip((diff - 10) * 8, 0, 255).astype('uint8')).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(2))
    # Keep only Erty's own blob (drop stray bits of the hero scene at the crop border).
    from scipy import ndimage
    lab, n = ndimage.label(np.asarray(m) > 20)
    if n:
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        keep = np.isin(lab, [i + 1 for i, s_ in enumerate(sizes) if s_ == sizes.max() or (s_ > sizes.max() * 0.002 and not (lab[:, :8] == i + 1).any())])
        keep = ndimage.binary_dilation(keep, iterations=6)
        m = Image.fromarray((np.asarray(m) * keep).astype('uint8')).filter(ImageFilter.GaussianBlur(1))
    ramp = np.clip(np.arange(m.width) / 60.0, 0, 1)[None, :] * np.clip((m.height - 1 - np.arange(m.height)) / 30.0, 0, 1)[:, None]
    m = Image.fromarray((np.asarray(m) * ramp).astype('uint8'))
    c.paste(e, (2110, 1640 - e.height), m)
    scr = Image.open(f'{R}/Assets/AppStore/screenshots/raw/{raw}/iphone69/01-notes.png')
    dev = fr['device'](scr, 900)
    top = (H2 - dev.height) // 2
    sh = Image.new('L', c.size, 0); sh.paste(dev.split()[3].point(lambda a: 60 if a else 0), (2820, top + 40))
    c.paste(Image.new('RGB', c.size, (40, 70, 45)), mask=sh.filter(ImageFilter.GaussianBlur(40)))
    c.paste(dev, (2820, top), dev)
    c.resize((5244, 2950), Image.LANCZOS).save(f'{OUT}/search-{loc}.png', optimize=True)
print('ok')
