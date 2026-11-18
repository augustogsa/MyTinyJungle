#!/usr/bin/env python3
"""My Tiny Jungle localization pipeline. See Documentation/Localization.md.

  python3 Tools/l10n/l10n.py sync              # pull keys from the last build (build/dd) into the catalogs
  python3 Tools/l10n/l10n.py merge LANG F...   # fill catalog values for LANG from fragment JSON files
  python3 Tools/l10n/l10n.py data LANG F...    # build MyTinyJungle/Knowledge/Locales/LANG.json from text/name tables
  python3 Tools/l10n/l10n.py missing LANG      # write what still needs translating to build/l10n-missing-LANG.json
  python3 Tools/l10n/l10n.py check [LANG...]   # CI gate: fails on any missing translation or escaped literal

Fragment format: {"<catalog key>": {"comment": "...", "pt-BR": "text" | {"one": "...", "other": "..."}, "en": {...plural}}}
"""
import glob, json, os, re, subprocess, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CATALOGS = {"MyTinyJungle": "MyTinyJungle/Localizable.xcstrings", "NotificationContent": "NotificationContent/Localizable.xcstrings"}
INFOPLIST = "MyTinyJungle/InfoPlist.xcstrings"
ALLOW = os.path.join(os.path.dirname(__file__), "allowlist.txt")
LANGS = ["pt-BR"]
SPEC = re.compile(r"%(?:\d+\$)?(?:lld|ld|lf|@|d|f|\.\d+f|arg)")


