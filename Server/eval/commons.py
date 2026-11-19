"""Wikimedia Commons helpers: search CC/PD photos of a plant and fetch ≤480 px thumbnails with credits."""
import json, re, time, urllib.parse, urllib.request

UA = "MyTinyJungle-brain/1.0 (support@simpleappscompany.com)"
API = "https://commons.wikimedia.org/w/api.php"
SKIP = re.compile(r"herbari|illustrat|drawing|specimen|map|stamp|seed|botanical|plate|\bsheet\b|distribution|logo|diagram|lithograph|kohler|curtis|\.(svg|tiff?|gif|pdf|webm|ogv)$", re.I)
OKLIC = re.compile(r"^(cc[- ]by|cc[- ]by[- ]sa|cc0|public domain|pd)", re.I)


def get(url, tries=4):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=40) as r:
                return r.read()
        except Exception:
            if i == tries - 1:
                raise
            time.sleep(2 + 3 * i)


def clean(html):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", html or "")).strip()[:120]


def search(query, limit=40):
    """Photos for a query: [{title, thumb, author, licence}] filtered to free licences, no drawings or sheets."""
    q = {"action": "query", "format": "json", "generator": "search", "gsrsearch": f"{query} filetype:bitmap",
         "gsrnamespace": 6, "gsrlimit": limit, "prop": "imageinfo", "iiprop": "url|extmetadata|size", "iiurlwidth": 480}
    d = json.loads(get(API + "?" + urllib.parse.urlencode(q)))
    out = []
    for p in sorted(d.get("query", {}).get("pages", {}).values(), key=lambda p: p.get("index", 0)):
        t = p["title"]
        ii = (p.get("imageinfo") or [{}])[0]
        md = ii.get("extmetadata", {})
        lic = clean(md.get("LicenseShortName", {}).get("value"))
        if SKIP.search(t) or not OKLIC.match(lic) or not ii.get("thumburl") or ii.get("width", 0) < 300:
            continue
        out.append({"title": t, "thumb": ii["thumburl"], "author": clean(md.get("Artist", {}).get("value")) or "unknown", "licence": lic})
    return out
