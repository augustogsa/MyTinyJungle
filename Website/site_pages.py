"""Feature pages (/features/<slug>) and the Good to know page (/good-to-know), EN and pt-BR.

Each feature: slug, then per language (intro, how-it-works bullets, questions).
"""

FEATURES = {
 "chat": ("chat", {
  "en": ("Log care the way you'd text a friend. Write “watered Monty and Pesto” and it's done: every plant gets the care logged and answers in its own voice.",
         ["Write in your own words, no forms or menus", "Several plants in one message", "Each plant replies with its own personality: dramatic, calm, chatty, curious", "Ask anything: “do you need water?”, “why are your leaves curling?”"],
         [("Do I have to type exactly?", "No. Write the way you talk. “gave everyone a drink”, “misted the fern” and “repotted Monty yesterday” all work."),
          ("Can I talk to all my plants at once?", "Yes. The jungle chat talks to every plant, and each plant also has its own chat with its history."),
          ("Are the replies random?", "Never. Every reply comes from that plant's real state: its soil, the weather, the season and what you logged.")]),
  "pt": ("Anota os cuidados como quem manda mensagem pra um amigo. Escreve “reguei a Costelinha e o Pesto” e pronto: o cuidado fica anotado e cada planta responde do jeito dela.",
         ["Escreve do seu jeito, sem formulário nem menu", "Várias plantas numa mensagem só", "Cada planta responde com a própria personalidade: dramática, tranquila, tagarela, curiosa", "Pergunta o que quiser: “precisa de água?”, “por que suas folhas estão enrolando?”"],
         [("Tem um jeito certo de escrever?", "Não. Escreve do jeito que você fala. “reguei todo mundo”, “borrifei a samambaia” e “troquei a Costelinha de vaso ontem” funcionam."),
          ("Dá pra falar com todas as plantas de uma vez?", "Dá. A conversa da selva fala com todas, e cada planta também tem a sua conversa com o histórico dela."),
          ("As respostas são aleatórias?", "Nunca. Cada resposta vem de como a planta tá de verdade: terra, clima, estação e o que você registrou.")])}),
 "soilTest": ("soil-check", {
  "en": ("Instead of guessing, push a finger into the soil and tell the app how it feels. Every check teaches My Tiny Jungle how fast that pot really dries.",
         ["Dry, a little damp or wet: three taps", "Learns each pot's rhythm from your checks", "Watering dates move with what it learns", "Works with the weather and your home, not a fixed chart"],
         [("How deep do I check?", "About two finger joints for most pots. The app tells you per plant: succulents like to dry fully, ferns never."),
          ("What if I forget to check?", "No problem. The app keeps estimating from the species, pot, room and weather, and asks again when it matters."),
          ("Do I need a moisture meter?", "No. Your finger is enough, and it's what the app is built around.")]),
  "pt": ("Em vez de chutar, põe o dedo na terra e conta pro app como ela tá. Cada teste ensina o My Tiny Jungle quanto tempo aquele vaso leva pra secar.",
         ["Seca, um pouco úmida ou molhada: três toques", "Aprende o ritmo de cada vaso a partir dos seus testes", "As datas de rega mudam conforme ele aprende", "Considera o clima e a sua casa, não uma tabela fixa"],
         [("Até onde eu enfio o dedo?", "Cerca de duas falanges na maioria dos vasos. O app indica por planta: suculentas gostam de secar totalmente, samambaias nunca."),
          ("E se eu esquecer de testar?", "Relaxa. O app continua calculando pela espécie, vaso, cômodo e clima, e pergunta de novo quando importa."),
          ("Preciso comprar medidor de umidade?", "Não. Seu dedo já resolve, e o app foi feito pensando nele.")])}),
 "calendarHeart": ("smart-reminders", {
  "en": ("Water, feed, mist and turn, only when it's actually time. Reminders follow each plant, your home and the weather, not a countdown.",
         ["At most one gentle reminder a day, with quiet hours", "Outdoor plants skip watering after rain", "Frost and heat warnings for balcony plants", "Snooze anything, or tell a plant you already did it"],
         [("Will I get lots of notifications?", "No. At most one reminder a day, with quiet hours, and you can snooze any of them."),
          ("Why did my reminder move?", "Something changed: rain, a heatwave, the heating coming on, or a soil check that showed the pot is still wet."),
          ("Can I turn off a type of reminder?", "Yes, per type and per plant, in the app's settings.")]),
  "pt": ("Regar, adubar, borrifar e girar, só quando precisa de verdade. Os lembretes seguem cada planta, a sua casa e o clima, não uma contagem regressiva.",
         ["No máximo um lembrete por dia, com horário de silêncio", "Plantas de fora pulam a rega depois da chuva", "Avisos de geada e calor para plantas da varanda", "Adia qualquer aviso ou avisa que já fez"],
         [("Vou receber muitas notificações?", "Não. No máximo um lembrete por dia, com horário de silêncio, e dá pra adiar qualquer um."),
          ("Por que meu lembrete mudou de dia?", "Alguma coisa mudou: chuva, onda de calor, aquecedor ligado ou um teste da terra mostrando que o vaso ainda está úmido."),
          ("Posso desligar um tipo de lembrete?", "Dá, sim, por tipo e por planta, nos ajustes do app.")])}),
 "firstAid": ("health-check", {
  "en": ("Yellow leaves, brown tips, a sudden droop. Take a photo or describe it, and get kind, clear steps for what's wrong and what to do now.",
         ["45 common symptoms explained in plain words", "Photo check in seconds", "A short plan, not a lecture", "Follow-up reminders until the plant recovers"],
         [("Is the photo uploaded?", "It's sent once to our own servers to be analysed, then thrown away. It's never stored."),
          ("Is it always right?", "It's careful, not magic. When it isn't sure, it says so and suggests what to look at next."),
          ("Is it free?", "Health checks come with Greenhouse and Jungle.")]),
  "pt": ("Folha amarela, ponta marrom, planta murchando do nada. Tira uma foto ou conta o que tá vendo e recebe o passo a passo do que tá errado e do que fazer agora.",
         ["45 sintomas comuns explicados em palavras simples", "Diagnóstico por foto em segundos", "Um plano curtinho, sem sermão", "Lembretes de acompanhamento até a planta se recuperar"],
         [("A foto vai pra algum lugar?", "Vai uma vez só pros nossos servidores pra ser analisada e depois é descartada. Não fica guardada."),
          ("Acerta sempre?", "É cuidadoso, mas não faz milagre. Quando não tem certeza, ele fala e diz no que ficar de olho."),
          ("É de graça?", "O diagnóstico de saúde vem com a Estufa e a Selva.")])}),
 "bug": ("pests", {
  "en": ("Spot pests early and follow a calm plan. 27 common pests, how to recognise them and how to get rid of them without panic.",
         ["Recognise pests from simple signs", "Step-by-step treatment plan", "Reminders to check again", "Advice on isolating a plant so others stay safe"],
         [("Which pests does it know?", "The usual indoor suspects: spider mites, mealybugs, fungus gnats, aphids, scale, thrips and more, 27 in total."),
          ("Does it recommend chemicals?", "It starts gentle: water, wiping, soap sprays. Stronger options come only when needed, with safety notes.")]),
  "pt": ("Pega as pragas cedo e segue um plano tranquilo. 27 pragas comuns, como reconhecer e como se livrar delas sem desespero.",
         ["Reconhece pragas por sinais simples", "Plano de tratamento passo a passo", "Lembretes pra conferir de novo", "Dicas pra isolar a planta e proteger as outras"],
         [("Quais pragas ele conhece?", "As de sempre dentro de casa: ácaros, cochonilhas, mosquinhas do fungo, pulgões, tripes e mais, 27 no total."),
          ("Ele manda usar veneno?", "Começa pelo mais leve: água, limpeza, sabão. Opções mais fortes só quando precisa, com cuidados de segurança.")])}),
 "pot": ("repotting", {
  "en": ("Know when it's time to repot, which pot size to choose and what soil each plant likes.",
         ["Signs that a plant needs a bigger home", "Pot size and material that suit it", "The right soil mix per species", "Gentle aftercare reminders"],
         [("How often should I repot?", "Most houseplants every one to two years, in spring. The app tells you per plant."),
          ("Does the pot material matter?", "Yes. Terracotta dries faster than plastic or glazed pots, and the app adjusts watering for it.")]),
  "pt": ("A hora certa de trocar de vaso, que tamanho escolher e qual substrato cada planta curte.",
         ["Sinais de que a planta precisa de um vaso maior", "Tamanho e material de vaso ideais", "O substrato certo pra cada espécie", "Lembretes de cuidado depois da troca"],
         [("De quanto em quanto tempo eu troco de vaso?", "A maioria das plantas de casa a cada um ou dois anos, na primavera. O app indica por planta."),
          ("O material do vaso faz diferença?", "Faz. Vaso de barro seca mais rápido que plástico ou cerâmica esmaltada, e o app ajusta a rega.")])}),
 "travel": ("travel-mode", {
  "en": ("Going away? Tell the app your dates and get a plan: who's fine, who needs a deep drink before you go, and who needs a friend to pop by.",
         ["A plan for every plant for your dates", "A deep-water checklist for the night before", "Hand care to a housemate while you're away", "A welcome-home check when you're back"],
         [("How long can my plants be alone?", "It depends on the plant, pot and season. The plan tells you exactly which ones will be fine."),
          ("Can someone else take over?", "Yes. Share your home and they get the reminders while you're away.")]),
  "pt": ("Vai viajar? Coloca as datas e recebe um plano: quem aguenta firme, quem precisa de uma rega caprichada antes e quem precisa de alguém dando uma olhada.",
         ["Um plano pra cada planta nas suas datas", "Checklist de rega caprichada pra véspera", "Passa os cuidados pra quem fica em casa", "Uma conferida de boas-vindas na volta"],
         [("Quanto tempo minhas plantas aguentam sozinhas?", "Depende da planta, do vaso e da estação. O plano mostra exatamente quais vão ficar bem."),
          ("Outra pessoa pode assumir?", "Pode, sim. Compartilha a casa e ela recebe os lembretes enquanto você estiver fora.")])}),
 "seedling": ("cuttings", {
  "en": ("Grow new plants from the ones you love, from the first cut to their own pot.",
         ["Where and how to cut", "Water or soil, and what to expect each week", "When roots are ready to pot", "The new plant joins your jungle with its own care plan"],
         [("Which plants are easy to propagate?", "Pothos, philodendron, tradescantia and many succulents are great first tries."),
          ("How long until roots?", "Usually two to six weeks. The app checks in so you know it's on track.")]),
  "pt": ("Faz mudinha das plantas que você mais ama, do primeiro corte até o vaso dela.",
         ["Onde e como cortar", "Na água ou na terra, e o que esperar a cada semana", "Quando as raízes tão prontas pro vaso", "A muda entra na sua selva com o próprio plano de cuidados"],
         [("Quais plantas são fáceis de multiplicar?", "Jiboia, filodendro, trapoeraba e um monte de suculenta são ótimas pra começar."),
          ("Quanto tempo até criar raiz?", "Geralmente de duas a seis semanas. O app acompanha pra você saber que tá tudo certo.")])}),
 "sun": ("seasons", {
  "en": ("What each season means for your plants, where you live: growing season, rest, frost and heat, in your hemisphere.",
         ["Feeding pauses in the rest season", "Watering slows in winter, picks up in summer", "Frost and heat alerts for outdoor plants", "Northern and southern hemispheres"],
         [("Does it know my seasons?", "Yes. It uses your rough location and hemisphere, so July means summer in Lisbon and winter in São Paulo."),
          ("Do I need to share my location?", "Only a rough area, and it stays private. You can also set your city by hand.")]),
  "pt": ("O que cada estação muda pras suas plantas, onde você mora: crescimento, descanso, geada e calor, no seu hemisfério.",
         ["Adubo pausa na época de descanso", "Rega diminui no inverno e aumenta no verão", "Alertas de geada e calor pras plantas de fora", "Hemisfério norte e sul"],
         [("Ele sabe como são as estações aqui?", "Sabe. Usa a sua região aproximada e o hemisfério: julho é verão em Lisboa e inverno em São Paulo."),
          ("Preciso compartilhar minha localização?", "Só a região aproximada, e ela fica privada. Também dá pra digitar a cidade.")])}),
 "fertilizer": ("label-scanner", {
  "en": ("In the shop and not sure? Point the camera at the back of a fertilizer, soil or treatment and see which of your plants it suits, how much to use and when.",
         ["A clear yes or no for each of your plants", "Dose and timing in plain words", "Works on most fertilizer, soil and treatment labels", "Reading happens on your iPhone"],
         [("Does it need internet?", "The label is read on your iPhone."),
          ("Is it free?", "The label scanner comes with Greenhouse and Jungle.")]),
  "pt": ("Bateu a dúvida na loja? Aponta a câmera pro verso do adubo, substrato ou remédio e vê pra quais plantas ele serve, quanto usar e quando.",
         ["Sim ou não, direto, pra cada planta", "Dose e frequência em palavras simples", "Funciona com a maioria dos rótulos de adubo, substrato e tratamento", "A leitura acontece no seu iPhone"],
         [("Precisa de internet?", "O rótulo é lido no seu iPhone."),
          ("É de graça?", "O leitor de rótulos vem com a Estufa e a Selva.")])}),
 "livingRoom": ("spaces", {
  "en": ("Room by room, the right light for every plant. Tell the app how bright each room is and it matches plants to the spots they'll love.",
         ["Rooms with their own light", "A warning when a plant sits in the wrong light", "Heating, air-con and humidity per home", "Indoor and outdoor spaces"],
         [("How do I know how bright a room is?", "The app asks simple questions: which way the window faces and how close the plant is."),
          ("Does the room change watering?", "Yes. Brighter, warmer rooms dry pots faster, and the app accounts for it.")]),
  "pt": ("Cômodo por cômodo, a luz certa pra cada planta. Conta pro app quanta luz bate em cada ambiente e ele mostra os cantinhos que cada planta vai amar.",
         ["Cômodos com a própria luz", "Aviso quando uma planta está na luz errada", "Aquecedor, ar-condicionado e umidade da casa", "Espaços internos e externos"],
         [("Como sei quanta luz um cômodo tem?", "O app faz umas perguntas simples: pra onde a janela dá e a que distância a planta fica dela."),
          ("O cômodo muda a rega?", "Muda. Cômodos mais claros e quentes secam o vaso mais rápido, e o app considera isso.")])}),
 "shieldLeaf": ("pets-and-kids", {
  "en": ("Clear notes for plants that aren't safe for cats, dogs or little ones, before they become a problem.",
         ["A warning on every plant that's toxic", "What happens and what to do if someone nibbles", "Safe alternatives when you're choosing new plants"],
         [("Is it a substitute for a vet?", "No. It's a heads-up. If a pet or child eats a plant, call your vet or a poison line."),
          ("Can I see only pet-safe plants?", "Yes, the warnings show right on each plant, so you can choose safely.")]),
  "pt": ("Avisos claros sobre plantas que não são seguras pra gatos, cachorros ou crianças, antes de virar problema.",
         ["Aviso em toda planta tóxica", "O que acontece e o que fazer se alguém morder", "Alternativas seguras ao escolher plantas novas"],
         [("Substitui o veterinário?", "Não. É só um alerta. Se o pet ou a criança comer alguma planta, liga pro veterinário ou pro Disque-Intoxicação (0800 722 6001)."),
          ("Dá pra saber quais são seguras pros pets?", "Dá, sim: o aviso aparece em cada planta, pra você escolher tranquilo.")])}),
}

