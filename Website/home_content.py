"""Landing page for mytinyjungle.com (EN + PT-PT). Mirrors the app: every tab, screen and feature."""


def I(name):
    return f'<img src="/icons/{name}.png" alt="" width="54" height="54" loading="lazy">'


H = {
 "en": {
  "kicker": "For plant parents, new and seasoned",
  "h1": "Your plants have a lot to say. <em>Now you can listen.</em>",
  "lead": "My Tiny Jungle is a cosy home for every plant you love. Tell it what you did in your own words, and your plants answer back, ask gently for what they need, and grow happier with you, week after week.",
  "note": "Free for up to 5 plants · Plus removes ads · Your photos stay on your phone",
  "f1": ("drop", "Goldie is thirsty", "Check the soil today"),
  "f2": ("award", "17 waterings on time", "You two have a rhythm"),
  "pills": [("soilTest", "No more guessing when to water"), ("chat", "Plants with real personalities"), ("calendarHeart", "Gentle reminders, never nagging"), ("healthShield", "Early help when one struggles"), ("homeLeaf", "Made for real homes")],
  "chapters": [
   {"id": "today", "icon": "sunflower", "eyebrow": "Today", "h": "Every morning, a calm look at your jungle.",
    "sub": "Open the app and see who needs you, who's thriving and what's coming up. Most days it simply says everyone is happy.",
    "shots": [("today1", "Care story cards", "Big, friendly cards for each plant that needs you today. One tap and it's done."),
              ("today-ring", "Your jungle's health", "A gentle ring shows how many plants are thriving, okay or in need of you."),
              ("today2", "Next sips, seasons and little lessons", "Who's thirsty next, what this season means at home, and a one-minute lesson to grow your green thumb."),
              ("conversations", "Every plant, one place", "See what each plant has to say, from Monty the monstera to Pesto the basil.")],
    "benefits": [("wateringCan", "Care in one tap", "Water, feed, mist or check the soil straight from Today."),
                 ("calendar", "Coming up, at a glance", "Know what's next before anyone droops."),
                 ("celebrate", "Little wins, celebrated", "Streaks and milestones make care feel like a joy.")]},
   {"id": "plants", "icon": "pottedPlant", "eyebrow": "My plants", "h": "Every plant is someone, with a name and a story.",
    "sub": "Your whole jungle in one beautiful grid, with status pills that tell you who's thriving and who'd love a soil check. Open any plant to see its own page.",
    "shots": [("plants", "My plants", "Photos, names and a little status for each one: Thriving, Check soil, Struggling."),
              ("plant", "Each plant's own page", "Water, Feed, Repot and Check right at the top, and the next two weeks of care below."),
              ("timeline", "A timeline of your life together", "Days together, last watering, care moments, cuttings and every record in one place."),
              ("profile", "Personality and home", "Choose a personality, set its room, pot and soil, so the advice fits it perfectly.")],
    "benefits": [("feedJar", "Water, Feed, Repot, Check", "The four things plants need most, always one tap away."),
                 ("growth", "Watch them grow", "A photo timeline that shows how far you've come."),
                 ("shieldLeaf", "Safe for pets and kids", "Clear warnings when a plant isn't safe to nibble.")]},
   {"id": "talk", "icon": "chat", "eyebrow": "Jungle chat", "h": "Talk to your plants. They talk back.",
    "sub": "Type like you'd text a friend: \u201cwatered Monty and Pesto\u201d. The app takes note, and your plants reply in their own voices. Ask anything, any time.",
    "chat": True},
   {"id": "care", "icon": "calendarHeart", "eyebrow": "Care", "h": "A care plan that fits your home and the seasons.",
    "sub": "Your week, your month and the year ahead, planned around how your plants actually live. Plus help for holidays, new cuttings and every how-to you'll ever need.",
    "shots": [("care-week", "This week", "Every soil check, watering and gentle peek for pests, day by day."),
              ("care-calendar", "Month and calendar", "See the whole month of care at a glance, with little dots for each plant."),
              ("care-season", "Seasons", "What spring, summer, autumn and winter mean for your plants, where you live."),
              ("travel", "Going away", "Pick your dates and see who's fine, who needs a deep water and who needs a sitter."),
              ("howto", "How-to guides", "Water the right amount, read the soil, prune, take a cutting, repot, treat pests: step by step.")],
    "benefits": [("soilTest", "The soil-check ritual", "Feel the soil, tell the app. It learns how fast each plant dries in your home."),
                 ("travel", "Holidays without worry", "A plan for every plant before you leave."),
                 ("seedling", "Propagation", "Take a cutting and follow it from water glass to new plant.")]},
   {"id": "scan", "icon": "fertilizer", "eyebrow": "Scan", "h": "Point at a label. Know what's right for your plants.",
    "sub": "Standing in the garden centre? Scan a fertiliser, soil or treatment and see which of your plants it suits, with how and when to use it. Or scan a new plant, or a sick leaf.",
    "shots": [("scan", "Labels, new plants and sick leaves", "One place to scan anything plant-related."),
              ("scan-result", "A verdict for every plant", "Leaves, roots and strength explained simply, then what each plant thinks of it."),
              ("health", "Health check", "Something looks off? Show a photo and tap what you see. Get kind, clear next steps.")],
    "benefits": [("fertilizer", "The right food, every time", "No more guessing in the garden centre aisle."),
                 ("sprout", "Meet a new plant", "Identify it and get its care plan straight away."),
                 ("firstAid", "Catch trouble early", "Spots, yellowing or pests, sorted before they spread.")]},
   {"id": "me", "icon": "award", "eyebrow": "Me", "h": "Your jungle, your story, your milestones.",
    "sub": "See how far you've come: plants, happy plants, care moments and years together. Organise plants by room, track milestones and celebrate every leaf.",
    "shots": [("me", "Your jungle at a glance", "Spaces, cuttings, milestones and your Plus status, all in one cosy page.")],
    "benefits": [("livingRoom", "Spaces", "Living room, kitchen, balcony: see which plant lives where."),
                 ("crown", "Milestones", "From your first plant to an all-happy jungle."),
                 ("gift", "Made to keep", "Your plants' story stays with you, season after season.")]},
  ],
  "chat": [("me", "Watered Monty and Pesto"), ("plant", "Monty", "Thank you! I'll let my top soil dry before the next drink."),
           ("plant", "Pesto", "Ahh, fresh water. Pick my top leaves soon so I stay bushy!"), ("me", "Should I feed Pearl?"),
           ("plant", "Pearl", "Not yet. It's autumn and I'm resting. Orchid feed again in spring."),
           ("plant", "Goldie", "Can you check my soil? I might be getting thirsty.")],
  "chat_shots": [("jungle-chat", "Your jungle, all together", "Talk to every plant at once."), ("plant-chat", "One-to-one", "A quiet chat with a single plant.")],
  "all_eyebrow": "Everything inside", "all_h": "All the help a plant parent could wish for.",
  "all": [("chat", "Chat with your plants", "Write it like a text. They reply with personality."),
          ("soilTest", "Soil-check ritual", "Learns each plant's rhythm so watering is just right."),
          ("calendarHeart", "Gentle care requests", "Water, feed, mist and turn, only when it's time."),
          ("firstAid", "Health check", "Kind, clear help when a plant struggles."),
          ("bug", "Pest guard", "Spot pests early and follow a simple plan."),
          ("pot", "Repot check", "Knows when it's time and what pot and soil to use."),
          ("travel", "Going away", "Holiday plans so every plant is fine while you're gone."),
          ("seedling", "Cuttings", "Grow new plants from the ones you love."),
          ("sun", "Season guide", "What each season means for your plants, where you live."),
          ("fertilizer", "Label scanner", "Know if a food or soil suits each of your plants."),
          ("livingRoom", "Spaces", "Room by room, the right light for every plant."),
          ("shieldLeaf", "Pet-safety warnings", "Clear notes for cats, dogs and little ones.")],
  "plus_eyebrow": "Tiny Jungle Plus", "plus_h": "Room for every plant you love.",
  "plus_p": "Plus gives you everything to keep your jungle happy: unlimited plants, early help when one struggles, the right food for each, and no ads. Quiet, calm care, the way it should feel.",
  "plans": [("Free", "€0", "forever", ["Up to 5 plants", "Jungle chat and plant voices", "Care requests and reminders", "Soil-check ritual", "Supported by ads"], False, ""),
            ("Plus monthly", "€1.99", "per month", ["Unlimited plants", "No ads", "Label scanner verdicts", "Health checks"], False, ""),
            ("Plus yearly", "€11.99", "per year", ["Everything in Plus", "Just €1 a month", "Save 50%"], True, "Best value")],
  "fine": "Prices in euros; local prices may vary. Subscriptions renew automatically until cancelled in your Apple account settings.",
  "trust": [("shieldLeaf", "Your photos stay with you", "Plant photos, scans and notes stay on your phone. No account needed."),
            ("careHands", "Advice you can trust", "Care tips come from a carefully reviewed plant library. When we're not sure, we say so."),
            ("celebrate", "No guilt, ever", "Missed a week? Your plants are just happy you're back, and tell you what to do first.")],
  "faq_h": "Good to know",
  "faq": [("Do I need to know anything about plants?", "Not at all. Add a plant with a photo or its name and My Tiny Jungle fills in the rest, in plain, friendly words."),
          ("Is it really free?", "Yes. Up to 5 plants with chat, care requests and reminders, forever, supported by ads. Plus is optional and removes ads."),
          ("Does it speak Portuguese?", "Yes. The app and your plants speak English and Portuguese."),
          ("Where do my plants' photos go?", "Nowhere. They stay on your phone.")],
  "c_h": "Give your plants a voice.", "c_p": "My Tiny Jungle is coming soon to iPhone. Your jungle is going to love it.",
 },
 "pt": {
  "kicker": "Para quem cuida de plantas, de primeira viagem ou com experiência",
  "h1": "As suas plantas têm muito para dizer. <em>Agora pode ouvi-las.</em>",
  "lead": "A My Tiny Jungle é uma casa acolhedora para todas as plantas de que gosta. Conte o que fez, por palavras suas, e as plantas respondem, pedem com carinho o que precisam e ficam mais felizes consigo, semana após semana.",
  "note": "Grátis até 5 plantas · O Plus remove os anúncios · As fotos ficam no seu telemóvel",
  "f1": ("drop", "A Goldie tem sede", "Ver a terra hoje"),
  "f2": ("award", "17 regas a horas", "Vocês têm ritmo"),
  "pills": [("soilTest", "Acabou-se adivinhar quando regar"), ("chat", "Plantas com personalidade"), ("calendarHeart", "Lembretes gentis, sem insistir"), ("healthShield", "Ajuda cedo quando uma sofre"), ("homeLeaf", "Feita para casas reais")],
  "chapters": [
   {"id": "today", "icon": "sunflower", "eyebrow": "Hoje", "h": "Todas as manhãs, um olhar tranquilo sobre a sua selva.",
    "sub": "Abra a app e veja quem precisa de si, quem está a crescer feliz e o que vem a seguir. Na maioria dos dias diz apenas que estão todas felizes.",
    "shots": [("today1", "Cartões de cuidados", "Cartões grandes e simpáticos para cada planta que precisa de si hoje. Um toque e está feito."),
              ("today-ring", "A saúde da sua selva", "Um anel suave mostra quantas plantas estão ótimas, bem ou a precisar de si."),
              ("today2", "Próximos goles, estações e pequenas lições", "Quem tem sede a seguir, o que a estação significa em casa e uma lição de um minuto."),
              ("conversations", "Todas as plantas, num só lugar", "Veja o que cada planta tem para dizer, do Monty à Pesto.")],
    "benefits": [("wateringCan", "Cuidar num toque", "Regar, adubar, borrifar ou ver a terra, logo no Hoje."),
                 ("calendar", "O que vem aí, num relance", "Saiba o que vem antes de alguma murchar."),
                 ("celebrate", "Pequenas vitórias celebradas", "Sequências e marcos tornam o cuidado uma alegria.")]},
   {"id": "plants", "icon": "pottedPlant", "eyebrow": "As minhas plantas", "h": "Cada planta é alguém, com nome e história.",
    "sub": "A selva inteira numa grelha bonita, com etiquetas que dizem quem está ótima e quem gostava que lhe visse a terra. Abra uma planta para ver a sua página.",
    "shots": [("plants", "As minhas plantas", "Fotos, nomes e um estado para cada uma: Ótima, Ver terra, Com dificuldades."),
              ("plant", "A página de cada planta", "Regar, Adubar, Mudar de vaso e Verificar no topo, e as próximas duas semanas em baixo."),
              ("timeline", "A vossa história juntos", "Dias juntos, última rega, momentos de cuidado, estacas e todos os registos."),
              ("profile", "Personalidade e casa", "Escolha a personalidade, a divisão, o vaso e a terra, para conselhos à medida.")],
    "benefits": [("feedJar", "Regar, Adubar, Vaso, Verificar", "O que as plantas mais precisam, sempre a um toque."),
                 ("growth", "Veja-as crescer", "Uma cronologia de fotos que mostra o caminho feito."),
                 ("shieldLeaf", "Seguro para animais e crianças", "Avisos claros quando uma planta não é para trincar.")]},
   {"id": "talk", "icon": "chat", "eyebrow": "Conversa da selva", "h": "Fale com as suas plantas. Elas respondem.",
    "sub": "Escreva como escreveria a um amigo: \u201creguei o Monty e a Pesto\u201d. A app toma nota e as plantas respondem com a sua própria voz. Pergunte o que quiser, quando quiser.",
    "chat": True},
   {"id": "care", "icon": "calendarHeart", "eyebrow": "Cuidados", "h": "Um plano à medida da sua casa e das estações.",
    "sub": "A semana, o mês e o ano, planeados à volta de como as suas plantas vivem. E ajuda para férias, estacas novas e todos os guias de que vai precisar.",
    "shots": [("care-week", "Esta semana", "Cada verificação da terra, rega e espreitadela a pragas, dia a dia."),
              ("care-calendar", "Mês e calendário", "Todo o mês de cuidados num relance, com pontinhos para cada planta."),
              ("care-season", "Estações", "O que a primavera, o verão, o outono e o inverno significam onde vive."),
              ("travel", "Vou viajar", "Escolha as datas e veja quem fica bem, quem precisa de rega funda e quem precisa de quem cuide."),
              ("howto", "Guias passo a passo", "Regar na medida certa, ler a terra, podar, fazer estacas, mudar de vaso, tratar pragas.")],
    "benefits": [("soilTest", "O ritual da terra", "Sinta a terra e diga à app. Ela aprende o ritmo de cada planta na sua casa."),
                 ("travel", "Férias sem preocupações", "Um plano para cada planta antes de sair."),
                 ("seedling", "Propagação", "Faça uma estaca e acompanhe-a do copo de água à planta nova.")]},
   {"id": "scan", "icon": "fertilizer", "eyebrow": "Ler", "h": "Aponte para o rótulo. Saiba o que serve às suas plantas.",
    "sub": "No viveiro, sem saber o que levar? Leia um adubo, terra ou tratamento e veja a que plantas serve, como e quando usar. Ou leia uma planta nova, ou uma folha doente.",
    "shots": [("scan", "Rótulos, plantas novas e folhas doentes", "Um só lugar para ler tudo o que é de plantas."),
              ("scan-result", "Um veredito para cada planta", "Folhas, raízes e força explicados de forma simples, e o que cada planta acha."),
              ("health", "Verificação de saúde", "Algo parece estranho? Mostre uma foto e toque no que vê. Receba próximos passos claros.")],
    "benefits": [("fertilizer", "A comida certa, sempre", "Chega de adivinhar no corredor do viveiro."),
                 ("sprout", "Conheça uma planta nova", "Identifique-a e receba logo o plano de cuidados."),
                 ("firstAid", "Apanhar problemas cedo", "Manchas, amarelos ou pragas, resolvidos antes de alastrarem.")]},
   {"id": "me", "icon": "award", "eyebrow": "Eu", "h": "A sua selva, a sua história, os seus marcos.",
    "sub": "Veja o caminho feito: plantas, plantas felizes, momentos de cuidado e anos juntos. Organize por divisão, acompanhe marcos e celebre cada folha.",
    "shots": [("me", "A sua selva num relance", "Divisões, estacas, marcos e o seu Plus, numa página acolhedora.")],
    "benefits": [("livingRoom", "Divisões", "Sala, cozinha, varanda: veja que planta vive onde."),
                 ("crown", "Marcos", "Da primeira planta a uma selva toda feliz."),
                 ("gift", "Para guardar", "A história das suas plantas fica consigo, estação após estação.")]},
  ],
  "chat": [("me", "Reguei o Monty e a Pesto"), ("plant", "Monty", "Obrigado! Vou deixar a terra de cima secar antes da próxima."),
           ("plant", "Pesto", "Ahh, água fresca. Apanha as minhas folhas de cima para eu ficar cheiinha!"), ("me", "Devo adubar a Pearl?"),
           ("plant", "Pearl", "Ainda não. É outono e estou a descansar. Adubo de orquídea outra vez na primavera."),
           ("plant", "Goldie", "Podes ver a minha terra? Acho que estou a ficar com sede.")],
  "chat_shots": [("jungle-chat", "A selva toda junta", "Fale com todas as plantas de uma vez."), ("plant-chat", "Cara a cara", "Uma conversa tranquila com uma só planta.")],
  "all_eyebrow": "Tudo lá dentro", "all_h": "Toda a ajuda que um amante de plantas pode desejar.",
  "all": [("chat", "Conversar com as plantas", "Escreva como uma mensagem. Elas respondem com personalidade."),
          ("soilTest", "Ritual da terra", "Aprende o ritmo de cada planta para regar na medida certa."),
          ("calendarHeart", "Pedidos de cuidado", "Regar, adubar, borrifar e rodar, só quando é altura."),
          ("firstAid", "Verificação de saúde", "Ajuda clara e gentil quando uma planta sofre."),
          ("bug", "Guarda contra pragas", "Detete pragas cedo e siga um plano simples."),
          ("pot", "Mudança de vaso", "Sabe quando é altura e que vaso e terra usar."),
          ("travel", "Vou viajar", "Planos de férias para todas ficarem bem."),
          ("seedling", "Estacas", "Faça plantas novas a partir das que adora."),
          ("sun", "Guia das estações", "O que cada estação significa onde vive."),
          ("fertilizer", "Leitor de rótulos", "Saiba se um adubo ou terra serve a cada planta."),
          ("livingRoom", "Divisões", "Divisão a divisão, a luz certa para cada planta."),
          ("shieldLeaf", "Avisos para animais", "Notas claras para gatos, cães e crianças.")],
  "plus_eyebrow": "Tiny Jungle Plus", "plus_h": "Espaço para todas as plantas que ama.",
  "plus_p": "O Plus dá-lhe tudo para manter a selva feliz: plantas ilimitadas, ajuda cedo quando uma sofre, a comida certa para cada uma e sem anúncios. Cuidar com calma, como deve ser.",
  "plans": [("Grátis", "0 €", "para sempre", ["Até 5 plantas", "Conversa e vozes das plantas", "Pedidos de cuidado e lembretes", "Ritual da terra", "Com anúncios"], False, ""),
            ("Plus mensal", "1,99 €", "por mês", ["Plantas ilimitadas", "Sem anúncios", "Vereditos do leitor de rótulos", "Verificações de saúde"], False, ""),
            ("Plus anual", "11,99 €", "por ano", ["Tudo o que o Plus inclui", "Só 1 € por mês", "Poupe 50%"], True, "Melhor valor")],
  "fine": "Preços em euros; podem variar consoante o país. As subscrições renovam automaticamente até serem canceladas nas definições da sua conta Apple.",
  "trust": [("shieldLeaf", "As fotos ficam consigo", "Fotos, leituras e notas ficam no seu telemóvel. Não precisa de conta."),
            ("careHands", "Conselhos de confiança", "As dicas vêm de uma biblioteca de plantas revista com cuidado. Quando não temos a certeza, dizemos."),
            ("celebrate", "Nunca há culpa", "Falhou uma semana? As plantas só ficam contentes por voltar e dizem-lhe o que fazer primeiro.")],
  "faq_h": "Bom saber",
  "faq": [("Preciso de perceber de plantas?", "Nada. Adicione uma planta com uma foto ou o nome e a My Tiny Jungle trata do resto, em palavras simples e simpáticas."),
          ("É mesmo grátis?", "Sim. Até 5 plantas com conversa, pedidos de cuidado e lembretes, para sempre, com anúncios. O Plus é opcional e remove os anúncios."),
          ("Fala português?", "Sim. A app e as suas plantas falam português e inglês."),
          ("Para onde vão as fotos das plantas?", "Para lado nenhum. Ficam no seu telemóvel.")],
  "c_h": "Dê voz às suas plantas.", "c_p": "A My Tiny Jungle chega em breve ao iPhone. A sua selva vai adorar.",
 },
}