def load(p): return json.load(open(os.path.join(ROOT, p)))
def save(p, d): open(os.path.join(ROOT, p), "w").write(json.dumps(d, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
def norm(k): return SPEC.sub("%", k)


def sync():
    for target, cat in CATALOGS.items():
        files = glob.glob(f"{ROOT}/build/dd/Build/Intermediates.noindex/MyTinyJungle.build/Release-*/{target}.build/**/*.stringsdata", recursive=True)
        if not files: sys.exit(f"no stringsdata for {target}: build first (build/dd)")
        subprocess.run(["xcrun", "xcstringstool", "sync", os.path.join(ROOT, cat), "--stringsdata", *files], check=True)
        d = load(cat)
        stale = [k for k, v in d["strings"].items() if v.get("extractionState") == "stale"]
        for k in stale: del d["strings"][k]
        save(cat, d)
        print(f"{cat}: {len(d['strings'])} keys, removed {len(stale)} stale")


def unit(v): return {"stringUnit": {"state": "translated", "value": v}}


def respec(value, key):
    """Rewrite the fragment's placeholders to the catalog key's real specifiers, keeping positions."""
    specs = SPEC.findall(key)
    plain = [re.sub(r"\d+\$", "", s) for s in specs]
    out, i = [], 0
    def rep(m):
        nonlocal i
        tok = m.group(0)
        pos = re.match(r"%(\d+)\$", tok)
        if pos:
            n = int(pos.group(1)) - 1
            return f"%{n+1}${plain[n][1:]}" if n < len(plain) else tok
        s = plain[i] if i < len(plain) else tok
        i += 1
        return (f"%{i}${s[1:]}" if len(plain) > 1 else s)
    return SPEC.sub(rep, value)


def loc(value, key):
    if isinstance(value, dict):
        return {"variations": {"plural": {f: unit(respec(v, key)) for f, v in value.items()}}}
    return unit(respec(value, key))


def merge(lang, frags):
    table = {}
    for f in frags:
        for k, v in json.load(open(f)).items(): table.setdefault(norm(k), v)
    for cat in CATALOGS.values():
        d = load(cat); hit = 0
        for k, e in d["strings"].items():
            f = table.get(norm(k))
            if not f or lang not in f: continue
            if "substitutions" in e.get("localizations", {}).get(lang, {}): continue  # hand-tuned multi-argument plural
            e.setdefault("localizations", {})[lang] = loc(f[lang], k)
            if isinstance(f.get("en"), dict): e["localizations"]["en"] = loc(f["en"], k)
            if f.get("comment") and not e.get("comment"): e["comment"] = f["comment"]
            hit += 1
        save(cat, d); print(f"{cat}: filled {hit}/{len(d['strings'])}")


def data_strings():
    """Every translatable English string in the bundled knowledge data (same rules as L10nData.swift)."""
    frozen = {"id", "scientific", "en", "pt", "family", "waterStyle", "light", "mix", "feed", "growth", "group", "groups",
              "pests", "tags", "wikidata", "aliases", "icon", "symbol", "kind", "species", "ids", "url"}
    out = set()
    def walk(o, key=None):
        if key in frozen and not (isinstance(o, list) and o and isinstance(o[0], dict)): return
        if isinstance(o, str):
            if re.search("[A-Za-z]{2}", o) and not re.fullmatch(r"[a-z0-9-]+", o) and not o.startswith("http"): out.add(o)
        elif isinstance(o, list): [walk(i, key) for i in o]
        elif isinstance(o, dict): [walk(v, k) for k, v in o.items()]
    walk(load("MyTinyJungle/Knowledge/species.json")); walk(load("MyTinyJungle/Knowledge/knowledge.json"))
    return out


def data(lang, files):
    text, names = {}, {}
    for f in files:
        d = json.load(open(f))
        (names if os.path.basename(f).startswith("names") else text).update(d)
    need = data_strings()
    text = {k: v for k, v in text.items() if k in need}
    os.makedirs(f"{ROOT}/MyTinyJungle/Knowledge/Locales", exist_ok=True)
    save(f"MyTinyJungle/Knowledge/Locales/{lang}.json", {"names": names, "text": text})
    print(f"{lang}: {len(names)} names, {len(text)}/{len(need)} texts")


def looks_user_facing(k):
    """Heuristic for literals the extractor could not prove are keys: sentence-like, starts uppercase,
    not a regex, not a parser keyword (lowercase), not a Latin family name or a short code."""
    if re.search(r"[\\^$|()\[\]{}]", k) or k.endswith("aceae") or len(k) < 3: return False
    if not re.match(r"[A-Z]", k): return False
    return bool(re.search(r"[A-Za-z]{2,}\s+[A-Za-z]{2,}", k) or re.fullmatch(r"[A-Z][a-z]{2,}[.!?]?", k))


def potential_literals():
    """String literals in Swift that look user-facing but are not in any catalog."""
    out = tempfile.mkdtemp()
    srcs = [f for d in CATALOGS for f in glob.glob(f"{ROOT}/{d}/**/*.swift", recursive=True)]
    subprocess.run(["xcrun", "xcstringstool", "extract", "--modern-localizable-strings", "--all-potential-swift-keys", *srcs, "-o", out], check=True, capture_output=True)
    keys = set()
    for c in CATALOGS.values(): keys |= {norm(k) for k in load(c)["strings"]}
    allow = set()
    if os.path.exists(ALLOW):
        allow = {l.rstrip("\n") for l in open(ALLOW) if l.strip() and not l.startswith("#")}
    bad = []
    for f in glob.glob(f"{out}/*.stringsdata"):
        sd = json.load(open(f))
        for table, items in sd["tables"].items():
            for it in items:
                k = it["key"]
                if norm(k) in keys or k in allow: continue
                if table == "__PotentialKeys" and not looks_user_facing(k): continue
                if True:
                    bad.append(f"{os.path.relpath(sd['source'], ROOT)}:{it['location']['startingLine']}: {k!r}")
    return sorted(set(bad))


def missing(lang):
    gaps = {}
    for cat in list(CATALOGS.values()) + [INFOPLIST]:
        for k, e in load(cat)["strings"].items():
            if e.get("shouldTranslate") is False or not re.search("[A-Za-z]", k): continue
            l = e.get("localizations", {}).get(lang)
            ok = l and (l.get("stringUnit", {}).get("state") == "translated" or "variations" in l)
            if not ok: gaps.setdefault(cat, []).append(k)
    p = f"{ROOT}/MyTinyJungle/Knowledge/Locales/{lang}.json"
    tab = json.load(open(p)) if os.path.exists(p) else {"names": {}, "text": {}}
    dm = sorted(s for s in data_strings() if s not in tab.get("text", {}))
    ids = {s["id"] for s in load("MyTinyJungle/Knowledge/species.json")}
    nm = sorted(ids - set(tab.get("names", {})))
    return gaps, dm, nm


def check(langs):
    fail = 0
    for lang in langs:
        gaps, dm, nm = missing(lang)
        for cat, ks in gaps.items():
            fail += len(ks); print(f"✗ {cat}: {len(ks)} keys missing {lang}", *ks[:20], sep="\n   ")
        if dm: fail += len(dm); print(f"✗ data: {len(dm)} knowledge strings missing {lang}", *dm[:10], sep="\n   ")
        if nm: fail += len(nm); print(f"✗ data: {len(nm)} species names missing {lang}", *nm[:10], sep="\n   ")
    lit = potential_literals()
    if lit:
        fail += len(lit)
        print(f"✗ {len(lit)} user-facing literals outside the catalog (localize, or add to Tools/l10n/allowlist.txt if not user-facing):", *lit, sep="\n   ")
    print("✓ localization complete" if not fail else f"{fail} problems")
    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    cmd, *args = sys.argv[1:] or ["check"]
    if cmd == "sync": sync()
    elif cmd == "merge": merge(args[0], args[1:])
    elif cmd == "data": data(args[0], args[1:])
    elif cmd == "missing":
        g, dm, nm = missing(args[0])
        os.makedirs(f"{ROOT}/build", exist_ok=True)
        json.dump({"catalog": g, "data": dm, "names": nm}, open(f"{ROOT}/build/l10n-missing-{args[0]}.json", "w"), ensure_ascii=False, indent=1)
        print(f"build/l10n-missing-{args[0]}.json")
    elif cmd == "check": check(args or LANGS)
    else: sys.exit(__doc__)
