"""Landing page content and layout for mytinyjungle.com (EN + PT-PT). Benefit-led, warm."""

_S = 'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"'
IC = {
    "chat": f'<svg {_S}><path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/></svg>',
    "drop": f'<svg {_S}><path d="M12 3s6 6.4 6 11a6 6 0 0 1-12 0c0-4.6 6-11 6-11z"/></svg>',
    "hand": f'<svg {_S}><path d="M4 20h16"/><path d="M8 20c0-3 1-5 4-6s4-3 4-6"/><circle cx="16" cy="6" r="1.5"/></svg>',
    "scan": f'<svg {_S}><path d="M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3"/><path d="M8 9v6M11 9v6M14 9v6M17 9v6"/></svg>',
    "steth": f'<svg {_S}><path d="M6 3v6a4 4 0 0 0 8 0V3"/><path d="M10 13v3a4 4 0 0 0 8 0v-2"/><circle cx="18" cy="12" r="2"/></svg>',
    "paw": f'<svg {_S}><circle cx="7" cy="9" r="1.8"/><circle cx="12" cy="6.5" r="1.8"/><circle cx="17" cy="9" r="1.8"/><path d="M8 17c0-2.5 1.8-5 4-5s4 2.5 4 5c0 1.7-1.6 2.5-4 2.5S8 18.7 8 17z"/></svg>',
    "home": f'<svg {_S}><path d="M4 11l8-7 8 7"/><path d="M6 10v10h12V10"/></svg>',
    "plane": f'<svg {_S}><path d="M3 13l18-7-7 18-2.5-8.5L3 13z"/></svg>',
    "sprout": f'<svg {_S}><path d="M12 20v-8"/><path d="M12 12c0-4-3-6-7-6 0 4 3 6 7 6z"/><path d="M12 14c0-3 2.5-5 6-5 0 3-2.5 5-6 5z"/></svg>',
    "sun": f'<svg {_S}><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>',
    "pot": f'<svg {_S}><path d="M5 9h14l-2 11H7L5 9z"/><path d="M4 9h16"/><path d="M12 9V4"/></svg>',
    "camera": f'<svg {_S}><path d="M4 8h3l2-2h6l2 2h3v11H4z"/><circle cx="12" cy="13" r="3.5"/></svg>',
    "lock": f'<svg {_S}><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>',
    "heart": f'<svg {_S}><path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/></svg>',
    "check": f'<svg {_S}><path d="M5 12l5 5 9-10"/></svg>',
    "bug": f'<svg {_S}><rect x="8" y="7" width="8" height="12" rx="4"/><path d="M12 7V4M4 12h4M16 12h4M5 7l3 2M19 7l-3 2M5 18l3-2M19 18l-3-2"/></svg>',
}

