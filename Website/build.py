#!/usr/bin/env python3
"""Builds the static mytinyjungle.com site into Website/dist (EN at /, PT-PT at /pt/)."""
import shutil
from pathlib import Path

ROOT = Path(__file__).parent
SRC, DIST = ROOT / "src", ROOT / "dist"
SITE = "https://mytinyjungle.com"
UPDATED = {"en": "18 November 2026", "pt": "18 de novembro de 2026"}
EMAIL = "support@simpleappscompany.com"

ICON = {
    "chat": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/></svg>',
    "drop": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3s6 6.4 6 11a6 6 0 0 1-12 0c0-4.6 6-11 6-11z"/></svg>',
    "finger": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20h16"/><path d="M12 4v10"/><path d="M9 11l3 3 3-3"/></svg>',
    "scan": '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3"/><path d="M8 9v6M11 9v6M14 9v6M17 9v6"/></svg>',
    "apple": '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M16.4 12.6c0-2.4 2-3.5 2-3.6-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.1-2.8.9-3.5.9s-1.8-.8-3-.8C7 7.3 5.5 8.2 4.7 9.7c-1.7 2.9-.4 7.2 1.2 9.6.8 1.2 1.7 2.4 2.9 2.4 1.2-.1 1.6-.8 3-.8s1.8.8 3 .7c1.3 0 2-1.2 2.8-2.3.9-1.3 1.2-2.6 1.3-2.7-.1 0-2.5-1-2.5-4zM14.1 5.5c.6-.8 1.1-1.8 1-2.9-.9 0-2 .6-2.7 1.4-.6.7-1.1 1.8-1 2.8 1 .1 2.1-.5 2.7-1.3z"/></svg>',
}

