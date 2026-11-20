#!/usr/bin/env python3
"""Raw simulator screens → App Store marketing shots (headline + device on brand background).
   python3 Tools/appstore/frame.py   (reads screenshots/raw/<lang>/<kind>, writes screenshots/<locale>/<kind>)"""
import json, os, glob
from PIL import Image, ImageDraw, ImageFont, ImageFilter
ROOT = os.path.join(os.path.dirname(__file__), '../../Assets/AppStore/screenshots')
HEAD = json.load(open(os.path.join(os.path.dirname(__file__), 'headlines.json')))
SRC = {'en-US': 'en-US', 'pt-BR': 'pt-BR', 'pt-PT': 'pt-BR'}
FONT = '/System/Library/Fonts/SFNSRounded.ttf'
INK = (34, 72, 48)
TINTS = [((250, 246, 236), (205, 228, 200)), ((246, 243, 232), (220, 232, 214)), ((250, 244, 232), (238, 218, 196)), ((244, 246, 238), (206, 226, 222))]
TOP, BOT = TINTS[0]

def font(size):
    f = ImageFont.truetype(FONT, size)
    try: f.set_variation_by_name('Bold')
    except Exception: pass
    return f

def background(w, h, i=0):
    TOP, BOT = TINTS[i % len(TINTS)]
    bg = Image.new('RGB', (w, h))
    px = [tuple(int(TOP[c] + (BOT[c] - TOP[c]) * y / h) for c in range(3)) for y in range(h)]
    d = ImageDraw.Draw(bg)
    for y, c in enumerate(px): d.line([(0, y), (w, y)], fill=c)
    glow = Image.new('L', (w, h), 0); ImageDraw.Draw(glow).ellipse([w * .1, h * .25, w * .9, h * .85], fill=90)
    bg.paste(Image.new('RGB', (w, h), (255, 255, 250)), mask=glow.filter(ImageFilter.GaussianBlur(w / 8)))
    return bg

DEV = os.path.join(os.path.dirname(__file__), 'device')
FRAME = Image.open(f'{DEV}/iphone-frame.webp').convert('RGBA')      # official frame from the website
MASK = Image.open(f'{DEV}/iphone-screen-mask.png').split()[-1]
SCR = MASK.getbbox()

def device(screen, width):
    """Screen inside the website's iPhone frame, frame scaled so the whole device is `width` px wide."""
    k = width / FRAME.width
    fr = FRAME.resize((int(FRAME.width * k), int(FRAME.height * k)), Image.LANCZOS)
    mk = MASK.resize(fr.size, Image.LANCZOS)
    x0, y0, x1, y1 = [int(v * k) for v in SCR]
    out = Image.new('RGBA', fr.size, (0, 0, 0, 0))
    out.paste(screen.convert('RGB').resize((x1 - x0, y1 - y0), Image.LANCZOS), (x0, y0))
    out.putalpha(mk)
    out.alpha_composite(fr)
    return out

def shadow(canvas, dev, x, y):
    sh = Image.new('L', canvas.size, 0)
    sh.paste(dev.split()[3].point(lambda a: 70 if a else 0), (x, y + 40))
    canvas.paste(Image.new('RGB', canvas.size, (40, 70, 45)), mask=sh.filter(ImageFilter.GaussianBlur(50)))
    canvas.paste(dev, (x, y), dev)

SIZE = {}  # one headline size per locale and kind, so every slide matches

def fit(heads, size, maxw):
    d = ImageDraw.Draw(Image.new('RGB', (1, 1)))
    while size > 40 and max(d.textlength(l, font=font(size)) for h in heads for l in h) > maxw: size -= 2
    return size

def text(canvas, lines, cx, y, size, maxw):
    d = ImageDraw.Draw(canvas)
    f = font(size)
    for l in lines:
        d.text((cx - d.textlength(l, font=f) / 2, y), l, font=f, fill=INK); y += int(size * 1.18)
    return y

def portrait(screen, head, i=0):
    W, H = 1320, 2868
    c = background(W, H, i)
    size = SIZE['p']; text(c, head.split('\n'), W / 2, 170, size, W - 120)
    end = 170 + int(size * 1.18) * 2
    dev = device(screen[0], 1160)
    shadow(c, dev, (W - dev.width) // 2, end + 80)
    return c

# iPhone Duo frames built from Apple's Simulator chrome (DeviceKit phone15 + the Duo display masks).
DUO = {k: (Image.open(f'{DEV}/duo-{k}-frame.png').convert('RGBA'), Image.open(f'{DEV}/duo-{k}-mask.png')) for k in ('open', 'closed')}

def duo(screen, kind, height):
    fr, mk = DUO[kind]; k = height / fr.height
    size = (int(fr.width * k), int(fr.height * k))
    fr, mk = fr.resize(size, Image.LANCZOS), mk.resize(size, Image.LANCZOS)
    x0, y0, x1, y1 = mk.getbbox()
    out = Image.new('RGBA', size, (0, 0, 0, 0))
    out.paste(screen.convert('RGB').resize((x1 - x0, y1 - y0), Image.LANCZOS), (x0, y0))
    out.putalpha(mk); out.alpha_composite(fr)
    return out

def landscape(screen, head, i=0, closed=None):
    W, H = 2853, 2007
    c = background(W, H, i)
    size = SIZE['l']; text(c, [head.replace('\n', ' ')], W / 2, 120, size, W - 240)
    end = 120 + int(size * 1.18)
    if closed is None:  # one open Duo
        dev = duo(screen[0], 'open', H - end - 140)
        shadow(c, dev, (W - dev.width) // 2, end + 70)
    else:  # two closed Duos, side by side, outer screens
        devs = [duo(s, 'closed', H - end - 140) for s in closed]
        gap = 140; x = (W - sum(d.width for d in devs) - gap) // 2
        for d in devs: shadow(c, d, x, end + 70); x += d.width + gap
    return c

for loc, src in SRC.items():
    SIZE['p'] = fit([h.split('\n') for h in HEAD[loc]], 120, 1200)
    SIZE['l'] = fit([[h.replace('\n', ' ')] for h in HEAD[loc]], 110, 2613)
    for kind in ('iphone69', 'duo'):
        raws = [[f'{ROOT}/raw/{src}/{kind}/{n}.png' for n in slot.split('+')] for slot in HEAD['order'][kind]]
        if not all(os.path.exists(r) for g in raws for r in g): print('missing', loc, kind); continue
        out = f'{ROOT}/{loc}/{kind}'; os.makedirs(out, exist_ok=True)
        for f in glob.glob(out + '/*.png'): os.remove(f)
        for i, r in enumerate(raws):
            ims = [Image.open(x) for x in r]
            if kind == 'iphone69': img = portrait(ims, HEAD[loc][i], i)
            elif len(r) == 1: img = landscape(ims, HEAD[loc][i], i)
            else: img = landscape(ims, HEAD[loc][i], i, closed=[Image.open(x.replace('/duo/', '/duoclosed/')) for x in r])
            name = '-'.join(os.path.basename(x)[3:-4] for x in r)
            img.convert('RGB').save(f'{out}/{i + 1:02d}-{name}.png', optimize=True)
        print(loc, kind, len(raws))
