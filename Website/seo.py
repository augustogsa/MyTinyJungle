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
    say = SAY[L].get(path, SAY[L]["default"])
    key = hashlib.sha1(f"v11|{L}|{path}|{title}|{desc}|{say}".encode()).hexdigest()[:12]
    cached = CACHE / f"{name}-{key}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    if not cached.exists():
        CACHE.mkdir(exist_ok=True)
        for old in CACHE.glob(f"{name}-*.png"):
            old.unlink()
        _render(L, path, title, desc, cached)
    out.write_bytes(cached.read_bytes())
    return f"{SITE}/og/{name}.png?v={key}"


ERTY_FOR = {"/": "wave", "/get": "wave", "/features": "celebrate", "/good-to-know": "learn", "/plus": "award",
            "/support": "love", "/404": "rain", "/features/chat": "love", "/features/soil-check": "soil",
            "/features/smart-reminders": "water", "/features/health-check": "scan", "/features/pests": "scan",
            "/features/repotting": "soil", "/features/travel-mode": "sleep", "/features/cuttings": "celebrate",
            "/features/seasons": "rain", "/features/label-scanner": "soilbag", "/features/spaces": "idle",
            "/features/pets-and-kids": "love"}
WARM_TOP, WARM_BOT, PEACH, INK_W, MUTED_W, LEAF_W = (255, 248, 238), (252, 233, 214), (255, 222, 192), (52, 38, 28), (128, 104, 86), (46, 98, 58)


def _rounded(img, r):
    m = Image.new("L", img.size, 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, img.width - 1, img.height - 1), r, fill=255)
    img.putalpha(m); return img


def _shadow(size, box, r, blur, alpha):
    from PIL import ImageFilter
    sh = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(box, r, fill=(120, 70, 30, alpha))
    return sh.filter(ImageFilter.GaussianBlur(blur))


SAY = {"en": {"/": "Hi! I'm Erty", "default": "Hi! I'm Erty", "/404": "Oops, wrong pot"},
       "pt": {"/": "Oi! Eu sou o Raminho", "default": "Oi! Eu sou o Raminho", "/404": "Ops, vaso errado"}}