GENERAL = {
 "en": [
  ("Getting started", [
   ("Do I need to know about plants?", "No. Add a plant by photo or name and the app builds its care plan, with simple explanations."),
   ("Who is Erty?", "The app's mascot and your plants' best friend. Erty greets you on first launch, asks a few questions about your home and sets everything up."),
   ("Which iPhones are supported?", "Any iPhone on the latest iOS. During the beta, you install it with Apple's free TestFlight app."),
   ("Is it in my language?", "The app and the plants speak English and Portuguese.")]),
  ("Plans and billing", [
   ("Is it really free?", "Yes. Sprout is free forever for up to 5 plants, with chat, reminders and soil checks, supported by small ads."),
   ("What do Greenhouse and Jungle add?", "Both include the same: unlimited plants, no ads, health checks, the label scanner, travel mode, seasons and cuttings guides. Jungle is the yearly plan at €1 a month."),
   ("How do I cancel?", "iPhone Settings → your name → Subscriptions → My Tiny Jungle. You keep your plan until the end of the paid period."),
   ("What happens to my plants if I cancel?", "Nothing is deleted. You keep caring for 5 plants for free and can come back any time.")]),
  ("Privacy", [
   ("Where are my photos kept?", "On your phone. If you sign in, they sync to your account so they follow you to your other devices. Photos you send to identify a plant or ask the AI doctor are analysed once and not kept."),
   ("How does sync work across my devices?", "Sign in with the same Apple or Google account on each device. Your plants, care history, chat and photos are kept on our own servers and stay the same on iPhone, iPad and Android. Only you and the people you share a jungle with can see them. Download everything or delete your account any time in Settings."),
   ("Do I need an account?", "No. Without one, everything stays on your phone. Sign in with Apple or Google when you want your jungle on more than one device or to share it with your home."),
   ("Do the ads track me?", "Only if you allow it when iOS asks. Greenhouse and Jungle remove ads completely.")]),
  ("Sharing a home", [
   ("Can I share my plants with someone?", "Yes. Invite the people you live with and you all care for the same plants, taking fair turns with no double watering."),
   ("What if I'm away?", "Someone at home takes over your turns, and the plants know who to thank.")]),
  ("Life happens", [
   ("I haven't looked after them for a while. Now what?", "No guilt. The app shows where to start, and the plants are happy to see you back."),
   ("A plant died. What now?", "It happens to everyone. You can keep its story in your jungle, and the app helps the next one do better.")]),
 ],
 "pt": [
  ("Primeiros passos", [
   ("Preciso manjar de plantas?", "Nada disso. Tira uma foto ou digita o nome da planta e o app monta todo o cuidado pra você, explicado do jeito mais simples."),
   ("Quem é o Raminho?", "É o mascote do app e o melhor amigo das suas plantas. Ele te recebe logo de cara, faz umas perguntinhas sobre a sua casa e deixa tudo prontinho."),
   ("Roda em qual iPhone?", "Em qualquer iPhone com o iOS mais recente. Durante os testes, a instalação é pelo TestFlight, um app de graça da Apple."),
   ("Tem em português?", "Tem, sim. O app e as plantas falam português e inglês.")]),
  ("Planos e pagamento", [
   ("É de graça mesmo?", "É, sim. O Broto é de graça pra sempre, pra até 5 plantas, com conversa, lembretes e teste da terra, e tem anúncios discretos."),
   ("O que os planos Estufa e Selva têm a mais?", "Os dois planos têm o mesmo: plantas ilimitadas, zero anúncios, diagnóstico de saúde, leitor de rótulos, modo viagem, estações e mudas. A Estufa é o plano mensal e a Selva, o anual, que sai mais em conta."),
   ("Como faço pra cancelar a assinatura?", "É rapidinho: Ajustes do iPhone → seu nome → Assinaturas → My Tiny Jungle → Cancelar assinatura. Seu plano continua valendo até o fim do período que você já pagou."),
   ("Se eu cancelar, perco minhas plantas?", "Não perde nada. Tudo fica salvo, você segue cuidando de até 5 plantas de graça e pode voltar quando quiser.")]),
  ("Privacidade", [
   ("Onde ficam minhas fotos?", "No seu celular. Se você entrar na conta, elas sincronizam com a sua conta pra te acompanhar nos outros aparelhos. Fotos que você manda pra identificar uma planta ou pro médico com IA são analisadas uma vez e não ficam guardadas."),
   ("Como funciona a sincronização entre aparelhos?", "Entra com a mesma conta Apple ou Google em cada aparelho. Suas plantas, histórico, conversas e fotos ficam guardados nos nossos servidores e aparecem iguaizinhos no iPhone, no iPad e no Android. Só você e quem divide a selva com você conseguem ver. Dá pra baixar tudo ou apagar a conta quando quiser, nos Ajustes."),
   ("Preciso criar uma conta?", "Não. Sem conta, tudo fica no seu celular. Entra com Apple ou Google quando quiser sua selva em mais de um aparelho ou dividir com quem mora com você."),
   ("Os anúncios me rastreiam?", "Só se você permitir quando o iOS perguntar. Estufa e Selva removem todos os anúncios.")]),
  ("Casa compartilhada", [
   ("Dá pra dividir os cuidados com mais gente?", "Dá, sim. Chama quem mora com você e todos cuidam das mesmas plantas, com rodízio justo e sem rega em dobro."),
   ("E quando eu viajar?", "Alguém da casa assume a sua vez, e as plantas sabem a quem agradecer.")]),
  ("A vida acontece", [
   ("Abandonei as plantas por um tempo. E agora?", "Sem culpa. O app mostra por onde começar e as plantas comemoram a sua volta."),
   ("Minha planta morreu. E agora?", "Acontece com todo mundo, relaxa. A história dela fica na sua selva, e o app ajuda a próxima a ir melhor.")]),
 ],
}

