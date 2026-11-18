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
  "free": ("Sprout", "Start with the plants on your windowsill.", "€0", "forever", ["Up to 5 plants, each with its own voice", "Smart watering that learns your home", "Weather, frost and heat warnings", "Share care with everyone at home", "Supported by small ads"]),
  "monthly": ("Greenhouse", "For a home that keeps growing.", "€1.99", "a month", ["Unlimited plants", "No ads, ever", "Photo health check when a leaf looks wrong", "Label scanner: know if a product suits each plant", "Travel mode, seasons and cuttings guides", "Cancel any time in two taps"]),
  "plus": ("Jungle", "The whole jungle, all year, for less than a coffee.", "€11.99", "a year", ["Everything in Plus", "Just €1 a month", "Half the price of paying monthly", "One payment, a whole year of happy plants"]),
  "best": "Best value", "plan_k": {"free": "Free", "monthly": "Plus · monthly", "plus": "Plus · yearly"}, "plans_h": "Start free. Grow when you're ready.", "plans_p": "Five plants are free, forever. When your jungle outgrows them, Plus costs less than a coffee a month.", "feat_p": "Every tool a plant parent could wish for, in four little groups.",
  "close_names": [("monstera", "Monty", "Monstera"), ("basil", "Pesto", "Basil"), ("orchid", "Pearl", "Orchid"), ("pothos", "Goldie", "Pothos"), ("echeveria", "Rosetta", "Echeveria"), ("peacelily", "Lily", "Peace lily"), ("snake", "Sergeant", "Snake plant"), ("zz", "Zeke", "ZZ plant")],
  "close_k": "8 plants waiting to say hello", "prev": "Previous screen", "next": "Next screen",
  "plus_btn": "Choose this plan",
  "fine": "Prices in euros; local prices may vary. Subscriptions renew automatically until cancelled in your Apple account settings.",
  "faq_h": "Good to know",
  "voice_h": "Funny, because it's true",
  "voice_p": "Every plant has a personality, and every nudge has a reason. The jokes come from the real weather, your home and whose turn it is.",
  "why": "Why now",
  "voices": [("peacelily", "Lily", "Dramatic", "Water. Now. I'm begging you, with my whole leaves.", "Heating's on, so her pot dries sooner"), ("echeveria", "Rosetta", "Independent", "Dry. Water when you can.", "Balcony, sunny week, no rain"), ("monstera", "Monty", "Calm", "My soil is dry now. A slow, deep drink would be lovely.", "Timed from his own soil checks"), ("pothos", "Goldie", "Chatty", "Hi hi! Could you stick a finger in my soil and tell me how it feels? I think I might be getting dry!", "Bright kitchen, small pot"), ("basil", "Pesto", "Dramatic", "Growing season and no snacks? Tragic.", "Growing season where you live"), ("orchid", "Pearl", "Curious", "Dry soil… does that mean drink time?", "You told it the soil felt dry")],
  "lock_h": "And when you're away from the app",
  "notifs": [("echeveria", "Frost tonight (0°C)", "Rosetta lives on the balcony. Please bring her inside or wrap her in fleece before bed. Frost hurts tender leaves."), ("echeveria", "A hot one tomorrow (36°C)", "Rosetta would love some afternoon shade and a deep drink in the cool of the morning."), ("peacelily", "Lily", "I'm wilting over here. Truly. One slow, deep drink would bring me back to life."), ("pothos", "Goldie is your turn today", ""), ("monstera", "My Tiny Jungle", "Tomorrow you travel. A deep, slow drink for everyone tonight, and they'll wait happily for you.")],
  "lock_date": "Wednesday, 18 November", "now": "now", "ntimes": ["now", "25m ago", "1h ago", "8:00", "Yesterday"], "lock_alt": "Lily's notification, expanded on the lock screen, with Watered, Still wet, Remind me tonight and Open chat",
  "know_h": "Not a timer. Care that knows your home.",
  "know_p": "Most plant apps ask how often to water, then count down: every 7 days, forever. My Tiny Jungle works it out for each plant, every day, from everything around it.",
  "vs_bell": "Reminder", "know_vs": (("A reminder app", ["Water every 7 days", "The same in July and January", "Waters the balcony in the rain", "Two people, two reminders, one drowned fern"]), ("My Tiny Jungle", ["Water when that pot will be dry", "Shifts with your seasons and hemisphere", "Skips outdoor plants after rain", "Shares turns, so nobody double-waters"])),
  "two_h": "Same monstera, two homes",
  "two_p": "Same plant, same week in July. One home needs water much sooner than the other.",
  "homes": [("Lisbon", "Balcony, terracotta pot, highs around 28 °C", "Every 5 days", "Warm days and a terracotta pot dry the soil fast. If it rains, the reminder waits."), ("Berlin", "Bright living room, plastic pot, 19 °C outside", "Every 8 days", "Indoors, plastic holds water longer. In winter, with the heating on, the sums change again.")],
  "timer_row": ("Fixed timer", "Every 7 days, whatever happens"), "day_lbl": "Day", "cmp_us": "My Tiny Jungle", "cmp_them": "A 7-day timer", "cmp_bad": ["Too late: thirsty, droopy leaves", "Too soon: soggy soil, sad roots"], "two_timer": "A 7-day timer gets both wrong. One goes thirsty. The other drowns.",
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
  "h1": "Suas plantas cuidadas do jeito certo, na sua casa.",
  "lead": "Nada de lembrete genérico a cada sete dias. O My Tiny Jungle considera o clima da sua cidade, a luz de cada cômodo, o vaso e o ritmo da terra para dizer o que cada planta precisa, no momento certo.",
  "cta": "Quero testar grátis",
  "note": "Grátis para até 5 plantas. Suas fotos ficam só no seu celular.",
  "stage_alt": "Tela do My Tiny Jungle no iPhone",
  "chapters": [
   {"id": "today", "h": "Tudo o que importa hoje, em uma tela", "p": "Quem precisa de água, quem está bem e o que vem pela frente. Sem lista enorme de tarefas: só o que faz diferença no seu dia.",
    "list": [("wateringCan", "Um cartão por planta, resolvido em um toque"), ("healthShield", "Saúde de cada planta em um anel: ótima, bem ou pedindo atenção"),
             ("drop", "Próximas regas, na ordem de quem vai precisar primeiro"), ("autumnLeaf", "O que a estação do ano muda dentro de casa"), ("sprout", "Uma dica curta por dia para você ganhar confiança")],
    "thumbs": [("today1", "Cuidados do dia"), ("today2", "Visão geral"), ("conversations", "Recados das plantas")]},
   {"id": "plants", "h": "Uma página para cada planta", "p": "Todas as suas plantas em um só lugar, com foto, nome e como estão. Toque em uma e veja a história completa dela.",
    "big": ["Regar", "Adubar", "Vaso", "Saúde"], "big_note": "As ações mais usadas ficam sempre no topo. Logo abaixo, os cuidados das próximas duas semanas.",
    "thumbs": [("plants", "Suas plantas"), ("timeline", "Histórico"), ("profile", "Perfil, cômodo e vaso")]},
   {"id": "talk", "h": "Converse com suas plantas", "p": "Conte o que você fez como se mandasse uma mensagem: “reguei a Costelinha e o Pesto”. O app registra tudo e cada planta responde com a própria personalidade. Experimente:",
    "chat": True, "thumbs": [("jungle-chat", "Conversa com todas"), ("plant-chat", "Conversa com uma")]},
   {"id": "care", "h": "Uma agenda que aprende com a sua casa", "p": "Semana, mês e estações planejados a partir do que acontece de verdade. Toque na terra, conte para o app, e ele aprende quanto tempo cada vaso leva para secar.",
    "thumbs": [("care-week", "Semana"), ("care-calendar", "Mês"), ("care-season", "Estações"), ("travel", "Viagem"), ("howto", "Guias")],
    "list": [("travel", "Modo viagem: saiba quem aguenta, quem precisa de uma rega reforçada e quem precisa de alguém por perto"), ("seedling", "Mudas acompanhadas da água até o vaso"),
             ("pot", "Guias simples de rega, poda, troca de vaso e pragas")]},
   {"id": "scan", "h": "Dúvida na loja? Escaneie o rótulo", "p": "Aponte a câmera para um adubo, substrato ou tratamento e descubra em segundos para quais das suas plantas ele serve, quanto usar e quando. Também funciona com plantas novas e folhas com algum problema.",
    "list": [("fertilizer", "Resposta clara para cada planta: serve ou não serve"), ("pottedPlant", "Planta nova já entra com o plano de cuidados pronto"), ("firstAid", "Folha com problema? Tire uma foto e veja o que fazer")],
    "thumbs": [("scan", "Escanear"), ("scan-result", "Resultado"), ("health", "Saúde")]},
   {"id": "share", "h": "Cuide junto com quem mora com você", "p": "Convide sua família, seu par ou quem divide a casa. Todo mundo vê as mesmas plantas, a vez de cada um é dividida de forma justa e ninguém rega a mesma planta duas vezes.",
    "list": [("gift", "Convite por link, e-mail ou mensagem"), ("calendarHeart", "Rodízio justo: quem não regou da última vez é o próximo"), ("careHands", "Vai viajar? Alguém assume os seus cuidados")],
    "thumbs": [("share-home", "Casa compartilhada"), ("share-turns", "Quem cuida de quem"), ("share-invite", "Convidar")]},
   {"id": "me", "h": "Acompanhe a sua evolução", "p": "Quantas plantas, quantas estão felizes, quantos cuidados e quanto tempo juntos. Das primeiras mudas a uma casa cheia de verde.",
    "list": [("livingRoom", "Plantas organizadas por cômodo"), ("award", "Conquistas que tornam o cuidado um hábito")],
    "thumbs": [("me", "Seu perfil")]},
  ],
  "pills": [("soilTest", "Rega na hora certa, sem adivinhação"), ("chat", "Plantas com personalidade"), ("calendarHeart", "Lembretes na medida"), ("healthShield", "Ajuda logo no primeiro sinal"), ("homeLeaf", "Feito para a sua casa")],
  "cards": {"today": [("wateringCan", "Cuidado em um toque", "Regue, adube ou confira a terra direto da tela inicial."), ("calendar", "O que vem pela frente", "Saiba antes de qualquer planta sofrer."), ("celebrate", "Conquistas", "Sequências e marcos que deixam o cuidado mais leve.")],
            "plants": [("feedJar", "Regar, adubar, vaso, saúde", "O essencial sempre a um toque."), ("growth", "Linha do tempo", "Fotos que mostram quanto cada planta cresceu."), ("shieldLeaf", "Segurança para pets e crianças", "Aviso claro quando uma planta é tóxica.")]},
  "chat_label": "Escolha uma planta e faça uma pergunta",
  "chat_plants": [("Costelinha", "monstera"), ("Pesto", "basil"), ("Pérola", "orchid"), ("Dourada", "pothos")],
  "chat_qs": ["Como você está?", "Precisa de água?", "Quer adubo?"],
  "chat_a": {
   "Costelinha": ["Muito bem, e tem folha nova chegando! Adorei o lugar perto da janela.", "Ainda não. A terra de cima continua úmida. Confere de novo na quinta?", "Agora não. No outono eu descanso. Na primavera, meia dose."],
   "Pesto": ["Cheio de folhas e muito perfumado. Colhe as pontas de cima que eu fico ainda mais bonito.", "Preciso, sim! Manjericão bebe bastante. Uma boa rega hoje seria perfeito.", "Um pouco, a cada duas semanas enquanto eu cresço. Sem exagero, senão perco o sabor."],
   "Pérola": ["Descansando e me preparando para a próxima florada.", "Ainda não. Me rega quando as raízes ficarem prateadas, mais ou menos uma vez por semana.", "Agora não. Adubo de orquídea só na primavera."],
   "Dourada": ["Um pouco murcha, para ser sincera. Acho que estou com sede.", "Sim! Confere a minha terra? Se os primeiros dois dedos estiverem secos, quero água.", "Depois de uma rega, sim. Nunca adube com a terra seca."]},
  "you": "Você",
  "all": [["chat", "Conversa com as plantas", "Registre cuidados como quem manda mensagem. Elas respondem."], ["soilTest", "Teste da terra", "Aprende o ritmo de cada planta para regar na medida certa."], ["calendarHeart", "Lembretes inteligentes", "Regar, adubar, borrifar e girar, só quando precisa."], ["firstAid", "Diagnóstico de saúde", "Ajuda clara quando uma planta não está bem."], ["bug", "Controle de pragas", "Identifique cedo e siga um plano simples."], ["pot", "Troca de vaso", "Saiba a hora certa, o vaso e o substrato ideais."], ["travel", "Modo viagem", "Um plano para todas ficarem bem enquanto você viaja."], ["seedling", "Mudas", "Multiplique as plantas que você mais gosta."], ["sun", "Estações", "O que cada época do ano muda na sua região."], ["fertilizer", "Leitor de rótulos", "Descubra se o produto serve para cada planta."], ["livingRoom", "Cômodos", "A luz certa para cada planta, cômodo por cômodo."], ["shieldLeaf", "Pets e crianças", "Avisos claros sobre plantas tóxicas."]],
  "all_h": "Tudo para cuidar bem das suas plantas",
  "feat_h": "Conheça todos os recursos",
  "feat": [("monstera", "Cuidado no dia a dia", [("chat", "Conversa com cada planta"), ("soilTest", "Teste da terra que aprende o ritmo de cada uma"), ("calendarHeart", "Lembretes de rega, adubo, borrifo e giro"), ("celebrate", "Sequências e conquistas, sem cobrança")]),
           ("peacelily", "Quando algo não vai bem", [("firstAid", "Diagnóstico por foto"), ("bug", "Controle de pragas com plano simples"), ("pot", "Troca de vaso: quando, qual vaso e qual substrato"), ("shieldLeaf", "Avisos para pets e crianças")]),
           ("snake", "Estações e viagens", [("sun", "Guia das estações para a sua região"), ("snow", "Cuidados no frio e no descanso de inverno"), ("travel", "Modo viagem"), ("seedling", "Mudas, passo a passo")]),
           ("orchid", "Na loja e em casa", [("fertilizer", "Leitor de rótulos com resposta para cada planta"), ("sprout", "Identifique plantas em segundos"), ("livingRoom", "Cômodos com a luz certa"), ("growth", "Histórico em fotos")])],
  "slip_h": "Comece a testar em dois minutos",
  "slip_p": "O My Tiny Jungle está em fase de testes para iPhone. A instalação é feita pelo TestFlight, app gratuito da Apple. Ainda há vagas: convide quem também ama plantas.",
  "slip": [("No iPhone", [("Abra esta página", "10 s"), ("Toque em Quero testar grátis", "5 s"), ("Baixe o TestFlight na App Store", "30 s")]),
           ("No TestFlight", [("Aceite o convite", "5 s"), ("Instale o My Tiny Jungle", "30 s")]),
           ("No app", [("Fotografe sua primeira planta", "40 s")])],
  "slip_end": ("Pronto: suas plantas já estão em boas mãos", "2 min"),
  "free": ("Broto", "Comece com as plantas da sua janela.", "0 €", "para sempre", ["Até 5 plantas, cada uma com sua personalidade", "Rega inteligente que aprende com a sua casa", "Avisos de geada, calor e chuva", "Cuidado dividido com quem mora com você", "Com anúncios discretos"]),
  "monthly": ("Estufa", "Para uma casa que não para de ganhar verde.", "1,99 €", "por mês", ["Plantas ilimitadas", "Zero anúncios", "Diagnóstico por foto quando uma folha preocupa", "Leitor de rótulos: saiba se o produto serve para cada planta", "Modo viagem, estações e guia de mudas", "Cancele quando quiser, em dois toques"]),
  "plus": ("Selva", "A selva inteira, o ano todo, por menos que um cafezinho.", "11,99 €", "por ano", ["Tudo do Plus", "Só 1 € por mês", "Metade do preço do plano mensal", "Um pagamento, um ano inteiro de plantas felizes"]),
  "best": "Mais vantajoso", "plan_k": {"free": "Grátis", "monthly": "Plus · mensal", "plus": "Plus · anual"}, "plans_h": "Comece grátis. Cresça quando quiser.", "plans_p": "Cinco plantas são grátis para sempre. Quando a sua selva crescer, o Plus custa menos que um cafezinho por mês.", "feat_p": "Todos os recursos, organizados em quatro grupos.",
  "close_names": [("monstera", "Costelinha", "Costela-de-adão"), ("basil", "Pesto", "Manjericão"), ("orchid", "Pérola", "Orquídea"), ("pothos", "Dourada", "Jiboia"), ("echeveria", "Rosinha", "Echevéria"), ("peacelily", "Lili", "Lírio-da-paz"), ("snake", "Jorge", "Espada-de-são-jorge"), ("zz", "Zezé", "Zamioculca")],
  "close_k": "8 plantas esperando por você", "prev": "Tela anterior", "next": "Próxima tela",
  "plus_btn": "Quero este plano",
  "fine": "Valores em euros. No app, o preço aparece em reais. A assinatura é renovada automaticamente e pode ser cancelada a qualquer momento nos ajustes da sua conta Apple.",
  "faq_h": "Perguntas frequentes",
  "voice_h": "Cada planta com a sua personalidade",
  "voice_p": "Os recados são divertidos, mas nunca aleatórios: cada um tem um motivo real, como o tempo lá fora, a sua casa ou de quem é a vez.",
  "why": "Motivo",
  "voices": [("peacelily", "Lili", "Dramática", "Água. Agora. Te imploro com todas as minhas folhas.", "Aquecedor ligado: o vaso seca mais rápido"), ("echeveria", "Rosinha", "Independente", "Seca. Rega quando puder.", "Varanda, semana de sol e nenhuma chuva"), ("monstera", "Costelinha", "Tranquila", "Minha terra secou. Uma rega lenta e caprichada seria uma delícia.", "Calculado a partir dos seus testes da terra"), ("pothos", "Dourada", "Tagarela", "Oiê! Pode enfiar o dedinho na minha terra e me contar como está? Acho que estou ficando seca!", "Cozinha bem iluminada e vaso pequeno"), ("basil", "Pesto", "Dramático", "Época de crescer e nada de lanchinho? Que tragédia.", "Época de crescimento na sua região"), ("orchid", "Pérola", "Curiosa", "Terra seca… quer dizer que é hora de beber?", "Você registrou a terra seca")],
  "lock_h": "Avisos que chegam na hora certa",
  "notifs": [("echeveria", "Geada hoje à noite (0 °C)", "A Rosinha mora na varanda. Leve ela pra dentro ou cubra com uma manta antes de dormir, tá? Geada machuca folhinha delicada."), ("echeveria", "Amanhã vai ser um calorão (36 °C)", "A Rosinha ia adorar uma sombrinha à tarde e uma boa regada no friozinho da manhã."), ("peacelily", "Lili", "Tô murchando aqui. Sério mesmo. Uma regada lenta e caprichada me traria de volta à vida."), ("pothos", "Hoje Dourada é com você", ""), ("monstera", "My Tiny Jungle", "Amanhã você viaja. Uma regada caprichada pra todo mundo hoje à noite, e elas vão te esperar felizes.")],
  "lock_alt": "", "lock_date": "quarta-feira, 18 de novembro", "now": "agora", "ntimes": ["agora", "há 25 min", "há 1 h", "8:00", "Ontem"],
  "know_h": "Lembrete fixo não entende de planta. O My Tiny Jungle entende.",
  "know_p": "A maioria dos apps pede um intervalo e repete o mesmo aviso para sempre. Aqui, o cuidado é recalculado todo dia, para cada planta, com base em tudo o que está ao redor dela.",
  "vs_bell": "Lembrete", "know_vs": (("Apps de lembrete", ["Rega a cada 7 dias, sempre", "Mesmo aviso no verão e no inverno", "Manda regar a varanda em dia de chuva", "Duas pessoas, dois avisos, planta encharcada"]), ("My Tiny Jungle", ["Rega quando o vaso realmente vai estar seco", "Ajusta o cuidado às estações e ao seu hemisfério", "Segura a rega das plantas de fora depois da chuva", "Organiza o rodízio para ninguém regar duas vezes"])),
  "two_h": "Mesma planta, casas diferentes, cuidados diferentes",
  "two_p": "Mesma planta, mesma semana de julho. Uma casa pede água bem antes da outra.",
  "homes": [("Lisboa", "Varanda, vaso de barro, máxima de 28 °C", "A cada 5 dias", "Calor e vaso de barro secam a terra mais rápido. Se chover, o lembrete espera."), ("Berlim", "Sala iluminada, vaso de plástico, 19 °C lá fora", "A cada 8 dias", "Dentro de casa, o plástico retém a água por mais tempo. No inverno, com aquecedor, o cálculo muda de novo.")],
  "timer_row": ("Lembrete fixo", "A cada 7 dias, aconteça o que acontecer"), "day_lbl": "Dia", "cmp_us": "My Tiny Jungle", "cmp_them": "Lembrete de 7 dias", "cmp_bad": ["Tarde demais: folhas murchas de sede", "Cedo demais: terra encharcada, raiz sofrendo"], "two_timer": "Um lembrete de 7 dias erra nas duas. Uma passa sede. A outra se afoga.",
  "in_h": "O que entra no cálculo",
  "inputs": [("sun", "Cidade e clima", "Tipo de clima, previsão do tempo, chuva, estações e hemisfério."), ("homeLeaf", "Sua casa", "Aquecedor no inverno, ar-condicionado no verão e umidade do ar."), ("livingRoom", "Luz de cada cômodo", "A luz de cada ambiente comparada com a necessidade de cada planta."), ("pot", "Vaso", "Tamanho, material e drenagem. Vaso de barro seca mais rápido que o de vidro."), ("soilTest", "Ritmo de cada planta", "Começa com os dados da espécie e se ajusta a cada teste da terra e a cada cuidado registrado."), ("balcony", "Dentro ou fora de casa", "Plantas externas seguem o tempo real. As internas seguem o clima da sua casa."), ("shieldLeaf", "Pets e crianças", "Avisos claros sobre plantas tóxicas para gatos, cães e crianças."), ("careHands", "Quem mora com você", "Rodízio de cuidados, cobertura em viagens e tudo sincronizado.")],
  "smart_h": "Simples de usar. Inteligente por trás.",
  "smart_p": "Por trás de cada recado há uma base sólida de conhecimento sobre plantas, sempre aplicada à planta, à sua casa e ao tempo lá fora.",
  "smart": [("628", "espécies", "Reconhecidas pelo nome, cada uma com seu ritmo de cuidado"), ("27", "pragas", "Identificadas cedo, com um plano de ação para cada uma"), ("45", "sintomas", "Folha amarela, ponta marrom, planta murcha: tudo explicado"),
            ("Clima", "", "Previsão local, estações e zona de rusticidade em cada lembrete"), ("Casa", "", "Aquecedor, ar-condicionado e luz de cada cômodo mudam a recomendação"), ("Pets e crianças", "", "Avisos claros sobre plantas tóxicas")],
  "faq": [("Posso dividir os cuidados com outras pessoas?", "Pode. Convide quem mora com você e todos cuidam das mesmas plantas, com rodízio justo e sem rega em dobro."), ("Preciso entender de plantas?", "Não. Adicione uma planta por foto ou pelo nome e o app monta o plano de cuidados, com explicações simples."), ("Quem é o Raminho?", "É o mascote do app e o melhor amigo das suas plantas. Ele te recebe no primeiro acesso, faz algumas perguntas sobre a sua casa e deixa tudo configurado."),
          ("É grátis mesmo?", "É. Até 5 plantas com conversa, lembretes e teste da terra, sem prazo para acabar, com anúncios. O Plus é opcional e remove os anúncios."),
          ("O app está em português?", "Está. O app e as plantas falam português e inglês."),
          ("Minhas fotos ficam salvas onde?", "Somente no seu celular. Fotos, leituras e anotações não vão para nenhum servidor, e você não precisa criar conta."),
          ("De onde vêm as recomendações?", "De uma biblioteca de plantas revisada com cuidado. Quando o app não tem certeza, ele avisa."),
          ("Fiquei um tempo sem cuidar. E agora?", "Sem problema. O app mostra por onde começar e as plantas comemoram a sua volta."),
          ("Vou receber muitas notificações?", "Não. No máximo um lembrete por dia, com horário de silêncio, e você pode adiar qualquer aviso."),
          ("Funciona em qual iPhone?", "Em qualquer iPhone com a versão mais recente do iOS. Durante os testes, a instalação é pelo TestFlight.")],
  "c_h": "Suas plantas merecem esse cuidado", "c_p": "O My Tiny Jungle está em fase de testes para iPhone. Participe agora e convide quem também ama plantas.",
 },
}