def _leaf(im, x, y, s, ang, col):
    lf = Image.new("RGBA", (s, s), (0, 0, 0, 0)); ld = ImageDraw.Draw(lf)
    ld.ellipse((s * .2, 0, s * .8, s), fill=col); ld.line((s / 2, s * .1, s / 2, s * .95), fill=(255, 255, 255, 90), width=max(2, s // 18))
    lf = lf.rotate(ang, resample=Image.BICUBIC, expand=True); im.alpha_composite(lf, (int(x), int(y)))


def _render(L, path, title, desc, dest):
    from PIL import ImageFilter
    W, Ht = 1200, 630
    src = ROOT / "src"
    im = Image.new("RGBA", (W, Ht))
    for y in range(Ht):
        k = y / Ht
        im.paste(tuple(int(WARM_TOP[i] + (WARM_BOT[i] - WARM_TOP[i]) * k) for i in range(3)) + (255,), (0, y, W, y + 1))
    # sun glow behind Erty
    glow = Image.new("RGBA", (W, Ht), (0, 0, 0, 0)); gd = ImageDraw.Draw(glow)
    gd.ellipse((640, 40, 1260, 660), fill=(255, 196, 140, 150)); gd.ellipse((760, 150, 1160, 550), fill=(255, 226, 180, 200))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(40)))
    # scattered leaves
    for x, y, sz, ang, c in [(620, 40, 54, 30, (126, 176, 96, 230)), (1120, 70, 44, -40, (98, 150, 80, 220)),
                             (660, 520, 40, 70, (150, 192, 110, 220)), (1110, 520, 60, -20, (110, 164, 88, 230)),
                             (40, 560, 34, 50, (150, 192, 110, 160))]:
        _leaf(im, x, y, sz, ang, c)
    mood = ERTY_FOR.get(path, "wave")
    er = Image.open(src / "assets" / "erty" / f"erty-{mood}.png").convert("RGBA")
    es = 500
    er = er.resize((es, int(er.height * es / er.width)), Image.LANCZOS)
    ex, ey = W - es + 40, Ht - er.height + 60
    sh = Image.new("RGBA", (W, Ht), (0, 0, 0, 0)); ImageDraw.Draw(sh).ellipse((ex + 90, Ht - 40, ex + es - 90, Ht + 30), fill=(150, 90, 40, 70))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(16)))
    im.alpha_composite(er, (ex, ey))
    d = ImageDraw.Draw(im)
    # speech bubble
    say = SAY[L].get(path, SAY[L]["default"])
    bf = _font(30, 680); bw = int(d.textlength(say, font=bf)) + 52
    bx, by = ex + 40 - bw // 2 + 60, max(36, ey - 30)
    bx = min(bx, W - bw - 30)
    im.alpha_composite(_shadow((W, Ht), (bx, by + 6, bx + bw, by + 70), 35, 10, 60)); d = ImageDraw.Draw(im)
    d.rounded_rectangle((bx, by, bx + bw, by + 64), 32, fill=(255, 255, 255))
    d.polygon([(bx + bw // 2 + 10, by + 62), (bx + bw // 2 + 40, by + 62), (bx + bw // 2 + 40, by + 88)], fill=(255, 255, 255))
    d.text((bx + 26, by + 14), say, font=bf, fill=LEAF_W)
    ic = _slug_icon(path)
    if ic:
        bs = 140; bx2, by2 = ex - 40, Ht - bs - 50
        im.alpha_composite(_shadow((W, Ht), (bx2, by2 + 8, bx2 + bs, by2 + bs + 8), bs // 2, 14, 80)); d = ImageDraw.Draw(im)
        d.ellipse((bx2, by2, bx2 + bs, by2 + bs), fill=(255, 253, 249))
        art = Image.open(src / "icons" / f"{ic}.png").convert("RGBA").resize((100, 100), Image.LANCZOS)
        im.alpha_composite(art, (bx2 + 20, by2 + 20)); d = ImageDraw.Draw(im)
    x, maxw = 72, 560
    icon = _rounded(Image.open(src / "assets" / "icon-512.png").convert("RGBA").resize((76, 76), Image.LANCZOS), 18)
    im.alpha_composite(_shadow((W, Ht), (x, 60 + 6, x + 76, 136 + 6), 18, 10, 80))
    im.alpha_composite(icon, (x, 60)); d = ImageDraw.Draw(im)
    d.text((x + 94, 78), BRAND, font=_font(38, 680), fill=LEAF_W)
    t = title.replace(f" · {BRAND}", "").replace(f"{BRAND}: ", "")
    t = t[:1].upper() + t[1:]
    size = 76
    while True:
        tf = _font(size, 760); lines = _wrap(d, t, tf, maxw)
        if len(lines) <= 3 or size <= 46:
            break
        size -= 4
    y = 200 if len(lines) == 3 else 230
    for ln in lines[:3]:
        d.text((x, y), ln, font=tf, fill=INK_W); y += int(size * 1.08)
    foot = "Grátis no iPhone" if L == "pt" else "Free on iPhone"
    ff = _font(28, 680); fw = int(d.textlength(foot, font=ff))
    im.alpha_composite(_shadow((W, Ht), (x, Ht - 112 + 6, x + fw + 56, Ht - 52 + 6), 30, 10, 70)); d = ImageDraw.Draw(im)
    d.rounded_rectangle((x, Ht - 112, x + fw + 56, Ht - 52), 30, fill=(46, 98, 58))
    d.text((x + 28, Ht - 98), foot, font=ff, fill=(255, 248, 238))
    d.text((x + fw + 80, Ht - 96), "mytinyjungle.com", font=_font(26, 560), fill=MUTED_W)
    im.convert("RGB").save(dest, optimize=True)


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


def faq_ld(qs):
    strip = lambda x: H.unescape(re.sub(r"<[^>]+>", "", x)).strip()
    return _ld({"@context": "https://schema.org", "@type": "FAQPage", "mainEntity": [
        {"@type": "Question", "name": strip(q), "acceptedAnswer": {"@type": "Answer", "text": strip(a)}} for q, a in qs]})


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
            f'<meta property="og:image:alt" content="{e(title)}"><meta property="og:image:type" content="image/png"><meta name="twitter:image:alt" content="{e(title)}">'
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
            name = f"{k}-{p.strip('/').replace('/', '-') or 'home'}"
            rows.append(f"<url><loc>{SITE}{langs[k]['prefix']}{p}</loc><lastmod>{LASTMOD}</lastmod>{alts}<image:image><image:loc>{SITE}/og/{name}.png</image:loc></image:image></url>")
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" '
            'xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">\n' + "\n".join(rows) + "\n</urlset>\n")


ROBOTS = f"""# {BRAND}: search and AI answers welcome, model training and scraping not.
User-agent: *
Allow: /

User-agent: Googlebot
User-agent: Bingbot
User-agent: Applebot
User-agent: OAI-SearchBot
User-agent: ChatGPT-User
User-agent: PerplexityBot
User-agent: Claude-SearchBot
Allow: /

# No model training on our words or images.
User-agent: GPTBot
User-agent: Google-Extended
User-agent: Applebot-Extended
User-agent: CCBot
User-agent: anthropic-ai
User-agent: ClaudeBot
User-agent: Bytespider
User-agent: meta-externalagent
Disallow: /

Sitemap: {SITE}/sitemap.xml
"""


def llms(T, rows_by_lang):
    en = T["en"]
    lines = [f"# {BRAND}", "", f"> {en['home_desc']}", "",
             "iPhone app by SimpleAppsCo LLC (Lisbon). Free for up to 5 plants; Greenhouse is €1.99 a month, Jungle €11.99 a year. "
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
# shared-jungle invite links land on one page when the app isn't installed
RewriteRule ^join/[A-Za-z0-9]{10}/?$ /join/index.html [L]
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
