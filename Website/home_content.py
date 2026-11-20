"""Landing page for mytinyjungle.com (EN + PT-BR).

Layout: a split stage. The reading column scrolls through the app tab by tab while the stage on the
right holds one of the project's real plant photos with the phone on top; both change as each chapter
arrives. Then a full-width features field, the beta slip, two pricing fields, the FAQ as reading text
and a closing photograph.
"""
import json

def sentences(text):
    """Each sentence stays whole on one line when it fits; lines break between sentences."""
    import re
    return " ".join(f'<span class="sn">{x}</span>' for x in re.split(r"(?<=[.!?])\s+", text))


TESTFLIGHT_URL = "https://testflight.apple.com/join/A8YUuUHj"
PLAY_URL = "https://play.google.com/store/apps/details?id=com.simpleappscompany.mytinyjungle"
BADGE_LABEL = {"en": ("Download on the App Store", "Get it on Google Play"), "pt": ("Baixar na App Store", "Disponível no Google Play")}


def badges(L="en", cls=""):
    """Official App Store and Google Play badges side by side (never redrawn). iPhone goes through the public TestFlight beta."""
    a, g = BADGE_LABEL["pt" if L == "pt" else "en"]
    return (f'<div class="{("store-badges " + cls).strip()}">'
            f'<a class="store-badge ios" href="{TESTFLIGHT_URL}" rel="noopener" aria-label="{a}"><img src="/assets/badges/app-store-badge.svg" alt="{a}" width="120" height="40"></a>'
            f'<a class="store-badge android" href="{PLAY_URL}" rel="noopener" aria-label="{g}"><img src="/assets/badges/google-play-badge.png" alt="{g}" width="134" height="40"></a></div>')


def I(name, size=40, lazy=True):
    lz = LAZY[not lazy]
    return f'<img class="i3d" src="/icons/{name}.png" alt="" width="{size}" height="{size}"{lz}>'


# Scene per chapter: (plant photo, app screen). Index 0 is the hero.
SCENES = [("monstera", "01-notes"), ("pothos", "02-jungle"), ("snake", "09-digest"), ("peacelily", "03-season"),
          ("orchid", "04-doctor"), ("basil", "05-identify"), ("zz", "08-household"), ("echeveria", "14-plus")]

