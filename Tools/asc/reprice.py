# /// script
# dependencies = ["pyjwt[crypto]", "requests"]
# ///
"""Subscription prices, same logic as MyDigitalMagnets: price set in Germany (EUR), Apple's equalised point in every
other storefront. Usage: uv run Tools/asc/reprice.py [--apply]   (env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_P8_PATH)"""
import jwt, time, os, sys, requests
APPLY = "--apply" in sys.argv
BASE = "DEU"
PLANS = {"com.simpleappscompany.mytinyjungle.plus.monthly": "1.99", "com.simpleappscompany.mytinyjungle.plus.yearly": "11.99"}
APP = "6836292367"
KEY = open(os.environ["ASC_P8_PATH"]).read()
def tok():
    n = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": n, "exp": n + 1200, "aud": "appstoreconnect-v1"}, KEY, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})
def api(m, p, body=None):
    r = requests.request(m, "https://api.appstoreconnect.apple.com" + p, json=body, headers={"Authorization": "Bearer " + tok()})
    if r.status_code >= 400: raise SystemExit(f"{m} {p} {r.status_code} {r.text[:400]}")
    return r.json() if r.text else {}
def all_(p):
    out, nxt = [], p
    while nxt:
        j = api("GET", nxt); out += j["data"]; inc = j.get("included", [])
        nxt = j.get("links", {}).get("next", "").replace("https://api.appstoreconnect.apple.com", "") or None
    return out
rel = lambda t, i: {"data": {"type": t, "id": i}}
for grp in all_(f"/v1/apps/{APP}/subscriptionGroups"):
    for s in all_(f"/v1/subscriptionGroups/{grp['id']}/subscriptions"):
        price = PLANS.get(s["attributes"]["productId"])
        if not price: continue
        point = next(p for p in all_(f"/v1/subscriptions/{s['id']}/pricePoints?filter[territory]={BASE}&limit=200") if p["attributes"]["customerPrice"] == price)
        eq = all_(f"/v1/subscriptionPricePoints/{point['id']}/equalizations?limit=200&include=territory")
        targets = [(point["id"], BASE)] + [(p["id"], p["relationships"]["territory"]["data"]["id"]) for p in eq if p["relationships"]["territory"]["data"]["id"] != BASE]
        print(s["attributes"]["productId"], f"€{price} DEU base +", len(targets) - 1, "equalised storefronts")
        if APPLY:
            for pid, ter in targets:
                api("POST", "/v1/subscriptionPrices", {"data": {"type": "subscriptionPrices", "attributes": {"preserveCurrentPrice": False},
                    "relationships": {"subscription": rel("subscriptions", s["id"]), "subscriptionPricePoint": rel("subscriptionPricePoints", pid), "territory": rel("territories", ter)}}})
            print("  applied")
