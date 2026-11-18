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
  "voice_h": "Funny, because it's true",
  "voice_p": "Every plant has a personality, and every nudge has a reason. The jokes come from the real weather, your home and whose turn it is.",
  "why": "Why now",
  "voices": [("peacelily", "Lily", "Dramatic", "Water. Now. I'm begging you, with my whole leaves.", "Heating's on, so her pot dries sooner"), ("echeveria", "Rosetta", "Independent", "Dry. Water when you can.", "Balcony, sunny week, no rain"), ("monstera", "Monty", "Calm", "My soil is dry now. A slow, deep drink would be lovely.", "Timed from his own soil checks"), ("pothos", "Goldie", "Chatty", "Hi hi! Could you stick a finger in my soil and tell me how it feels? I think I might be getting dry!", "Bright kitchen, small pot"), ("basil", "Pesto", "Dramatic", "Growing season and no snacks? Tragic.", "Growing season where you live"), ("orchid", "Pearl", "Curious", "Dry soil… does that mean drink time?", "You told it the soil felt dry")],
  "lock_h": "And when you're away from the app",
  "notifs": [("echeveria", "Frost tonight (0°C)", "Rosetta lives on the balcony. Please bring her inside or wrap her in fleece before bed. Frost hurts tender leaves."), ("echeveria", "A hot one tomorrow (36°C)", "Rosetta would love some afternoon shade and a deep drink in the cool of the morning."), ("peacelily", "Lily", "I'm wilting over here. Truly. One slow, deep drink would bring me back to life."), ("pothos", "Goldie is your turn today", ""), ("monstera", "My Tiny Jungle", "Tomorrow you travel. A deep, slow drink for everyone tonight, and they'll wait happily for you.")],
  "lock_alt": "Lily's notification, expanded on the lock screen, with Watered, Still wet, Remind me tonight and Open chat",
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
  "h1": "Cuidado de planta que entende a sua casa.",
  "lead": "Os outros apps só tocam um alarme. O My Tiny Jungle olha o tempo na sua cidade, o aquecedor, a luz de cada cômodo, o vaso e quanto a terra demora pra secar, e descobre o que cada planta precisa. Depois, elas mesmas te contam, cada uma do seu jeito.",
  "cta": "Quero testar no TestFlight",
  "note": "De graça para até 5 plantas. Suas fotos não saem do seu celular.",
  "stage_alt": "My Tiny Jungle aberto no iPhone",
  "chapters": [
   {"id": "today", "h": "Bom dia, sem estresse", "p": "Abriu o app, já sabe quem está precisando de você, quem está bem e o que vem por aí. Na maior parte dos dias, a notícia é boa: está todo mundo feliz.",
    "list": [("wateringCan", "Um cartão por planta, resolvido com um toque"), ("healthShield", "Um anel que mostra quem está ótima, bem ou pedindo atenção"),
             ("drop", "Quem vai ficar com sede primeiro"), ("autumnLeaf", "O que a estação muda aí dentro de casa"), ("sprout", "Uma dica rapidinha por dia pra você pegar o jeito")],
    "thumbs": [("today1", "Os cartões"), ("today2", "Tudo de uma vez"), ("conversations", "O que elas andam dizendo")]},
   {"id": "plants", "h": "Cada planta com a sua página", "p": "Todas as suas plantas numa grade, com nome, foto e como estão. Tocou numa, a vida inteira dela está ali.",
    "big": ["Regar", "Adubar", "Vaso", "Checar"], "big_note": "O que ela mais precisa fica sempre no topo, e logo abaixo vêm os cuidados das próximas duas semanas.",
    "thumbs": [("plants", "Minhas plantas"), ("timeline", "A história de vocês"), ("profile", "Jeitinho, cômodo e vaso")]},
   {"id": "talk", "h": "Você fala. Elas respondem.", "p": "Escreva do jeito que você mandaria no WhatsApp: “reguei a Costelinha e o Pesto”. O app anota e as plantas respondem, cada uma com a sua personalidade. Testa aqui:",
    "chat": True, "thumbs": [("jungle-chat", "Papo com todas"), ("plant-chat", "Papo com uma")]},
   {"id": "care", "h": "Uma agenda feita pra sua casa", "p": "A semana, o mês e o ano, montados em cima de como as suas plantas vivem de verdade. Você enfia o dedo na terra, conta pro app, e ele aprende quanto tempo cada vaso leva pra secar aí.",
    "thumbs": [("care-week", "Esta semana"), ("care-calendar", "O mês"), ("care-season", "Estações"), ("travel", "Vou viajar"), ("howto", "Passo a passo")],
    "list": [("travel", "Vai viajar? Ele diz quem aguenta firme, quem precisa de uma regada caprichada e quem precisa de alguém de olho"), ("seedling", "Mudas acompanhadas desde o copinho d’água até virar planta"),
             ("pot", "Passo a passo de regar, podar, trocar de vaso e cuidar de praga")]},
   {"id": "scan", "h": "Na loja, aponte para o rótulo", "p": "Parado na frente da prateleira sem saber qual adubo levar? Aponte a câmera para o rótulo e veja na hora para quais das suas plantas ele serve, quanto usar e quando. Também dá pra escanear uma planta nova ou uma folha doente.",
    "list": [("fertilizer", "Cada planta diz se aquele produto serve pra ela"), ("pottedPlant", "Planta nova já chega com plano de cuidado"), ("firstAid", "Folha estranha? Foto, e você recebe o que fazer, explicado direitinho")],
    "thumbs": [("scan", "Escanear"), ("scan-result", "O veredito"), ("health", "Saúde")]},
   {"id": "share", "h": "Cuidem juntos", "p": "Mora com namorado, família ou divide apê? Chame todo mundo pro app e cuidem das mesmas plantas. A vez é dividida certinho, todo mundo vê o que já foi feito e ninguém rega duas vezes.",
    "list": [("gift", "Convite com um toque, por link, e-mail ou mensagem"), ("calendarHeart", "Vez justa: quem não regou da última vez é o próximo"), ("careHands", "Ocupado ou viajando? Alguém fala “deixa comigo”")],
    "thumbs": [("share-home", "Nossa selva"), ("share-turns", "Quem cuida de quem"), ("share-invite", "Chamar alguém")]},
   {"id": "me", "h": "Sua selva crescendo junto com você", "p": "Quantas plantas, quantas felizes, quantos cuidados e quanto tempo juntos. Cômodos, mudas e conquistas, da primeira plantinha até a casa virar uma selva.",
    "list": [("livingRoom", "Sala, cozinha, varanda: quem mora onde"), ("award", "Conquistas que deixam o cuidado ainda mais gostoso")],
    "thumbs": [("me", "Você")]},
  ],
  "pills": [("soilTest", "Nada de regar no chute"), ("chat", "Plantas com personalidade"), ("calendarHeart", "Lembretes que não enchem"), ("healthShield", "Ajuda logo que uma começa a sofrer"), ("homeLeaf", "Feito pra casa de verdade")],
  "cards": {"today": [("wateringCan", "Cuidar com um toque", "Regar, adubar, borrifar ou checar a terra, direto da tela Hoje."), ("calendar", "O que vem por aí", "Você fica sabendo antes de alguma murchar."), ("celebrate", "Cada conquista comemorada", "Sequências e marcos deixam o cuidado divertido.")],
            "plants": [("feedJar", "Regar, adubar, vaso, checar", "O que elas mais precisam, sempre a um toque."), ("growth", "Veja crescer", "Uma linha do tempo de fotos pra ver o quanto ela cresceu."), ("shieldLeaf", "Pets e crianças em segurança", "Aviso claro quando a planta não pode ser mordida.")]},
  "chat_label": "Escolha uma planta e pergunte",
  "chat_plants": [("Costelinha", "monstera"), ("Pesto", "basil"), ("Pérola", "orchid"), ("Dourada", "pothos")],
  "chat_qs": ["Tudo bem com você?", "Tá com sede?", "Quer adubo?"],
  "chat_a": {
   "Costelinha": ["Tudo ótimo, e tem folha nova vindo aí! Obrigada pelo cantinho perto da janela.", "Ainda não. A terra de cima ainda tá úmida. Dá uma olhadinha de novo na quinta?", "Agora não. No outono eu descanso. Na primavera, meia dose, combinado?"],
   "Pesto": ["Cheio de folha e cheiroso! Colhe as pontinhas de cima que eu fico ainda mais cheio.", "Tô, sim! Manjericão bebe bastante. Uma boa regada hoje seria perfeito.", "Um pouquinho, a cada duas semanas enquanto eu tô crescendo. Sem exagerar, senão perco o sabor."],
   "Pérola": ["Descansando e sonhando com a próxima haste de flor.", "Ainda não. Me rega quando as raízes ficarem prateadas, mais ou menos uma vez por semana.", "Agora não. Adubo de orquídea só quando chegar a primavera."],
   "Dourada": ["Meio caidinha, pra ser sincera. Acho que tô com sede.", "Tô! Confere minha terra? Se os dois dedos de cima estiverem secos, eu ia amar uma água.", "Depois de beber, sim. Nunca me aduba com a terra seca."]},
  "you": "Você",
  "all": [["chat", "Papo com as plantas", "Escreva como numa mensagem. Elas respondem com personalidade."], ["soilTest", "O teste do dedo na terra", "Aprende o ritmo de cada planta pra regar na medida certa."], ["calendarHeart", "Pedidos de cuidado", "Regar, adubar, borrifar e girar o vaso, só quando é a hora."], ["firstAid", "Check-up", "Ajuda clara e carinhosa quando uma planta não vai bem."], ["bug", "De olho nas pragas", "Pega a praga no começo e mostra um plano simples."], ["pot", "Troca de vaso", "Avisa a hora e diz qual vaso e qual substrato usar."], ["travel", "Vou viajar", "Um plano pra todas ficarem bem enquanto você está fora."], ["seedling", "Mudas", "Faça plantas novas a partir das que você ama."], ["sun", "Estações", "O que cada época do ano muda aí onde você mora."], ["fertilizer", "Leitor de rótulo", "Diz se o adubo ou a terra serve pra cada planta."], ["livingRoom", "Cômodos", "Cômodo por cômodo, a luz certa pra cada planta."], ["shieldLeaf", "Pets e crianças", "Avisos claros pra quem tem gato, cachorro ou criança."]],
  "all_h": "Tudo o que quem ama planta queria ter",
  "feat_h": "Tudo o que vem no app",
  "feat": [("monstera", "Cuidado que presta atenção", [("chat", "Converse com cada planta, cada uma com sua voz"), ("soilTest", "O teste do dedo na terra aprende o ritmo de cada uma"), ("calendarHeart", "Lembretes gentis de regar, adubar, borrifar e girar"), ("celebrate", "Sequências e conquistas, sem culpa nenhuma")]),
           ("peacelily", "Quando uma não vai bem", [("firstAid", "Check-up por foto"), ("bug", "Pragas com um plano simples"), ("pot", "Troca de vaso: quando, qual vaso, qual substrato"), ("shieldLeaf", "Avisos pra gato, cachorro e criança")]),
           ("snake", "Estações e viagens", [("sun", "Guia das estações pra onde você mora"), ("snow", "Descanso no inverno e proteção no frio"), ("travel", "Plano de viagem pra ninguém sofrer"), ("seedling", "Mudas, passo a passo")]),
           ("orchid", "Na loja e em casa", [("fertilizer", "Leitor de rótulo com veredito pra cada planta"), ("sprout", "Descubra uma planta nova em segundos"), ("livingRoom", "Cômodos com a luz certa"), ("growth", "A história de cada uma em fotos")])],
  "slip_h": "Em dois minutos você já está testando",
  "slip_p": "O My Tiny Jungle está aberto pra testes no iPhone. Quem instala é o TestFlight, um app gratuito da Apple. Chama alguém também: são 100 vagas.",
  "slip": [("No iPhone", [("Abra esta página", "10 s"), ("Toque em Quero testar", "5 s"), ("Baixe o TestFlight na App Store", "30 s")]),
           ("No TestFlight", [("Aceite o convite", "5 s"), ("Instale o My Tiny Jungle", "30 s")]),
           ("No app", [("Tire uma foto da primeira planta", "40 s")])],
  "slip_end": ("Pronto, sua selva começa a falar", "2 min"),
  "free": ("Grátis", "Pra começar sua selvinha.", "0 €", "pra sempre", "Até 5 plantas, com papo, pedidos de cuidado, lembretes e o teste da terra. Com anúncios."),
  "monthly": ("Plus mensal", "Pra testar tudo, mês a mês.", "1,99 €", "por mês", "Plantas sem limite, sem anúncios, leitor de rótulo e check-up de saúde. Cancele quando quiser."),
  "plus": ("Plus anual", "Pra todas as plantas que você ama, o ano todo.", "11,99 €", "por ano", "Tudo do Plus por 1 € por mês. Sai pela metade do mensal."),
  "best": "Vale mais a pena", "feat_p": "Todas as ferramentas que quem ama planta queria ter, em quatro grupos.",
  "close_names": [("monstera", "Costelinha", "Costela-de-adão"), ("basil", "Pesto", "Manjericão"), ("orchid", "Pérola", "Orquídea"), ("pothos", "Dourada", "Jiboia"), ("echeveria", "Rosinha", "Echevéria"), ("peacelily", "Lili", "Lírio-da-paz"), ("snake", "Jorginho", "Espada-de-são-jorge"), ("zz", "Zezé", "Zamioculca")],
  "close_k": "8 plantas loucas pra te dar oi", "prev": "Tela anterior", "next": "Próxima tela",
  "plus_btn": "Assinar o Plus no app",
  "fine": "Preços em euros. No app, você vê o valor em reais. A assinatura renova sozinha até você cancelar nos ajustes da sua conta Apple.",
  "faq_h": "Perguntas que sempre aparecem",
  "voice_h": "Dá risada, mas é tudo verdade",
  "voice_p": "Cada planta tem a sua personalidade, e cada recado tem um motivo de verdade: o tempo lá fora, a sua casa, de quem é a vez.",
  "why": "Por que agora",
  "voices": [("peacelily", "Lili", "Dramática", "Água. Agora. Te imploro com todas as minhas folhas.", "O aquecedor tá ligado e o vaso seca mais rápido"), ("echeveria", "Rosinha", "Independente", "Seca. Rega quando puder.", "Varanda, semana de sol, nenhuma chuva"), ("monstera", "Costelinha", "Tranquila", "Minha terra secou. Uma rega lenta e caprichada seria uma delícia.", "Calculado pelos testes de terra que você fez"), ("pothos", "Dourada", "Tagarela", "Oiê! Pode enfiar o dedinho na minha terra e me contar como está? Acho que estou ficando seca!", "Cozinha bem clara e vaso pequeno"), ("basil", "Pesto", "Dramático", "Época de crescer e nada de lanchinho? Que tragédia.", "É época de crescimento aí onde você mora"), ("orchid", "Pérola", "Curiosa", "Terra seca… quer dizer que é hora de beber?", "Você contou que a terra estava seca")],
  "lock_h": "E quando você nem está no app",
  "notifs": [("echeveria", "Geada hoje à noite (0 °C)", "A Rosinha mora na varanda. Leve ela pra dentro ou cubra com uma manta antes de dormir, tá? Geada machuca folhinha delicada."), ("echeveria", "Amanhã vai ser um calorão (36 °C)", "A Rosinha ia adorar uma sombrinha à tarde e uma boa regada no friozinho da manhã."), ("peacelily", "Lili", "Tô murchando aqui. Sério mesmo. Uma regada lenta e caprichada me traria de volta à vida."), ("pothos", "Hoje Dourada é com você", ""), ("monstera", "My Tiny Jungle", "Amanhã você viaja. Uma regada caprichada pra todo mundo hoje à noite, e elas vão te esperar felizes.")],
  "lock_alt": "",
  "know_h": "Não é despertador. É cuidado que conhece a sua casa.",
  "know_p": "Quase todo app de planta pergunta de quantos em quantos dias regar e liga um contador: a cada 7 dias, pra sempre. O My Tiny Jungle refaz a conta todo dia, pra cada planta, olhando tudo o que está em volta dela.",
  "know_vs": (("App de lembrete comum", ["Rega a cada 7 dias", "Igualzinho no verão e no inverno", "Manda regar a varanda no meio da chuva", "Duas pessoas, dois alarmes, uma samambaia afogada"]), ("My Tiny Jungle", ["Rega quando aquele vaso vai estar seco", "Muda com as estações e o seu hemisfério", "Deixa a planta de fora quieta depois da chuva", "Divide a vez pra ninguém regar em dobro"])),
  "two_h": "A mesma costela-de-adão, duas casas",
  "two_p": "A mesma semana de julho, a mesma planta. Vidas completamente diferentes.",
  "homes": [("Lisboa", "Varanda, vaso de barro, máxima de 28 °C", "Mais ou menos a cada 5 dias", "Calor e vaso de barro secam a terra rapidinho. Se chover, o lembrete espera."), ("Berlim", "Sala clara, vaso de plástico, 19 °C lá fora", "Mais ou menos a cada 8 dias", "Dentro de casa, o plástico segura a água por mais tempo. No inverno, com o aquecedor ligado, a conta muda de novo.")],
  "two_timer": "Um alarme fixo mandaria regar as duas a cada 7 dias: água de menos em Lisboa, água demais em Berlim.",
  "in_h": "Tudo o que entra na conta",
  "inputs": [("sun", "Sua cidade e o clima", "O tipo de clima, a previsão do tempo, a chuva, as estações e o hemisfério onde você mora."), ("homeLeaf", "Sua casa", "Aquecedor no inverno, ar-condicionado no verão e se o ar aí é seco ou úmido."), ("livingRoom", "A luz de cada cômodo", "A luz que você marcou em cada cômodo, comparada com o que cada planta gosta."), ("pot", "O vaso", "Tamanho, material e se tem furo. Vaso de barro seca mais rápido que o de vidro."), ("soilTest", "O ritmo de cada uma", "Começa com os dados da espécie. Depois, os seus testes de terra e o histórico ensinam quanto tempo aquele vaso leva pra secar."), ("balcony", "Dentro ou fora", "Planta de fora segue o tempo de verdade. Planta de dentro segue a sua casa."), ("shieldLeaf", "Pets e crianças", "Avisos claros sobre plantas tóxicas pra gato, cachorro e criança."), ("careHands", "Quem mora com você", "De quem é a vez, quem cobre quando alguém viaja e tudo sincronizado pra ninguém regar duas vezes.")],
  "smart_h": "Fofo por fora, esperto por dentro",
  "smart_p": "Por trás do papo carinhoso tem muito conhecimento de planta. Cada resposta leva em conta a planta, a sua casa e o tempo lá fora.",
  "smart": [("628", "espécies", "Reconhecidas pelo nome, cada uma com o seu ritmo de cuidado"), ("27", "pragas", "Pegas no começo, com um plano tranquilo pra cada uma"), ("45", "sintomas", "Folha amarela, ponta marrom, planta caidinha: tudo explicado"),
            ("Clima", "", "Tempo local, estações e zona de rusticidade guiam cada lembrete"), ("Casa", "", "Aquecedor, ar-condicionado e a luz de cada cômodo mudam o conselho"), ("Pets e crianças", "", "Avisos claros sobre plantas que não podem ser mordiscadas")],
  "faq": [("Dá pra dividir as plantas com alguém?", "Dá. Chame quem mora com você e todo mundo cuida da mesma selva, com a vez dividida certinho e sem rega dobrada."), ("Preciso entender de planta?", "Nada. Adicione a planta com uma foto ou pelo nome e o app faz o resto, explicando tudo com palavras simples."), ("Quem é o Raminho?", "É a folhinha do ícone do app e o melhor amigo das suas plantas. Ele te recebe quando você começa, faz umas perguntas fáceis sobre a sua casa e já deixa tudo pronto."),
          ("É de graça mesmo?", "É. Até 5 plantas com papo, pedidos de cuidado e lembretes, pra sempre, com anúncios. O Plus é opcional e tira os anúncios."),
          ("Fala português?", "Fala, sim. O app e as suas plantas falam português e inglês."),
          ("Minhas fotos vão pra onde?", "Pra lugar nenhum. Fotos, leituras e anotações ficam no seu celular, e você nem precisa criar conta."),
          ("De onde vêm as dicas?", "De uma biblioteca de plantas revisada com muito cuidado. Quando o app não tem certeza, ele fala."),
          ("Fiquei uma semana sem cuidar. E agora?", "Elas só ficam felizes que você voltou e dizem o que fazer primeiro."),
          ("Vai ficar me enchendo de notificação?", "Não. No máximo um lembrete por dia, com horário de silêncio, e dá pra adiar qualquer um."),
          ("Funciona em qual iPhone?", "Em qualquer iPhone com o iOS mais recente. Durante o beta, a instalação é pelo TestFlight.")],
  "c_h": "Deixe suas plantas falarem", "c_p": "O My Tiny Jungle está em fase de testes no iPhone. Entre hoje e chame alguém pra vir junto.",
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
<section class="voices" id="voices"><div class="wrap">
<div class="vhead"><h2>{h['voice_h']}</h2><p>{h['voice_p']}</p></div>
<div class="vgrid"><div class="msgs">{"".join(f'<div class="msg"><img class="av" src="/assets/plants/{ph}.jpg" alt="" width="44" height="44" loading="lazy"><div><p class="who"><b>{nm}</b><span>{pers}</span></p><p class="bub">{line}</p><p class="whyl">{h["why"]}: {why}</p></div></div>' for ph, nm, pers, line, why in h["voices"])}</div>
<div class="lock"><h3>{h['lock_h']}</h3><div class="lockphone"><p class="ltime">9:41</p>{"".join(f'<div class="ncard"><img src="/assets/plants/{ph}.jpg" alt="" width="38" height="38" loading="lazy"><div><b>{t}</b>{f"<span>{b}</span>" if b else ""}</div></div>' for ph, t, b in h["notifs"])}</div>
{f'<img class="lockshot" src="/assets/notif/lily-expanded.jpg" alt="{h["lock_alt"]}" width="550" height="1196" loading="lazy">' if h["lock_alt"] else ""}</div></div>
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