UI = {
 "en": {"gk_title": "Good to know", "gk_desc": "Every question about My Tiny Jungle, from getting started to each feature.", "gk_intro": "Everything people ask about My Tiny Jungle, in one place. Still curious? Write to us from the Support page.",
        "by_feature": "Feature by feature", "how": "How it works", "q": "Questions", "all_q": "All questions", "more": "Learn more", "features": "All features", "feat_desc": "Everything My Tiny Jungle does for your plants. Tap a feature to see how it works.", "plus_badge": "Paid plans"},
 "pt": {"gk_title": "Bom saber", "gk_desc": "Todas as dúvidas sobre o My Tiny Jungle, dos primeiros passos a cada recurso.", "gk_intro": "Tudo o que o pessoal pergunta sobre o My Tiny Jungle, num lugar só. Ainda ficou com dúvida? Fala com a gente na página de Ajuda.",
        "by_feature": "Recurso por recurso", "how": "Como funciona", "q": "Perguntas", "all_q": "Ver todas as perguntas", "more": "Saiba mais", "features": "Todos os recursos", "feat_desc": "Tudo o que o My Tiny Jungle faz pelas suas plantas. Toca num recurso pra ver como funciona.",
  "feat_desc": "Tudo o que o My Tiny Jungle faz pelas suas plantas. Toca num recurso pra ver como funciona.", "plus_badge": "Planos pagos"},
}
PLUS = {"firstAid", "fertilizer", "travel", "seedling", "sun"}

