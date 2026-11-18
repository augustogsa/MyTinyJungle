"""Landing page for mytinyjungle.com (EN + PT-BR).

Layout: a split stage. The reading column scrolls through the app tab by tab while the stage on the
right holds one of the project's real plant photos with the phone on top; both change as each chapter
arrives. Then a full-width features field, the beta slip, two pricing fields, the FAQ as reading text
and a closing photograph.
"""
import json

TESTFLIGHT_URL = "https://testflight.apple.com/join/A8YUuUHj"


def I(name, size=40):
    return f'<img class="i3d" src="/icons/{name}.png" alt="" width="{size}" height="{size}" loading="lazy">'


# Scene per chapter: (plant photo, app screen). Index 0 is the hero.
SCENES = [("monstera", "today1"), ("echeveria", "today-ring"), ("pothos", "plant"), ("basil", None),
          ("peacelily", "care-week"), ("orchid", "scan-result"), ("zz", "me")]

H = {
 "en": {
  "h1": "Your plants talk back.",
  "lead": "My Tiny Jungle is a cosy iPhone app for every plant you love. Tell it what you did in your own words. Your plants answer, ask gently for what they need, and grow happier with you.",
  "cta": "Join the beta on TestFlight",
  "note": "Free for up to 5 plants. Your photos stay on your phone.",
  "stage_alt": "My Tiny Jungle on iPhone",
  "chapters": [
   {"id": "today", "h": "Today, a calm morning check", "p": "Open the app and see who needs you, who is thriving and what is coming up. Most days it simply says everyone is happy.",
    "list": [("wateringCan", "Care cards for each plant that needs you, done in one tap"), ("healthShield", "A health ring: thriving, okay or asking for you"),
             ("drop", "Next sips: who will be thirsty next"), ("autumnLeaf", "What this season means inside your home"), ("sprout", "A one-minute lesson to grow your green thumb")],
    "thumbs": [("today1", "Care cards"), ("today2", "At a glance"), ("conversations", "What they say")]},
   {"id": "plants", "h": "Every plant has a page", "p": "Your whole jungle in one grid, each with a name, a photo and a little status. Open one and its life is there.",
    "big": ["Water", "Feed", "Repot", "Check"], "big_note": "The four things plants need most, always at the top of their page, with the next two weeks of care below.",
    "thumbs": [("plants", "My plants"), ("timeline", "Your life together"), ("profile", "Personality, room and pot")]},
   {"id": "talk", "h": "Talk to them. They answer.", "p": "Type it like a text to a friend: “watered Monty and Pesto”. The app takes note and your plants reply in their own voices. Try it here.",
    "chat": True, "thumbs": [("jungle-chat", "The whole jungle"), ("plant-chat", "One to one")]},
   {"id": "care", "h": "A plan for your home and season", "p": "Your week, your month and the year ahead, planned around how your plants really live. Feel the soil, tell the app, and it learns how fast each plant dries in your home.",
    "thumbs": [("care-week", "This week"), ("care-calendar", "The month"), ("care-season", "Seasons"), ("travel", "Going away"), ("howto", "How-to guides")],
    "list": [("travel", "Going away: who is fine, who needs a deep drink, who needs a sitter"), ("seedling", "Cuttings followed from the water glass to a new plant"),
             ("pot", "Step-by-step guides: watering, pruning, repotting, pests")]},
   {"id": "scan", "h": "Scan a label in the shop", "p": "Standing in the garden centre? Point at a fertiliser, soil or treatment and see which of your plants it suits, and how and when to use it. Or scan a new plant, or a sick leaf.",
    "list": [("fertilizer", "A verdict from each of your plants on that bottle"), ("pottedPlant", "Meet a new plant and get its care plan straight away"), ("firstAid", "Show a sick leaf and get kind, clear next steps")],
    "thumbs": [("scan", "Scan anything"), ("scan-result", "Verdicts"), ("health", "Health check")]},
   {"id": "me", "h": "Your jungle, your story", "p": "Plants, happy plants, care moments and years together. Rooms and spaces, cuttings and milestones, from your first plant to an all-happy jungle.",
    "list": [("livingRoom", "Living room, kitchen, balcony: who lives where"), ("award", "Milestones that make care feel like a joy")],
    "thumbs": [("me", "Me")]},
  ],
  "chat_label": "Pick a plant, then ask",
  "chat_plants": [("Monty", "monstera"), ("Pesto", "basil"), ("Pearl", "orchid"), ("Goldie", "pothos")],
  "chat_qs": ["How are you?", "Do you need water?", "Should I feed you?"],
  "chat_a": {
   "Monty": ["Happy and growing a new leaf. Thank you for the bright spot by the window.", "Not yet. My top soil is still damp. Check me again on Thursday.", "Not now. Autumn is my resting time. Half-strength food again in spring."],
   "Pesto": ["Bushy and smelling lovely. Pick my top leaves soon so I stay that way.", "Yes please. Basil drinks a lot, a good soak today would be perfect.", "A little, every two weeks while I am growing. Not too much, or I lose flavour."],
   "Pearl": ["Resting, and dreaming of my next flower spike.", "Not yet. Water me when my roots look silvery, about once a week.", "Not this season. Orchid food again when spring arrives."],
   "Goldie": ["A little droopy, to be honest. I think I am thirsty.", "Yes, can you check my soil? If the top two centimetres are dry, I would love a drink.", "After a drink, yes. Never feed me when I am dry."]},
  "you": "You",
  "feat_h": "Everything inside",
  "feat": [("monstera", "Care that listens", [("chat", "Chat with every plant, in their own voices"), ("soilTest", "The soil-check ritual learns each plant's rhythm"), ("calendarHeart", "Gentle requests to water, feed, mist and turn"), ("celebrate", "Streaks and milestones, never guilt")]),
           ("peacelily", "Help when one struggles", [("firstAid", "Health check from a photo"), ("bug", "Pest guard with a simple plan"), ("pot", "Repot check: when, which pot, which soil"), ("shieldLeaf", "Clear warnings for cats, dogs and little ones")]),
           ("snake", "Seasons and holidays", [("sun", "A season guide for where you live"), ("snow", "Winter rest and frost care"), ("travel", "Holiday plans so everyone is fine"), ("seedling", "Cuttings and propagation, step by step")]),
           ("orchid", "In the shop and at home", [("fertilizer", "Label scanner with a verdict per plant"), ("sprout", "Identify a new plant in seconds"), ("livingRoom", "Rooms and spaces with the right light"), ("growth", "A photo timeline of how far you have come")])],
  "slip_h": "Join the beta in two minutes",
  "slip_p": "My Tiny Jungle is open for beta testers on iPhone. Apple's free TestFlight app installs it. Bring a friend: there is room for 100 testers.",
  "slip": [("On your iPhone", [("Open this page", "10 s"), ("Tap Join the beta", "5 s"), ("Install TestFlight from the App Store", "30 s")]),
           ("In TestFlight", [("Accept the invite", "5 s"), ("Install My Tiny Jungle", "30 s")]),
           ("In the app", [("Add your first plant with a photo", "40 s")])],
  "slip_end": ("Your jungle starts talking", "2 min"),
  "free": ("Free", "For your first little jungle.", "€0", "forever", "Up to 5 plants with chat, care requests, reminders and the soil-check ritual. Supported by ads."),
  "monthly": ("Plus monthly", "Try everything, month by month.", "€1.99", "a month", "Unlimited plants, no ads, label verdicts and health checks. Cancel any time."),
  "plus": ("Plus yearly", "For every plant you love, all year.", "€11.99", "a year", "Everything in Plus for just €1 a month. Half the price of paying monthly."),
  "best": "Best value", "feat_p": "Every tool a plant parent could wish for, in four little groups.",
  "close_names": [("monstera", "Monty", "Monstera"), ("basil", "Pesto", "Basil"), ("orchid", "Pearl", "Orchid"), ("pothos", "Goldie", "Pothos"), ("echeveria", "Rosetta", "Echeveria"), ("peacelily", "Lily", "Peace lily"), ("snake", "Sergeant", "Snake plant"), ("zz", "Zeke", "ZZ plant")],
  "close_k": "8 plants waiting to say hello", "prev": "Previous screen", "next": "Next screen",
  "plus_btn": "Get Plus in the app",
  "fine": "Prices in euros; local prices may vary. Subscriptions renew automatically until cancelled in your Apple account settings.",
  "faq_h": "Good to know",
  "faq": [("Do I need to know anything about plants?", "Not at all. Add a plant with a photo or its name and the app fills in the rest, in plain, friendly words."),
          ("Is it really free?", "Yes. Up to 5 plants with chat, care requests and reminders, forever, supported by ads. Plus is optional and removes the ads."),
          ("Does it speak Portuguese?", "Yes. The app and your plants speak English and Portuguese."),
          ("Where do my plant photos go?", "Nowhere. Photos, scans and notes stay on your phone, and you do not need an account."),
          ("Where does the advice come from?", "From a carefully reviewed plant library. When the app is not sure, it says so."),
          ("I missed a week. Now what?", "Your plants are simply happy you are back, and tell you what to do first."),
          ("Will it nag me?", "No. One gentle note a day at most, with quiet hours, and you can snooze anything."),
          ("Which iPhones?", "Any iPhone that runs the latest iOS. During the beta it installs through TestFlight.")],
  "c_h": "Give your plants a voice", "c_p": "My Tiny Jungle is in beta on iPhone. Join today and bring a friend.",
 },
 "pt": {
  "h1": "Suas plantas respondem.",
  "lead": "O My Tiny Jungle é um app aconchegante para iPhone, feito para todas as plantas que você ama. Conte o que fez, do seu jeito. Elas respondem, pedem com carinho o que precisam e ficam mais felizes com você.",
  "cta": "Entrar no beta pelo TestFlight",
  "note": "Grátis para até 5 plantas. Suas fotos ficam no seu celular.",
  "stage_alt": "My Tiny Jungle no iPhone",
  "chapters": [
   {"id": "today", "h": "Hoje, uma manhã tranquila", "p": "Abra o app e veja quem precisa de você, quem está ótima e o que vem por aí. Na maioria dos dias, ele só avisa que está todo mundo feliz.",
    "list": [("wateringCan", "Cartões de cuidado para cada planta, resolvidos com um toque"), ("healthShield", "Um anel de saúde: ótima, bem ou pedindo atenção"),
             ("drop", "Próximas regadas: quem vai sentir sede primeiro"), ("autumnLeaf", "O que a estação muda dentro de casa"), ("sprout", "Uma lição de um minuto para pegar o jeito com as plantas")],
    "thumbs": [("today1", "Cartões"), ("today2", "Num relance"), ("conversations", "O que elas dizem")]},
   {"id": "plants", "h": "Cada planta tem sua própria página", "p": "Sua selva inteira numa grade, cada uma com nome, foto e um status rapidinho. Toque numa e a vida dela está toda ali.",
    "big": ["Regar", "Adubar", "Vaso", "Checar"], "big_note": "O que as plantas mais precisam, sempre no topo da página, com os cuidados das próximas duas semanas logo abaixo.",
    "thumbs": [("plants", "Minhas plantas"), ("timeline", "A história de vocês"), ("profile", "Personalidade, cômodo e vaso")]},
   {"id": "talk", "h": "Converse com elas. Elas respondem.", "p": "Escreva como se fosse para um amigo: “reguei o Monty e o Pesto”. O app anota tudo e as plantas respondem com a própria voz. Experimente aqui.",
    "chat": True, "thumbs": [("jungle-chat", "A selva toda"), ("plant-chat", "Papo a dois")]},
   {"id": "care", "h": "Um plano para a sua casa", "p": "A semana, o mês e o ano, planejados em volta do jeito que suas plantas vivem. Sinta a terra, conte ao app, e ele aprende quanto tempo cada planta leva para secar na sua casa.",
    "thumbs": [("care-week", "Esta semana"), ("care-calendar", "O mês"), ("care-season", "Estações"), ("travel", "Vou viajar"), ("howto", "Guias")],
    "list": [("travel", "Vou viajar: quem fica de boa, quem precisa de uma rega caprichada, quem precisa de alguém de olho"), ("seedling", "Mudas acompanhadas do copinho de água até virar planta"),
             ("pot", "Guias passo a passo: regar, podar, trocar de vaso, pragas")]},
   {"id": "scan", "h": "Escaneie um rótulo na loja", "p": "No garden center, sem saber o que levar? Aponte para um adubo, substrato ou tratamento e veja para quais plantas serve, como e quando usar. Ou escaneie uma planta nova, ou uma folha doente.",
    "list": [("fertilizer", "Um veredito de cada planta sobre aquele produto"), ("pottedPlant", "Conheça uma planta nova e já receba o plano dela"), ("firstAid", "Mostre uma folha doente e receba os próximos passos, bem explicados")],
    "thumbs": [("scan", "Escaneie tudo"), ("scan-result", "Vereditos"), ("health", "Saúde")]},
   {"id": "me", "h": "Sua selva, sua história", "p": "Plantas, plantas felizes, momentos de cuidado e anos juntos. Cômodos, mudas e conquistas, da primeira plantinha a uma selva inteira feliz.",
    "list": [("livingRoom", "Sala, cozinha, varanda: quem mora onde"), ("award", "Conquistas que deixam o cuidado ainda mais gostoso")],
    "thumbs": [("me", "Você")]},
  ],
  "chat_label": "Escolha uma planta e pergunte",
  "chat_plants": [("Monty", "monstera"), ("Pesto", "basil"), ("Pearl", "orchid"), ("Goldie", "pothos")],
  "chat_qs": ["Como você está?", "Precisa de água?", "Devo te adubar?"],
  "chat_a": {
   "Monty": ["Feliz e soltando uma folha nova. Obrigado pelo cantinho iluminado perto da janela.", "Ainda não. A terra de cima ainda está úmida. Dá uma olhada de novo na quinta.", "Agora não. O outono é meu descanso. Adubo com meia dose na primavera."],
   "Pesto": ["Cheio de folhas e cheiroso. Colhe as pontinhas de cima para eu continuar assim.", "Sim, por favor. Manjericão bebe muito, uma boa regada hoje seria perfeita.", "Um pouquinho, a cada duas semanas enquanto estou crescendo. Sem exagero, senão perco o sabor."],
   "Pearl": ["Descansando, sonhando com a próxima haste de flores.", "Ainda não. Me rega quando as raízes estiverem prateadas, uma vez por semana.", "Nesta estação, não. Adubo de orquídea quando a primavera chegar."],
   "Goldie": ["Meio murchinha, para ser sincera. Acho que estou com sede.", "Sim, dá uma olhada na minha terra? Se os dois centímetros de cima estiverem secos, eu adoraria uma água.", "Depois de beber, sim. Nunca me adube com a terra seca."]},
  "you": "Você",
  "feat_h": "Tudo o que vem no app",
  "feat": [("monstera", "Cuidado com atenção", [("chat", "Converse com cada planta, na voz dela"), ("soilTest", "O ritual da terra aprende o ritmo de cada uma"), ("calendarHeart", "Lembretes gentis para regar, adubar, borrifar e girar o vaso"), ("celebrate", "Sequências e conquistas, nunca culpa")]),
           ("peacelily", "Ajuda quando uma não vai bem", [("firstAid", "Checagem de saúde por foto"), ("bug", "Proteção contra pragas com um plano simples"), ("pot", "Troca de vaso: quando, qual vaso, qual substrato"), ("shieldLeaf", "Avisos claros para gatos, cachorros e crianças")]),
           ("snake", "Estações e férias", [("sun", "Guia das estações para onde você mora"), ("snow", "Descanso no inverno e proteção contra o frio"), ("travel", "Planos de férias para todas ficarem bem"), ("seedling", "Mudas e propagação, passo a passo")]),
           ("orchid", "Na loja e em casa", [("fertilizer", "Leitor de rótulos com veredito por planta"), ("sprout", "Identifique uma planta nova em segundos"), ("livingRoom", "Cômodos com a luz certa"), ("growth", "Uma linha do tempo em fotos de toda a jornada")])],
  "slip_h": "Entre no beta em dois minutos",
  "slip_p": "O My Tiny Jungle está aberto para testers no iPhone. O app gratuito TestFlight, da Apple, faz a instalação. Chame um amigo: tem vaga para 100 testers.",
  "slip": [("No iPhone", [("Abra esta página", "10 s"), ("Toque em Entrar no beta", "5 s"), ("Instale o TestFlight pela App Store", "30 s")]),
           ("No TestFlight", [("Aceite o convite", "5 s"), ("Instale o My Tiny Jungle", "30 s")]),
           ("No app", [("Adicione a primeira planta com uma foto", "40 s")])],
  "slip_end": ("Sua selva começa a falar", "2 min"),
  "free": ("Grátis", "Para a sua primeira mini selva.", "0 €", "para sempre", "Até 5 plantas com bate-papo, pedidos de cuidado, lembretes e o ritual da terra. Com anúncios."),
  "monthly": ("Plus mensal", "Experimente tudo, mês a mês.", "1,99 €", "por mês", "Plantas ilimitadas, sem anúncios, vereditos de rótulos e checagens de saúde. Cancele quando quiser."),
  "plus": ("Plus anual", "Para todas as plantas que você ama, o ano inteiro.", "11,99 €", "por ano", "Tudo do Plus por só 1 € por mês. Metade do preço do plano mensal."),
  "best": "Melhor valor", "feat_p": "Todas as ferramentas que quem cuida de plantas pode querer, em quatro grupinhos.",
  "close_names": [("monstera", "Monty", "Costela-de-adão"), ("basil", "Pesto", "Manjericão"), ("orchid", "Pearl", "Orquídea"), ("pothos", "Goldie", "Jiboia"), ("echeveria", "Rosetta", "Echeveria"), ("peacelily", "Lily", "Lírio-da-paz"), ("snake", "Sergeant", "Espada-de-são-jorge"), ("zz", "Zeke", "Zamioculca")],
  "close_k": "8 plantas esperando para dizer olá", "prev": "Tela anterior", "next": "Próxima tela",
  "plus_btn": "Assinar o Plus no app",
  "fine": "Preços em euros; podem variar de acordo com o país. As assinaturas são renovadas automaticamente até serem canceladas nos ajustes da sua conta Apple.",
  "faq_h": "Bom saber",
  "faq": [("Preciso entender de plantas?", "Nadinha. Adicione uma planta com uma foto ou pelo nome e o app cuida do resto, com palavras simples e carinhosas."),
          ("É grátis mesmo?", "Sim. Até 5 plantas com bate-papo, pedidos de cuidado e lembretes, para sempre, com anúncios. O Plus é opcional e remove os anúncios."),
          ("Fala português?", "Fala, sim. O app e suas plantas falam português e inglês."),
          ("Para onde vão as fotos?", "Para lugar nenhum. Fotos, leituras e anotações ficam no seu celular, e você nem precisa criar conta."),
          ("De onde vêm as dicas?", "De uma biblioteca de plantas revisada com cuidado. Quando o app não tem certeza, ele avisa."),
          ("Fiquei uma semana sem cuidar. E agora?", "As plantas só ficam felizes com a sua volta e dizem o que fazer primeiro."),
          ("Ele vai ficar me enchendo?", "Não. No máximo um lembrete gentil por dia, com horário de silêncio, e você pode adiar tudo."),
          ("Quais iPhones?", "Qualquer iPhone com a versão mais recente do iOS. Durante o beta, a instalação é pelo TestFlight.")],
  "c_h": "Dê voz às suas plantas", "c_p": "O My Tiny Jungle está em beta no iPhone. Entre hoje e chame um amigo.",
 },
}


