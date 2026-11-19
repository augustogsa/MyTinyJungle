# Builds Retention Messaging images (opaque PNG): hero 3840x2160 + 1024 bullet icons.
# Hero uses the real watering Erty frame (Assets/Brand/Erty/erty-watering-frame.png, frame 236 of erty-long-source.mp4)
# on the video's own flat cream background, so it blends with no seam.
from PIL import Image, ImageDraw, ImageFilter
import os
R = os.path.dirname(os.path.abspath(__file__)) + "/../.."
I = R + "/Assets/Icons3D-source/"; E = R + "/MyTinyJungle/Assets.xcassets/Erty/"
OUT = R + "/Assets/AppStore/retention/"
W, H = 3840, 2160
BG = (247, 237, 231)  # video background
def ld(p, h):
    im = Image.open(p).convert("RGBA"); im = im.crop(im.getbbox())
    return im.resize((round(im.width * h / im.height), h), Image.LANCZOS)
def ground_shadow(bg, cx, y, w):  # soft contact shadow like the video's
    s = Image.new("RGBA", bg.size, 0); ImageDraw.Draw(s).ellipse((cx - w // 2, y - 28, cx + w // 2, y + 28), fill=(150, 110, 90, 70))
    bg.alpha_composite(s.filter(ImageFilter.GaussianBlur(26)))
bg = Image.new("RGBA", (W, H), BG + (255,))
# Erty watering, scaled; frame ground line is y~815 of 960
S = 1.9; fr = Image.open(R + "/Assets/Brand/Erty/erty-watering-frame.png").convert("RGBA")
fr = fr.resize((round(960 * S), round(960 * S)), Image.LANCZOS)
GROUND = 1720; fx = W // 2 - fr.width // 2 + 60; fy = GROUND - round(815 * S)
m = Image.new("L", fr.size, 0); ImageDraw.Draw(m).rectangle((60, 60, fr.width - 60, fr.height - 60), fill=255)
fr.putalpha(m.filter(ImageFilter.GaussianBlur(40)))
bg.alpha_composite(fr, (fx, fy))
# potted friends on the same floor
for n, h, cx in [("plant_013.png", 470, 520), ("plant_035.png", 420, 1020), ("plant_036.png", 520, 2980), ("plant_015.png", 380, 3420)]:
    p = ld(I + n, h); ground_shadow(bg, cx, GROUND - 6, int(p.width * 0.9)); bg.alpha_composite(p, (cx - p.width // 2, GROUND - p.height))
sun = ld(I + "extra_sun.png", 380); bg.alpha_composite(sun, (W - 680, 140))
bg.convert("RGB").save(OUT + "hero.png", optimize=True)
# bullet icons 1024 opaque, mint tile
for key, n in [("bullet-plants", "erty-plant"), ("bullet-health", "erty-scan"), ("bullet-soil", "erty-soilbag"), ("bullet-calm", "erty-sleep")]:
    t = Image.new("RGBA", (1024, 1024), (238, 247, 232, 255)); ic = ld(E + f"{n}.imageset/{n}.png", 780)
    t.alpha_composite(ic, ((1024 - ic.width) // 2, (1024 - ic.height) // 2)); t.convert("RGB").save(OUT + key + ".png", optimize=True)
print("ok")