# Story features (App Store order, intelligence first). Each has a screenshot from the store set.
FEATURES.update({
 "sunflower": ("plants-text-you", {
  "en": ("You don't have to remember a thing. Your plants keep an eye on the soil, the weather and the calendar, and send you a message when something needs you: a frost tonight, a dry pot, a growing-season snack.",
         ["A message from the plant itself, in its own voice", "Frost, heat and rain warnings in time to act", "Thirst, feeding and repotting, only when it's due", "At most one gentle nudge a day, with quiet hours"],
         [("Will my phone buzz all day?", "No. Plants bundle what they need into at most one message a day, and nothing during your quiet hours."),
          ("How do they know?", "From the species, the pot, the room, your soil checks and the local forecast. Every message comes from that real state, never at random."),
          ("Do I need to set anything up?", "No. Add a plant and it starts looking after itself. You can mute any type of message per plant.")]),
  "pt": ("Você não precisa lembrar de nada. Suas plantas ficam de olho na terra, no clima e no calendário, e te mandam mensagem quando precisam de você: geada hoje à noite, vaso seco, um adubinho na época de crescer.",
         ["A mensagem vem da própria planta, do jeito dela", "Aviso de geada, calorão e chuva a tempo de agir", "Rega, adubo e troca de vaso só quando chega a hora", "No máximo um toque por dia, com horário de silêncio"],
         [("Meu celular vai apitar o dia todo?", "Não. As plantas juntam tudo numa mensagem por dia, no máximo, e ficam quietinhas no seu horário de silêncio."),
          ("Como elas sabem?", "Pela espécie, pelo vaso, pelo cômodo, pelos seus testes da terra e pela previsão do tempo daí. Cada mensagem vem disso, nunca é aleatória."),
          ("Preciso configurar alguma coisa?", "Não. Adicionou a planta, ela já começa a se cuidar. Dá pra silenciar qualquer tipo de mensagem, planta por planta.")])}),
 "sprout": ("identify", {
  "en": ("New plants, no idea what they are? Take one photo of the whole shelf and My Tiny Jungle names every plant in it, then adds the ones you pick with their care plans ready.",
         ["One photo, every plant on the shelf", "Common and botanical names", "Pick which ones to add with a switch", "Each new plant arrives with its own care plan and voice"],
         [("Does it work with one plant too?", "Yes. Get close for a single leaf or step back for the whole plant or shelf."),
          ("Is my photo kept?", "No. The photo is sent once to name the plants and isn't stored."),
          ("What if it gets one wrong?", "Switch it off before adding, or change the species later on the plant's page.")]),
  "pt": ("Planta nova e nem ideia de qual é? Tira uma foto da estante inteira e o My Tiny Jungle descobre cada planta, e adiciona as que você escolher com os cuidados prontinhos.",
         ["Uma foto, todas as plantas da estante", "Nome popular e nome científico", "Escolhe quais adicionar num toque", "Cada planta chega com os próprios cuidados e personalidade"],
         [("Funciona com uma planta só?", "Funciona. Chega pertinho pra uma folha ou dá uns passos pra trás pra pegar a planta inteira ou a estante."),
          ("A foto fica guardada?", "Não. A foto vai uma vez só pra descobrir as plantas e não fica guardada."),
          ("E se errar alguma?", "É só desmarcar antes de adicionar, ou trocar a espécie depois na página da planta.")])}),
 "careHands": ("shared-care", {
  "en": ("Share your jungle with the people you live with. Everyone sees the same plants, turns go to whoever did least, and nobody waters the cactus twice.",
         ["Invite your household with a link", "Fair turns, so care doesn't fall on one person", "Hand off a plant when you're busy, with one tap", "Add a plant sitter for a trip, with an end date"],
         [("Does everyone need the app?", "Yes, each person signs in with Apple or Google and joins with your invite link."),
          ("How are turns decided?", "Turns go to whoever didn't do it last, keeping things fair across the month."),
          ("Is sharing free?", "Yes. Sharing care comes with every plan, free included.")]),
  "pt": ("Divide a selva com quem mora com você. Todo mundo vê as mesmas plantas, a vez vai pra quem cuidou menos e ninguém rega o cacto duas vezes.",
         ["Chama o pessoal de casa com um link", "Rodízio justo, pra ninguém ficar com tudo", "Tá corrido? Passa a planta pra alguém num toque", "Chama alguém pra cuidar enquanto você viaja, com data pra acabar"],
         [("Todo mundo precisa do app?", "Precisa. Cada pessoa entra com Apple ou Google e participa pelo seu link de convite."),
          ("Como fica o rodízio?", "A vez vai pra quem não cuidou da última vez, pra ficar justo no mês todo."),
          ("Dividir é de graça?", "É. Dividir os cuidados vem em todos os planos, inclusive no grátis.")])}),
 "calendar": ("weekly-digest", {
  "en": ("One look and you know your week: what's coming up, who to keep an eye on, who grew, and what the weather will do to your pots.",
         ["Coming up: every task for the next days", "Keep an eye on: plants that need attention soon", "Look who grew: new leaves and milestones", "Weather ahead and what it means for watering"],
         [("When does it arrive?", "Any time you open Your week, and as a short summary at the start of the week."),
          ("Does it include shared plants?", "Yes. In a shared jungle it shows everyone's turns too.")]),
  "pt": ("Numa olhada você já sabe como vai ser a semana: o que vem por aí, quem precisa de atenção, quem cresceu e o que o tempo vai fazer com os vasos.",
         ["O que vem por aí: todas as tarefas dos próximos dias", "De olho: plantas que vão precisar de você logo", "Olha quem cresceu: folhas novas e conquistas", "Previsão do tempo e o que ela muda na rega"],
         [("Quando aparece?", "Sempre que você abre Sua semana, e num resuminho no começo da semana."),
          ("Mostra as plantas compartilhadas?", "Mostra. Numa selva compartilhada aparece a vez de cada um também.")])}),
 "pottedPlant": ("plant-chat", {
  "en": ("Every plant has its own chat, with its history, its mood and its personality. Ask Monty how he's doing and he answers from his real soil, light and care.",
         ["A one-to-one chat with every plant", "Its watering, light and room right at the top", "Personalities: dramatic, calm, chatty, curious", "Send a photo and it tells you what it sees"],
         [("Is it just for fun?", "It's fun, and it's useful: every answer comes from that plant's real state and care history."),
          ("Can I ask anything?", "Anything about the plant: water, light, leaves, pests, repotting. It says when it isn't sure.")]),
  "pt": ("Cada planta tem a sua conversa, com histórico, humor e personalidade. Pergunta pra Costelinha como ela tá e ela responde pela terra, pela luz e pelos cuidados de verdade.",
         ["Uma conversa só sua com cada planta", "Rega, luz e cômodo logo no topo", "Personalidades: dramática, tranquila, tagarela, curiosa", "Manda uma foto e ela conta o que tá vendo"],
         [("É só brincadeira?", "É divertido e é útil: cada resposta vem de como a planta tá de verdade e do histórico dela."),
          ("Posso perguntar qualquer coisa?", "Qualquer coisa sobre a planta: água, luz, folhas, pragas, troca de vaso. Quando não tem certeza, ela fala.")])}),
})