def render_home(L, t, page, phone, apple_icon):
    h = H[L]
    cta = f'<a class="btn" href="#pricing">{apple_icon}{t["cta"]}</a>'

    def shot(name, title, text):
        return f'<div class="shot">{phone("app/" + name + ".jpg", title)}<h3>{title}</h3><p>{text}</p></div>'

    def benefits(items):
        return '<div class="benefits">' + "".join(f'<div class="benefit">{I(i)}<div><b>{b}</b><span>{s}</span></div></div>' for i, b, s in items) + "</div>"

    chapters = ""
    for c in h["chapters"]:
        head = (f'<div class="chapter-head"><div class="ic">{I(c["icon"])}</div><div><div class="eyebrow">{c["eyebrow"]}</div>'
                f'<h2>{c["h"]}</h2><p class="sub">{c["sub"]}</p></div></div>')
        if c.get("chat"):
            bub = "".join(f'<div class="b me">{x[1]}</div>' if x[0] == "me" else f'<div class="b plant"><small>{x[1]}</small>{x[2]}</div>' for x in h["chat"])
            shots = "".join(shot(*s) for s in h["chat_shots"])
            body = f'<div class="chat"><div class="bubbles">{bub}</div><div class="gallery" style="padding-top:0">{shots}</div></div>'
        else:
            body = f'<div class="gallery">{"".join(shot(*s) for s in c["shots"])}</div>{benefits(c["benefits"])}'
        anchor = ' id="features"' if c["id"] == "today" else f' id="{c["id"]}"'
        chapters += f'<section class="chapter"{anchor}><div class="wrap">{head}{body}</div></section>'

    pills = "".join(f'<div class="pill">{I(i)}{x}</div>' for i, x in h["pills"])
    feats = "".join(f'<div class="card">{I(i)}<h3>{a}</h3><p>{b}</p></div>' for i, a, b in h["all"])
    plans = "".join(
        f'<div class="plan{" hl" if hl else ""}"><div class="name">{nm}{f"<span class=tag>{tag}</span>" if tag else ""}</div>'
        f'<div class="price">{pr}</div><div class="per">{per}</div><ul>{"".join(f"<li>{x}</li>" for x in items)}</ul></div>'
        for nm, pr, per, items, hl, tag in h["plans"])
    faq = "".join(f"<details><summary>{q}</summary><p>{a}</p></details>" for q, a in h["faq"])
    f1, f2 = h["f1"], h["f2"]

    body = f"""
<section class="hero"><div class="wrap">
<div><span class="kicker">{I('pottedPlant')}{h['kicker']}</span><h1>{h['h1']}</h1><p class="lead">{h['lead']}</p>
{cta}<p class="note">{h['note']}</p></div>
<div class="stage">
<div class="float f1">{I(f1[0])}<div>{f1[1]}<small>{f1[2]}</small></div></div>
{phone('app/today1.jpg', 'Today').replace('loading="lazy"', 'fetchpriority="high"').replace('class="phone "', 'class="phone front"')}
{phone('app/plant.jpg', 'Plant page', 'back')}
<div class="float f2">{I(f2[0])}<div>{f2[1]}<small>{f2[2]}</small></div></div>
</div></div></section>
<section><div class="wrap"><div class="pills">{pills}</div></div></section>
{chapters}
<section class="chapter"><div class="wrap">
<div class="eyebrow">{h['all_eyebrow']}</div><h2>{h['all_h']}</h2><div class="grid">{feats}</div>
<div class="trust">{"".join(f'<div class="benefit">{I(i)}<div><b>{a}</b><span>{b}</span></div></div>' for i, a, b in h["trust"])}</div>
</div></section>
<section class="chapter" id="pricing"><div class="wrap"><div class="plus">
{phone('app/plus.jpg', 'Tiny Jungle Plus')}
<div><div class="eyebrow">{h['plus_eyebrow']}</div><h2>{h['plus_h']}</h2><p class="sub">{h['plus_p']}</p>
<div class="plans">{plans}</div><p class="fine">{h['fine']}</p></div>
</div></div></section>
<section class="chapter"><div class="wrap narrow"><h2>{h['faq_h']}</h2><div class="faq">{faq}</div></div></section>
<section class="closing"><div class="wrap"><img class="app" src="/assets/icon-512.png" alt="My Tiny Jungle" width="110" height="110">
<h2>{h['c_h']}</h2><p>{h['c_p']}</p>{cta}</div></section>"""
    return page(L, "/", t["home_title"], t["home_desc"], body)