H = {
 "en": {
  "h1": "A home full of <em>happy</em> plants starts with a little chat.",
  "lead": "My Tiny Jungle is the cosy plant companion that remembers everything for you. Tell it what you did, in your own words. Your plants answer back, ask for what they need, and quietly learn your home.",
  "note": "Free for up to 5 plants · No account needed · Photos stay on your iPhone",
  "promises": [("drop", "No more guessing when to water"), ("heart", "Plants with real personalities"), ("paw", "Pet-safety warnings built in"), ("lock", "Your photos stay on your phone")],
  "chat_eyebrow": "This is what caring feels like", "chat_h": "You type like you'd text a friend. Your jungle answers.",
  "chat": [("me", "watered Milo and Luna yesterday"), ("card", "Logged · Watered Milo and Luna, yesterday"),
           ("plant", "Milo · Monstera", "Thank you! That should keep me happy for about a week. 🌿"),
           ("plant", "Luna · Calathea", "Could you poke my soil on Tuesday? I like it just damp, never soggy."),
           ("me", "Luna's leaves are curling a bit"),
           ("plant", "Luna · Calathea", "That's usually thirst or dry air. A quick mist and a step back from the sunny window would really help.")],
  "stories": [
    {"img": "screen-home.jpg", "alt": "Home screen", "eyebrow": "Every morning", "h": "Open the app, see who needs you. Then get on with your day.",
     "p": "Home shows your plant shelf, what's due today and how the whole jungle is doing, at a glance. Most days it simply says everyone is happy.",
     "pts": [("check", "One calm list of today's care, nothing more"), ("chat", "Log care in a sentence, or with one tap on Water, Feed, Soil or Mist"), ("heart", "Plants thank you, so you see that the care is working")]},
    {"img": "screen-plant.jpg", "alt": "Plant page", "eyebrow": "Every plant is someone", "h": "Your monstera isn't a row in a spreadsheet. It's Milo.",
     "p": "Each plant gets its own page, its own story and one of six personalities: dramatic, chill, chatty and more. It remembers every watering, feed, repot and new leaf, so you never have to.",
     "pts": [("camera", "A photo timeline of how it has grown"), ("pot", "Pot, soil and location details, with a repot check when it's time"), ("paw", "A clear warning if the plant is toxic to cats, dogs or kids")]},
    {"img": "screen-care.jpg", "alt": "Care calendar", "eyebrow": "Care that learns", "h": "Watering schedules that fit your home, not a generic chart.",
     "p": "Instead of guessing, My Tiny Jungle asks you to feel the soil now and then. From your answers it learns how fast each plant dries in your home, and adjusts with the seasons.",
     "pts": [("hand", "The soil-check ritual: 10 seconds, no more overwatering"), ("sun", "Feeding that follows the season and your hemisphere"), ("plane", "Travel care: what to do before you leave for a week")]},
    {"img": "screen-scan.jpg", "alt": "Scan screen", "eyebrow": "Shop with confidence", "h": "Standing in the garden centre? Point at the label.",
     "p": "Scan a fertiliser, potting mix or treatment and My Tiny Jungle reads the label, then tells you which of your plants it suits, which need it diluted, and which should skip it, with the reasons.",
     "pts": [("scan", "Suitable, with conditions or not recommended, for each plant"), ("sprout", "Scan a new plant to identify it and get its care plan"), ("bug", "Scan a sick leaf to narrow down spots, yellowing or pests")]},
  ],
  "all_eyebrow": "Everything in one cosy app", "all_h": "All the help a plant parent could want.",
  "all": [
    ("chat", "", "Chat-first logging", "English or Portuguese, many plants at once, “yesterday” or “2 days ago”. It just understands."),
    ("drop", "sun", "Gentle care requests", "Water, feed, mist, rotate. Your plants ask when it's time, and only then."),
    ("hand", "peach", "Soil-check ritual", "Learns each plant's drying rhythm so watering is right for your home."),
    ("steth", "terra", "Health check", "Answer a few questions about what you see and get likely causes and a plan."),
    ("bug", "", "Pest plan", "Step-by-step treatment for common pests, with check-ins until they're gone."),
    ("pot", "sun", "Repot check", "Knows when a plant has outgrown its pot and what size and soil to use next."),
    ("home", "peach", "Spaces & placement", "Organise by room and see which plant suits which window."),
    ("plane", "terra", "Travel care", "Off on holiday? Get a plan to keep everyone alive while you're away."),
    ("sprout", "", "Propagation", "Guides for cuttings and divisions, so one plant becomes many."),
    ("sun", "sun", "Season guide", "What changes in spring, summer, autumn and winter, for your plants."),
    ("paw", "peach", "Pet-safety warnings", "Toxic plants are flagged clearly, for cats, dogs and little ones."),
    ("scan", "terra", "Product scanner", "Check fertilisers and soils against every plant you own."),
  ],
  "trust_h": "Calm, kind and honest.", "trust": [
    ("lock", "Your photos never leave your phone", "Plant recognition and label scanning run on your iPhone. No account needed. Plus removes ads."),
    ("check", "Advice you can trust", "Care rules come from a reviewed plant library, never from guesswork. When the app isn't sure, it says so."),
    ("heart", "Made for real life", "Missed a week? No guilt trips. Your plants are glad you're back and tell you what to do first."),
  ],
  "p_eyebrow": "Pricing", "p_h": "Start free. Let your jungle grow when you're ready.",
  "plans": [
    ("Free", "€0", "forever", ["Up to 5 plants", "Chat logging and plant voices", "Care requests and soil-check ritual", "Care calendar and reminders", "Pet-safety warnings", "Supported by ads"], False, ""),
    ("Tiny Jungle Plus", "€1.99", "per month", ["No ads", "Unlimited plants", "Product scanner with per-plant verdicts", "Plant Doctor health checks", "Memory insights about how each plant is growing"], False, ""),
    ("Tiny Jungle Plus", "€11.99", "per year", ["Everything in Plus", "Just €1 a month", "Save 50% over monthly"], True, "Best value"),
  ],
  "fine": "Prices in euros; local prices may vary by country. Subscriptions renew automatically until cancelled in your Apple ID settings.",
  "faq_h": "Good to know",
  "faq": [
    ("Do I need to know anything about plants?", "Not at all. Add a plant with a photo or its name, and My Tiny Jungle fills in the basics. It explains things in plain words."),
    ("Is it really free?", "Yes. The free plan covers up to 5 plants with chat, care requests and reminders, forever, supported by ads. Plus removes ads and is optional."),
    ("Does it work in Portuguese?", "Yes. The app and the chat understand English and Portuguese."),
    ("What about my data?", "Your plants, photos and scans stay on your iPhone, with no account. The free version shows ads; Plus removes them."),
  ],
  "c_h": "Give your plants a voice.", "c_p": "My Tiny Jungle is coming soon to iPhone. Your jungle is going to love it.",
 },
 "pt": {
  "h1": "Uma casa cheia de plantas <em>felizes</em> começa com uma conversa.",
  "lead": "A My Tiny Jungle é a companheira acolhedora que se lembra de tudo por si. Diga o que fez, por palavras suas. As plantas respondem, pedem o que precisam e vão conhecendo a sua casa.",
  "note": "Grátis até 5 plantas · Sem conta · As fotos ficam no seu iPhone",
  "promises": [("drop", "Acabou-se adivinhar quando regar"), ("heart", "Plantas com personalidade"), ("paw", "Avisos para animais de estimação"), ("lock", "As fotos ficam no telemóvel")],
  "chat_eyebrow": "É assim que sabe cuidar", "chat_h": "Escreve como escreveria a um amigo. A sua selva responde.",
  "chat": [("me", "reguei o Milo e a Luna ontem"), ("card", "Registado · Rega do Milo e da Luna, ontem"),
           ("plant", "Milo · Monstera", "Obrigado! Assim fico feliz durante cerca de uma semana. 🌿"),
           ("plant", "Luna · Calateia", "Podes tocar na minha terra na terça? Gosto dela só húmida, nunca encharcada."),
           ("me", "as folhas da Luna estão a enrolar"),
           ("plant", "Luna · Calateia", "Normalmente é sede ou ar seco. Um borrifo e afastar-me um pouco da janela ao sol ajudava muito.")],
  "stories": [
    {"img": "screen-home.jpg", "alt": "Ecrã inicial", "eyebrow": "Todas as manhãs", "h": "Abra a app, veja quem precisa de si. E siga com o seu dia.",
     "p": "O início mostra a prateleira das plantas, o que há para hoje e como está a selva, num relance. Na maioria dos dias diz apenas que estão todas felizes.",
     "pts": [("check", "Uma lista tranquila dos cuidados de hoje, nada mais"), ("chat", "Registe numa frase, ou com um toque em Regar, Adubar, Terra ou Borrifar"), ("heart", "As plantas agradecem, para ver que os cuidados resultam")]},
    {"img": "screen-plant.jpg", "alt": "Página da planta", "eyebrow": "Cada planta é alguém", "h": "A sua monstera não é uma linha numa folha de cálculo. É o Milo.",
     "p": "Cada planta tem a sua página, a sua história e uma de seis personalidades: dramática, descontraída, conversadora e mais. Lembra-se de cada rega, adubo, mudança de vaso e folha nova, para não ter de se lembrar.",
     "pts": [("camera", "Uma cronologia de fotos de como cresceu"), ("pot", "Vaso, substrato e local, com verificação de mudança de vaso"), ("paw", "Aviso claro se a planta for tóxica para gatos, cães ou crianças")]},
    {"img": "screen-care.jpg", "alt": "Calendário de cuidados", "eyebrow": "Cuidados que aprendem", "h": "Regas à medida da sua casa, não de uma tabela genérica.",
     "p": "Em vez de adivinhar, a My Tiny Jungle pede-lhe que sinta a terra de vez em quando. Com as respostas aprende quão depressa cada planta seca na sua casa e ajusta-se às estações.",
     "pts": [("hand", "O ritual da terra: 10 segundos, chega de regar a mais"), ("sun", "Adubo que segue a estação e o seu hemisfério"), ("plane", "Cuidados de viagem: o que fazer antes de sair uma semana")]},
    {"img": "screen-scan.jpg", "alt": "Ecrã Ler", "eyebrow": "Compre com confiança", "h": "No viveiro, sem saber? Aponte para o rótulo.",
     "p": "Leia um adubo, substrato ou tratamento e a My Tiny Jungle lê o rótulo e diz-lhe a que plantas serve, quais precisam de dose diluída e quais devem evitar, com as razões.",
     "pts": [("scan", "Adequado, com condições ou não recomendado, por planta"), ("sprout", "Leia uma planta nova para a identificar e ter o plano de cuidados"), ("bug", "Leia uma folha doente para perceber manchas, amarelos ou pragas")]},
  ],
  "all_eyebrow": "Tudo numa app acolhedora", "all_h": "Toda a ajuda que um pai ou mãe de plantas pode querer.",
  "all": [
    ("chat", "", "Registo por conversa", "Português ou inglês, várias plantas de uma vez, “ontem” ou “há 2 dias”. Simplesmente percebe."),
    ("drop", "sun", "Pedidos de cuidado", "Regar, adubar, borrifar, rodar. As plantas pedem quando é altura, e só então."),
    ("hand", "peach", "Ritual da terra", "Aprende o ritmo de cada planta para regar na medida certa da sua casa."),
    ("steth", "terra", "Verificação de saúde", "Responda a umas perguntas sobre o que vê e receba causas prováveis e um plano."),
    ("bug", "", "Plano contra pragas", "Tratamento passo a passo para pragas comuns, com acompanhamento até desaparecerem."),
    ("pot", "sun", "Mudança de vaso", "Sabe quando a planta já não cabe no vaso e que tamanho e substrato usar."),
    ("home", "peach", "Divisões e lugar", "Organize por divisão e veja que planta fica melhor em que janela."),
    ("plane", "terra", "Cuidados de viagem", "Vai de férias? Receba um plano para manter todas vivas na sua ausência."),
    ("sprout", "", "Propagação", "Guias para estacas e divisões, para que uma planta dê muitas."),
    ("sun", "sun", "Guia das estações", "O que muda na primavera, verão, outono e inverno, para as suas plantas."),
    ("paw", "peach", "Avisos de toxicidade", "Plantas tóxicas assinaladas com clareza, para gatos, cães e crianças."),
    ("scan", "terra", "Leitor de produtos", "Compare adubos e substratos com todas as suas plantas."),
  ],
  "trust_h": "Tranquila, gentil e honesta.", "trust": [
    ("lock", "As fotos nunca saem do telemóvel", "O reconhecimento de plantas e a leitura de rótulos acontecem no iPhone. Sem conta. O Plus remove os anúncios."),
    ("check", "Conselhos de confiança", "As regras de cuidados vêm de uma biblioteca de plantas revista, nunca de palpites. Quando a app não tem a certeza, diz."),
    ("heart", "Feita para a vida real", "Falhou uma semana? Sem culpas. As plantas ficam contentes por voltar e dizem-lhe o que fazer primeiro."),
  ],
  "p_eyebrow": "Preços", "p_h": "Comece grátis. Deixe a selva crescer quando quiser.",
  "plans": [
    ("Grátis", "0 €", "para sempre", ["Até 5 plantas", "Registo por conversa e vozes das plantas", "Pedidos de cuidado e ritual da terra", "Calendário e lembretes", "Avisos de toxicidade", "Com anúncios"], False, ""),
    ("Tiny Jungle Plus", "1,99 €", "por mês", ["Sem anúncios", "Plantas ilimitadas", "Leitor de produtos com veredito por planta", "Verificações de saúde com o Plant Doctor", "Memória de como cada planta está a crescer"], False, ""),
    ("Tiny Jungle Plus", "11,99 €", "por ano", ["Tudo o que o Plus inclui", "Só 1 € por mês", "Poupe 50% face ao mensal"], True, "Melhor valor"),
  ],
  "fine": "Preços em euros; podem variar consoante o país. As subscrições renovam automaticamente até serem canceladas nas definições do seu ID Apple.",
  "faq_h": "Bom saber",
  "faq": [
    ("Preciso de perceber de plantas?", "Nada. Adicione uma planta com uma foto ou o nome e a My Tiny Jungle preenche o básico. Explica tudo em palavras simples."),
    ("É mesmo grátis?", "Sim. O plano grátis inclui até 5 plantas com conversa, pedidos de cuidado e lembretes, para sempre, com anúncios. O Plus remove os anúncios e é opcional."),
    ("Funciona em português?", "Sim. A app e a conversa percebem português e inglês."),
    ("E os meus dados?", "As plantas, fotos e leituras ficam no seu iPhone, sem conta. A versão grátis tem anúncios; o Plus remove-os."),
  ],
  "c_h": "Dê voz às suas plantas.", "c_p": "A My Tiny Jungle chega em breve ao iPhone. A sua selva vai adorar.",
 },
}