T = {
 "en": {
  "lang": "en", "prefix": "", "other": "pt", "other_label": "PT",
  "nav": ["Features", "Pricing", "Support"],
  "foot": ["Support", "Privacy", "Terms"], "made": "Made in Lisbon by Simple Apps Company",
  "cta": "Coming soon on the App Store",
  "home_title": "My Tiny Jungle: plant care that talks back",
  "home_desc": "Chat with your plants. Log care by just saying what you did, get gentle care requests, and keep every plant happy. On-device and private.",
  "h1": "Your plants have <em>something</em> to say.",
  "lead": "My Tiny Jungle turns plant care into a chat. Tell it what you did in plain words, and your plants answer back with what they need next.",
  "note": "Free for up to 5 plants. Photos stay on your iPhone.",
  "chat": [("me", "watered Milo and Luna yesterday"), ("plant", "Milo", "Thank you! I'm good for about a week."),
            ("plant", "Luna", "Could you check my soil on Tuesday? Calatheas like it just damp."), ("me", "Luna's leaves are curling"),
            ("plant", "Luna", "Usually that's thirst or dry air. Try a quick mist and move me out of direct sun.")],
  "f_eyebrow": "How it works", "f_h": "Care that feels like a conversation, not a chore.",
  "f_sub": "No forms, no spreadsheets. Type like you'd text a friend and My Tiny Jungle sorts out the rest.",
  "features": [
    ("chat", "", "Plants that talk", "Each plant has its own voice. They thank you, nudge you, and tell you when something's off."),
    ("drop", "sun", "Care requests", "Watering, misting, feeding, rotating. Your plants ask when it's time, based on the plant, the season and the room."),
    ("finger", "peach", "The soil-check ritual", "Instead of guessing, poke the soil and tell the app how it feels. Schedules adapt to your home, not a generic chart."),
    ("scan", "terra", "Product scanner", "Scan a fertiliser or potting mix and find out if it suits your plant and how much to use."),
  ],
  "s1_eyebrow": "Your jungle at a glance", "s1_h": "Every plant, every room, one calm list.",
  "s1_sub": "Add a plant with a photo or a sentence. My Tiny Jungle recognises it on your iPhone and fills in the care basics.",
  "s1_list": [("Plants", "Names, species, rooms and history"), ("Today", "The chat where you log care and ask questions"), ("Care", "This week, this month, this season"), ("Scan", "Products and plants, on-device")],
  "s2_eyebrow": "Plan ahead", "s2_h": "Know what's next before your plants droop.",
  "s2_sub": "A care calendar built from what you actually did. Going away? Travel care tells you what to do before you leave.",
  "s3_eyebrow": "Scan", "s3_h": "Point at a label. Know if it's right for your plants.",
  "s3_sub": "Scan the back of a fertiliser, potting mix or treatment and My Tiny Jungle checks it against every plant you have. Or scan a new plant, or a sick leaf, to find out what's going on.",
  "p_eyebrow": "Pricing", "p_h": "Start free. Grow when you're ready.",
  "plans": [
    ("Free", "€0", "forever", ["Up to 5 plants", "Chat and care requests", "Soil-check ritual", "Care calendar"], False, ""),
    ("Tiny Jungle Plus", "€1.99", "per month", ["Unlimited plants", "Product scanner", "Travel care and propagation guides", "Season planning"], False, ""),
    ("Tiny Jungle Plus", "€11.99", "per year", ["Everything in monthly", "Save 50% over monthly"], True, "Best value"),
  ],
  "fine": "Prices in euros; local prices may vary by country. Subscriptions renew automatically until cancelled in your Apple ID settings.",
  "c_h": "Give your plants a voice.", "c_p": "My Tiny Jungle is coming soon to iPhone.",
  # support
  "sup_title": "Support", "sup_desc": "Help with My Tiny Jungle: contact, subscriptions and common questions.",
  "sup_intro": f'Questions, bugs or ideas? Email <a href="mailto:{EMAIL}?subject=My%20Tiny%20Jungle">{EMAIL}</a>. A person reads every message and we reply within two working days.',
  "sup_tip": "Please include your iPhone model, iOS version and the app version (Me tab).",
  "faq_h": "Common questions",
  "faq": [
    ("How do I cancel Tiny Jungle Plus?", "Open iPhone Settings → your name → Subscriptions → My Tiny Jungle → Cancel Subscription. You keep Plus until the end of the period you paid for."),
    ("Can I get a refund?", 'Purchases are handled by Apple. Request a refund at <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a>.'),
    ("I bought Plus but the app still shows the free plan.", "Open Me → Restore Purchases while signed in with the same Apple ID you used to subscribe."),
    ("Are my photos uploaded?", "No. Plant recognition and product scans run on your iPhone. We never receive your photos."),
    ("What happens to my plants if I reach 5 on the free plan?", "Nothing is deleted. You can keep caring for your 5 plants, or upgrade to add more."),
    ("How do I delete my data?", "Delete the app. Your data only lives on your device (and in your own iCloud backup, if enabled)."),
  ],
  # privacy
  "pri_title": "Privacy Policy", "pri_desc": "My Tiny Jungle does not collect personal data. Photos and scans stay on your device.",
  "pri_box": "Short version: My Tiny Jungle does not collect any data about you. Your plants, photos, notes and scans stay on your iPhone. We have no accounts, no analytics and no tracking.",
  "pri": [
    ("Who we are", f"My Tiny Jungle is published by Simple Apps Company (“we”). Contact: <a href=\"mailto:{EMAIL}\">{EMAIL}</a>."),
    ("Data we collect", "None. The app has no sign-up and no account. We do not run analytics, advertising or tracking SDKs, and we do not use your data to track you across apps or websites. This matches the “Data Not Collected” label on the App Store."),
    ("Photos and camera", "When you photograph a plant or scan a product, the image is processed on your iPhone using Apple's on-device frameworks. Images are never sent to us or to third parties."),
    ("Your plants and notes", "Plant names, care logs, reminders and chat messages are stored locally on your device. If iCloud backup is on, they are included in your own encrypted Apple backup, which we cannot access."),
    ("Notifications", "Care reminders are scheduled locally on your device. You can turn them off at any time in iPhone Settings."),
    ("Purchases", "Subscriptions are processed entirely by Apple. We never see your name, email or payment details. To keep subscriptions working, our server may receive Apple's App Store Server Notifications, which contain only anonymous transaction identifiers and subscription status."),
    ("Children", "My Tiny Jungle is suitable for all ages and does not knowingly collect data from anyone, including children."),
    ("Your rights", "Because we hold no personal data about you, there is nothing for us to access, correct or delete. Deleting the app removes all its data from your device. You can still contact us about privacy at any time, and you have the right to complain to your data protection authority (in Portugal, the CNPD)."),
    ("Changes", "If this policy changes, we'll update this page and the date above. If we ever start collecting data, we'll ask first."),
  ],
  # terms
  "ter_title": "Terms of Use", "ter_desc": "Terms of use for My Tiny Jungle, including subscriptions and auto-renewal.",
  "ter": [
    ("Agreement", 'By downloading or using My Tiny Jungle you agree to these terms and to Apple\'s <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">Licensed Application End User License Agreement</a> (the “Standard EULA”), which applies between you and Simple Apps Company. If these terms and the Standard EULA conflict, these terms apply where the law allows.'),
    ("The app", "My Tiny Jungle helps you keep track of houseplant care. Care tips and plant identification are suggestions, not guarantees. Plants are living things and results vary; use your own judgement, especially for plants that may be toxic to pets or children."),
    ("Free plan and Tiny Jungle Plus", "The free plan lets you care for up to 5 plants. Tiny Jungle Plus is an optional auto-renewable subscription that unlocks unlimited plants and extra features, offered monthly (€1.99) or yearly (€11.99). Prices shown in the app in your local currency are the ones that apply."),
    ("Payment and auto-renewal", "<ul><li>Payment is charged to your Apple ID account when you confirm the purchase.</li><li>The subscription renews automatically for the same period and price unless you cancel at least 24 hours before the end of the current period.</li><li>Your account is charged for renewal within 24 hours before the current period ends.</li><li>You can manage or cancel in iPhone Settings → your name → Subscriptions. Cancelling stops the next renewal; you keep access until the paid period ends.</li><li>If a free trial is offered, any unused part of it ends when you buy a subscription.</li></ul>"),
    ("Refunds", 'Refunds are handled by Apple under its policies at <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a>. EU consumer rights are not affected.'),
    ("Acceptable use", "Don't reverse engineer, resell or misuse the app, and don't use it to break the law."),
    ("Liability", "The app is provided “as is”. To the extent the law allows, Simple Apps Company is not liable for indirect losses, including the loss of a plant. Nothing in these terms limits rights you have as a consumer that cannot be excluded."),
    ("Changes and law", "We may update these terms; the date above shows the latest version. These terms are governed by Portuguese law, without depriving you of protections under the law of your country of residence."),
    ("Contact", f'<a href="mailto:{EMAIL}">{EMAIL}</a>'),
  ],
  "updated": "Last updated",
 },
 "pt": {
  "lang": "pt-PT", "prefix": "/pt", "other": "en", "other_label": "EN",
  "nav": ["Funcionalidades", "Preços", "Suporte"],
  "foot": ["Suporte", "Privacidade", "Termos"], "made": "Feito em Lisboa pela Simple Apps Company",
  "cta": "Em breve na App Store",
  "home_title": "My Tiny Jungle: cuidar de plantas, à conversa",
  "home_desc": "Converse com as suas plantas. Registe os cuidados por escrito, receba pedidos de cuidado e mantenha todas as plantas felizes. No dispositivo e privado.",
  "h1": "As suas plantas têm <em>algo</em> a dizer.",
  "lead": "A My Tiny Jungle transforma o cuidado das plantas numa conversa. Diga o que fez por palavras suas e as plantas respondem com o que precisam a seguir.",
  "note": "Grátis até 5 plantas. As fotografias ficam no seu iPhone.",
  "chat": [("me", "reguei o Milo e a Luna ontem"), ("plant", "Milo", "Obrigado! Fico bem durante cerca de uma semana."),
            ("plant", "Luna", "Podes verificar a minha terra na terça? As calateias gostam dela só húmida."), ("me", "as folhas da Luna estão a enrolar"),
            ("plant", "Luna", "Normalmente é sede ou ar seco. Experimenta borrifar-me e afasta-me do sol direto.")],
  "f_eyebrow": "Como funciona", "f_h": "Cuidar como quem conversa, não como quem cumpre tarefas.",
  "f_sub": "Sem formulários nem folhas de cálculo. Escreva como escreveria a um amigo e a My Tiny Jungle trata do resto.",
  "features": [
    ("chat", "", "Plantas que falam", "Cada planta tem a sua voz. Agradecem, lembram e avisam quando algo não está bem."),
    ("drop", "sun", "Pedidos de cuidado", "Regar, borrifar, adubar, rodar. As plantas pedem quando é altura, conforme a espécie, a estação e a divisão."),
    ("finger", "peach", "O ritual de verificar a terra", "Em vez de adivinhar, toque na terra e diga à app como está. Os horários adaptam-se à sua casa, não a uma tabela genérica."),
    ("scan", "terra", "Leitor de produtos", "Leia um adubo ou substrato e saiba se serve para a sua planta e quanto usar."),
  ],
  "s1_eyebrow": "A sua selva num relance", "s1_h": "Todas as plantas, todas as divisões, uma lista tranquila.",
  "s1_sub": "Adicione uma planta com uma foto ou uma frase. A My Tiny Jungle reconhece-a no seu iPhone e preenche os cuidados básicos.",
  "s1_list": [("Plantas", "Nomes, espécies, divisões e histórico"), ("Hoje", "A conversa onde regista cuidados e faz perguntas"), ("Cuidados", "Esta semana, este mês, esta estação"), ("Ler", "Produtos e plantas, no dispositivo")],
  "s2_eyebrow": "Planeie com antecedência", "s2_h": "Saiba o que vem a seguir antes de as plantas murcharem.",
  "s2_sub": "Um calendário feito a partir do que realmente fez. Vai viajar? Os cuidados de viagem dizem-lhe o que fazer antes de sair.",
  "s3_eyebrow": "Ler", "s3_h": "Aponte para o rótulo. Saiba se serve para as suas plantas.",
  "s3_sub": "Leia o verso de um adubo, substrato ou tratamento e a My Tiny Jungle compara-o com todas as suas plantas. Ou leia uma planta nova, ou uma folha doente, para perceber o que se passa.",
  "p_eyebrow": "Preços", "p_h": "Comece grátis. Cresça quando quiser.",
  "plans": [
    ("Grátis", "0 €", "para sempre", ["Até 5 plantas", "Conversa e pedidos de cuidado", "Ritual de verificar a terra", "Calendário de cuidados"], False, ""),
    ("Tiny Jungle Plus", "1,99 €", "por mês", ["Plantas ilimitadas", "Leitor de produtos", "Guias de viagem e propagação", "Planeamento por estação"], False, ""),
    ("Tiny Jungle Plus", "11,99 €", "por ano", ["Tudo o que o mensal inclui", "Poupe 50% face ao mensal"], True, "Melhor valor"),
  ],
  "fine": "Preços em euros; podem variar consoante o país. As subscrições renovam automaticamente até serem canceladas nas definições do seu ID Apple.",
  "c_h": "Dê voz às suas plantas.", "c_p": "A My Tiny Jungle chega em breve ao iPhone.",
  "sup_title": "Suporte", "sup_desc": "Ajuda com a My Tiny Jungle: contacto, subscrições e perguntas frequentes.",
  "sup_intro": f'Dúvidas, erros ou ideias? Escreva para <a href="mailto:{EMAIL}?subject=My%20Tiny%20Jungle">{EMAIL}</a>. Uma pessoa lê todas as mensagens e respondemos em dois dias úteis.',
  "sup_tip": "Indique o modelo do iPhone, a versão do iOS e a versão da app (separador Eu).",
  "faq_h": "Perguntas frequentes",
  "faq": [
    ("Como cancelo o Tiny Jungle Plus?", "Abra Definições do iPhone → o seu nome → Subscrições → My Tiny Jungle → Cancelar subscrição. Mantém o Plus até ao fim do período pago."),
    ("Posso pedir reembolso?", 'As compras são geridas pela Apple. Peça o reembolso em <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a>.'),
    ("Comprei o Plus mas a app mostra o plano grátis.", "Abra Eu → Restaurar compras, com o mesmo ID Apple usado na subscrição."),
    ("As minhas fotografias são enviadas?", "Não. O reconhecimento de plantas e a leitura de produtos acontecem no seu iPhone. Nunca recebemos as suas fotografias."),
    ("O que acontece se chegar às 5 plantas no plano grátis?", "Nada é apagado. Pode continuar a cuidar das 5 plantas ou subscrever para adicionar mais."),
    ("Como apago os meus dados?", "Apague a app. Os dados só existem no seu dispositivo (e na sua cópia de segurança do iCloud, se ativa)."),
  ],
  "pri_title": "Política de Privacidade", "pri_desc": "A My Tiny Jungle não recolhe dados pessoais. Fotografias e leituras ficam no seu dispositivo.",
  "pri_box": "Em resumo: a My Tiny Jungle não recolhe quaisquer dados sobre si. As plantas, fotografias, notas e leituras ficam no seu iPhone. Não há contas, análises nem rastreamento.",
  "pri": [
    ("Quem somos", f"A My Tiny Jungle é publicada pela Simple Apps Company (“nós”). Contacto: <a href=\"mailto:{EMAIL}\">{EMAIL}</a>."),
    ("Dados que recolhemos", "Nenhuns. A app não tem registo nem conta. Não usamos ferramentas de análise, publicidade ou rastreamento, nem usamos os seus dados para o seguir noutras apps ou sites. Isto corresponde à indicação “Dados não recolhidos” na App Store."),
    ("Fotografias e câmara", "Quando fotografa uma planta ou lê um produto, a imagem é processada no seu iPhone com as ferramentas da Apple no dispositivo. As imagens nunca nos são enviadas nem a terceiros."),
    ("As suas plantas e notas", "Nomes, registos de cuidados, lembretes e mensagens ficam guardados no seu dispositivo. Com a cópia de segurança do iCloud ativa, são incluídos na sua cópia encriptada da Apple, à qual não temos acesso."),
    ("Notificações", "Os lembretes são agendados localmente no seu dispositivo. Pode desativá-los a qualquer momento nas Definições do iPhone."),
    ("Compras", "As subscrições são processadas inteiramente pela Apple. Nunca vemos o seu nome, email ou dados de pagamento. Para manter as subscrições a funcionar, o nosso servidor pode receber as notificações do App Store Server da Apple, que contêm apenas identificadores anónimos de transação e o estado da subscrição."),
    ("Crianças", "A My Tiny Jungle é adequada a todas as idades e não recolhe dados de ninguém, incluindo crianças."),
    ("Os seus direitos", "Como não temos dados pessoais seus, não há nada a aceder, corrigir ou apagar. Apagar a app remove todos os dados do dispositivo. Pode contactar-nos sobre privacidade a qualquer momento e tem o direito de apresentar queixa à CNPD."),
    ("Alterações", "Se esta política mudar, atualizamos esta página e a data acima. Se algum dia passarmos a recolher dados, pediremos primeiro."),
  ],
  "ter_title": "Termos de Utilização", "ter_desc": "Termos de utilização da My Tiny Jungle, incluindo subscrições e renovação automática.",
  "ter": [
    ("Acordo", 'Ao descarregar ou usar a My Tiny Jungle aceita estes termos e o <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">Contrato de Licença de Utilizador Final de Aplicações Licenciadas</a> da Apple (o “EULA Padrão”), aplicável entre si e a Simple Apps Company. Em caso de conflito, prevalecem estes termos na medida permitida por lei.'),
    ("A app", "A My Tiny Jungle ajuda a acompanhar o cuidado de plantas de interior. Dicas e identificações são sugestões, não garantias. As plantas são seres vivos e os resultados variam; use o seu bom senso, sobretudo com plantas que possam ser tóxicas para animais ou crianças."),
    ("Plano grátis e Tiny Jungle Plus", "O plano grátis permite cuidar de até 5 plantas. O Tiny Jungle Plus é uma subscrição opcional de renovação automática que desbloqueia plantas ilimitadas e funcionalidades extra, mensal (1,99 €) ou anual (11,99 €). Aplicam-se os preços mostrados na app na sua moeda local."),
    ("Pagamento e renovação automática", "<ul><li>O pagamento é cobrado na sua conta do ID Apple ao confirmar a compra.</li><li>A subscrição renova automaticamente pelo mesmo período e preço, salvo se cancelar pelo menos 24 horas antes do fim do período atual.</li><li>A renovação é cobrada nas 24 horas anteriores ao fim do período atual.</li><li>Pode gerir ou cancelar em Definições do iPhone → o seu nome → Subscrições. O cancelamento impede a renovação seguinte; mantém o acesso até ao fim do período pago.</li><li>Se for oferecido um período experimental, a parte não usada termina quando compra uma subscrição.</li></ul>"),
    ("Reembolsos", 'Os reembolsos são geridos pela Apple em <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a>. Os seus direitos de consumidor na UE não são afetados.'),
    ("Utilização aceitável", "Não faça engenharia inversa, revenda nem uso indevido da app, nem a use para infringir a lei."),
    ("Responsabilidade", "A app é fornecida “tal como está”. Na medida permitida por lei, a Simple Apps Company não é responsável por perdas indiretas, incluindo a perda de uma planta. Nada nestes termos limita direitos de consumidor que não possam ser excluídos."),
    ("Alterações e lei aplicável", "Podemos atualizar estes termos; a data acima indica a versão mais recente. Estes termos regem-se pela lei portuguesa, sem prejuízo das proteções da lei do seu país de residência."),
    ("Contacto", f'<a href="mailto:{EMAIL}">{EMAIL}</a>'),
  ],
  "updated": "Última atualização",
 },
}