# The shared jungle chat and the season page now lead with what the screenshots show.
FEATURES["chat"][1]["en"] = ("Tell the jungle what you did, in your own words. Write “watered Monty and Pesto” and the care is logged for every plant you named, and each one answers back.",) + FEATURES["chat"][1]["en"][1:]
FEATURES["chat"][1]["pt"] = ("Conta pra selva o que você fez, do seu jeito. Escreve “reguei a Costelinha e o Pesto” e o cuidado fica anotado pra cada planta que você citou, e cada uma responde.",) + FEATURES["chat"][1]["pt"][1:]
FEATURES["sun"][1]["en"] = ("My Tiny Jungle knows your weather, each room's light and the season where you live, and adjusts every plant's care on its own: less water in winter, no feeding while they rest, frost warnings for the balcony.",
  ["Local forecast: rain, frost and heatwaves", "Each room's light, matched to every plant", "Feeding pauses in the rest season", "Northern and southern hemispheres"], FEATURES["sun"][1]["en"][2])
FEATURES["sun"][1]["pt"] = ("O My Tiny Jungle sabe o clima daí, a luz de cada cômodo e a estação onde você mora, e ajusta os cuidados de cada planta sozinho: menos água no inverno, nada de adubo no descanso, aviso de geada pra varanda.",
  ["Previsão do tempo daí: chuva, geada e calorão", "A luz de cada cômodo, combinada com cada planta", "Adubo pausa na época de descanso", "Hemisfério norte e sul"], FEATURES["sun"][1]["pt"][2])

