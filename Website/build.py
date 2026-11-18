#!/usr/bin/env python3
"""Builds the static mytinyjungle.com site into Website/dist (EN at /, PT-PT at /pt/)."""
import hashlib
import shutil
from pathlib import Path

ROOT = Path(__file__).parent
SRC, DIST = ROOT / "src", ROOT / "dist"
SITE = "https://mytinyjungle.com"
CSS_V = hashlib.sha1((Path(__file__).parent / "src" / "style.css").read_bytes()).hexdigest()[:10]
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
  "home_desc": "Chat with your plants. Log care by just saying what you did, get gentle care requests, and keep every plant happy. Your photos stay on your device.",
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
    ("Why do I see ads?", "Ads keep the free version free. Tiny Jungle Plus removes them. You can change ad personalisation in Me → Privacy &amp; ads choices."),
    ("What happens to my plants if I reach 5 on the free plan?", "Nothing is deleted. You can keep caring for your 5 plants, or upgrade to add more."),
    ("How do I delete my data?", "Delete the app: your plant data only lives on your device (and in your own iCloud backup, if enabled). For ad data, see the Privacy Policy."),
  ],
  # privacy
  "pri_title": "Privacy Policy", "pri_desc": "How My Tiny Jungle handles data: plant photos and scans stay on your device; the free version shows Google AdMob ads.",
  "pri_box": "Short version: your plants, photos, notes and scans stay on your iPhone and we never receive them. The free version shows ads from Google AdMob, which may process limited device data to show and measure ads, with your consent where the law requires it. Tiny Jungle Plus has no ads and makes no ad requests.",
  "pri": [
    ("Who is responsible", f"My Tiny Jungle is published by Simple Apps Company (“we”), the data controller for the app. Contact: <a href=\"mailto:{EMAIL}\">{EMAIL}</a>."),
    ("What stays on your device", "Plant photos, plant recognition, label scans, plant names, care logs, reminders and chat messages are processed and stored only on your iPhone. If iCloud backup is on, they are included in your own encrypted Apple backup, which we cannot access. We have no accounts and no servers that receive this data."),
    ("Ads in the free version (Google AdMob)", "<ul><li>The free version shows ads served by Google AdMob. Google acts as an independent controller for the data it processes to serve ads; Simple Apps Company is the controller for the app itself.</li><li>To show and measure ads, the Google Mobile Ads SDK may collect: your device advertising identifier (IDFA), only if you allow tracking when iOS asks; approximate location derived from your IP address; ad interactions (views and taps); and diagnostic and performance data about the ad SDK.</li><li>This is used for advertising, ad measurement, fraud prevention and keeping ads working. It is never linked to your plants, photos or scans.</li></ul>"),
    ("Your consent and choices", "<ul><li>In the EEA, UK and Switzerland we ask for your consent using Google's User Messaging Platform (UMP) before any personalised ads are shown. If you don't consent, you may see non-personalised ads, which use only contextual and limited data.</li><li>Elsewhere, ads are non-personalised unless you allow tracking in the iOS prompt.</li><li>You can change your mind at any time in the app under Me → Privacy &amp; ads choices, and in iPhone Settings → Privacy &amp; Security → Tracking.</li><li>Subscribing to Tiny Jungle Plus removes all ads: no ads are shown and the app makes no ad SDK requests.</li></ul>"),
    ("Google's policies", f"Learn more in <a href=\"https://policies.google.com/technologies/partner-sites\">How Google uses information from sites or apps that use its services</a> and the <a href=\"https://policies.google.com/privacy\">Google Privacy Policy</a>."),
    ("Notifications", "Care reminders are scheduled locally on your device. You can turn them off at any time in iPhone Settings."),
    ("Purchases", "Subscriptions are processed entirely by Apple. We never see your name, email or payment details. To keep subscriptions working, our server may receive Apple's App Store Server Notifications, which contain only anonymous transaction identifiers and subscription status."),
    ("Legal bases (GDPR)", "Personalised ads and the advertising identifier: your consent (Art. 6(1)(a)), which you can withdraw at any time. Non-personalised ads, ad measurement and fraud prevention: our legitimate interest in funding a free app (Art. 6(1)(f)). Subscription status: performance of the contract (Art. 6(1)(b))."),
    ("Children", "My Tiny Jungle is not directed at children under 13 and does not knowingly collect their data. Ads are requested with Google's settings for a general audience and are never personalised without consent."),
    ("Your rights", "You can ask us about your data, and you have the rights of access, rectification, erasure, restriction, objection and portability, and to withdraw consent. Because the app's own data lives only on your device, deleting the app removes it. For ad data held by Google, use the in-app ad choices, reset your advertising identifier, or contact Google. You may also complain to your data protection authority (in Portugal, the CNPD)."),
    ("Changes", "If this policy changes, we'll update this page and the date above."),
  ],
  # terms
  "ter_title": "Terms of Use", "ter_desc": "Terms of use for My Tiny Jungle, including subscriptions and auto-renewal.",
  "ter": [
    ("Agreement", 'By downloading or using My Tiny Jungle you agree to these terms and to Apple\'s <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">Licensed Application End User License Agreement</a> (the “Standard EULA”), which applies between you and Simple Apps Company. If these terms and the Standard EULA conflict, these terms apply where the law allows.'),
    ("The app", "My Tiny Jungle helps you keep track of houseplant care. Care tips and plant identification are suggestions, not guarantees. Plants are living things and results vary; use your own judgement, especially for plants that may be toxic to pets or children."),
    ("Free plan and Tiny Jungle Plus", "The free plan lets you care for up to 5 plants and shows ads (see the Privacy Policy). Tiny Jungle Plus is an optional auto-renewable subscription that removes ads and unlocks unlimited plants and extra features, offered monthly (€1.99) or yearly (€11.99). Prices shown in the app in your local currency are the ones that apply."),
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
  "home_desc": "Converse com as suas plantas. Registe os cuidados por escrito, receba pedidos de cuidado e mantenha todas as plantas felizes. As fotografias ficam no seu dispositivo.",
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
    ("Porque vejo anúncios?", "Os anúncios mantêm a versão grátis gratuita. O Tiny Jungle Plus remove-os. Pode alterar a personalização em Eu → Privacidade e anúncios."),
    ("O que acontece se chegar às 5 plantas no plano grátis?", "Nada é apagado. Pode continuar a cuidar das 5 plantas ou subscrever para adicionar mais."),
    ("Como apago os meus dados?", "Apague a app: os dados das plantas só existem no seu dispositivo (e na sua cópia do iCloud, se ativa). Para dados de anúncios, veja a Política de Privacidade."),
  ],
  "pri_title": "Política de Privacidade", "pri_desc": "Como a My Tiny Jungle trata os dados: fotos e leituras ficam no dispositivo; a versão grátis mostra anúncios Google AdMob.",
  "pri_box": "Em resumo: as plantas, fotografias, notas e leituras ficam no seu iPhone e nunca as recebemos. A versão grátis mostra anúncios do Google AdMob, que pode tratar dados limitados do dispositivo para mostrar e medir anúncios, com o seu consentimento quando a lei o exige. O Tiny Jungle Plus não tem anúncios nem faz pedidos de anúncios.",
  "pri": [
    ("Quem é responsável", f"A My Tiny Jungle é publicada pela Simple Apps Company (“nós”), responsável pelo tratamento dos dados da app. Contacto: <a href=\"mailto:{EMAIL}\">{EMAIL}</a>."),
    ("O que fica no seu dispositivo", "Fotografias das plantas, reconhecimento de plantas, leituras de rótulos, nomes, registos de cuidados, lembretes e mensagens são tratados e guardados apenas no seu iPhone. Com a cópia de segurança do iCloud ativa, são incluídos na sua cópia encriptada da Apple, à qual não temos acesso. Não temos contas nem servidores que recebam estes dados."),
    ("Anúncios na versão grátis (Google AdMob)", "<ul><li>A versão grátis mostra anúncios servidos pelo Google AdMob. A Google atua como responsável independente pelos dados que trata para servir anúncios; a Simple Apps Company é responsável pela app.</li><li>Para mostrar e medir anúncios, o SDK Google Mobile Ads pode recolher: o identificador de publicidade do dispositivo (IDFA), apenas se permitir o rastreamento quando o iOS pergunta; localização aproximada a partir do endereço IP; interações com anúncios (visualizações e toques); e dados de diagnóstico e desempenho do SDK.</li><li>Estes dados servem para publicidade, medição, prevenção de fraude e funcionamento dos anúncios. Nunca são associados às suas plantas, fotografias ou leituras.</li></ul>"),
    ("O seu consentimento e escolhas", "<ul><li>No EEE, Reino Unido e Suíça pedimos o seu consentimento através da User Messaging Platform (UMP) da Google antes de mostrar anúncios personalizados. Se não consentir, poderá ver anúncios não personalizados, que usam apenas dados contextuais e limitados.</li><li>Noutros países, os anúncios não são personalizados, salvo se permitir o rastreamento no pedido do iOS.</li><li>Pode mudar de ideias a qualquer momento na app em Eu → Privacidade e anúncios, e em Definições do iPhone → Privacidade e segurança → Rastreamento.</li><li>Subscrever o Tiny Jungle Plus remove todos os anúncios: não são mostrados e a app não faz pedidos ao SDK de anúncios.</li></ul>"),
    ("Políticas da Google", f"Saiba mais em <a href=\"https://policies.google.com/technologies/partner-sites?hl=pt-PT\">Como a Google usa informações de sites ou apps que utilizam os seus serviços</a> e na <a href=\"https://policies.google.com/privacy?hl=pt-PT\">Política de Privacidade da Google</a>."),
    ("Notificações", "Os lembretes são agendados localmente no seu dispositivo. Pode desativá-los a qualquer momento nas Definições do iPhone."),
    ("Compras", "As subscrições são processadas inteiramente pela Apple. Nunca vemos o seu nome, email ou dados de pagamento. Para manter as subscrições a funcionar, o nosso servidor pode receber as notificações do App Store Server da Apple, que contêm apenas identificadores anónimos de transação e o estado da subscrição."),
    ("Fundamentos jurídicos (RGPD)", "Anúncios personalizados e identificador de publicidade: o seu consentimento (art. 6.º, n.º 1, al. a)), que pode retirar a qualquer momento. Anúncios não personalizados, medição e prevenção de fraude: o nosso interesse legítimo em financiar uma app grátis (art. 6.º, n.º 1, al. f)). Estado da subscrição: execução do contrato (art. 6.º, n.º 1, al. b))."),
    ("Crianças", "A My Tiny Jungle não se destina a menores de 13 anos e não recolhe intencionalmente os seus dados. Os anúncios são pedidos com as definições da Google para público geral e nunca são personalizados sem consentimento."),
    ("Os seus direitos", "Pode contactar-nos sobre os seus dados e tem os direitos de acesso, retificação, apagamento, limitação, oposição e portabilidade, e de retirar o consentimento. Como os dados da app ficam apenas no seu dispositivo, apagar a app remove-os. Para dados de anúncios detidos pela Google, use as escolhas de anúncios na app, reponha o identificador de publicidade ou contacte a Google. Pode também apresentar queixa à CNPD."),
    ("Alterações", "Se esta política mudar, atualizamos esta página e a data acima."),
  ],
  "ter_title": "Termos de Utilização", "ter_desc": "Termos de utilização da My Tiny Jungle, incluindo subscrições e renovação automática.",
  "ter": [
    ("Acordo", 'Ao descarregar ou usar a My Tiny Jungle aceita estes termos e o <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">Contrato de Licença de Utilizador Final de Aplicações Licenciadas</a> da Apple (o “EULA Padrão”), aplicável entre si e a Simple Apps Company. Em caso de conflito, prevalecem estes termos na medida permitida por lei.'),
    ("A app", "A My Tiny Jungle ajuda a acompanhar o cuidado de plantas de interior. Dicas e identificações são sugestões, não garantias. As plantas são seres vivos e os resultados variam; use o seu bom senso, sobretudo com plantas que possam ser tóxicas para animais ou crianças."),
    ("Plano grátis e Tiny Jungle Plus", "O plano grátis permite cuidar de até 5 plantas e mostra anúncios (ver a Política de Privacidade). O Tiny Jungle Plus é uma subscrição opcional de renovação automática que remove os anúncios e desbloqueia plantas ilimitadas e funcionalidades extra, mensal (1,99 €) ou anual (11,99 €). Aplicam-se os preços mostrados na app na sua moeda local."),
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
<link rel="stylesheet" href="/style.css?v={CSS_V}">
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
    if (SRC / "app-ads.txt").exists():
        shutil.copy(SRC / "app-ads.txt", DIST / "app-ads.txt")
    (DIST / "robots.txt").write_text(f"User-agent: *\nAllow: /\nSitemap: {SITE}/sitemap.xml\n")
    (DIST / "sitemap.xml").write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
                                      + "".join(f"<url><loc>{u}</loc></url>" for u in urls) + "</urlset>\n")
    (DIST / ".htaccess").write_text(
        "DirectorySlash Off\nErrorDocument 404 /\n"
        "RewriteEngine On\nRewriteCond %{REQUEST_FILENAME} -d\nRewriteCond %{REQUEST_FILENAME}/index.html -f\nRewriteRule ^(.*[^/])$ $1/index.html [L]\n"
        "<IfModule mod_headers.c>\n<FilesMatch \"\\.(jpg|png)$\">\nHeader set Cache-Control \"public, max-age=604800\"\n</FilesMatch>\n"
        "Header always set X-Content-Type-Options nosniff\nHeader always set Referrer-Policy strict-origin-when-cross-origin\n</IfModule>\n")
    print("built", len(urls), "pages")


if __name__ == "__main__":
    build()
