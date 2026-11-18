# Domain setup — mytinyjungle.com (2026-11-18)

Mirrors mydigitalmagnets.com: Cloudflare in front, OVH VPS (51.38.39.82, cPanel account `simpleapps`) as origin.

## Registrar (IONOS)
- Registered at IONOS (contract 114478896, IONOS Instant Domain). Nameservers set to `kai.ns.cloudflare.com`, `kiki.ns.cloudflare.com`. The IONOS DNS zone is no longer used.

## Cloudflare
- Zone `mytinyjungle.com`, ID `0d62132a5345d7391e43bc76dd63ff48` (also in `~/.config/mydigitalmagnets/cloudflare.env` as `CLOUDFLARE_ZONE_ID_MYTINYJUNGLE`). Active.
- DNS: `A` apex, `www`, `api` → 51.38.39.82, all proxied. `TXT @ v=spf1 -all` and `_dmarc v=DMARC1; p=reject;` (domain sends no mail).
- SSL Full (strict), Always Use HTTPS on, min TLS 1.2, TLS 1.3, HTTP/3, Brotli, automatic HTTPS rewrites, browser check, security level medium.
- Differences from mydigitalmagnets.com: Full (strict) and TLS 1.2 instead of Full and TLS 1.0 (origin has a valid origin cert, so strict is safe). No email routing and no MX (mydigitalmagnets uses cPanel mail; My Tiny Jungle support mail is support@simpleappscompany.com).
- Origin certificate: Cloudflare Origin CA, RSA, `mytinyjungle.com` + `*.mytinyjungle.com`, valid to 2041-11-14. Local copy in `~/.config/mydigitalmagnets/mytinyjungle/` (origin.crt/.key/.csr).

## VPS (cPanel + Apache, same pattern as mydigitalmagnets)
- Addon domain `mytinyjungle.com` (cPanel subdomain `mytinyjungle.simpleappscompany.com`), docroot `/home/simpleapps/public_html/mytinyjungle.com`. `www` is a server alias.
- Subdomain `api.mytinyjungle.com`, docroot `/home/simpleapps/public_html/api.mytinyjungle.com` (unused; everything is proxied).
- TLS: origin cert installed on both vhosts with `whmapi1 installssl`.
- Apache includes (survive cPanel rebuilds), both `ssl` and `std`:
  - `/etc/apache2/conf.d/userdata/{ssl,std}/2_4/simpleapps/mytinyjungle.simpleappscompany.com/mtj-site.conf`: Cloudflare-only access.
  - `/etc/apache2/conf.d/userdata/{ssl,std}/2_4/simpleapps/api.mytinyjungle.com/mtj-proxy.conf`: reverse proxy to `127.0.0.1:3300` (port reserved for the My Tiny Jungle API), Cloudflare-only, JSON 503 while the backend is down.
  - Both include the shared `/etc/apache2/conf.d/userdata/mdm-cloudflare-only.inc` (direct origin hits get 403).
- After changing includes: `/scripts/rebuildhttpdconf && apachectl -t && /scripts/restartsrv_httpd`.

## Website
- Source in `Website/` (static, `build.py` → `dist/`). EN at `/`, PT-PT at `/pt/`. Pages: landing, `/support`, `/privacy`, `/terms`, plus `robots.txt` and `sitemap.xml`.
- Deploy: `Website/deploy.sh` (builds, rsyncs to the docroot, keeps the cPanel `.htaccess` block and appends the site rules after `# BEGIN mytinyjungle`).

## App Store Connect (app 6836292367)
- Support URL `https://mytinyjungle.com/support`, privacy `https://mytinyjungle.com/privacy`, marketing `https://mytinyjungle.com/` for en-US and pt-PT (ASC API).
- App Store Server Notifications V2, production and sandbox: `https://api.mytinyjungle.com/storekit/notifications` (ASC web UI).

## Verification (2026-11-18, through Cloudflare)
| URL | Result |
|---|---|
| https://mytinyjungle.com/ | 200 |
| https://www.mytinyjungle.com/ | 200 |
| /support, /privacy, /terms, /pt/, /pt/support, /pt/privacy | 200 |
| http://mytinyjungle.com/ | 301 → https |
| https://api.mytinyjungle.com/storekit/notifications (POST) | 503 JSON from the origin proxy (TLS and routing OK; API not deployed yet) |
| Direct origin https://51.38.39.82 with Host header | 403 (Cloudflare-only) |

When the My Tiny Jungle API ships, run it on `127.0.0.1:3300` and the existing proxy and notification URL work with no further changes.