def render_home(L, t, page, phone, apple_icon):
    h = H[L]
    cta = f'<span class="btn">{apple_icon}{t["cta"]}</span>'
    promises = "".join(f'<li><span class="pi">{IC[i]}</span>{x}</li>' for i, x in h["promises"])

    def bubble(c):
        if c[0] == "me":
            return f'<div class="b me">{c[1]}</div>'
        if c[0] == "card":
            return f'<div class="b log">{IC["check"]}{c[1]}</div>'
        return f'<div class="b plant"><small>{c[1]}</small>{c[2]}</div>'
    chat = "".join(bubble(c) for c in h["chat"])

    stories = ""
    for n, s in enumerate(h["stories"]):
        pts = "".join(f'<li><span class="pi">{IC[i]}</span><span>{x}</span></li>' for i, x in s["pts"])
        stories += (f'<section class="section story"><div class="wrap split{" rev" if n % 2 == 0 else ""}">'
                    f'{phone(s["img"], s["alt"])}'
                    f'<div><div class="eyebrow">{s["eyebrow"]}</div><h2>{s["h"]}</h2><p class="sub">{s["p"]}</p><ul class="pts">{pts}</ul></div>'
                    f'</div></section>')

    feats = "".join(f'<div class="card"><div class="ico {c}">{IC[i]}</div><h3>{hd}</h3><p>{d}</p></div>' for i, c, hd, d in h["all"])
    trust = "".join(f'<div><div class="ico">{IC[i]}</div><h3>{hd}</h3><p>{d}</p></div>' for i, hd, d in h["trust"])
    plans = "".join(
        f'<div class="plan{" hl" if hl else ""}"><div class="name">{nm}{f"<span class=tag>{tag}</span>" if tag else ""}</div>'
        f'<div class="price">{pr}</div><div class="per">{per}</div><ul>{"".join(f"<li>{x}</li>" for x in items)}</ul></div>'
        for nm, pr, per, items, hl, tag in h["plans"])
    faq = "".join(f"<details><summary>{q}</summary><p>{a}</p></details>" for q, a in h["faq"])

    body = f"""
<section class="hero"><div class="wrap">
<div><h1>{h['h1']}</h1><p class="lead">{h['lead']}</p>
<div class="ctas">{cta}</div><p class="note">{h['note']}</p></div>
<div class="stage"><div class="blob"></div>{phone('screen-home.jpg', 'Home screen').replace('loading="lazy"', 'fetchpriority="high"')}{phone('screen-plant.jpg', 'Plant page', 'back')}</div>
</div></section>
<section class="promises"><div class="wrap"><ul>{promises}</ul></div></section>
<section class="talk"><div class="wrap"><div class="eyebrow">{h['chat_eyebrow']}</div><h2>{h['chat_h']}</h2><div class="bubbles">{chat}</div></div></section>
<div id="features"></div>{stories}
<section class="section"><div class="wrap">
<div class="eyebrow">{h['all_eyebrow']}</div><h2>{h['all_h']}</h2>
<div class="grid three">{feats}</div></div></section>
<section class="trust"><div class="wrap"><h2>{h['trust_h']}</h2><div class="trust-grid">{trust}</div></div></section>
<section class="section" id="pricing"><div class="wrap">
<div class="eyebrow">{h['p_eyebrow']}</div><h2>{h['p_h']}</h2>
<div class="plans">{plans}</div><p class="fine">{h['fine']}</p></div></section>
<section class="section"><div class="wrap narrow"><h2>{h['faq_h']}</h2><div class="faq">{faq}</div></div></section>
<section class="closing"><div class="wrap"><img src="/assets/icon-512.png" alt="My Tiny Jungle icon" width="96" height="96">
<h2>{h['c_h']}</h2><p>{h['c_p']}</p>{cta}</div></section>"""
    return page(L, "/", t["home_title"], t["home_desc"], body)
