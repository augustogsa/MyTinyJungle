#!/usr/bin/env python3
"""Brain eval against the live API (run as root on the VPS, like integration.sh).

  sudo python3 /tmp/eval/run.py            # full run, prints metrics, exits 1 if a threshold fails
  sudo python3 /tmp/eval/run.py --quick    # the deploy check: every ask/care-plan case, all identify photos,
                                           # a slice of diagnose and scene photos (the vision model is slow on CPU)

Two throwaway users (Plus through a referral, so diagnose is allowed), deleted at the end.
Identify counts a hit when the answer is the labelled species or a cultivar of the same species.
"""
import base64, http.client, json, os, socket, subprocess, sys, time
from pathlib import Path

HERE = Path(__file__).resolve().parent
QUICK = "--quick" in sys.argv
SOCK = "/run/mtj/api.sock"
TH = {"identify_top1": 0.85, "identify_top3": 0.95, "diagnose_top3": 0.80, "ask_lang": 0.85, "careplan": 0.95, "scene_field": 0.70}
MAX = {"identify_p50": 0.6, "identify_p95": 1.5}  # seconds, measured live on uncached photos


class UConn(http.client.HTTPConnection):
    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect(SOCK)


def call(tok, path, body=None, method="POST", retry=True):
    st, r = _call(tok, path, body, method)
    if st == 429 and retry:  # daily quota: the eval users are throwaway, reset theirs and go on
        psql("delete from api_quota where subject in (select 'u:' || id::text from users where email like 'ieval-%@mytinyjungle.test')")
        st, r = _call(tok, path, body, method)
    return st, r


def _call(tok, path, body=None, method="POST"):
    c = UConn("x", timeout=130)
    c.request(method, path, json.dumps(body) if body is not None else None, {"Authorization": f"Bearer {tok}", "Content-Type": "application/json"})
    r = c.getresponse()
    data = r.read()
    try:
        return r.status, json.loads(data or b"{}")
    except ValueError:
        return r.status, {}


def psql(q):
    return subprocess.run(["/opt/mtj/bin/mtj-psql", "-d", "mytinyjungle", "-Atq", "-c", q], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, stdin=subprocess.DEVNULL).stdout.strip()


def api_env():
    env = dict(os.environ)
    for line in open("/opt/mtj/secrets/api.env"):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env[k] = v.strip().strip("'\"")
    return env


def token(email):
    return subprocess.run(env=api_env(), args=["runuser", "-u", "mtj-api", "-g", "nobody", "-G", "mtj-api", "--", "/opt/mtj/bin/mtj-api", "test-token", email], stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, check=True).stdout.strip()


def photo(f, fresh=False):
    b = (HERE / f).read_bytes()
    if fresh:  # same pixels, different bytes: a JPEG comment defeats the server's sha256 cache (honest timing)
        c = b"eval " + os.urandom(8).hex().encode()
        b = b[:2] + b"\xff\xfe" + (len(c) + 2).to_bytes(2, "big") + c + b[2:]
    return base64.b64encode(b).decode()


def q(xs, p):
    s = sorted(xs)
    return s[min(len(s) - 1, int(len(s) * p))] if s else 0


def species_base():
    man = json.load(open("/var/lib/mtj/content/manifest.json"))
    sp = json.load(open("/var/lib/mtj/content/b/" + man["files"]["data/species.json"]["h"]))
    out = {}
    for s in sp:
        w = (s.get("scientific") or "").replace("×", "").replace("'", " '").split()
        out[s["id"]] = " ".join(x for x in w[:2] if not x.startswith("'")).lower()
    return out


def hit_species(base, got, want):
    """Same id, same species (cultivars count), or a genus label answered with a species of that genus."""
    g, w = base.get(got, ""), base.get(want, "")
    if got == want or (g and g == w):
        return True
    return bool(g and w) and ((" " not in w and g.split()[0] == w) or (" " not in g and w.split()[0] == g))


def pct(a, b):
    return a / b if b else 0.0


