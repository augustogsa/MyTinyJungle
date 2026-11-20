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
erty = HERO.crop((1300, 300, 2600, 1800))
for loc, raw in (('en-US', 'en-US'), ('pt-BR', 'pt-BR'), ('pt-PT', 'pt-BR')):
    W2, H2 = 3840, 2160
    c = Image.new('RGB', (W2, H2), BG)
    d = ImageDraw.Draw(c); f = fr['font'](150)
    lines = HEAD[loc][0].split('\n')
    while max(d.textlength(l, font=f) for l in lines) > 1900: f = fr['font'](f.size - 6)
    y = H2 // 2 - int(f.size * 1.2)
    for l in lines: d.text((200, y), l, font=f, fill=fr['INK']); y += int(f.size * 1.2)
    e = erty.resize((int(erty.width * 0.62), int(erty.height * 0.62)), Image.LANCZOS)
    m = Image.new('L', e.size, 0); ImageDraw.Draw(m).rectangle([120, 0, e.width - 120, e.height], fill=255)
    c.paste(e, (2130, 1720 - e.height), m.filter(ImageFilter.GaussianBlur(70)))
    scr = Image.open(f'{R}/Assets/AppStore/screenshots/raw/{raw}/iphone69/01-notes.png')
    dev = fr['device'](scr, 900)
    top = (H2 - dev.height) // 2
    sh = Image.new('L', c.size, 0); sh.paste(dev.split()[3].point(lambda a: 60 if a else 0), (2820, top + 40))
    c.paste(Image.new('RGB', c.size, (40, 70, 45)), mask=sh.filter(ImageFilter.GaussianBlur(40)))
    c.paste(dev, (2820, top), dev)
    c.resize((5244, 2950), Image.LANCZOS).save(f'{OUT}/search-{loc}.png', optimize=True)
print('ok')