LAZY = {True: "", False: ' loading="lazy"'}


def render_home(L, t, page, phone, apple_icon):
    h = H[L]
    cta = f'<a class="btn" href="{TESTFLIGHT_URL}" rel="noopener">{apple_icon}{h["cta"]}</a>'

    def screen(name, alt, cls="screen"):
        return f'<img class="{cls}" src="/assets/app/{name}.jpg" alt="{alt}" width="1100" height="2392" loading="lazy">'

    def ilist(items):
        return '<ul class="ilist">' + "".join(f"<li>{I(i)}<span>{x}</span></li>" for i, x in items) + "</ul>"

    def thumbs(items):
        cards = "".join(f'<figure class="slide">{phone("app/" + n + ".jpg", c)}<figcaption>{c}</figcaption></figure>' for n, c in items)
        nav = (f'<div class="snav"><button type="button" class="sbtn prev" aria-label="{h["prev"]}">&larr;</button>'
               f'<button type="button" class="sbtn next" aria-label="{h["next"]}">&rarr;</button></div>')
        return f'<div class="slider"><div class="track" tabindex="0">{cards}</div>{nav}</div>'

    layers = "".join(
        f'<div class="layer{" on" if k == 0 else ""}" data-scene="{k}"><img class="photo" src="/assets/plants/{ph}.jpg" alt="" width="1100" height="1400"{LAZY[k == 0]}>'
        f'{phone("app/" + sc + ".jpg", h["stage_alt"], "stage-phone") if sc else ""}</div>'
        for k, (ph, sc) in enumerate(SCENES))

    chapters = ""
    for k, c in enumerate(h["chapters"], start=1):
        ph, sc = SCENES[k]
        inner = f'<h2>{c["h"]}</h2><p class="lead2">{c["p"]}</p>'
        if sc:
            inner += f'<div class="m-scene"><img class="photo" src="/assets/plants/{ph}.jpg" alt="" width="1100" height="1400" loading="lazy">{phone("app/" + sc + ".jpg", c["h"], "stage-phone")}</div>'
        if c.get("big"):
            inner += '<ul class="four">' + "".join(f"<li>{w}</li>" for w in c["big"]) + f'</ul><p class="four-note">{c["big_note"]}</p>'
        if c.get("chat"):
            plants = "".join(f'<button type="button" class="chip{" on" if j == 0 else ""}" data-plant="{n}" aria-pressed="{"true" if j == 0 else "false"}"><img src="/assets/plants/{p}.jpg" alt="" width="28" height="28" loading="lazy">{n}</button>' for j, (n, p) in enumerate(h["chat_plants"]))
            qs = "".join(f'<button type="button" class="ask" data-q="{j}">{q}</button>' for j, q in enumerate(h["chat_qs"]))
            first = h["chat_plants"][0][0]
            inner += (f'<div class="talk" data-answers=\'{json.dumps(h["chat_a"], ensure_ascii=False).replace(chr(39), "&#39;")}\'>'
                      f'<p class="talk-label">{h["chat_label"]}</p><div class="chips" role="group">{plants}</div>'
                      f'<div class="log" aria-live="polite"><p class="b me">{h["chat_qs"][0]}</p><p class="b plant"><b>{first}</b>{h["chat_a"][first][0]}</p></div>'
                      f'<div class="asks" role="group">{qs}</div></div>')
        if c.get("list"):
            inner += ilist(c["list"])
        if len(c["thumbs"]) > 1 and not c.get("chat"):
            inner += thumbs(c["thumbs"])
        chapters += f'<section class="chapter" id="{c["id"]}" data-scene="{k}">{inner}</section>'

    feats = "".join(
        f'<article class="fblock"><img class="fphoto" src="/assets/plants/{ph}.jpg" alt="" width="1100" height="800" loading="lazy"><h3>{title}</h3>{ilist(items)}</article>'
        for ph, title, items in h["feat"])

    slip = "".join(f'<h3>{g}</h3>' + "".join(f'<p class="row"><span>{a}</span><i></i><span>{b}</span></p>' for a, b in rows) for g, rows in h["slip"])
    se = h["slip_end"]

    def field(cls, d, btn, tag=""):
        name, who, price, per, inc = d
        tg = f'<span class="tag">{tag}</span>' if tag else ""
        return (f'<div class="field {cls}">{tg}<h3>{name}</h3><p class="who">{who}</p><p>{inc}</p>'
                f'<div class="pfoot"><p class="price">{price}<small>{per}</small></p>{btn}</div></div>')

    faq = "".join(f"<p><b>{q}</b> {a}</p>" for q, a in h["faq"])

    body = f"""
<div class="split">
<div class="read">
<section class="hero" data-scene="0"><h1>{h['h1']}</h1><p class="lead">{h['lead']}</p>{cta}<p class="note">{h['note']}</p>
<div class="m-scene"><img class="photo" src="/assets/plants/monstera.jpg" alt="" width="1100" height="1400" fetchpriority="high">{phone("app/today1.jpg", h["stage_alt"], "stage-phone")}</div></section>
{chapters}
</div>
<div class="stage" aria-hidden="true">{layers}</div>
</div>
<section class="features" id="features"><div class="wrap"><div class="fhead"><h2>{h['feat_h']}</h2><p>{h['feat_p']}</p></div><div class="fgrid">{feats}</div></div></section>
<section class="beta" id="beta"><div class="wrap bgrid"><div><h2>{h['slip_h']}</h2><p>{h['slip_p']}</p>{cta}</div>
<div class="slip">{slip}<p class="row end"><span>{se[0]}</span><span>{se[1]}</span></p></div></div></section>
<section class="pricing" id="pricing"><h2 class="vh">Plus</h2><div class="wrap fields">
{field("free", h["free"], f'<a class="btn ghost" href="{TESTFLIGHT_URL}" rel="noopener">{h["cta"]}</a>')}
{field("monthly", h["monthly"], f'<a class="btn" href="{TESTFLIGHT_URL}" rel="noopener">{h["plus_btn"]}</a>')}
{field("plus", h["plus"], f'<a class="btn light" href="{TESTFLIGHT_URL}" rel="noopener">{h["plus_btn"]}</a>', h["best"])}
</div></section>
<p class="wrap fine">{h['fine']}</p>
<section class="faq" id="faq"><div class="wrap qgrid"><h2>{h['faq_h']}</h2><div class="qtext">{faq}</div></div></section>
<section class="closing"><div class="wrap cgrid">
<div class="ctext"><img class="appicon" src="/assets/apple-touch-icon.png" alt="" width="88" height="88" loading="lazy"><h2>{h['c_h']}</h2><p>{h['c_p']}</p>{cta.replace('class="btn"', 'class="btn light"')}<p class="note">{h['note']}</p></div>
<div class="mosaic"><p class="mk">{h['close_k']}</p>{"".join(f'<figure><img src="/assets/plants/{ph}.jpg" alt="{kind}" width="400" height="400" loading="lazy"><figcaption><b>{nm}</b>{kind}</figcaption></figure>' for ph, nm, kind in h["close_names"])}</div>
</div></section>"""
    return page(L, "/", t["home_title"], t["home_desc"], body)