H = {
 "en": {
  "h1": "Plant care that knows your home.",
  "lead": "Forget “water every 7 days”. My Tiny Jungle looks at your weather, your rooms, the pot and how fast the soil really dries, and works out what each plant needs. Then your plants just text you.",
  "cta": "Join the beta on TestFlight",
  "note": "Free for up to 5 plants. No card, no catch.",
  "stage_alt": "My Tiny Jungle on iPhone",
  "chapters": [
   {"id": "talk", "h": "Tell them what you did. They'll answer.", "p": "Just type it like you'd text a friend: “watered Monty and Pesto”. That's it, it's logged. And yes, they reply, each in their own little voice. Go on, try it:",
    "chat": True, "thumbs": [("02-jungle", "The whole jungle"), ("10-chat", "Just you and Monty")]},
   {"id": "week", "h": "Your whole week, in one look", "p": "What's coming up, who needs a bit of love, who just popped a new leaf, and what the weather's about to do to your pots. There's a widget too, so you don't even have to open the app.",
    "list": [("calendar", "Coming up: every watering and feed for the next few days"), ("growth", "Look who grew: a new leaf gets a little party"), ("sun", "Weather ahead: a hot, dry week means checking pots sooner")],
    "thumbs": [("09-digest", "Your week"), ("11-widgets", "Widgets")]},
   {"id": "care", "h": "It knows what season it is. At your place.", "p": "Autumn in Lisbon isn't autumn in São Paulo. Care follows your season, your hemisphere and your rooms, so they drink less while they rest and eat when they grow. Off on a trip? It tells you who'll be fine and who needs a sitter.",
    "list": [("autumnLeaf", "Seasons: what this month means for your plants"), ("travel", "Going away: who'll be fine and who needs a hand"), ("pot", "How-to guides: watering, pruning, cuttings, repotting")],
    "thumbs": [("03-season", "Seasons"), ("07-away", "Going away"), ("13-guides", "How-to guides")]},
   {"id": "doctor", "h": "Yellow leaves? Let's figure it out.", "p": "Snap the leaf that's worrying you. You'll see what's probably going on, why it happened, and a few easy steps to fix it. Like asking your friend who's great with plants.",
    "list": [("firstAid", "What's wrong, in plain words"), ("drop", "Why it happened, from that plant's real care"), ("healthShield", "Short steps you can do today")],
    "thumbs": [("04-doctor", "Health check")]},
   {"id": "shop", "h": "New plants? Snap the whole shelf.", "p": "Back from the garden centre with a full bag? One photo and every plant on the shelf gets its name and care plan. Holding a bag of fertiliser in the shop? Scan it and see which of your plants will love it.",
    "list": [("sprout", "One photo names every plant"), ("fertilizer", "Scan a label, get a verdict for each plant"), ("pottedPlant", "New plants arrive with their care ready")],
    "thumbs": [("05-identify", "Shelf photo"), ("06-scan", "Label scan")]},
   {"id": "share", "h": "Share the jungle. Nobody waters twice.", "p": "Live with a partner, family or housemates? Everyone looks after the same plants, turns go to whoever did least, and when you're busy someone just says “I've got it”. Proud of a plant? Share its passport with a link or QR code.",
    "list": [("careHands", "Fair turns, all month long"), ("calendarHeart", "Busy or away? Someone takes over"), ("gift", "Plant passport: a care card anyone can open")],
    "thumbs": [("08-household", "Our jungle"), ("12-passport", "Plant passport")]},
   {"id": "grow", "h": "Free to start. Room to grow.", "p": "Five plants are free, forever. When your windowsill turns into a jungle, Greenhouse and Jungle unlock unlimited plants, the plant doctor, the label scanner, and no ads.",
    "list": [("pottedPlant", "Unlimited plants"), ("firstAid", "Plant doctor and label scanner"), ("celebrate", "No ads, ever")],
    "thumbs": [("14-plus", "Plans")]},
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
  "all": [["sunflower", "Plants that text you first", "Frost, thirst or a snack: they message you before it's a problem."], ["chat", "One chat for every plant", "Log care for every plant in one message, in your own words."], ["sun", "Weather, light and seasons", "Care that adjusts to your forecast, rooms and season."], ["firstAid", "AI plant doctor", "What's wrong, and the steps to fix it."], ["sprout", "Shelf identify", "One photo names every plant on the shelf."], ["fertilizer", "Label scanner", "Know if a food or soil suits each of your plants."], ["travel", "Going away", "Holiday plans so every plant is fine while you're gone."], ["careHands", "Shared care", "Fair turns at home, no double watering."], ["calendar", "Your week", "Your whole week of plant care in one look."], ["pottedPlant", "Plant chat", "A one-to-one chat with every plant."], ["soilTest", "Soil-check ritual", "Learns each plant's rhythm so watering is just right."], ["calendarHeart", "Gentle care requests", "Water, feed, mist and turn, only when it's time."], ["bug", "Pest guard", "Spot pests early and follow a simple plan."], ["pot", "Repot check", "Knows when it's time and what pot and soil to use."], ["seedling", "Cuttings", "Grow new plants from the ones you love."], ["livingRoom", "Spaces", "Room by room, the right light for every plant."], ["shieldLeaf", "Pet-safety warnings", "Clear notes for cats, dogs and little ones."]],
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
  "plus": ("Jungle", "The whole jungle, all year, for less than a coffee.", "€11.99", "a year", ["Everything in Greenhouse", "Just €1 a month", "Half the price of paying monthly", "One payment, a whole year of happy plants"]),
  "best": "Best value", "plan_k": {"free": "Free", "monthly": "Greenhouse · monthly", "plus": "Jungle · yearly"}, "plans_h": "Start free. Grow when you're ready.", "plans_p": "Five plants are free, forever. When your jungle outgrows them, Greenhouse costs less than a coffee a month.", "feat_p": "Every tool a plant parent could wish for, in four little groups.",
  "close_names": [("monstera", "Monty", "Monstera"), ("basil", "Pesto", "Basil"), ("orchid", "Pearl", "Orchid"), ("pothos", "Goldie", "Pothos"), ("echeveria", "Rosetta", "Echeveria"), ("peacelily", "Lily", "Peace lily"), ("snake", "Sergeant", "Snake plant"), ("zz", "Zeke", "ZZ plant")],
  "close_k": "8 plants waiting to say hello", "prev": "Previous screen", "next": "Next screen",
  "plus_btn": "Choose this plan",
  "fine": "Prices in euros; local prices may vary. Subscriptions renew automatically until cancelled in your Apple account settings.",
  "faq_h": "Good to know", "faq_more": "All questions",
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
            ("Daily", "", "Every plant's plan is worked out again each day, never a fixed countdown"), ("Your pots", "", "Soil checks teach it how fast each pot really dries"), ("Weather", "", "Rain skips the balcony, frost and heatwaves warn you the day before"),
            ("Seasons", "", "Rest and growth follow your hemisphere, so July is right in Lisbon and São Paulo"), ("Rooms", "", "Light, heating and air-con of each room change the advice"), ("Turns", "", "Shared homes get fair turns, cover when you travel and no double watering"),
            ("Voices", "", "Every nudge comes with its real reason, in the plant's own personality"), ("Pets & kids", "", "Clear warnings for plants that aren't safe to nibble"), ("Private", "", "Your jungle is yours. We never sell your data")],
  "faq": [("Can I share my plants with someone?", "Yes. Invite your partner, family or housemates and you all look after the same jungle, with fair turns and no double watering."), ("Do I need to know anything about plants?", "Not at all. Add a plant with a photo or its name and the app fills in the rest, in plain, friendly words."), ("Who is Erty?", "Erty is the little leaf on the app icon and your plants' best friend. Erty greets you when you start, asks a few easy questions about your home and sets everything up for you."),
          ("Is it really free?", "Yes. Up to 5 plants with chat, care requests and reminders, forever, supported by ads. Greenhouse and Jungle are optional and remove the ads."),
          ("Does it speak Portuguese?", "Yes. The app and your plants speak English and Portuguese."),
          ("Where do my plant photos go?", "Without an account, on your phone. Sign in, and your jungle (photos included) is kept on our own servers so it's the same on your iPhone, iPad and Android, and only you and the people you share with can see it. When you ask the app to name a plant or check a leaf, that photo is analysed once and never kept."),
          ("Where does the advice come from?", "From a carefully reviewed plant library. When the app is not sure, it says so."),
          ("I missed a week. Now what?", "Your plants are simply happy you are back, and tell you what to do first."),
          ("Will it nag me?", "No. One gentle note a day at most, with quiet hours, and you can snooze anything."),
          ("Which iPhones?", "Any iPhone that runs the latest iOS. During the beta it installs through TestFlight.")],
  "c_h": "Give your plants a voice", "c_p": "My Tiny Jungle is in beta on iPhone and Android. Join today and bring a friend.",
 },
 "pt": {
  "h1": "Suas plantas bem cuidadas, do jeitinho da sua casa.",
  "lead": "Esquece aquele lembrete de sete em sete dias. O My Tiny Jungle olha o clima daí, cada cômodo, o vaso e quanto a terra leva pra secar de verdade, e descobre o que cada planta precisa. Aí suas plantas mesmo te mandam mensagem.",
  "cta": "Quero testar de graça",
  "note": "De graça pra até 5 plantas. Sem cartão, sem pegadinha.",
  "stage_alt": "Tela do My Tiny Jungle no iPhone",
  "chapters": [
   {"id": "talk", "h": "Conta o que você fez. Elas respondem.", "p": "Escreve como se mandasse mensagem pra uma amiga: “reguei a Costelinha e o Pesto”. Pronto, tá anotado. E sim, cada uma responde do jeitinho dela. Testa aí:",
    "chat": True, "thumbs": [("02-jungle", "A selva toda"), ("10-chat", "Papo com uma planta")]},
   {"id": "week", "h": "Sua semana toda numa olhada", "p": "O que vem por aí, quem tá precisando de um carinho, quem soltou folha nova e o que o tempo vai aprontar com os vasos. E tem widget, pra você nem precisar abrir o app.",
    "list": [("calendar", "Vem aí: todas as regas e adubos dos próximos dias"), ("growth", "Olha quem cresceu: folha nova vira festa"), ("sun", "Previsão: semana quente e seca, vaso conferido mais cedo")],
    "thumbs": [("09-digest", "Sua semana"), ("11-widgets", "Widgets")]},
   {"id": "care", "h": "Ele sabe que estação é. Aí na sua casa.", "p": "Outono em Lisboa não é outono em São Paulo. Os cuidados seguem a sua estação, o seu hemisfério e cada cômodo: menos água quando elas descansam, adubo quando crescem. Vai viajar? Ele te fala quem aguenta firme e quem precisa de alguém de olho.",
    "list": [("autumnLeaf", "Estações: o que o mês muda pras suas plantas"), ("travel", "Viagem: quem fica de boa e quem precisa de ajuda"), ("pot", "Guias: rega, poda, muda e troca de vaso")],
    "thumbs": [("03-season", "Estações"), ("07-away", "Viagem"), ("13-guides", "Guias")]},
   {"id": "doctor", "h": "Folha amarelando? Bora descobrir.", "p": "Tira uma foto da folha que tá te preocupando. Você fica sabendo o que provavelmente tá rolando, por quê, e uns passos simples pra resolver. Tipo perguntar praquela amiga que manja de planta.",
    "list": [("firstAid", "O problema, explicado sem complicação"), ("drop", "O porquê, pelos cuidados reais da planta"), ("healthShield", "Passos curtinhos pra fazer hoje mesmo")],
    "thumbs": [("04-doctor", "Saúde")]},
   {"id": "shop", "h": "Planta nova? Tira foto da estante toda.", "p": "Chegou da floricultura com a sacola cheia? Uma foto e cada planta da estante ganha nome e cuidados. Tá na loja com um saco de adubo na mão? Escaneia e vê quais plantas vão curtir.",
    "list": [("sprout", "Uma foto descobre todas as plantas"), ("fertilizer", "Escaneia o rótulo e vê o que serve pra cada uma"), ("pottedPlant", "Planta nova já chega com os cuidados prontos")],
    "thumbs": [("05-identify", "Estante"), ("06-scan", "Rótulo")]},
   {"id": "share", "h": "Divide a selva. Ninguém rega duas vezes.", "p": "Mora com o mozão, a família ou com amigos? Todo mundo cuida das mesmas plantas, a vez vai pra quem cuidou menos e, se você tá na correria, alguém fala “deixa comigo”. Morrendo de orgulho de uma planta? Compartilha o passaporte dela por link ou QR code.",
    "list": [("careHands", "Rodízio justo o mês todo"), ("calendarHeart", "Tá corrido ou viajando? Alguém assume"), ("gift", "Passaporte da planta: um cartão de cuidados que qualquer um abre")],
    "thumbs": [("08-household", "Nossa selva"), ("12-passport", "Passaporte")]},
   {"id": "grow", "h": "Começa de graça. Cresce quando quiser.", "p": "Cinco plantas são de graça pra sempre. Quando a janela virar uma selva, o Estufa e o Selva liberam plantas ilimitadas, o doutor de plantas, o leitor de rótulos e nada de anúncio.",
    "list": [("pottedPlant", "Plantas ilimitadas"), ("firstAid", "Doutor de plantas e leitor de rótulos"), ("celebrate", "Zero anúncio")],
    "thumbs": [("14-plus", "Planos")]},
  ],
  "pills": [("soilTest", "Rega na hora certa, sem adivinhação"), ("chat", "Plantas com personalidade"), ("calendarHeart", "Lembretes na medida"), ("healthShield", "Ajuda logo no primeiro sinal"), ("homeLeaf", "Feito para a sua casa")],
  "cards": {"today": [("wateringCan", "Cuidado em um toque", "Rega, aduba ou confere a terra direto da tela inicial."), ("calendar", "O que vem pela frente", "Fica sabendo antes de qualquer planta sofrer."), ("celebrate", "Conquistas", "Sequências e marcos que deixam o cuidado mais leve.")],
            "plants": [("feedJar", "Regar, adubar, vaso, saúde", "O essencial sempre a um toque de distância."), ("growth", "Linha do tempo", "Fotos que mostram quanto cada planta cresceu."), ("shieldLeaf", "Segurança para pets e crianças", "Aviso claro quando uma planta é tóxica.")]},
  "chat_label": "Escolhe uma planta e manda uma pergunta",
  "chat_plants": [("Costelinha", "monstera"), ("Pesto", "basil"), ("Pérola", "orchid"), ("Dourada", "pothos")],
  "chat_qs": ["Como você está?", "Precisa de água?", "Quer adubo?"],
  "chat_a": {
   "Costelinha": ["Tô ótima, e tem folha nova chegando! Amei o cantinho perto da janela.", "Ainda não. A terra de cima ainda tá úmida. Confere de novo na quinta?", "Agora não. No outono eu tô descansando. Na primavera, meia dose."],
   "Pesto": ["Cheio de folhas e muito perfumado. Colhe as pontas de cima que eu fico ainda mais bonito.", "Preciso, sim! Manjericão bebe bastante. Uma boa rega hoje seria perfeito.", "Um pouco, a cada duas semanas enquanto eu cresço. Sem exagero, senão perco o sabor."],
   "Pérola": ["Descansando e me preparando pra próxima florada.", "Ainda não. Me rega quando as raízes ficarem prateadas, lá pra uma vez por semana.", "Agora não. Adubo de orquídea só na primavera."],
   "Dourada": ["Meio murchinha, pra ser sincera. Acho que tô com sede.", "Tô! Confere minha terra? Se os primeiros dois dedos tiverem secos, quero água.", "Depois de uma rega, sim. Nunca adube com a terra seca."]},
  "you": "Você",
  "all": [["sunflower", "Plantas que te avisam", "Geada, sede ou adubo: elas te mandam mensagem antes do problema."], ["chat", "Uma conversa pra todas", "Anota o cuidado de todas as plantas numa mensagem só, do seu jeito."], ["sun", "Clima, luz e estações", "Cuidados que se ajustam à previsão, aos cômodos e à estação."], ["firstAid", "Médico de plantas com IA", "O que tá errado e o passo a passo pra resolver."], ["sprout", "Identifica a estante", "Uma foto descobre todas as plantas da estante."], ["fertilizer", "Leitor de rótulos", "Descobre se o produto serve pra cada planta."], ["travel", "Modo viagem", "Um plano pra todo mundo ficar bem enquanto você viaja."], ["careHands", "Cuidado dividido", "Rodízio justo em casa, sem regar duas vezes."], ["calendar", "Sua semana", "A semana inteira de cuidados numa olhada só."], ["pottedPlant", "Papo com cada planta", "Uma conversa só sua com cada planta."], ["soilTest", "Teste da terra", "Aprende o ritmo de cada planta pra regar na medida certa."], ["calendarHeart", "Lembretes inteligentes", "Regar, adubar, borrifar e girar, só quando precisa."], ["bug", "Controle de pragas", "Pega cedo e segue um plano simples."], ["pot", "Troca de vaso", "A hora certa, o vaso e o substrato ideais."], ["seedling", "Mudas", "Faz mudinha das plantas que você mais ama."], ["livingRoom", "Cômodos", "A luz certa pra cada planta, cômodo por cômodo."], ["shieldLeaf", "Pets e crianças", "Avisos claros sobre plantas tóxicas."]],
  "all_h": "Tudo pra cuidar bem das suas plantas",
  "feat_h": "Conheça todos os recursos",
  "feat": [("monstera", "Cuidado no dia a dia", [("chat", "Conversa com cada planta"), ("soilTest", "Teste da terra que aprende o ritmo de cada uma"), ("calendarHeart", "Lembretes de rega, adubo, borrifo e giro"), ("celebrate", "Sequências e conquistas, sem cobrança")]),
           ("peacelily", "Quando algo não vai bem", [("firstAid", "Diagnóstico por foto"), ("bug", "Controle de pragas com plano simples"), ("pot", "Troca de vaso: quando, qual vaso e qual substrato"), ("shieldLeaf", "Avisos para pets e crianças")]),
           ("snake", "Estações e viagens", [("sun", "Guia das estações pra sua região"), ("snow", "Cuidados no frio e no descanso de inverno"), ("travel", "Modo viagem"), ("seedling", "Mudas, passo a passo")]),
           ("orchid", "Na loja e em casa", [("fertilizer", "Leitor de rótulos com resposta para cada planta"), ("sprout", "Descobre que planta é em segundos"), ("livingRoom", "Cômodos com a luz certa"), ("growth", "Histórico em fotos")])],
  "slip_h": "Comece a testar em dois minutos",
  "slip_p": "O My Tiny Jungle está em fase de testes para iPhone. A instalação é feita pelo TestFlight, app gratuito da Apple. Ainda há vagas: convide quem também ama plantas.",
  "slip": [("No iPhone", [("Abra esta página", "10 s"), ("Toque em Quero testar de graça", "5 s"), ("Baixe o TestFlight na App Store", "30 s")]),
           ("No TestFlight", [("Aceite o convite", "5 s"), ("Instale o My Tiny Jungle", "30 s")]),
           ("No app", [("Fotografe sua primeira planta", "40 s")])],
  "slip_end": ("Pronto: suas plantas já estão em boas mãos", "2 min"),
  "free": ("Broto", "Pra começar com as plantas da sua janela.", "0 €", "para sempre", ["Até 5 plantas, cada uma com sua personalidade", "Rega inteligente que aprende com a sua casa", "Avisos de geada, calor e chuva", "Cuidado dividido com quem mora com você", "Com anúncios discretos"]),
  "monthly": ("Estufa", "Pra casa que não para de ganhar verde.", "1,99 €", "por mês", ["Plantas ilimitadas", "Zero anúncios", "Diagnóstico por foto quando uma folha preocupa", "Leitor de rótulos: vê se o produto serve pra cada planta", "Modo viagem, estações e guia de mudas", "Cancela quando quiser, em dois toques"]),
  "plus": ("Selva", "A selva inteira, o ano todo, por menos que um cafezinho por mês.", "11,99 €", "por ano", ["Tudo da Estufa", "Só 1 € por mês", "Metade do preço do plano mensal", "Um pagamento, um ano inteiro de plantas felizes"]),
  "best": "Mais vantajoso", "plan_k": {"free": "Grátis", "monthly": "Estufa · mensal", "plus": "Selva · anual"}, "plans_h": "Comece de graça. Cresça quando quiser.", "plans_p": "Cinco plantas são de graça pra sempre. Quando a sua selva crescer, a Estufa sai por menos que um cafezinho por mês.", "feat_p": "Todos os recursos, organizados em quatro grupos.",
  "close_names": [("monstera", "Costelinha", "Costela-de-adão"), ("basil", "Pesto", "Manjericão"), ("orchid", "Pérola", "Orquídea"), ("pothos", "Dourada", "Jiboia"), ("echeveria", "Rosinha", "Echevéria"), ("peacelily", "Lili", "Lírio-da-paz"), ("snake", "Jorge", "Espada-de-são-jorge"), ("zz", "Zezé", "Zamioculca")],
  "close_k": "8 plantas te esperando", "prev": "Tela anterior", "next": "Próxima tela",
  "plus_btn": "Quero este plano",
  "fine": "Valores em euros. No app, o preço aparece em reais. A assinatura renova sozinha e dá pra cancelar quando quiser nos ajustes da sua conta Apple.",
  "faq_h": "Bom saber", "faq_more": "Ver todas as perguntas",
  "voice_h": "Cada planta com a sua personalidade",
  "voice_p": "Os recados são divertidos, mas nunca à toa: cada um tem um motivo de verdade, tipo o tempo lá fora, a sua casa ou de quem é a vez.",
  "why": "Motivo",
  "voices": [("peacelily", "Lili", "Dramática", "Água. Agora. Tô implorando com todas as minhas folhas.", "Aquecedor ligado: o vaso seca mais rápido"), ("echeveria", "Rosinha", "Independente", "Seca. Rega quando puder.", "Varanda, semana de sol e nenhuma chuva"), ("monstera", "Costelinha", "Tranquila", "Minha terra secou. Uma rega devagarinho e caprichada ia ser uma delícia.", "Calculado a partir dos seus testes da terra"), ("pothos", "Dourada", "Tagarela", "Oiê! Enfia o dedinho na minha terra e me conta como tá? Acho que tô ficando seca!", "Cozinha bem iluminada e vaso pequeno"), ("basil", "Pesto", "Dramático", "Época de crescer e nada de lanchinho? Que tragédia.", "Época de crescimento na sua região"), ("orchid", "Pérola", "Curiosa", "Terra seca… quer dizer que é hora de beber água?", "Você registrou a terra seca")],
  "lock_h": "Avisos que chegam na hora certa",
  "notifs": [("echeveria", "Geada hoje à noite (0 °C)", "A Rosinha mora na varanda. Leve ela pra dentro ou cubra com uma manta antes de dormir, tá? Geada machuca folhinha delicada."), ("echeveria", "Amanhã vai ser um calorão (36 °C)", "A Rosinha ia adorar uma sombrinha à tarde e uma boa regada no friozinho da manhã."), ("peacelily", "Lili", "Tô murchando aqui. Sério mesmo. Uma regada lenta e caprichada me traria de volta à vida."), ("pothos", "Hoje Dourada é com você", ""), ("monstera", "My Tiny Jungle", "Amanhã você viaja. Uma regada caprichada pra todo mundo hoje à noite, e elas vão te esperar felizes.")],
  "lock_alt": "", "lock_date": "quarta-feira, 18 de novembro", "now": "agora", "ntimes": ["agora", "há 25 min", "há 1 h", "8:00", "Ontem"],
  "know_h": "Lembrete fixo não manja de planta. A gente manja.",
  "know_p": "A maioria dos apps pede um intervalo e repete o mesmo aviso pra sempre. Aqui, o cuidado é recalculado todo dia, pra cada planta, com base em tudo o que tá em volta dela.",
  "vs_bell": "Lembrete", "know_vs": (("Apps de lembrete", ["Rega a cada 7 dias, sempre", "Mesmo aviso no verão e no inverno", "Manda regar a varanda em dia de chuva", "Duas pessoas, dois avisos, planta afogada"]), ("My Tiny Jungle", ["Rega quando o vaso vai estar seco de verdade", "Ajusta o cuidado às estações e ao seu hemisfério", "Segura a rega das plantas de fora depois da chuva", "Organiza o rodízio pra ninguém regar duas vezes"])),
  "two_h": "Mesma planta, casas diferentes, cuidados diferentes.",
  "two_p": "Mesma planta, mesma semana de julho. Uma casa pede água bem antes da outra.",
  "homes": [("Lisboa", "Varanda, vaso de barro, máxima de 28 °C", "A cada 5 dias", "Calor e vaso de barro secam a terra mais rápido. Se chover, o lembrete espera."), ("Berlim", "Sala iluminada, vaso de plástico, 19 °C lá fora", "A cada 8 dias", "Dentro de casa, o plástico retém a água por mais tempo. No inverno, com aquecedor, o cálculo muda de novo.")],
  "timer_row": ("Lembrete fixo", "A cada 7 dias, aconteça o que acontecer"), "day_lbl": "Dia", "cmp_us": "My Tiny Jungle", "cmp_them": "Lembrete de 7 dias", "cmp_bad": ["Tarde demais: folhas murchas de sede", "Cedo demais: terra encharcada, raiz sofrendo"], "two_timer": "Um lembrete de 7 dias erra nas duas. Uma passa sede. A outra se afoga.",
  "in_h": "O que entra no cálculo",
  "inputs": [("sun", "Cidade e clima", "Tipo de clima, previsão do tempo, chuva, estações e hemisfério."), ("homeLeaf", "Sua casa", "Aquecedor no inverno, ar-condicionado no verão e umidade do ar."), ("livingRoom", "Luz de cada cômodo", "A luz de cada ambiente comparada com o que cada planta precisa."), ("pot", "Vaso", "Tamanho, material e drenagem. Vaso de barro seca mais rápido que o de vidro."), ("soilTest", "Ritmo de cada planta", "Começa com o que se sabe da espécie e vai se ajustando a cada teste da terra e a cada cuidado anotado."), ("balcony", "Dentro ou fora de casa", "Plantas externas seguem o tempo real. As internas seguem o clima da sua casa."), ("shieldLeaf", "Pets e crianças", "Avisos claros sobre plantas tóxicas pra gatos, cachorros e crianças."), ("careHands", "Quem mora com você", "Rodízio de cuidados, cobertura em viagens e tudo sincronizado.")],
  "smart_h": "Simples de usar. Inteligente por trás.",
  "smart_p": "Por trás de cada recado tem muito conhecimento sobre plantas, sempre aplicado à planta, à sua casa e ao tempo lá fora.",
  "smart": [("628", "espécies", "Reconhecidas pelo nome, cada uma com seu ritmo de cuidado"), ("27", "pragas", "Descobertas cedo, com um plano pra cada uma"), ("45", "sintomas", "Folha amarela, ponta marrom, planta murcha: tudo explicado"),
            ("Todo dia", "", "O plano de cada planta é recalculado diariamente, nunca uma contagem fixa"), ("Seus vasos", "", "O teste da terra ensina quanto tempo cada vaso leva pra secar"), ("Clima", "", "Choveu? A varanda não precisa de rega. Geada e calorão, o app avisa um dia antes"),
            ("Estações", "", "Descanso e crescimento seguem o seu hemisfério: julho é inverno em São Paulo"), ("Cômodos", "", "Luz, aquecedor e ar-condicionado de cada cômodo mudam a recomendação"), ("Rodízio", "", "Casa compartilhada com vez justa, cobertura nas viagens e sem rega em dobro"),
            ("Personalidade", "", "Cada aviso vem com o motivo real, na voz da própria planta"), ("Pets e crianças", "", "Avisos claros sobre plantas tóxicas"), ("Privado", "", "Sua selva é sua. A gente nunca vende seus dados")],
  "faq": [("Posso dividir os cuidados com outras pessoas?", "Dá, sim. Chama quem mora com você e todos cuidam das mesmas plantas, com rodízio justo e sem rega em dobro."), ("Preciso entender de plantas?", "Não. Adicione uma planta por foto ou pelo nome e o app monta o plano de cuidados, com explicações simples."), ("Quem é o Raminho?", "É o mascote do app e o melhor amigo das suas plantas. Ele te recebe logo de cara, faz umas perguntinhas sobre a sua casa e deixa tudo prontinho."),
          ("É grátis mesmo?", "É, sim. Até 5 plantas com bate-papo, lembretes e teste da terra, sem prazo pra acabar, com anúncios. Estufa e Selva são opcionais e tiram os anúncios."),
          ("O app está em português?", "Está. O app e as plantas falam português e inglês."),
          ("Onde ficam minhas fotos?", "Sem conta, no seu celular. Se você entrar com uma conta, sua selva (fotos inclusive) fica guardada nos nossos servidores pra aparecer igualzinha no iPhone, no iPad e no Android, e só você e quem você convidar conseguem ver. Quando você pede pro app descobrir uma planta ou olhar uma folha, a foto é analisada uma vez só e não fica guardada."),
          ("De onde vêm as recomendações?", "De uma biblioteca de plantas revisada com muito cuidado. Quando o app não tem certeza, ele fala."),
          ("Fiquei um tempo sem cuidar. E agora?", "Sem culpa. O app mostra por onde começar e as plantas comemoram a sua volta."),
          ("Vou receber muitas notificações?", "Não. No máximo um lembrete por dia, com horário de silêncio, e dá pra adiar qualquer aviso."),
          ("Funciona em qual iPhone?", "Em qualquer iPhone com o iOS mais recente. Durante os testes, a instalação é pelo TestFlight.")],
  "c_h": "Suas plantas merecem esse cuidado", "c_p": "O My Tiny Jungle tá em fase de testes no iPhone e no Android. Entra agora e chama quem também ama planta.",
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

from site_pages import FEATURES as _F
FEAT_SLUG = {k: v[0] for k, v in _F.items()}


def render_home(L, t, page, phone, apple_icon):
    h = H[L]
    A = "shots/" + ("pt" if L == "pt" else "en")
    S = lambda n: f"{A}/{n}-960.webp"
    cta = badges(L)

    def screen(name, alt, cls="screen"):
        return f'<img class="{cls}" src="/assets/{S(name)}" alt="{alt}" width="1100" height="2392" loading="lazy">'

    def ilist(items):
        return '<ul class="ilist">' + "".join(f"<li>{I(i)}<span>{x}</span></li>" for i, x in items) + "</ul>"

    def thumbs(items):
        cards = "".join(f'<figure class="slide">{phone(S(n), c)}<figcaption>{c}</figcaption></figure>' for n, c in items)
        nav = (f'<div class="snav"><button type="button" class="sbtn prev" aria-label="{h["prev"]}">&larr;</button>'
               f'<button type="button" class="sbtn next" aria-label="{h["next"]}">&rarr;</button></div>')
        return f'<div class="slider"><div class="track" tabindex="0">{cards}</div>{nav}</div>'

    shots = [[]] + [c["thumbs"] if not c.get("chat") else [] for c in h["chapters"]]

    def layer(k, ph, sc):
        reel = shots[k] if len(shots[k]) > 1 else []
        dots = ""
        if reel:
            dots = '<div class="reel" role="group">' + "".join(
                f'<button type="button" class="rdot{" on" if j == 0 else ""}" data-i="{j}" data-src="/assets/{S(n)}">{cap}</button>'
                for j, (n, cap) in enumerate(reel)) + "</div>"
        first = reel[0][0] if reel else sc
        ph_html = phone(S(first), h["stage_alt"], "stage-phone").replace(' loading="lazy"', "") if sc else ""
        return (f'<div class="layer{" on" if k == 0 else ""}" data-scene="{k}"><img class="photo" src="/assets/plants/{ph}.jpg" alt="" width="1100" height="1400"{LAZY[k == 0]}>'
                f'{ph_html}{dots}</div>')

    layers = "".join(layer(k, ph, sc) for k, (ph, sc) in enumerate(SCENES))

    chapters = ""
    for k, c in enumerate(h["chapters"], start=1):
        ph, sc = SCENES[k]
        inner = f'<h2>{c["h"]}</h2><p class="lead2">{c["p"]}</p>'
        if sc:
            inner += f'<div class="m-scene"><img class="photo" src="/assets/plants/{ph}.jpg" alt="" width="1100" height="1400" loading="lazy">{phone(S(sc), c["h"], "stage-phone")}</div>'
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
<div class="m-scene"><img class="photo" src="/assets/plants/monstera.jpg" alt="" width="1100" height="1400" fetchpriority="high">{phone(S(SCENES[0][1]), h["stage_alt"], "stage-phone")}</div></section>
{chapters}
</div>
<div class="stage">{layers}</div>
</div>
<section class="know" id="smart-care"><div class="wrap">
<div class="ktop"><div class="khead">{E("scan", 120)}<h2>{h['know_h']}</h2><p>{h['know_p']}</p>
<div class="vs2"><p class="vh2 them">{h["know_vs"][0][0]}</p><p class="vh2 us">{h["know_vs"][1][0]}</p>{"".join(f'<div class="vn them" style="--d:{k*500}"><span class="vic">⏰</span><div><b>{h["vs_bell"]}</b><span>{a}</span></div></div><div class="vn us" style="transition-delay:{k*500+300}ms"><img src="/assets/plants/{ph}.jpg" alt="" width="36" height="36" loading="lazy"><div><b>My Tiny Jungle</b><span>{b}</span></div></div>' for k, (a, b, ph) in enumerate(zip(h["know_vs"][0][1], h["know_vs"][1][1], ("monstera", "peacelily", "echeveria", "pothos"))))}</div></div>
{phone(S("03-season"), h["in_h"], "kphone")}</div>
<div class="two"><div class="ttext"><h3>{h['two_h']}</h3><p>{h['two_p']}</p></div>
{cmp_chart(h)}
<p class="timer">{sentences(h['two_timer'])}</p></div>
<div class="inputs"><h3>{h['in_h']}</h3><div class="igrid">{"".join(f'<div class="inp">{I(ic, 48)}<h4>{t}</h4><p>{d}</p></div>' for ic, t, d in h["inputs"])}</div></div>
</div></section>
<section class="voices" id="voices"><div class="wrap">
<div class="vhead"><h2>{h['voice_h']}</h2><p>{h['voice_p']}</p></div>
<div class="vgrid"><div class="msgs">{"".join(f'<div class="msg"><img class="av" src="/assets/plants/{ph}.jpg" alt="" width="44" height="44" loading="lazy"><div><p class="who"><b>{nm}</b><span>{pers}</span></p><p class="bub">{line}</p><p class="whyl">{h["why"]}: {why}</p></div></div>' for ph, nm, pers, line, why in h["voices"])}</div>
</div>
<div class="lock"><h3>{h['lock_h']}</h3><div class="lockpair"><div class="phone lockdev"><div class="phone-screen"><div class="lockphone"><p class="ldate">{h["lock_date"]}</p><p class="ltime">9:41</p>{"".join(f'<div class="ncard"><img src="/assets/plants/{ph}.jpg" alt="" width="38" height="38" loading="lazy"><div class="nb"><b>{t}<i>{tm}</i></b>{f"<span>{b}</span>" if b else ""}</div></div>' for (ph, t, b), tm in zip(h["notifs"], h["ntimes"]))}</div></div><img class="phone-frame" src="/assets/device/iphone-frame.webp" alt="" width="588" height="1200"></div>
</div></div></div>
</div></section>
<section class="allf" id="features"><div class="wrap"><h2>{h['all_h']}</h2><div class="agrid">{"".join(f'<a class="acard" href="{t["prefix"]}/features/{FEAT_SLUG[i]}">{I(i, 64)}<h3>{x}</h3><p>{y}</p></a>' for i, x, y in h["all"])}</div></div></section>
<section class="smart" id="smart"><div class="wrap sgrid"><div class="stext"><h2>{h['smart_h']}</h2><p>{h['smart_p']}</p></div><div class="facts">{"".join(f'<div class="fact"><b>{n}</b>{f"<span>{u}</span>" if u else ""}<p>{d}</p></div>' for n, u, d in h["smart"])}</div></div></section>
<section class="pricing" id="pricing"><div class="wrap phead">{E("water", 120)}<h2>{h["plans_h"]}</h2><p>{h["plans_p"]}</p></div><div class="wrap fields">
{field("free", h["free"], badges(L))}
{field("monthly", h["monthly"], f'<a class="btn" href="https://www.mytinyjungle.com{t["prefix"]}/plus?plan=monthly">{h["plus_btn"]}</a>')}
{field("plus", h["plus"], f'<a class="btn light" href="https://www.mytinyjungle.com{t["prefix"]}/plus?plan=yearly">{h["plus_btn"]}</a>', h["best"])}
</div></section>
<p class="wrap fine">{h['fine']}</p>
<section class="faq" id="faq"><div class="wrap qgrid"><div class="qhead">{E("scan", 140)}<h2>{h['faq_h']}</h2><p><a class="btn ghost" href="{t['prefix']}/good-to-know">{h['faq_more']}</a></p></div><div class="qtext">{faq}</div></div></section>
<section class="closing"><div class="wrap cgrid">
<div class="ctext">{E("love", 150)}<h2>{h['c_h']}</h2><p>{h['c_p']}</p>{badges(L, "on-dark")}<p class="note">{h['note']}</p></div>
<div class="mosaic">{"".join(f'<figure><img src="/assets/plants/{ph}.jpg" alt="{kind}" width="400" height="400" loading="lazy"><figcaption><b>{nm}</b>{kind}</figcaption></figure>' for ph, nm, kind in h["close_names"])}</div>
</div></section>"""
    return page(L, "/", t["home_title"], t["home_desc"], body)
