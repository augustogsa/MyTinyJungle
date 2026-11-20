"""Store screenshots -> web: WebP at SHOT_W widths in src/assets/shots/<en|pt>/.
Usage: python3 tools/shots.py [raw_dir]   (default ../Assets/AppStore/screenshots/raw)"""
import sys
from pathlib import Path
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from site_pages import SHOTS, SHOT_W

W = Path(__file__).resolve().parent.parent
raw = Path(sys.argv[1]) if len(sys.argv) > 1 else W.parent / "Assets/AppStore/screenshots/raw"
for L, loc in (("en", "en-US"), ("pt", "pt-BR")):
    out = W / "src/assets/shots" / L
    out.mkdir(parents=True, exist_ok=True)
    for f in sorted((raw / loc / "iphone69").glob("*.png")):
        name = f.stem
        im = Image.open(f).convert("RGB")
        for w in SHOT_W:
            im.resize((w, round(im.height * w / im.width)), Image.LANCZOS).save(out / f"{name}-{w}.webp", "WEBP", quality=80, method=6)
print("shots ok")