def page(L, path, title, desc, body):
    t = T[L]; p = t["prefix"]
    other = T[t["other"]]["prefix"] + path
    canon = SITE + p + path
    alts = "".join(f'<link rel="alternate" hreflang="{T[k]["lang"]}" href="{SITE}{T[k]["prefix"]}{path}">' for k in T)
    n = t["nav"]; f = t["foot"]
    return f"""<!doctype html>
<html lang="{t['lang']}"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title}</title><meta name="description" content="{desc}">
<link rel="canonical" href="{canon}">{alts}<link rel="alternate" hreflang="x-default" href="{SITE}{path}">
<meta name="theme-color" content="#FCFAF6"><meta name="color-scheme" content="light">
<meta property="og:title" content="{title}"><meta property="og:description" content="{desc}">
<meta property="og:image" content="{SITE}/assets/icon-512.png"><meta property="og:url" content="{canon}">
<meta name="apple-itunes-app" content="app-id=6836292367">
<link rel="icon" href="/assets/favicon-64.png"><link rel="apple-touch-icon" href="/assets/apple-touch-icon.png">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,500;0,9..144,600;1,9..144,500&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/style.css">
</head><body>
<header class="nav"><div class="wrap">
<a class="brand" href="{p}/"><img src="/assets/apple-touch-icon.png" alt="">My Tiny Jungle</a>
<nav><a class="hide-s" href="{p}/#features">{n[0]}</a><a class="hide-s" href="{p}/#pricing">{n[1]}</a><a href="{p}/support">{n[2]}</a>
<a class="lang" href="{other}" hreflang="{T[t['other']]['lang']}">{t['other_label']}</a></nav>
</div></header>
<main>{body}</main>
<footer><div class="wrap"><span>© 2026 Simple Apps Company · {t['made']}</span>
<nav><a href="{p}/support">{f[0]}</a><a href="{p}/privacy">{f[1]}</a><a href="{p}/terms">{f[2]}</a></nav></div></footer>
</body></html>"""