# feature key -> (screenshot, outcome headline). Two-sentence headlines break between sentences.
SHOTS = {
 "sunflower": ("01-notes", {"en": "No more dead plants.\nThey'll text you first.", "pt": "Chega de planta morta.\nElas te mandam mensagem antes."}),
 "chat": ("02-jungle", {"en": "Just say what you did.\nEveryone gets the memo.", "pt": "Só conta o que fez.\nTodo mundo fica sabendo."}),
 "sun": ("03-season", {"en": "Frost or heatwave?\nYour plants are on it.", "pt": "Geada ou calorão?\nSuas plantas já sabem."}),
 "firstAid": ("04-doctor", {"en": "Yellow leaves?\nWe'll tell you why.", "pt": "Folha amarelando?\nA gente te fala o porquê."}),
 "sprout": ("05-identify", {"en": "Snap your shelf.\nWe'll name every plant.", "pt": "Tira foto da estante.\nA gente descobre cada planta."}),
 "fertilizer": ("06-scan", {"en": "New fertilizer?\nSee who'll love it.", "pt": "Comprou adubo?\nVeja quem vai curtir."}),
 "travel": ("07-away", {"en": "Off on a trip?\nYour plants are sorted.", "pt": "Vai viajar?\nSuas plantas ficam de boa."}),
 "careHands": ("08-household", {"en": "Share the jungle.\nNo more double watering.", "pt": "Divide a selva.\nChega de regar duas vezes."}),
 "calendar": ("09-digest", {"en": "Your whole week, sorted in one look.", "pt": "Sua semana toda, numa olhada só."}),
 "pottedPlant": ("10-chat", {"en": "And yep, they talk back.", "pt": "E sim, elas respondem."}),
}
SHOT_W = (400, 640, 960)
UI["en"].update({"story_h": "What your plants do for you", "more_h": "More help, plant by plant", "see": "See how it works"})
UI["pt"].update({"story_h": "O que suas plantas fazem por você", "more_h": "Mais ajuda, planta por planta", "see": "Ver como funciona"})