LAZY = {True: "", False: ' loading="lazy"'}


def cmp_chart(h):
    cards = "".join(
        f'<div class="hc">{I(ic, 56)}<p class="city">{c}</p><p class="spot">{sp}</p>'
        f'<div class="hrow us"><span>{h["cmp_us"]}</span><b>{ev}</b></div>'
        f'<div class="hrow them"><span>{h["cmp_them"]}</span><b>{bad}</b></div></div>'
        for (c, sp, ev, why), ic, bad in zip(h["homes"], ("sun", "livingRoom"), h["cmp_bad"]))
    return f'<div class="hcards">{cards}</div>'

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
        body_ = '<ul class="pts">' + "".join("<li>%s</li>" % x for x in inc) + "</ul>" if isinstance(inc, list) else "<p>%s</p>" % inc
        return (f'<div class="field {cls}">{tg}<p class="kick">{h["plan_k"][cls]}</p><h3>{name}</h3><p class="who">{who}</p>{body_}'
                f'<div class="pfoot"><p class="price">{price}<small>{per}</small></p>{btn}</div></div>')

    def E(m, sz, cls=""):
        return (f'<video class="erty {cls}" width="{sz}" height="{sz}" autoplay loop muted playsinline aria-hidden="true" poster="/assets/erty/erty-{m}.png?v=2">'
                f'<source src="/assets/erty/erty-{m}.mov?v=2" type=\'video/quicktime; codecs="hvc1"\'><source src="/assets/erty/erty-{m}.webm?v=2" type="video/webm"></video>')

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
<div class="vs2"><p class="vh2 them">{h["know_vs"][0][0]}</p><p class="vh2 us">{h["know_vs"][1][0]}</p>{"".join(f'<div class="vn them" style="--d:{k*500}"><span class="vic">⏰</span><div><b>{h["vs_bell"]}</b><span>{a}</span></div></div><div class="vn us" style="transition-delay:{k*500+300}ms"><img src="/assets/plants/{ph}.jpg" alt="" width="36" height="36" loading="lazy"><div><b>My Tiny Jungle</b><span>{b}</span></div></div>' for k, (a, b, ph) in enumerate(zip(h["know_vs"][0][1], h["know_vs"][1][1], ("monstera", "peacelily", "echeveria", "pothos"))))}</div></div>
{phone(A + "/care-season.jpg", h["in_h"], "kphone")}</div>
<div class="two"><div class="ttext"><h3>{h['two_h']}</h3><p>{h['two_p']}</p></div>
{cmp_chart(h)}
<p class="timer">{h['two_timer']}</p></div>
<div class="inputs"><h3>{h['in_h']}</h3><div class="igrid">{"".join(f'<div class="inp">{I(ic, 48)}<h4>{t}</h4><p>{d}</p></div>' for ic, t, d in h["inputs"])}</div></div>
</div></section>
<section class="voices" id="voices"><div class="wrap">
<div class="vhead"><h2>{h['voice_h']}</h2><p>{h['voice_p']}</p></div>
<div class="vgrid"><div class="msgs">{"".join(f'<div class="msg"><img class="av" src="/assets/plants/{ph}.jpg" alt="" width="44" height="44" loading="lazy"><div><p class="who"><b>{nm}</b><span>{pers}</span></p><p class="bub">{line}</p><p class="whyl">{h["why"]}: {why}</p></div></div>' for ph, nm, pers, line, why in h["voices"])}</div>
</div>
<div class="lock"><h3>{h['lock_h']}</h3><div class="lockpair"><div class="phone lockdev"><div class="phone-screen"><div class="lockphone"><p class="ldate">{h["lock_date"]}</p><p class="ltime">9:41</p>{"".join(f'<div class="ncard"><img src="/assets/plants/{ph}.jpg" alt="" width="38" height="38" loading="lazy"><div class="nb"><b>{t}<i>{tm}</i></b>{f"<span>{b}</span>" if b else ""}</div></div>' for (ph, t, b), tm in zip(h["notifs"], h["ntimes"]))}</div></div><img class="phone-frame" src="/assets/device/iphone-frame.webp" alt="" width="588" height="1200"></div>
</div></div></div>
</div></section>
<section class="allf" id="features"><div class="wrap"><h2>{h['all_h']}</h2><div class="agrid">{"".join(f'<div class="acard">{I(i, 64)}<h3>{x}</h3><p>{y}</p></div>' for i, x, y in h["all"])}</div></div></section>
<section class="smart" id="smart"><div class="wrap sgrid"><div class="stext"><h2>{h['smart_h']}</h2><p>{h['smart_p']}</p></div><div class="facts">{"".join(f'<div class="fact"><b>{n}</b>{f"<span>{u}</span>" if u else ""}<p>{d}</p></div>' for n, u, d in h["smart"])}</div></div></section>
<section class="pricing" id="pricing"><div class="wrap phead">{E("water", 120)}<h2>{h["plans_h"]}</h2><p>{h["plans_p"]}</p></div><div class="wrap fields">
{field("free", h["free"], f'<a class="btn ghost" href="{TESTFLIGHT_URL}" rel="noopener">{h["cta"]}</a>')}
{field("monthly", h["monthly"], f'<a class="btn" href="https://www.mytinyjungle.com{t["prefix"]}/plus?plan=monthly">{h["plus_btn"]}</a>')}
{field("plus", h["plus"], f'<a class="btn light" href="https://www.mytinyjungle.com{t["prefix"]}/plus?plan=yearly">{h["plus_btn"]}</a>', h["best"])}
</div></section>
<p class="wrap fine">{h['fine']}</p>
<section class="faq" id="faq"><div class="wrap qgrid"><div class="qhead">{E("scan", 140)}<h2>{h['faq_h']}</h2></div><div class="qtext">{faq}</div></div></section>
<section class="closing"><div class="wrap cgrid">
<div class="ctext">{E("love", 150)}<h2>{h['c_h']}</h2><p>{h['c_p']}</p>{cta.replace('class="btn"', 'class="btn light"')}<p class="note">{h['note']}</p></div>
<div class="mosaic">{"".join(f'<figure><img src="/assets/plants/{ph}.jpg" alt="{kind}" width="400" height="400" loading="lazy"><figcaption><b>{nm}</b>{kind}</figcaption></figure>' for ph, nm, kind in h["close_names"])}</div>
</div></section>"""
    return page(L, "/", t["home_title"], t["home_desc"], body)