def phone(img, alt, cls=""):
    return f'<div class="phone {cls}"><img src="/assets/{img}" alt="{alt}" width="1100" height="2392" loading="lazy"></div>'


def home(L):
    from home_content import render_home
    return render_home(L, T[L], page, phone, ICON["apple"])


def doc(L, path, title, desc, inner):
    t = T[L]
    body = f'<section class="doc"><div class="wrap"><h1>{title}</h1><p class="meta">{t["updated"]}: {UPDATED[L]}</p>{inner}</div></section>'
    return page(L, path, f"{title} · My Tiny Jungle", desc, body)


def sections(items):
    return "".join(f"<h2>{h}</h2>{b if b.startswith('<ul>') else f'<p>{b}</p>'}" for h, b in items)


def build():
    if DIST.exists():
        shutil.rmtree(DIST)
    (DIST / "assets").mkdir(parents=True)
    for f in (SRC / "assets").iterdir():
        shutil.copy(f, DIST / "assets" / f.name)
    shutil.copy(SRC / "style.css", DIST / "style.css")
    urls = []
    for L, t in T.items():
        p = t["prefix"]
        out = {
            "": home(L),
            "support": doc(L, "/support", t["sup_title"], t["sup_desc"],
                           f'<p>{t["sup_intro"]}</p><div class="box"><p>{t["sup_tip"]}</p></div><h2>{t["faq_h"]}</h2><div class="faq">'
                           + "".join(f"<details><summary>{q}</summary><p>{a}</p></details>" for q, a in t["faq"]) + "</div>"),
            "privacy": doc(L, "/privacy", t["pri_title"], t["pri_desc"], f'<div class="box"><p>{t["pri_box"]}</p></div>' + sections(t["pri"])),
            "terms": doc(L, "/terms", t["ter_title"], t["ter_desc"], sections(t["ter"])),
        }
        for slug, html in out.items():
            d = DIST / p.lstrip("/") / slug
            d.mkdir(parents=True, exist_ok=True)
            (d / "index.html").write_text(html)
            urls.append(f"{SITE}{p}/{slug}".rstrip("/") if slug else f"{SITE}{p}/")
    (DIST / "robots.txt").write_text(f"User-agent: *\nAllow: /\nSitemap: {SITE}/sitemap.xml\n")
    (DIST / "sitemap.xml").write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
                                      + "".join(f"<url><loc>{u}</loc></url>" for u in urls) + "</urlset>\n")
    (DIST / ".htaccess").write_text(
        "DirectorySlash Off\nErrorDocument 404 /\n"
        "RewriteEngine On\nRewriteCond %{REQUEST_FILENAME} -d\nRewriteCond %{REQUEST_FILENAME}/index.html -f\nRewriteRule ^(.*[^/])$ $1/index.html [L]\n"
        "<IfModule mod_headers.c>\n<FilesMatch \"\\.(jpg|png|css)$\">\nHeader set Cache-Control \"public, max-age=604800\"\n</FilesMatch>\n"
        "Header always set X-Content-Type-Options nosniff\nHeader always set Referrer-Policy strict-origin-when-cross-origin\n</IfModule>\n")
    print("built", len(urls), "pages")


if __name__ == "__main__":
    build()
