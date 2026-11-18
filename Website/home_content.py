"""Landing page for mytinyjungle.com (EN + PT-BR).

Layout: a split stage. The reading column scrolls through the app tab by tab while the stage on the
right holds one of the project's real plant photos with the phone on top; both change as each chapter
arrives. Then a full-width features field, the beta slip, two pricing fields, the FAQ as reading text
and a closing photograph.
"""
import json

TESTFLIGHT_URL = "https://testflight.apple.com/join/A8YUuUHj"


def I(name, size=40, lazy=True):
    lz = LAZY[not lazy]
    return f'<img class="i3d" src="/icons/{name}.png" alt="" width="{size}" height="{size}"{lz}>'


# Scene per chapter: (plant photo, app screen). Index 0 is the hero.
SCENES = [("monstera", "today1"), ("echeveria", "today-ring"), ("pothos", "plant"), ("basil", "jungle-chat"),
          ("peacelily", "care-week"), ("orchid", "scan-result"), ("snake", "share-home"), ("zz", "me")]

H = {
 "en": {
  "h1": "Plant care that knows your home.",
  "lead": "Other apps water on a timer. My Tiny Jungle works out each plant's care from your weather, your heating, the light in each room, its pot and how its soil really dries. Then your plants tell you, in their own words.",
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
   {"id": "share", "h": "Share your jungle", "p": "Living with a partner, family or housemates? Invite them and care for the same plants together. Turns are shared fairly, everyone sees what was done, and nobody waters twice.",
    "list": [("gift", "Invite in one tap: by link, email or message"), ("calendarHeart", "Fair turns: whoever didn't water last time goes next"), ("careHands", "Cover for each other: busy or away? Someone says I've got it")],
    "thumbs": [("share-home", "Our jungle"), ("share-turns", "Who looks after what"), ("share-invite", "Invite someone")]},
   {"id": "me", "h": "Your jungle, growing with you", "p": "Plants, happy plants, care moments and years together. Rooms and spaces, cuttings and milestones, from your first plant to an all-happy jungle.",
    "list": [("livingRoom", "Living room, kitchen, balcony: who lives where"), ("award", "Milestones that make care feel like a joy")],
    "thumbs": [("me", "Me")]},
  ],
  "pills": [("soilTest", "No more guessing when to water"), ("chat", "Plants with real personalities"), ("calendarHeart", "Gentle reminders, never nagging"), ("healthShield", "Early help when one struggles"), ("homeLeaf", "Grown for real homes")],
  "cards": {"today": [("wateringCan", "Care in one tap", "Water, feed, mist or check the soil straight from Today."), ("calendar", "Coming up, at a glance", "Know what's next before anyone droops."), ("celebrate", "Little wins, celebrated", "Streaks and milestones make care feel like a joy.")],
            "plants": [("feedJar", "Water, Feed, Repot, Check", "The four things plants need most, always one tap away."), ("growth", "Watch them grow", "A photo timeline that shows how far you've come."), ("shieldLeaf", "Safe for pets and kids", "Clear warnings when a plant isn't safe to nibble.")]},
  "chat_label": "Pick a plant, then ask",
  "chat_plants": [("Monty", "monstera"), ("Pesto", "basil"), ("Pearl", "orchid"), ("Goldie", "pothos")],
  "chat_qs": ["How are you?", "Do you need water?", "Should I feed you?"],
  "chat_a": {
   "Monty": ["Happy and growing a new leaf. Thank you for the bright spot by the window.", "Not yet. My top soil is still damp. Check me again on Thursday.", "Not now. Autumn is my resting time. Half-strength food again in spring."],
   "Pesto": ["Bushy and smelling lovely. Pick my top leaves soon so I stay that way.", "Yes please. Basil drinks a lot, a good soak today would be perfect.", "A little, every two weeks while I am growing. Not too much, or I lose flavour."],
   "Pearl": ["Resting, and dreaming of my next flower spike.", "Not yet. Water me when my roots look silvery, about once a week.", "Not this season. Orchid food again when spring arrives."],
   "Goldie": ["A little droopy, to be honest. I think I am thirsty.", "Yes, can you check my soil? If the top two centimetres are dry, I would love a drink.", "After a drink, yes. Never feed me when I am dry."]},
  "you": "You",
  "all": [["chat", "Chat with your plants", "Write it like a text. They reply with personality."], ["soilTest", "Soil-check ritual", "Learns each plant's rhythm so watering is just right."], ["calendarHeart", "Gentle care requests", "Water, feed, mist and turn, only when it's time."], ["firstAid", "Health check", "Kind, clear help when a plant struggles."], ["bug", "Pest guard", "Spot pests early and follow a simple plan."], ["pot", "Repot check", "Knows when it's time and what pot and soil to use."], ["travel", "Going away", "Holiday plans so every plant is fine while you're gone."], ["seedling", "Cuttings", "Grow new plants from the ones you love."], ["sun", "Season guide", "What each season means for your plants, where you live."], ["fertilizer", "Label scanner", "Know if a food or soil suits each of your plants."], ["livingRoom", "Spaces", "Room by room, the right light for every plant."], ["shieldLeaf", "Pet-safety warnings", "Clear notes for cats, dogs and little ones."]],
  "all_h": "All the help a plant parent could wish for",
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
  "know_h": "Not a timer. Care that knows your home.",
  "know_p": "Most plant apps ask how often to water, then count down: every 7 days, forever. My Tiny Jungle works it out for each plant, every day, from everything around it.",
  "know_vs": (("A reminder app", ["Water every 7 days", "The same in July and January", "Waters the balcony in the rain", "Two people, two reminders, one drowned fern"]), ("My Tiny Jungle", ["Water when that pot will be dry", "Shifts with your seasons and hemisphere", "Skips outdoor plants after rain", "Shares turns, so nobody double-waters"])),
  "two_h": "Same monstera, two homes",
  "two_p": "One week in July. Same plant, same species. Different lives.",
  "homes": [("Lisbon", "Balcony, terracotta pot, highs around 28 °C", "About every 5 days", "Warm days and a terracotta pot dry the soil fast. If it rains, the reminder waits."), ("Berlin", "Bright living room, plastic pot, 19 °C outside", "About every 8 days", "Indoors, plastic holds water longer. In winter, with the heating on, the sums change again.")],
  "two_timer": "A fixed timer says every 7 days for both: too little in Lisbon, too much in Berlin.",
  "in_h": "What it takes into account",
  "inputs": [("sun", "Your city and climate", "Climate type, the local forecast, rain, the seasons and your hemisphere."), ("homeLeaf", "Your home", "Heating in winter, air conditioning in summer, and whether the air is dry or damp."), ("livingRoom", "Light, room by room", "The light you set for each room, matched to what each plant likes."), ("pot", "The pot", "Size, material and drainage. Terracotta dries faster than glass."), ("soilTest", "Its own rhythm", "Species data first, then your soil checks and care history teach it how fast that pot really dries."), ("balcony", "Inside or out", "Outdoor plants follow the real weather. Indoor plants follow your home."), ("shieldLeaf", "Pets and kids", "Clear warnings for plants that are toxic to cats, dogs or little ones."), ("careHands", "Your household", "Whose turn it is, cover while someone travels, and shared care so nobody waters twice.")],
  "smart_h": "Quietly very clever",
  "smart_p": "Behind the friendly chat is real plant knowledge. Every answer is tuned to the plant, your home and the weather outside your window.",
  "smart": [("628", "species", "Known by name, each with its own care rhythm"), ("27", "pests", "Spotted early, with a calm plan for each"), ("45", "symptoms", "Yellow leaves, brown tips, droop: read and explained"),
            ("Climate", "", "Local weather, seasons and hardiness zone shape every reminder"), ("Home", "", "Heating, air-con, draughts and room light change the advice"), ("Pets & kids", "", "Clear warnings for plants that aren't safe to nibble")],
  "faq": [("Can I share my plants with someone?", "Yes. Invite your partner, family or housemates and you all look after the same jungle, with fair turns and no double watering."), ("Do I need to know anything about plants?", "Not at all. Add a plant with a photo or its name and the app fills in the rest, in plain, friendly words."), ("Who is Erty?", "Erty is the little leaf on the app icon and your plants' best friend. Erty greets you when you start, asks a few easy questions about your home and sets everything up for you."),
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
  "h1": "O cuidado que conhece a sua casa.",
  "lead": "Outros apps regam no cronômetro. O My Tiny Jungle descobre o cuidado de cada planta pelo tempo na sua cidade, o aquecedor, a luz de cada cômodo, o vaso e o jeito que a terra seca de verdade. E as plantas te contam tudo, do jeito delas.",
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
   {"id": "share", "h": "Divida a sua selva", "p": "Mora com alguém, com a família ou divide a casa? Convide quem mora com você e cuidem das mesmas plantas juntos. A vez é dividida de forma justa, todo mundo vê o que já foi feito e ninguém rega duas vezes.",
    "list": [("gift", "Convite em um toque: por link, e-mail ou mensagem"), ("calendarHeart", "Vez justa: quem não regou da última vez é o próximo"), ("careHands", "Um cobre o outro: ocupado ou viajando? Alguém diz deixa comigo")],
    "thumbs": [("share-home", "Nossa selva"), ("share-turns", "Quem cuida de quem"), ("share-invite", "Convidar alguém")]},
   {"id": "me", "h": "Sua selva, crescendo com você", "p": "Plantas, plantas felizes, momentos de cuidado e anos juntos. Cômodos, mudas e conquistas, da primeira plantinha a uma selva inteira feliz.",
    "list": [("livingRoom", "Sala, cozinha, varanda: quem mora onde"), ("award", "Conquistas que deixam o cuidado ainda mais gostoso")],
    "thumbs": [("me", "Você")]},
  ],
  "pills": [("soilTest", "Chega de adivinhar quando regar"), ("chat", "Plantas com personalidade"), ("calendarHeart", "Lembretes gentis, sem insistir"), ("healthShield", "Ajuda cedo quando uma sofre"), ("homeLeaf", "Cultivado para casas de verdade")],
  "cards": {"today": [("wateringCan", "Cuidar num toque", "Regar, adubar, borrifar ou ver a terra, direto do Hoje."), ("calendar", "O que vem aí, num relance", "Saiba o que vem antes de alguma murchar."), ("celebrate", "Pequenas vitórias celebradas", "Sequências e marcos tornam o cuidado uma alegria.")],
            "plants": [("feedJar", "Regar, Adubar, Vaso, Verificar", "O que as plantas mais precisam, sempre a um toque."), ("growth", "Veja-as crescer", "Uma linha do tempo de fotos que mostra o caminho feito."), ("shieldLeaf", "Seguro para pets e crianças", "Avisos claros quando uma planta não é para morder.")]},
  "chat_label": "Escolha uma planta e pergunte",
  "chat_plants": [("Monty", "monstera"), ("Pesto", "basil"), ("Pearl", "orchid"), ("Goldie", "pothos")],
  "chat_qs": ["Como você está?", "Precisa de água?", "Devo te adubar?"],
  "chat_a": {
   "Monty": ["Feliz e soltando uma folha nova. Obrigado pelo cantinho iluminado perto da janela.", "Ainda não. A terra de cima ainda está úmida. Dá uma olhada de novo na quinta.", "Agora não. O outono é meu descanso. Adubo com meia dose na primavera."],
   "Pesto": ["Cheio de folhas e cheiroso. Colhe as pontinhas de cima para eu continuar assim.", "Sim, por favor. Manjericão bebe muito, uma boa regada hoje seria perfeita.", "Um pouquinho, a cada duas semanas enquanto estou crescendo. Sem exagero, senão perco o sabor."],
   "Pearl": ["Descansando, sonhando com a próxima haste de flores.", "Ainda não. Me rega quando as raízes estiverem prateadas, uma vez por semana.", "Nesta estação, não. Adubo de orquídea quando a primavera chegar."],
   "Goldie": ["Meio murchinha, para ser sincera. Acho que estou com sede.", "Sim, dá uma olhada na minha terra? Se os dois centímetros de cima estiverem secos, eu adoraria uma água.", "Depois de beber, sim. Nunca me adube com a terra seca."]},
  "you": "Você",
  "all": [["chat", "Conversar com as plantas", "Escreva como uma mensagem. Elas respondem com personalidade."], ["soilTest", "Ritual da terra", "Aprende o ritmo de cada planta para regar na medida certa."], ["calendarHeart", "Pedidos de cuidado", "Regar, adubar, borrifar e rodar, só na hora certa."], ["firstAid", "Verificação de saúde", "Ajuda clara e gentil quando uma planta sofre."], ["bug", "Guarda contra pragas", "Identifique pragas cedo e siga um plano simples."], ["pot", "Mudança de vaso", "Sabe a hora certa e qual vaso e terra usar."], ["travel", "Vou viajar", "Planos de férias para todas ficarem bem."], ["seedling", "Mudas", "Faça plantas novas a partir das que você ama."], ["sun", "Guia das estações", "O que cada estação significa onde você mora."], ["fertilizer", "Leitor de rótulos", "Saiba se um adubo ou terra serve a cada planta."], ["livingRoom", "Cômodos", "Cômodo a cômodo, a luz certa para cada planta."], ["shieldLeaf", "Avisos para animais", "Notas claras para gatos, cachorros e crianças."]],
  "all_h": "Toda a ajuda que quem cuida de plantas pode querer",
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
  "know_h": "Não é um alarme. É um cuidado que conhece a sua casa.",
  "know_p": "A maioria dos apps de plantas pergunta de quanto em quanto tempo regar e começa a contagem: a cada 7 dias, para sempre. O My Tiny Jungle calcula para cada planta, todo dia, olhando tudo o que está em volta dela.",
  "know_vs": (("Um app de lembrete", ["Regar a cada 7 dias", "Igualzinho em julho e em janeiro", "Manda regar a varanda debaixo de chuva", "Duas pessoas, dois lembretes, uma samambaia afogada"]), ("My Tiny Jungle", ["Rega quando aquele vaso vai estar seco", "Acompanha as estações e o seu hemisfério", "Pula as plantas de fora depois da chuva", "Divide a vez para ninguém regar em dobro"])),
  "two_h": "A mesma costela-de-adão, duas casas",
  "two_p": "Uma semana de julho. A mesma planta, a mesma espécie. Vidas bem diferentes.",
  "homes": [("Lisboa", "Varanda, vaso de barro, máximas de 28 °C", "Mais ou menos a cada 5 dias", "Dias quentes e vaso de barro secam a terra rapidinho. Se chover, o lembrete espera."), ("Berlim", "Sala bem iluminada, vaso de plástico, 19 °C lá fora", "Mais ou menos a cada 8 dias", "Dentro de casa, o plástico segura a água por mais tempo. No inverno, com o aquecedor ligado, a conta muda de novo.")],
  "two_timer": "Um alarme fixo mandaria regar as duas a cada 7 dias: pouca água em Lisboa, água demais em Berlim.",
  "in_h": "Tudo o que ele leva em conta",
  "inputs": [("sun", "Sua cidade e o clima", "O tipo de clima, a previsão do tempo, a chuva, as estações e o seu hemisfério."), ("homeLeaf", "Sua casa", "Aquecedor no inverno, ar-condicionado no verão e se o ar é seco ou úmido."), ("livingRoom", "A luz de cada cômodo", "A luz que você marca em cada cômodo, combinada com o que cada planta gosta."), ("pot", "O vaso", "Tamanho, material e furo de drenagem. Vaso de barro seca mais rápido que o de vidro."), ("soilTest", "O ritmo de cada uma", "Começa pelos dados da espécie. Depois, os seus testes de terra e o histórico de cuidados ensinam quanto tempo aquele vaso leva para secar."), ("balcony", "Dentro ou fora de casa", "As plantas de fora seguem o tempo de verdade. As de dentro seguem a sua casa."), ("shieldLeaf", "Pets e crianças", "Avisos claros sobre plantas tóxicas para gatos, cachorros e os pequenos."), ("careHands", "Quem mora com você", "De quem é a vez, quem cobre quando alguém viaja e cuidados sincronizados para ninguém regar duas vezes.")],
  "smart_h": "Discreto e muito esperto",
  "smart_p": "Por trás da conversa carinhosa tem conhecimento de verdade sobre plantas. Cada resposta leva em conta a planta, a sua casa e o tempo lá fora.",
  "smart": [("628", "espécies", "Reconhecidas pelo nome, cada uma com seu ritmo de cuidado"), ("27", "pragas", "Identificadas cedo, com um plano tranquilo para cada uma"), ("45", "sintomas", "Folha amarela, ponta marrom, murchinha: tudo explicado"),
            ("Clima", "", "Tempo local, estações e zona de rusticidade guiam cada lembrete"), ("Casa", "", "Aquecedor, ar-condicionado, vento encanado e luz de cada cômodo mudam o conselho"), ("Pets e crianças", "", "Avisos claros sobre plantas que não podem ser mordiscadas")],
  "faq": [("Dá para dividir as plantas com alguém?", "Dá sim. Convide quem mora com você e todo mundo cuida da mesma selva, com a vez dividida de forma justa e sem rega dobrada."), ("Preciso entender de plantas?", "Nadinha. Adicione uma planta com uma foto ou pelo nome e o app cuida do resto, com palavras simples e carinhosas."), ("Quem é o Raminho?", "O Raminho é a folhinha do ícone do app e o melhor amigo das suas plantas. Ele te recebe no começo, faz algumas perguntas fáceis sobre a sua casa e já deixa tudo pronto."),
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
    A = "app-pt" if L == "pt" else "app"
    cta = f'<a class="btn" href="{TESTFLIGHT_URL}" rel="noopener">{apple_icon}{h["cta"]}</a>'

    def screen(name, alt, cls="screen"):
        return f'<img class="{cls}" src="/assets/{A}/{name}.jpg" alt="{alt}" width="1100" height="2392" loading="lazy">'

    def ilist(items):
        return '<ul class="ilist">' + "".join(f"<li>{I(i)}<span>{x}</span></li>" for i, x in items) + "</ul>"

    def thumbs(items):
        cards = "".join(f'<figure class="slide">{phone(A + "/" + n + ".jpg", c)}<figcaption>{c}</figcaption></figure>' for n, c in items)
        nav = (f'<div class="snav"><button type="button" class="sbtn prev" aria-label="{h["prev"]}">&larr;</button>'
               f'<button type="button" class="sbtn next" aria-label="{h["next"]}">&rarr;</button></div>')
        return f'<div class="slider"><div class="track" tabindex="0">{cards}</div>{nav}</div>'

    shots = [[]] + [c["thumbs"] if not c.get("chat") else [] for c in h["chapters"]]

    def layer(k, ph, sc):
        reel = shots[k] if len(shots[k]) > 1 else []
        dots = ""
        if reel:
            dots = '<div class="reel" role="group">' + "".join(
                f'<button type="button" class="rdot{" on" if j == 0 else ""}" data-i="{j}" data-src="/assets/{A}/{n}.jpg">{cap}</button>'
                for j, (n, cap) in enumerate(reel)) + "</div>"
        first = reel[0][0] if reel else sc
        ph_html = phone(A + "/" + first + ".jpg", h["stage_alt"], "stage-phone").replace(' loading="lazy"', "") if sc else ""
        return (f'<div class="layer{" on" if k == 0 else ""}" data-scene="{k}"><img class="photo" src="/assets/plants/{ph}.jpg" alt="" width="1100" height="1400"{LAZY[k == 0]}>'
                f'{ph_html}{dots}</div>')

    layers = "".join(layer(k, ph, sc) for k, (ph, sc) in enumerate(SCENES))

    chapters = ""
    for k, c in enumerate(h["chapters"], start=1):
        ph, sc = SCENES[k]
        inner = f'<h2>{c["h"]}</h2><p class="lead2">{c["p"]}</p>'
        if sc:
            inner += f'<div class="m-scene"><img class="photo" src="/assets/plants/{ph}.jpg" alt="" width="1100" height="1400" loading="lazy">{phone(A + "/" + sc + ".jpg", c["h"], "stage-phone")}</div>'
        if c.get("big") and c["id"] not in h["cards"]:
            inner += '<ul class="four">' + "".join(f"<li>{w}</li>" for w in c["big"]) + f'</ul><p class="four-note">{c["big_note"]}</p>'
        if c.get("chat"):
            plants = "".join(f'<button type="button" class="chip{" on" if j == 0 else ""}" data-plant="{n}" aria-pressed="{"true" if j == 0 else "false"}"><img src="/assets/plants/{p}.jpg" alt="" width="28" height="28" loading="lazy">{n}</button>' for j, (n, p) in enumerate(h["chat_plants"]))
            qs = "".join(f'<button type="button" class="ask" data-q="{j}">{q}</button>' for j, q in enumerate(h["chat_qs"]))
            first = h["chat_plants"][0][0]
            inner += (f'<div class="talk" data-answers=\'{json.dumps(h["chat_a"], ensure_ascii=False).replace(chr(39), "&#39;")}\'>'
                      f'<p class="talk-label">{h["chat_label"]}</p><div class="chips" role="group">{plants}</div>'
                      f'<div class="log" aria-live="polite"><p class="b me">{h["chat_qs"][0]}</p><p class="b plant"><b>{first}</b>{h["chat_a"][first][0]}</p></div>'
                      f'<div class="asks" role="group">{qs}</div></div>')
        items = h["cards"].get(c["id"]) or [(i, *(x.split(": ", 1) if ": " in x else (x, ""))) for i, x in c.get("list", [])]
        if items:
            inner += '<div class="cards">' + "".join(f'<div class="bcard">{I(i, 56, False)}<div><b>{a}</b>{f"<span>{b}</span>" if b else ""}</div></div>' for i, a, b in items) + "</div>"
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

    def E(m, sz, cls=""):
        return (f'<video class="erty {cls}" width="{sz}" height="{sz}" autoplay loop muted playsinline aria-hidden="true" poster="/assets/erty/erty-{m}.png">'
                f'<source src="/assets/erty/erty-{m}.mov" type=\'video/quicktime; codecs="hvc1"\'><source src="/assets/erty/erty-{m}.webm" type="video/webm"></video>')

    faq = "".join(f"<p><b>{q}</b> {a}</p>" for q, a in h["faq"])

    body = f"""
<div class="split">
<div class="read">
<section class="hero" data-scene="0">{E("wave", 112, "hi")}<h1>{h['h1']}</h1><p class="lead">{h['lead']}</p>{cta}<p class="note">{h['note']}</p>
<div class="m-scene"><img class="photo" src="/assets/plants/monstera.jpg" alt="" width="1100" height="1400" fetchpriority="high">{phone(A + "/today1.jpg", h["stage_alt"], "stage-phone")}</div></section>
{chapters}
</div>
<div class="stage">{layers}</div>
</div>
<section class="know" id="smart-care"><div class="wrap">
<div class="ktop"><div class="khead">{E("scan", 120)}<h2>{h['know_h']}</h2><p>{h['know_p']}</p>
<div class="vs">{"".join(f'<div class="vcol{" us" if j else ""}"><h3>{t}</h3><ul>{"".join(f"<li>{x}</li>" for x in xs)}</ul></div>' for j, (t, xs) in enumerate(h["know_vs"]))}</div></div>
{phone(A + "/care-season.jpg", h["in_h"], "kphone")}</div>
<div class="two"><div class="ttext"><h3>{h['two_h']}</h3><p>{h['two_p']}</p></div>
<div class="homes">{"".join(f'<div class="home"><p class="city">{c}</p><p class="spot">{sp}</p><p class="every">{ev}</p><p>{why}</p></div>' for c, sp, ev, why in h["homes"])}</div>
<p class="timer">{h['two_timer']}</p></div>
<div class="inputs"><h3>{h['in_h']}</h3><div class="igrid">{"".join(f'<div class="inp">{I(ic, 48)}<h4>{t}</h4><p>{d}</p></div>' for ic, t, d in h["inputs"])}</div></div>
</div></section>
<section class="pills-band" aria-label="Why"><div class="wrap pills">{"".join(f'<p class="pill">{I(i, 48)}{x}</p>' for i, x in h["pills"])}</div></section>
<section class="allf" id="features"><div class="wrap"><h2>{h['all_h']}</h2><div class="agrid">{"".join(f'<div class="acard">{I(i, 64)}<h3>{x}</h3><p>{y}</p></div>' for i, x, y in h["all"])}</div></div></section>
<section class="smart" id="smart"><div class="wrap sgrid"><div class="stext"><h2>{h['smart_h']}</h2><p>{h['smart_p']}</p></div><div class="facts">{"".join(f'<div class="fact"><b>{n}</b>{f"<span>{u}</span>" if u else ""}<p>{d}</p></div>' for n, u, d in h["smart"])}</div></div></section>
<section class="beta" id="beta"><div class="wrap bgrid"><div>{E("water", 130)}<h2>{h['slip_h']}</h2><p>{h['slip_p']}</p>{cta}</div>
<div class="slip">{slip}<p class="row end"><span>{se[0]}</span><span>{se[1]}</span></p></div></div></section>
<section class="pricing" id="pricing"><h2 class="vh">Plus</h2><div class="wrap fields">
{field("free", h["free"], f'<a class="btn ghost" href="{TESTFLIGHT_URL}" rel="noopener">{h["cta"]}</a>')}
{field("monthly", h["monthly"], f'<a class="btn" href="{TESTFLIGHT_URL}" rel="noopener">{h["plus_btn"]}</a>')}
{field("plus", h["plus"], f'<a class="btn light" href="{TESTFLIGHT_URL}" rel="noopener">{h["plus_btn"]}</a>', h["best"])}
</div></section>
<p class="wrap fine">{h['fine']}</p>
<section class="faq" id="faq"><div class="wrap qgrid"><div class="qhead">{E("scan", 140)}<h2>{h['faq_h']}</h2></div><div class="qtext">{faq}</div></div></section>
<section class="closing"><div class="wrap cgrid">
<div class="ctext">{E("love", 150)}<h2>{h['c_h']}</h2><p>{h['c_p']}</p>{cta.replace('class="btn"', 'class="btn light"')}<p class="note">{h['note']}</p></div>
<div class="mosaic">{"".join(f'<figure><img src="/assets/plants/{ph}.jpg" alt="{kind}" width="400" height="400" loading="lazy"><figcaption><b>{nm}</b>{kind}</figcaption></figure>' for ph, nm, kind in h["close_names"])}</div>
</div></section>"""
    return page(L, "/", t["home_title"], t["home_desc"], body)
