#!/usr/bin/env python3
"""Merge Tools/l10n/staging/<lang>.json (full localization objects per catalog) and
staging/new-strings.json ({key: {lang: text}}) into the String Catalogs."""
import json, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ST = os.path.join(ROOT, "Tools/l10n/staging")
CATS = ["MyTinyJungle/Localizable.xcstrings", "MyTinyJungle/InfoPlist.xcstrings", "NotificationContent/Localizable.xcstrings"]
langs = sys.argv[1:]
cat = {c: json.load(open(os.path.join(ROOT, c))) for c in CATS}
for lang in langs:
    f = os.path.join(ST, f"{lang}.json")
    if not os.path.exists(f): continue
    d = json.load(open(f)); d = d.get("catalog", d)
    for c, keys in d.items():
        s = cat[c]["strings"]
        for k, loc in keys.items():
            if k in s: s[k].setdefault("localizations", {})[lang] = loc
new = json.load(open(os.path.join(ST, "new-strings.json")))
s = cat[CATS[0]]["strings"]
for k, by in new.items():
    if k not in s: continue
    for lang, text in by.items():
        if lang == "pt-BR" or lang in langs:
            s[k].setdefault("localizations", {})[lang] = {"stringUnit": {"state": "translated", "value": text}}
for k in ["", "Plus", "· mytinyjungle.com"]:
    if k in s: s[k]["shouldTranslate"] = False
for c in CATS:
    open(os.path.join(ROOT, c), "w").write(json.dumps(cat[c], ensure_ascii=False, indent=2, sort_keys=True) + "\n")
for lang in ["pt-BR"] + langs:
    miss = [k for k, v in s.items() if v.get("shouldTranslate", True) and lang not in v.get("localizations", {})]
    print(lang, "missing", len(miss), miss[:5])
