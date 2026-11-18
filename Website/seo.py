"""SEO layer for mytinyjungle.com: share cards, structured data, sitemap, robots, llms.txt, manifest, 404, /get landing, server rules."""
import hashlib
import html as H
import json
import re
from datetime import date
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).parent
SITE = "https://mytinyjungle.com"
APP_ID = "6836292367"
APP_STORE = f"https://apps.apple.com/app/id{APP_ID}"
TESTFLIGHT = "https://testflight.apple.com/join/A8YUuUHj"
BRAND = "My Tiny Jungle"
ORG = "SimpleAppsCo LLC"
LASTMOD = date.today().isoformat()
INDEXNOW_KEY = "5f2b9c7e1a4d4e08b3c6a9f0d2e7b415"
GREEN, INK, CREAM, MUTED = (31, 85, 48), (24, 36, 28), (252, 250, 246), (96, 110, 100)
LOCALE = {"en": "en_US", "pt": "pt_BR"}
NOINDEX = {"/plus", "/404"}
CACHE = ROOT / ".og-cache"
HOME_DESC = {}
PAGES = []  # (L, path) for sitemap
CRUMB = {"en": {"features": "Features", "home": "Home"}, "pt": {"features": "Recursos", "home": "Início"}}


def _font(size, weight):
    f = ImageFont.truetype(str(ROOT / "tools" / "Intern.ttf"), size)
    f.set_variation_by_axes([min(32, max(14, size // 3)), weight])
    return f


def _wrap(d, text, font, width):
    lines, cur = [], ""
    for w in text.split():
        t = (cur + " " + w).strip()
        if d.textlength(t, font=font) <= width:
            cur = t
        else:
            lines.append(cur); cur = w
    return lines + [cur] if cur else lines


def _slug_icon(path):
    from site_pages import FEATURES
    m = re.match(r"/features/([\w-]+)$", path)
    if m:
        for ic, (slug, _) in FEATURES.items():
            if slug == m[1]:
                return ic
    return None


def og_image(L, path, title, desc, dist):
    """1200x630 share card per page and language, cached by content."""
    name = f"{L}-{path.strip('/').replace('/', '-') or 'home'}"
    out = dist / "og" / f"{name}.png"
    key = hashlib.sha1(f"v4|{L}|{path}|{title}|{desc}".encode()).hexdigest()[:12]
    cached = CACHE / f"{name}-{key}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    if not cached.exists():
        CACHE.mkdir(exist_ok=True)
        for old in CACHE.glob(f"{name}-*.png"):
            old.unlink()
        _render(L, path, title, desc, cached)
    out.write_bytes(cached.read_bytes())
    return f"{SITE}/og/{name}.png?v={key}"


def _render(L, path, title, desc, dest):
    W, Ht = 1200, 630
    im = Image.new("RGB", (W, Ht), CREAM)
    d = ImageDraw.Draw(im)
    src = ROOT / "src"
    ic = _slug_icon(path)
    # right visual: phone screenshot on home/features hub, 3D icon on features, mascot elsewhere
    if path in ("/", "/features", "/get"):
        shot = Image.open(src / "assets" / ("app-pt" if L == "pt" else "app") / "today1.jpg").convert("RGB")
        sw = 270; sh = int(shot.height * sw / shot.width)
        shot = shot.resize((sw, sh), Image.LANCZOS)
        frame = Image.new("RGBA", (sw + 24, min(sh, 560) + 24), (0, 0, 0, 0))
        fd = ImageDraw.Draw(frame); fd.rounded_rectangle((0, 0, frame.width - 1, frame.height - 1), 46, fill=(20, 24, 22))
        mask = Image.new("L", (sw, min(sh, 560)), 0); ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, min(sh, 560) - 1), 36, fill=255)
        frame.paste(shot.crop((0, 0, sw, min(sh, 560))), (12, 12), mask)
        im.paste(frame, (W - frame.width - 90, 50), frame)
    else:
        p = src / "icons" / f"{ic}.png" if ic else src / "assets" / "erty" / "erty-wave.png"
        art = Image.open(p).convert("RGBA")
        s = 300 if ic else 330
        art = art.resize((s, int(art.height * s / art.width)), Image.LANCZOS)
        d.ellipse((W - 470, 115, W - 70, 515), fill=(234, 242, 230))
        im.paste(art, (W - 270 - s // 2, 315 - art.height // 2), art)
    x, maxw = 80, 640
    d.text((x, 70), BRAND, font=_font(34, 650), fill=GREEN)
    t = title.replace(f" · {BRAND}", "").replace(f"{BRAND}: ", "")
    t = t[:1].upper() + t[1:]
    size = 68
    while True:
        tf = _font(size, 720); lines = _wrap(d, t, tf, maxw)
        if len(lines) <= 3 or size <= 44:
            break
        size -= 4
    y = 170
    for ln in lines[:3]:
        d.text((x, y), ln, font=tf, fill=INK); y += int(size * 1.12)
    df = _font(28, 420)
    dl = _wrap(d, desc, df, maxw)
    if len(dl) > 3:
        dl = _wrap(d, re.split(r"(?<=[.!?])\s", desc)[0], df, maxw)
    for ln in dl[:3]:
        d.text((x, y + 24), ln, font=df, fill=MUTED); y += 38
    foot = "Grátis no iPhone · mytinyjungle.com" if L == "pt" else "Free on iPhone · mytinyjungle.com"
    d.text((x, Ht - 80), foot, font=_font(26, 560), fill=GREEN)
    im.save(dest, optimize=True)


def _ld(obj):
    return '<script type="application/ld+json">' + json.dumps(obj, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/") + "</script>"


def _app(L):
    return {
        "@type": "MobileApplication", "@id": f"{SITE}/#app", "name": BRAND,
        "operatingSystem": "iOS 26.0 or later", "applicationCategory": "LifestyleApplication",
        "applicationSubCategory": "Plant care", "url": SITE + ("/pt/" if L == "pt" else "/"),
        "downloadUrl": TESTFLIGHT, "installUrl": TESTFLIGHT, "sameAs": [APP_STORE],
        "image": f"{SITE}/assets/icon-512.png", "inLanguage": ["en", "pt-BR"],
        "screenshot": [f"{SITE}/assets/{'app-pt' if L == 'pt' else 'app'}/{s}.jpg" for s in ("today1", "plant-chat", "care-week", "scan-result")],
        "publisher": {"@id": f"{SITE}/#org"}, "author": {"@id": f"{SITE}/#org"},
        "offers": [
            {"@type": "Offer", "name": "Sprout", "price": "0", "priceCurrency": "EUR", "category": "free"},
            {"@type": "Offer", "name": "Greenhouse", "price": "1.99", "priceCurrency": "EUR", "category": "subscription",
             "priceSpecification": {"@type": "UnitPriceSpecification", "price": "1.99", "priceCurrency": "EUR", "billingDuration": "P1M"}},
            {"@type": "Offer", "name": "Jungle", "price": "11.99", "priceCurrency": "EUR", "category": "subscription",
             "priceSpecification": {"@type": "UnitPriceSpecification", "price": "11.99", "priceCurrency": "EUR", "billingDuration": "P1Y"}},
        ],
        "description": HOME_DESC.get(L, ""),
    }


def jsonld(L, path, title, desc, canon, img):
    lang = "pt-BR" if L == "pt" else "en"
    pre = "/pt" if L == "pt" else ""
    graph = [
        {"@type": "Organization", "@id": f"{SITE}/#org", "name": ORG, "alternateName": "Simple Apps Company",
         "url": "https://simpleappscompany.com", "logo": f"{SITE}/assets/icon-512.png",
         "email": "support@simpleappscompany.com", "address": {"@type": "PostalAddress", "addressLocality": "Lisbon", "addressCountry": "PT"},
         "brand": {"@type": "Brand", "name": BRAND, "logo": f"{SITE}/assets/icon-512.png"}},
        {"@type": "WebSite", "@id": f"{SITE}/#website", "url": SITE + "/", "name": BRAND, "publisher": {"@id": f"{SITE}/#org"},
         "inLanguage": ["en", "pt-BR"]},
        {"@type": "WebPage", "@id": canon + "#page", "url": canon, "name": title, "description": desc, "inLanguage": lang,
         "isPartOf": {"@id": f"{SITE}/#website"}, "about": {"@id": f"{SITE}/#app"}, "dateModified": LASTMOD,
         "primaryImageOfPage": {"@type": "ImageObject", "url": img, "width": 1200, "height": 630}},
    ]
    if path in ("/", "/features") or path.startswith("/features/") or path == "/get":
        graph.append(_app(L))
    if path != "/":
        items = [(CRUMB[L]["home"], f"{SITE}{pre}/")]
        if path.startswith("/features/"):
            items.append((CRUMB[L]["features"], f"{SITE}{pre}/features"))
        items.append((title.replace(f" · {BRAND}", ""), canon))
        graph.append({"@type": "BreadcrumbList", "itemListElement": [
            {"@type": "ListItem", "position": i + 1, "name": n, "item": u} for i, (n, u) in enumerate(items)]})
        graph[2]["breadcrumb"] = {"@id": canon + "#crumbs"}; graph[-1]["@id"] = canon + "#crumbs"
    return _ld({"@context": "https://schema.org", "@graph": graph})


def head(L, path, title, desc, canon, dist):
    """Extra <head> tags: robots, Open Graph, X card, schema, manifest."""
    img = og_image(L, path, title, desc, dist)
    PAGES.append((L, path))
    other = "pt" if L == "en" else "en"
    e = H.escape
    robots = "noindex,follow" if path in NOINDEX else "index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1"
    return (f'<meta name="robots" content="{robots}">'
            f'<meta property="og:type" content="website"><meta property="og:site_name" content="{BRAND}">'
            f'<meta property="og:locale" content="{LOCALE[L]}"><meta property="og:locale:alternate" content="{LOCALE[other]}">'
            f'<meta property="og:image" content="{img}"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630">'
            f'<meta property="og:image:alt" content="{e(title)}">'
            f'<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="{e(title)}">'
            f'<meta name="twitter:description" content="{e(desc)}"><meta name="twitter:image" content="{img}">'
            f'<meta name="application-name" content="{BRAND}"><meta name="apple-mobile-web-app-title" content="{BRAND}">'
            f'<meta name="format-detection" content="telephone=no">'
            f'<link rel="manifest" href="/site.webmanifest"><link rel="author" href="{SITE}/humans.txt">'
            + jsonld(L, path, title, desc, canon, img))


def sitemap(langs):
    """Sitemap with hreflang alternates and lastmod; noindex pages left out."""
    paths = []
    for L, p in PAGES:
        if p not in NOINDEX and p not in paths:
            paths.append(p)
    rows = []
    for p in paths:
        alts = "".join(f'<xhtml:link rel="alternate" hreflang="{langs[k]["lang"]}" href="{SITE}{langs[k]["prefix"]}{p}"/>' for k in langs)
        alts += f'<xhtml:link rel="alternate" hreflang="x-default" href="{SITE}{p}"/>'
        for k in langs:
            rows.append(f"<url><loc>{SITE}{langs[k]['prefix']}{p}</loc><lastmod>{LASTMOD}</lastmod>{alts}</url>")
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" '
            'xmlns:xhtml="http://www.w3.org/1999/xhtml">\n' + "\n".join(rows) + "\n</urlset>\n")


ROBOTS = f"""# {BRAND}: everyone welcome, search and AI assistants alike.
User-agent: *
Allow: /

User-agent: Googlebot
User-agent: Bingbot
User-agent: Applebot
User-agent: Applebot-Extended
User-agent: OAI-SearchBot
User-agent: ChatGPT-User
User-agent: GPTBot
User-agent: PerplexityBot
User-agent: ClaudeBot
User-agent: Claude-SearchBot
User-agent: Google-Extended
Allow: /

Sitemap: {SITE}/sitemap.xml
"""


def llms(T, rows_by_lang):
    en = T["en"]
    lines = [f"# {BRAND}", "", f"> {en['home_desc']}", "",
             "iPhone app by SimpleAppsCo LLC (Lisbon). Free for up to 5 plants; Plus is €1.99 a month or €11.99 a year. "
             "Available in English and Brazilian Portuguese. Photos stay on the iPhone.", "",
             "## Pages", f"- [Home]({SITE}/): what the app does and pricing", f"- [Features]({SITE}/features): every feature",
             f"- [Good to know]({SITE}/good-to-know): all common questions", f"- [Support]({SITE}/support): contact and subscriptions",
             f"- [Privacy]({SITE}/privacy)", f"- [Terms]({SITE}/terms)", f"- [Get the app]({SITE}/get)", "", "## Features"]
    lines += [f"- [{title}]({SITE}/features/{slug}): {short}" for ic, slug, title, short, _ in rows_by_lang["en"]]
    lines += ["", "## Português (Brasil)", f"- [Início]({SITE}/pt/)", f"- [Recursos]({SITE}/pt/features)", f"- [Bom saber]({SITE}/pt/good-to-know)", ""]
    return "\n".join(lines)


def manifest():
    return json.dumps({"name": BRAND, "short_name": BRAND, "start_url": "/", "display": "browser", "background_color": "#FCFAF6",
                       "theme_color": "#FCFAF6", "icons": [{"src": "/assets/favicon-192.png", "sizes": "192x192", "type": "image/png"},
                                                           {"src": "/assets/icon-512.png", "sizes": "512x512", "type": "image/png"}],
                       "related_applications": [{"platform": "itunes", "url": APP_STORE, "id": APP_ID}]}, indent=1)


HUMANS = f"/* TEAM */\nMade by: Simple Apps Company\nSite: https://simpleappscompany.com\nFrom: Lisbon, Portugal\n\n/* SITE */\nLanguage: English, Português (Brasil)\nLast update: {LASTMOD}\n"
SECURITY = f"Contact: mailto:support@simpleappscompany.com\nExpires: {date.today().year + 1}-11-18T00:00:00.000Z\nPreferred-Languages: en, pt\nCanonical: {SITE}/.well-known/security.txt\n"

# Apache rules. Subdomains (get., app., br., pt., www.) map to the main site once DNS points them here.
HTACCESS = r"""Options -Indexes
DirectorySlash Off
ErrorDocument 404 /404.html
ErrorDocument 403 /404.html
AddDefaultCharset utf-8
AddType application/manifest+json .webmanifest
AddType text/plain .txt
RewriteEngine On
# one host, https only
RewriteCond %{HTTP_HOST} ^www\.mytinyjungle\.com$ [NC]
RewriteRule ^ https://mytinyjungle.com%{REQUEST_URI} [R=301,L]
# share subdomains
RewriteCond %{HTTP_HOST} ^(get|app|download|beta)\.mytinyjungle\.com$ [NC]
RewriteRule ^ https://mytinyjungle.com/get [R=301,L]
RewriteCond %{HTTP_HOST} ^(br|pt)\.mytinyjungle\.com$ [NC]
RewriteRule ^(.*)$ https://mytinyjungle.com/pt/$1 [R=301,L]
RewriteCond %{HTTPS} off
RewriteCond %{HTTP:X-Forwarded-Proto} !https
RewriteCond %{HTTP:CF-Visitor} !https
RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]
# share shortcuts
RewriteRule ^(download|app|ios|iphone|beta|testflight)/?$ /get [R=301,L]
RewriteRule ^pt/(baixar|app|download|beta)/?$ /pt/get [R=301,L]
RewriteCond %{THE_REQUEST} \s/+(.*?/)?index\.html[\s?]
RewriteRule ^(pt/)?index\.html$ /$1 [R=301,L]
RewriteCond %{THE_REQUEST} \s/+.+/index\.html[\s?]
RewriteRule ^(.+?)/index\.html$ /$1 [R=301,L]
# trailing slash: /pt/ is the only folder URL; everything else has none
RewriteRule ^pt$ /pt/ [R=301,L]
RewriteCond %{REQUEST_URI} !^/pt/$
RewriteCond %{ENV:REDIRECT_STATUS} ^$
RewriteCond %{REQUEST_FILENAME} !-f
RewriteRule ^(.+)/$ /$1 [R=301,L]
RewriteCond %{REQUEST_FILENAME} -d
RewriteCond %{REQUEST_FILENAME}/index.html -f
RewriteRule ^(.*[^/])$ $1/index.html [L]
<IfModule mod_deflate.c>
AddOutputFilterByType DEFLATE text/html text/css text/plain text/xml application/javascript application/json application/xml application/manifest+json image/svg+xml
</IfModule>
<IfModule mod_headers.c>
<FilesMatch "\.(jpg|jpeg|png|webp|webm|mov|mp4|woff2|ico)$">
Header set Cache-Control "public, max-age=2592000"
</FilesMatch>
<FilesMatch "\.(css|js)$">
Header set Cache-Control "public, max-age=31536000, immutable"
</FilesMatch>
<FilesMatch "\.(html|xml|txt|webmanifest)$">
Header set Cache-Control "public, max-age=600"
</FilesMatch>
<Files "apple-app-site-association">
Header set Content-Type application/json
</Files>
Header always set X-Content-Type-Options nosniff
Header always set Referrer-Policy strict-origin-when-cross-origin
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
Header always set X-Frame-Options SAMEORIGIN
Header always set Permissions-Policy "camera=(), microphone=(), geolocation=(), interest-cohort=()"
</IfModule>
"""


# Search titles for feature pages: what people type, then the brand. H1 keeps the friendly name.
FEATURE_TITLE = {
 "en": {"chat": "Plant care log by chat", "soil-check": "Soil moisture check for houseplants", "smart-reminders": "Smart plant watering reminders",
        "health-check": "Plant disease identifier by photo", "pests": "Houseplant pest identification and treatment", "repotting": "When to repot a plant",
        "travel-mode": "Plant care while on vacation", "cuttings": "Plant propagation from cuttings", "seasons": "Seasonal houseplant care guide",
        "label-scanner": "Fertilizer and potting mix label scanner", "spaces": "Plant care by room and light", "pets-and-kids": "Plants toxic to cats, dogs and kids"},
 "pt": {"chat": "Diário de cuidados das plantas por chat", "soil-check": "Como saber se a planta precisa de água", "smart-reminders": "Lembrete de regar plantas inteligente",
        "health-check": "Identificar doença de planta por foto", "pests": "Pragas em plantas: identificar e tratar", "repotting": "Quando trocar a planta de vaso",
        "travel-mode": "Como cuidar das plantas viajando", "cuttings": "Como fazer muda de planta", "seasons": "Cuidados com plantas em cada estação",
        "label-scanner": "Leitor de rótulo de adubo e substrato", "spaces": "Plantas por cômodo e luz", "pets-and-kids": "Plantas tóxicas para gatos, cachorros e crianças"},
}


def meta_desc(*parts, limit=155):
    """Joins sentences up to ~155 chars, never cutting one in half."""
    text = " ".join(re.sub(r"<[^>]+>", "", x).strip() for x in parts if x)
    out = ""
    for sent in re.split(r"(?<=[.!?])\s+", text):
        if len(out) + len(sent) + 1 > limit:
            continue
        out = (out + " " + sent).strip()
    return out or text[:limit - 1].rsplit(" ", 1)[0] + "…"
