#!/usr/bin/env python3
"""Publish the content pack (repo Content/) to the API host.

Every file is stored once under b/<sha256[:32]>.<ext> (immutable, cached forever by Cloudflare and the app);
manifest.json maps logical paths ("icons/water.png", "data/species.json") to hashes. Old blobs are kept so
older app versions holding an older manifest keep working. The manifest goes up last, atomically.

  Server/content/publish.py            # dry run: prints what changes
  Server/content/publish.py --apply    # uploads to $MTJ_HOST (default mdm-ovh)
"""
import hashlib, json, os, shutil, subprocess, sys, tempfile, time
from pathlib import Path

root = Path(__file__).resolve().parents[2] / "Content"
host = os.environ.get("MTJ_HOST", "mdm-ovh")
remote = "/var/lib/mtj/content"
allowed = {".json", ".png", ".jpg", ".mov", ".webp"}

files, stage = {}, Path(tempfile.mkdtemp())
(stage / "b").mkdir()
for p in sorted(root.rglob("*")):
    if not p.is_file() or p.name.startswith("."):
        continue
    if p.suffix not in allowed:
        sys.exit(f"unsupported file {p}")
    data = p.read_bytes()
    if p.suffix == ".json":
        data = json.dumps(json.loads(data), ensure_ascii=False, separators=(",", ":")).encode()
    h = hashlib.sha256(data).hexdigest()[:32]
    (stage / "b" / f"{h}{p.suffix}").write_bytes(data)
    files[p.relative_to(root).as_posix()] = {"h": h + p.suffix, "n": len(data)}

# The app's offline floor: the same data files, minified and lzfse-compressed into the bundle.
seed = root.parent / "MyTinyJungle/Content/Seed"
for logical, f in files.items():
    if logical.startswith("data/"):
        raw = stage / "b" / f["h"]
        subprocess.run(["compression_tool", "-encode", "-a", "lzfse", "-i", str(raw), "-o", str(seed / (logical.replace("/", "_") + ".lzfse"))], check=True)

manifest = {"version": time.strftime("%Y%m%d%H%M%S", time.gmtime()), "files": files}
(stage / "manifest.json").write_text(json.dumps(manifest, separators=(",", ":"), sort_keys=True))
total = sum(f["n"] for f in files.values())
print(f"{len(files)} files, {total/1e6:.1f} MB")

if "--apply" not in sys.argv:
    print("dry run; pass --apply to publish")
    sys.exit(0)
run = lambda *a: subprocess.run(a, check=True)
run("ssh", host, f"install -d -m 0755 {remote} {remote}/b")
# tar -k keeps existing blobs untouched (they are immutable by name).
subprocess.run(f"tar -C {stage}/b -cf - . | ssh {host} 'tar -C {remote}/b -xkf - 2>/dev/null; chmod 0644 {remote}/b/*'", shell=True, check=True)
run("scp", "-q", str(stage / "manifest.json"), f"{host}:{remote}/manifest.json.new")
run("ssh", host, f"chmod 0644 {remote}/manifest.json.new && mv {remote}/manifest.json.new {remote}/manifest.json")
shutil.rmtree(stage)
print("published", manifest["version"])
