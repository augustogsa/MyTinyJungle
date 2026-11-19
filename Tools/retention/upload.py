# /// script
# dependencies = ["pyjwt[crypto]", "requests"]
# ///
"""Retention Messaging: upload Erty images + messages, set defaults for both subscriptions.
Usage: uv run Tools/retention/upload.py [sandbox|production] [upload|status|defaults]
Re-runnable: ids are stable UUIDs, 409 = already there. Defaults need APPROVED state (production waits for App Review)."""
import sys, time, uuid, json, os, jwt, requests

ENV = sys.argv[1] if len(sys.argv) > 1 else "sandbox"
CMD = sys.argv[2] if len(sys.argv) > 2 else "upload"
BASE = {"sandbox": "https://api.storekit-sandbox.apple.com", "production": "https://api.storekit.apple.com"}[ENV]
KEY_ID, ISSUER, BUNDLE = "2Z677UP7N7", os.environ["ASC_ISSUER_ID"], "com.simpleappscompany.mytinyjungle"
KEY = open(os.path.expanduser(f"~/.config/mydigitalmagnets/SubscriptionKey_{KEY_ID}.p8")).read()
DIR = os.path.dirname(os.path.abspath(__file__)) + "/../../Assets/AppStore/retention/"
PRODUCTS = ["com.simpleappscompany.mytinyjungle.plus.monthly", "com.simpleappscompany.mytinyjungle.plus.yearly"]
NS = uuid.UUID("6f1c0f4e-3b1a-4c7e-9a52-7d1e0b7a1c01")
uid = lambda name: str(uuid.uuid5(NS, name))

def auth():
    now = int(time.time())
    tok = jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1", "bid": BUNDLE},
                     KEY, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})
    return {"Authorization": f"Bearer {tok}"}

IMAGES = {"hero": "FULL_SIZE", "bullet-plants": "BULLET_POINT", "bullet-health": "BULLET_POINT",
          "bullet-soil": "BULLET_POINT", "bullet-calm": "BULLET_POINT"}

EN = dict(header="Erty and your plants will miss you",
          body="Your jungle is in good hands with us. Stay and keep every plant happy, healthy and well fed. Your plants stay yours either way.",
          alt="Erty, the little sprout, hugging a potted plant on a sunny windowsill full of happy plants",
          bullets=[("bullet-plants", "Room for every plant you adopt", "Erty planting a seed"),
                   ("bullet-health", "Catch a droopy leaf before it gets worse", "Erty with a magnifying glass"),
                   ("bullet-soil", "Scan soil and food to see who will love it", "Erty holding a bag of soil"),
                   ("bullet-calm", "No ads, just calm plant care", "Erty resting by a row of sprouts")])
PT = dict(header="O Raminho e suas plantas vão morrer de saudade",
          body="Fica mais um pouquinho! Aqui cada plantinha tem água na hora certa, comidinha boa e muito carinho. E elas continuam sendo suas, tá?",
          alt="O Raminho, um brotinho fofo, abraçando um vaso numa janela ensolarada cheia de plantas felizes",
          bullets=[("bullet-plants", "Espaço pra todas as plantas que você adotar", "Raminho plantando uma semente"),
                   ("bullet-health", "Pega aquela folha murcha antes de piorar", "Raminho com uma lupa"),
                   ("bullet-soil", "Escaneia terra e adubo e vê quem vai amar", "Raminho segurando um saco de terra"),
                   ("bullet-calm", "Sem anúncio, só cuidado na paz", "Raminho descansando ao lado de mudinhas")])
MESSAGES = {"en": EN, "pt": PT}
LOCALES = {"en-US": "en", "en-GB": "en", "en-AU": "en", "en-CA": "en", "pt-BR": "pt"}

def check(r, what):
    ok = r.status_code in (200, 201) or (r.status_code == 409)
    print(f"{'ok ' if ok else 'ERR'} {r.status_code} {what} {'' if ok else r.text}")
    if not ok: sys.exit(1)

def upload():
    for name, size in IMAGES.items():
        r = requests.put(f"{BASE}/inApps/v1/messaging/image/{uid('img-' + name)}", params={"imageSize": size},
                         data=open(DIR + name + ".png", "rb").read(), headers={**auth(), "Content-Type": "image/png"})
        check(r, f"image {name}")
    for lang, m in MESSAGES.items():
        assert len(m["header"]) <= 66 and len(m["body"]) <= 144 and len(m["alt"]) <= 150, lang
        body = {"header": m["header"], "body": m["body"], "headerPosition": "ABOVE_BODY",
                "image": {"imageIdentifier": uid("img-hero"), "altText": m["alt"]},
                "bulletPoints": [{"text": t, "imageIdentifier": uid("img-" + i), "altText": a} for i, t, a in m["bullets"]]}
        for b in body["bulletPoints"]: assert len(b["text"]) <= 66, b
        r = requests.put(f"{BASE}/inApps/v1/messaging/message/{uid('msg-' + lang)}", json=body, headers=auth())
        check(r, f"message {lang}")

def status():
    for kind in ("image", "message"):
        r = requests.get(f"{BASE}/inApps/v1/messaging/{kind}/list", headers=auth()); check(r, f"{kind} list")
        print(json.dumps(r.json(), indent=1))

def defaults():
    for p in PRODUCTS:
        for loc, lang in LOCALES.items():
            r = requests.put(f"{BASE}/inApps/v1/messaging/default/{p}/{loc}", json={"messageIdentifier": uid("msg-" + lang)}, headers=auth())
            check(r, f"default {p.rsplit('.', 1)[1]} {loc}")

{"upload": upload, "status": status, "defaults": defaults}[CMD]()