def main():
    A, B = token("ieval-a@mytinyjungle.test"), token("ieval-b@mytinyjungle.test")
    results, fails = {}, []
    try:
        _, rc = call(A, "/v1/me/referral", method="GET")
        call(B, f"/v1/referrals/{rc['code']}/redeem")
        base = species_base()

        # Identify (species only: the scene is checked on its own below).
        cases = json.load(open(HERE / "identify.json"))
        t1 = t3 = 0
        misses, lat = [], []
        for c in cases:
            t0 = time.time()
            _, r = call(A, "/v1/brain/identify", {"photo": photo(c["file"], fresh=True), "lang": "en", "scene": False})
            lat.append(time.time() - t0)
            got = [x["id"] for x in r.get("candidates", [])]
            same = [hit_species(base, g, c["expect"]) for g in got]
            t1 += bool(same[:1] and same[0])
            t3 += any(same[:3])
            if not (same[:1] and same[0]):
                misses.append(f"{c['file']} -> {got[:3]}")
        results["identify_top1"], results["identify_top3"] = pct(t1, len(cases)), pct(t3, len(cases))
        print(f"identify  top-1 {t1}/{len(cases)} = {results['identify_top1']:.0%}   top-3 {t3}/{len(cases)} = {results['identify_top3']:.0%}")
        for m in misses:
            print("   miss", m)
        results["identify_p50"], results["identify_p95"] = q(lat, 0.5), q(lat, 0.95)
        t0 = time.time(); call(A, "/v1/brain/identify", {"photo": photo(cases[0]["file"]), "lang": "en"}); call(A, "/v1/brain/identify", {"photo": photo(cases[0]["file"]), "lang": "en"})
        print(f"identify  latency p50 {results['identify_p50'] * 1000:.0f} ms  p95 {results['identify_p95'] * 1000:.0f} ms (uncached)   cached {(time.time() - t0) * 500:.0f} ms")
        st, r = call(A, "/v1/brain/identify", {"photo": photo(cases[1]["file"], fresh=True), "lang": "en"})
        assert st == 200 and r.get("scene", {}).get("soil") and r.get("sceneDepth") in ("quick", "full"), r

        # Multi-photo scans: both photos of a species as one scan (fused species vote, one charge).
        by = {}
        for c in cases:
            by.setdefault(c["expect"], []).append(c["file"])
        m1 = mn = 0
        for sp_, fs in by.items():
            if len(fs) < 2:
                continue
            st, r = call(A, "/v1/brain/identify", {"photos": [{"photo": photo(fs[0], fresh=True), "kind": "whole"}, {"photo": photo(fs[1], fresh=True), "kind": "leaf"}], "lang": "pt-BR"})
            got = [x["id"] for x in r.get("candidates", [])]
            mn += 1
            m1 += bool(got) and hit_species(base, got[0], sp_)
            assert st == 200 and r.get("used") == ["whole", "leaf"] and isinstance(r.get("tips"), list), r
            if r["tips"]:
                assert all(t["kind"] in ("flower", "stem") and t["why"] for t in r["tips"]), r["tips"]
        results["identify_multi_top1"] = pct(m1, mn)
        print(f"identify  multi-photo top-1 {m1}/{mn} = {results['identify_multi_top1']:.0%} (single {results['identify_top1']:.0%})")
        if results["identify_multi_top1"] + 1e-9 < results["identify_top1"]:
            fails.append("multi-photo identify worse than single")

        # Ask, per language.
        per = {}
        for c in json.load(open(HERE / "ask.json")):
            for lang, q in c["q"].items():
                _, r = call(A, "/v1/brain/ask", {"q": q, "lang": lang, **c.get("with", {})})
                ids = [a.get("id") for a in r.get("answers", [])]
                hit = any(i in c["expect"] for i in ids)
                n, h = per.get(lang, (0, 0))
                per[lang] = (n + 1, h + hit)
                if not hit:
                    print(f"   ask miss {lang}: {q} -> {ids[:6]}")
        worst = min(pct(h, n) for n, h in per.values())
        results["ask_lang"] = worst
        print("ask       " + "  ".join(f"{l} {h}/{n}" for l, (n, h) in sorted(per.items())) + f"   worst {worst:.0%}")

        # Care plans for real situations.
        cps = json.load(open(HERE / "careplan.json"))
        ok = 0
        for c in cps:
            _, r = call(A, "/v1/brain/care-plan", c["in"])
            e, why = c["expect"], []
            if "waterStyle" in e and r.get("waterStyle") != e["waterStyle"]:
                why.append(f"waterStyle {r.get('waterStyle')}")
            if "medium" in e and r.get("medium") != e["medium"]:
                why.append(f"medium {r.get('medium')}")
            if e.get("feedZero") and r.get("feedEveryWeeks") != 0:
                why.append(f"feed {r.get('feedEveryWeeks')}")
            if "advice" in e and not set(e["advice"]) & set(r.get("adviceIds") or []):
                why.append(f"advice {r.get('adviceIds')}")
            if e.get("warning") and not any(e["warning"].lower() in w.lower() for w in r.get("warnings") or []):
                why.append(f"warnings {r.get('warnings')}")
            if e.get("followUps") and len(r.get("followUps") or []) < e["followUps"]:
                why.append(f"followUps {r.get('followUps')}")
            if e.get("weatherNote") and not any(e["weatherNote"].lower() in w.lower() for w in r.get("weatherNotes") or []):
                why.append(f"weatherNotes {r.get('weatherNotes')}")
            if "waterMin" in e and (r.get("waterEveryDays") or [0])[0] < e["waterMin"]:
                why.append(f"water {r.get('waterEveryDays')}")
            if "waterMax" in e and (r.get("waterEveryDays") or [0, 99])[1] > e["waterMax"]:
                why.append(f"water {r.get('waterEveryDays')}")
            ok += not why
            if why:
                print(f"   care-plan miss {c['name']}: {'; '.join(why)}")
        results["careplan"] = pct(ok, len(cps))
        print(f"care-plan {ok}/{len(cps)} = {results['careplan']:.0%}")

        # Diagnose (photo + the owner's short note, as the app sends it).
        dx = json.load(open(HERE / "diagnose.json"))
        if QUICK:
            dx = dx[::5]
        hit = 0
        for c in dx:
            psql("delete from ai_usage")  # the eval account would hit the daily cap
            st, r = call(B, "/v1/diagnose", {"photo": photo(c["file"]), "note": c.get("note", ""), "lang": c.get("lang", "en"), "species": c.get("species", "")})
            ids = r.get("ids") or []
            h = any(i in c["expect"] for i in ids[:3])
            hit += h
            if not h:
                print(f"   diagnose miss {c['file']}: {ids} ({st})")
        # Multi-photo diagnosis: two photos of the same problem (leaf + underside) as one scan.
        allx = json.load(open(HERE / "diagnose.json"))
        pairs, seen = [], {}
        for c in allx:
            k = c["expect"][0]
            if k in seen and len(pairs) < (2 if QUICK else 6):
                pairs.append((seen.pop(k), c))
            else:
                seen[k] = c
        mh = 0
        for a, b in pairs:
            psql("delete from ai_usage")
            st, r = call(B, "/v1/diagnose", {"photos": [{"photo": photo(a["file"], fresh=True), "kind": "leaf"}, {"photo": photo(b["file"], fresh=True), "kind": "underside"}],
                                             "note": a.get("note", ""), "lang": a.get("lang", "en"), "species": a.get("species", "")})
            ok = st == 200 and r.get("used") == ["leaf", "underside"] and any(i in a["expect"] for i in (r.get("ids") or [])[:3])
            mh += ok
            if not ok:
                print(f"   diagnose multi miss {a['file']}+{b['file']}: {r.get('ids')} used={r.get('used')} ({st})")
        print(f"diagnose  multi-photo top-3 {mh}/{len(pairs)}")
        if pairs and pct(mh, len(pairs)) < TH["diagnose_top3"]:
            fails.append(f"diagnose multi {mh}/{len(pairs)}")
        results["diagnose_top3"] = pct(hit, len(dx))
        print(f"diagnose  top-3 {hit}/{len(dx)} = {results['diagnose_top3']:.0%}")

        # Scene fields.
        sc = json.load(open(HERE / "scene.json"))
        if QUICK:
            sc = sc[::4]
        fields = {}
        for c in sc:
            _, r = call(A, "/v1/brain/scene", {"photo": photo(c["file"]), "lang": "en"})
            s = r.get("scene", {})
            for path, want in c["expect"].items():
                v = s
                for k in path.split("."):
                    v = (v or {}).get(k, {})
                got = v.get("value") if isinstance(v, dict) else None
                n, h = fields.get(path, (0, 0))
                fields[path] = (n + 1, h + (got == want))
                if got != want:
                    print(f"   scene miss {c['file']} {path}: {got} (want {want})")
        tot_n = sum(n for n, _ in fields.values()); tot_h = sum(h for _, h in fields.values())
        results["scene_field"] = pct(tot_h, tot_n)
        print("scene     " + "  ".join(f"{p} {h}/{n}" for p, (n, h) in sorted(fields.items())) + f"   overall {results['scene_field']:.0%}")
    finally:
        psql("delete from users where email like 'ieval-%@mytinyjungle.test'")
    for k, v in TH.items():
        if results.get(k, 0) < v:
            fails.append(f"{k} {results.get(k, 0):.0%} < {v:.0%}")
    for k, v in MAX.items():
        if results.get(k, 99) > v:
            fails.append(f"{k} {results.get(k, 99):.2f}s > {v}s")
    print("PASS all thresholds" if not fails else "FAIL " + ", ".join(fails))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
