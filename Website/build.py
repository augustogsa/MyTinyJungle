import re
import json
from home_content import TESTFLIGHT_URL as TESTFLIGHT
#!/usr/bin/env python3
"""Builds the static mytinyjungle.com site into Website/dist (EN at /, pt-BR at /pt/)."""
import hashlib
import shutil
import seo
from pathlib import Path

ROOT = Path(__file__).parent
SRC, DIST = ROOT / "src", ROOT / "dist"
SITE = "https://mytinyjungle.com"
BRAND_NAME = (Path(__file__).parent / "src" / "brand-name.html").read_text()
CSS_V = hashlib.sha1(b"".join((Path(__file__).parent / "src" / f).read_bytes() for f in ("style.css", "site.js"))).hexdigest()[:10]
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
  "lang": "en", "prefix": "", "lights": "Turn the lights off or on", "other": "pt", "other_label": "PT",
  "nav": ["Inside the app", "Plus", "Support", "Join the beta"],
  "foot": ["Support", "Privacy", "Terms", "Good to know","Features"], "made": 'Planted in Lisbon by <a href="https://simpleappscompany.com">Simple Apps Company</a>',
  "cta": "Coming soon on the App Store",
  "home_title": "My Tiny Jungle: the plant care app that knows your home",
  "home_desc": "Not a watering timer. My Tiny Jungle works out each plant's care from your weather, room light, pot and soil, and your plants tell you in their own words.",
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
  "s2_sub": "A care calendar grown from what you actually did. Going away? Travel care tells you what to do before you leave.",
  "s3_eyebrow": "Scan", "s3_h": "Point at a label. Know if it's right for your plants.",
  "s3_sub": "Scan the back of a fertiliser, potting mix or treatment and My Tiny Jungle checks it against every plant you have. Or scan a new plant, or a sick leaf, to find out what's going on.",
  "p_eyebrow": "Pricing", "p_h": "Start free. Grow when you're ready.",
  "plans": [
    ("Free", "€0", "forever", ["Up to 5 plants", "Chat and care requests", "Soil-check ritual", "Care calendar"], False, ""),
    ("My Tiny Jungle Plus", "€1.99", "per month", ["Unlimited plants", "Product scanner", "Travel care and propagation guides", "Season planning"], False, ""),
    ("My Tiny Jungle Plus", "€11.99", "per year", ["Everything in monthly", "Save 50% over monthly"], True, "Best value"),
  ],
  "fine": "Prices in euros; local prices may vary by country. Subscriptions renew automatically until cancelled in your Apple ID settings.",
  "c_h": "Give your plants a voice.", "c_p": "My Tiny Jungle is coming soon to iPhone.",
  # support
  "sup_title": "Support", "sup_desc": "Help with My Tiny Jungle: contact, subscriptions and common questions.",
  "sup_intro": f'Questions, bugs or ideas? Email <a href="mailto:{EMAIL}?subject=My%20Tiny%20Jungle">{EMAIL}</a>. A person reads every message and we reply within two working days.',
  "sup_tip": "Please include your iPhone model, iOS version and the app version (Me tab).",
  "faq_h": "Common questions",
  "faq": [
    ("How do I cancel My Tiny Jungle Plus?", "Open iPhone Settings → your name → Subscriptions → My Tiny Jungle → Cancel Subscription. You keep Plus until the end of the period you paid for."),
    ("Can I get a refund?", 'Purchases are handled by Apple. Request a refund at <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a>.'),
    ("I bought Plus but the app still shows the free plan.", "Open Me → Restore Purchases while signed in with the same Apple ID you used to subscribe."),
    ("Are my photos uploaded?", "No. Plant recognition and product scans run on your iPhone. We never receive your photos."),
    ("Why do I see ads?", "Ads keep the free version free. My Tiny Jungle Plus removes them. You can change ad personalisation in Me → Privacy &amp; ads choices."),
    ("What happens to my plants if I reach 5 on the free plan?", "Nothing is deleted. You can keep caring for your 5 plants, or upgrade to add more."),
    ("How do I delete my data?", "Delete the app: your plant data only lives on your device (and in your own iCloud backup, if enabled). For ad data, see the Privacy Policy."),
  ],
  # privacy
  "pri_title": "Privacy Policy", "pri_desc": "How My Tiny Jungle handles data: plant photos and scans stay on your device; the free version shows Google AdMob ads.",
  "pri_box": "Short version: your plants, photos, notes and scans stay on your iPhone and we never receive them. The free version shows ads from Google AdMob, which may process limited device data to show and measure ads, with your consent where the law requires it. My Tiny Jungle Plus has no ads and makes no ad requests.",
  "pri": [
    ("Who is responsible", f"My Tiny Jungle is published by Simple Apps Company (“we”), the data controller for the app. Contact: <a href=\"mailto:{EMAIL}\">{EMAIL}</a>."),
    ("What stays on your device", "Plant photos, plant recognition, label scans, plant names, care logs, reminders and chat messages are processed and stored only on your iPhone. If iCloud backup is on, they are included in your own encrypted Apple backup, which we cannot access. We have no accounts and no servers that receive this data."),
    ("Ads in the free version (Google AdMob)", "<ul><li>The free version shows ads served by Google AdMob. Google acts as an independent controller for the data it processes to serve ads; Simple Apps Company is the controller for the app itself.</li><li>To show and measure ads, the Google Mobile Ads SDK may collect: your device advertising identifier (IDFA), only if you allow tracking when iOS asks; approximate location derived from your IP address; ad interactions (views and taps); and diagnostic and performance data about the ad SDK.</li><li>This is used for advertising, ad measurement, fraud prevention and keeping ads working. It is never linked to your plants, photos or scans.</li></ul>"),
    ("Your consent and choices", "<ul><li>In the EEA, UK and Switzerland we ask for your consent using Google's User Messaging Platform (UMP) before any personalised ads are shown. If you don't consent, you may see non-personalised ads, which use only contextual and limited data.</li><li>Elsewhere, ads are non-personalised unless you allow tracking in the iOS prompt.</li><li>You can change your mind at any time in the app under Me → Privacy &amp; ads choices, and in iPhone Settings → Privacy &amp; Security → Tracking.</li><li>Subscribing to My Tiny Jungle Plus removes all ads: no ads are shown and the app makes no ad SDK requests.</li></ul>"),
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
    ("Free plan and My Tiny Jungle Plus", "The free plan lets you care for up to 5 plants and shows ads (see the Privacy Policy). My Tiny Jungle Plus is an optional auto-renewable subscription that removes ads and unlocks unlimited plants and extra features, offered monthly (€1.99) or yearly (€11.99). Prices shown in the app in your local currency are the ones that apply."),
    ("Payment and auto-renewal", "<ul><li>Payment is charged to your Apple ID account when you confirm the purchase.</li><li>The subscription renews automatically for the same period and price unless you cancel at least 24 hours before the end of the current period.</li><li>Your account is charged for renewal within 24 hours before the current period ends.</li><li>You can manage or cancel in iPhone Settings → your name → Subscriptions. Cancelling stops the next renewal; you keep access until the paid period ends.</li><li>If a free trial is offered, any unused part of it ends when you buy a subscription.</li></ul>"),
    ("Refunds", 'Refunds are handled by Apple under its policies at <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a>. EU consumer rights are not affected.'),
    ("Acceptable use", "Don't reverse engineer, resell or misuse the app, and don't use it to break the law."),
    ("Liability", "The app is provided “as is”. To the extent the law allows, Simple Apps Company is not liable for indirect losses, including the loss of a plant. Nothing in these terms limits rights you have as a consumer that cannot be excluded."),
    ("Changes and law", "We may update these terms; the date above shows the latest version. These terms are governed by Portuguese law, without depriving you of protections under the law of your country of residence."),
    ("Contact", f'<a href="mailto:{EMAIL}">{EMAIL}</a>'),
  ],
  "get_nav": "Get the app", "get_title": "Get My Tiny Jungle for iPhone", "get_desc": "Free for up to 5 plants. Join the beta on TestFlight and your plants start talking today.",
  "get_intro": "My Tiny Jungle is in public beta on iPhone. Install TestFlight, tap the button, and add your first plant in under a minute.",
  "get_btn": "Join the beta on TestFlight", "get_pts": ["Free for up to 5 plants, no card needed", "Works on iPhone with iOS 26 or later", "English and Brazilian Portuguese", "Photos stay on your iPhone"],
  "nf_title": "This page wandered off", "nf_desc": "We couldn't find that page. It may have moved, or the link has a typo.", "nf_home": "Back to the jungle",
  "updated": "Last updated", "plus_title": "Opening My Tiny Jungle", "plus_desc": "Choose your plan in the app.", "plus_intro": "If My Tiny Jungle is on this iPhone, it opens straight to your plan. Not installed yet? Get it free with TestFlight first, then tap the plan again.", "plus_btn": "Get My Tiny Jungle on TestFlight", "plus_tip": "On a computer? Open mytinyjungle.com on your iPhone to join.",
 },
 "pt": {
  "lang": "pt-BR", "prefix": "/pt", "lights": "Apagar ou acender as luzes", "other": "en", "other_label": "EN",
  "nav": ["O app", "Plus", "Ajuda", "Quero testar"],
  "foot": ["Ajuda", "Privacidade", "Termos", "Bom saber","Recursos"], "made": 'Plantado em Lisboa pela <a href="https://simpleappscompany.com">Simple Apps Company</a>',
  "cta": "Em breve na App Store",
  "home_title": "My Tiny Jungle: o app que cuida das suas plantas do jeito certo",
  "home_desc": "Chega de lembrete genérico. O My Tiny Jungle olha o clima, a luz de cada cômodo, o vaso e a terra pra te dizer do que cada planta precisa, na hora certa.",
  "h1": "Suas plantas têm <em>muito</em> a dizer.",
  "lead": "O My Tiny Jungle transforma o cuidado com as plantas num bate-papo. Conte o que você fez do seu jeito e elas respondem dizendo do que precisam agora.",
  "note": "Grátis para até 5 plantas. Suas fotos ficam no seu iPhone.",
  "chat": [("me", "reguei o Milo e a Luna ontem"), ("plant", "Milo", "Valeu! Agora fico de boa por mais ou menos uma semana."),
            ("plant", "Luna", "Dá uma olhada na minha terra na terça? Caláteia gosta dela só úmida."), ("me", "as folhas da Luna estão enrolando"),
            ("plant", "Luna", "Geralmente é sede ou ar seco. Borrifa uma aguinha em mim e me tira do sol direto.")],
  "f_eyebrow": "Como funciona", "f_h": "Cuidar como quem conversa, não como quem cumpre tarefa.",
  "f_sub": "Nada de formulário nem planilha. Escreva como você mandaria mensagem para um amigo e o My Tiny Jungle cuida do resto.",
  "features": [
    ("chat", "", "Plantas que falam", "Cada planta tem sua própria voz. Elas agradecem, lembram você e avisam quando algo não vai bem."),
    ("drop", "sun", "Pedidos de cuidado", "Regar, borrifar, adubar, girar o vaso. As plantas pedem na hora certa, de acordo com a espécie, a estação e o cômodo."),
    ("finger", "peach", "O ritual de sentir a terra", "Em vez de chutar, coloque o dedo na terra e conte ao app como ela está. A rotina se ajusta à sua casa, não a uma tabela genérica."),
    ("scan", "terra", "Leitor de produtos", "Escaneie um adubo ou substrato e descubra se serve para sua planta e quanto usar."),
  ],
  "s1_eyebrow": "Sua selva num relance", "s1_h": "Todas as plantas, todos os cômodos, numa lista tranquila.",
  "s1_sub": "Adicione uma planta com uma foto ou uma frase. O My Tiny Jungle reconhece a espécie no seu iPhone e já preenche os cuidados básicos.",
  "s1_list": [("Plantas", "Nomes, espécies, cômodos e histórico"), ("Hoje", "O bate-papo onde você anota cuidados e tira dúvidas"), ("Cuidados", "Esta semana, este mês, esta estação"), ("Escanear", "Produtos e plantas, direto no celular")],
  "s2_eyebrow": "Planeje com antecedência", "s2_h": "Saiba o que vem pela frente antes de alguma planta murchar.",
  "s2_sub": "Um calendário que cresce com o que você realmente fez. Vai viajar? Os cuidados de viagem dizem o que fazer antes de sair de casa.",
  "s3_eyebrow": "Escanear", "s3_h": "Aponte para o rótulo. Descubra se serve para suas plantas.",
  "s3_sub": "Escaneie o verso de um adubo, substrato ou tratamento e o My Tiny Jungle compara com todas as suas plantas. Ou escaneie uma planta nova, ou uma folha doente, para entender o que está acontecendo.",
  "p_eyebrow": "Preços", "p_h": "Comece de graça. Cresça quando quiser.",
  "plans": [
    ("Grátis", "0 €", "para sempre", ["Até 5 plantas", "Bate-papo e pedidos de cuidado", "Ritual de sentir a terra", "Calendário de cuidados"], False, ""),
    ("My Tiny Jungle Plus", "1,99 €", "por mês", ["Plantas ilimitadas", "Leitor de produtos", "Guias de viagem e de mudas", "Planejamento por estação"], False, ""),
    ("My Tiny Jungle Plus", "11,99 €", "por ano", ["Tudo do plano mensal", "Economize 50% em relação ao mensal"], True, "Melhor custo-benefício"),
  ],
  "fine": "Preços em euros; podem variar de acordo com o país. As assinaturas são renovadas automaticamente até serem canceladas nos ajustes do seu ID Apple.",
  "c_h": "Dê voz às suas plantas.", "c_p": "O My Tiny Jungle chega em breve ao iPhone.",
  "sup_title": "Ajuda", "sup_desc": "Fala com a gente, tira dúvidas da assinatura e vê as perguntas mais comuns.",
  "sup_intro": f'Ficou com dúvida, achou um bug ou teve uma ideia? Manda um e-mail pra <a href="mailto:{EMAIL}?subject=My%20Tiny%20Jungle">{EMAIL}</a>. Quem lê é gente de verdade, e a gente responde em até dois dias úteis.',
  "sup_tip": "Pra agilizar, conta qual é o seu iPhone, a versão do iOS e a versão do app (aba Você).",
  "faq_h": "Perguntas frequentes",
  "faq": [
    ("Como faço pra cancelar o My Tiny Jungle Plus?", "É rapidinho: Ajustes do iPhone → seu nome → Assinaturas → My Tiny Jungle → Cancelar assinatura. O Plus continua valendo até o fim do período que você já pagou."),
    ("Dá pra pedir reembolso?", 'Quem cuida das compras é a Apple. Pede o reembolso em <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a>.'),
    ("Assinei o Plus, mas o app continua no plano de graça.", "Vai em Você → Restaurar compras, com o mesmo ID Apple da assinatura."),
    ("Minhas fotos vão pra algum lugar?", "Não. O reconhecimento de plantas e a leitura de produtos acontecem no seu iPhone. Nunca recebemos suas fotos."),
    ("Por que aparecem anúncios?", "São eles que bancam a versão de graça. O My Tiny Jungle Plus tira todos. Dá pra mudar a personalização em Você → Privacidade e anúncios."),
    ("E quando eu chegar a 5 plantas no plano de graça?", "Nada é apagado. Você segue cuidando das 5 ou assina pra colocar mais."),
    ("Como eu apago meus dados?", "É só apagar o app: os dados das plantas só existem no seu aparelho (e no seu backup do iCloud, se estiver ativado). Sobre dados de anúncios, veja a Política de Privacidade."),
  ],
  "pri_title": "Política de Privacidade", "pri_desc": "Como o My Tiny Jungle trata seus dados: fotos e leituras ficam no celular; a versão grátis mostra anúncios do Google AdMob.",
  "pri_box": "Resumindo: suas plantas, fotos, anotações e leituras ficam no seu iPhone e nunca chegam até nós. A versão grátis mostra anúncios do Google AdMob, que pode tratar dados limitados do aparelho para exibir e medir anúncios, com o seu consentimento quando a lei exige. O My Tiny Jungle Plus não tem anúncios e não faz nenhuma solicitação de anúncios.",
  "pri": [
    ("Quem é o responsável", f"O My Tiny Jungle é publicado pela Simple Apps Company (“nós”), controladora dos dados tratados pelo app. Contato: <a href=\"mailto:{EMAIL}\">{EMAIL}</a>."),
    ("O que fica no seu aparelho", "Fotos das plantas, reconhecimento de plantas, leituras de rótulos, nomes, registros de cuidados, lembretes e mensagens são processados e armazenados apenas no seu iPhone. Se o backup do iCloud estiver ativado, eles entram no seu backup criptografado da Apple, ao qual não temos acesso. Não temos contas nem servidores que recebam esses dados."),
    ("Anúncios na versão grátis (Google AdMob)", "<ul><li>A versão grátis mostra anúncios veiculados pelo Google AdMob. O Google atua como controlador independente dos dados que trata para veicular anúncios; a Simple Apps Company é a controladora do app.</li><li>Para exibir e medir anúncios, o SDK Google Mobile Ads pode coletar: o identificador de publicidade do aparelho (IDFA), somente se você permitir o rastreamento quando o iOS perguntar; localização aproximada a partir do endereço IP; interações com anúncios (visualizações e toques); e dados de diagnóstico e desempenho do SDK.</li><li>Esses dados são usados para publicidade, medição, prevenção de fraudes e funcionamento dos anúncios. Eles nunca são associados às suas plantas, fotos ou leituras.</li></ul>"),
    ("Seu consentimento e suas escolhas", "<ul><li>No EEE, no Reino Unido e na Suíça, pedimos seu consentimento pela User Messaging Platform (UMP) do Google antes de mostrar anúncios personalizados. Se você não consentir, poderá ver anúncios não personalizados, que usam apenas dados contextuais e limitados.</li><li>Nos demais países, os anúncios não são personalizados, a menos que você permita o rastreamento no aviso do iOS.</li><li>Você pode mudar de ideia quando quiser no app, em Você → Privacidade e anúncios, e em Ajustes do iPhone → Privacidade e Segurança → Rastreamento.</li><li>Assinar o My Tiny Jungle Plus remove todos os anúncios: nenhum anúncio é exibido e o app não faz nenhuma solicitação ao SDK de anúncios.</li></ul>"),
    ("Políticas do Google", f"Saiba mais em <a href=\"https://policies.google.com/technologies/partner-sites?hl=pt-BR\">Como o Google usa informações de sites ou apps que usam nossos serviços</a> e na <a href=\"https://policies.google.com/privacy?hl=pt-BR\">Política de Privacidade do Google</a>."),
    ("Notificações", "Os lembretes são agendados localmente no seu aparelho. Você pode desativá-los quando quiser nos Ajustes do iPhone."),
    ("Compras", "As assinaturas são processadas inteiramente pela Apple. Nunca vemos seu nome, e-mail ou dados de pagamento. Para manter as assinaturas funcionando, nosso servidor pode receber as notificações do App Store Server da Apple, que contêm apenas identificadores anônimos de transação e o status da assinatura."),
    ("Bases legais (RGPD)", "Anúncios personalizados e identificador de publicidade: seu consentimento (art. 6º, nº 1, alínea a), que você pode revogar a qualquer momento. Anúncios não personalizados, medição e prevenção de fraudes: nosso legítimo interesse em manter um app gratuito (art. 6º, nº 1, alínea f). Status da assinatura: execução de contrato (art. 6º, nº 1, alínea b)."),
    ("Crianças", "O My Tiny Jungle não é destinado a menores de 13 anos e não coleta intencionalmente dados deles. Os anúncios são solicitados com as configurações do Google para público geral e nunca são personalizados sem consentimento."),
    ("Seus direitos", "Você pode falar com a gente sobre seus dados e tem direito de acesso, retificação, exclusão, limitação, oposição e portabilidade, além de revogar o consentimento. Como os dados do app ficam apenas no seu aparelho, apagar o app os remove. Para dados de anúncios mantidos pelo Google, use as escolhas de anúncios no app, redefina o identificador de publicidade ou fale com o Google. Você também pode apresentar uma reclamação à CNPD (autoridade de proteção de dados de Portugal)."),
    ("Usuários no Brasil (LGPD)", f"Se você está no Brasil, tem os direitos previstos na Lei Geral de Proteção de Dados (Lei nº 13.709/2018), como confirmação, acesso, correção, anonimização, portabilidade, eliminação e revogação do consentimento. Para exercê-los, escreva para <a href=\"mailto:{EMAIL}\">{EMAIL}</a>. Você também pode recorrer à ANPD."),
    ("Alterações", "Se esta política mudar, atualizaremos esta página e a data acima."),
  ],
  "ter_title": "Termos de Uso", "ter_desc": "Termos de uso do My Tiny Jungle, incluindo assinaturas e renovação automática.",
  "ter": [
    ("Acordo", 'Ao baixar ou usar o My Tiny Jungle, você aceita estes termos e o <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">Contrato de Licença de Usuário Final de Aplicativos Licenciados</a> da Apple (o “EULA Padrão”), válido entre você e a Simple Apps Company. Em caso de conflito, prevalecem estes termos, na medida permitida por lei.'),
    ("O app", "O My Tiny Jungle ajuda você a acompanhar o cuidado com plantas de dentro de casa. Dicas e identificações são sugestões, não garantias. Plantas são seres vivos e os resultados variam; use o bom senso, principalmente com plantas que possam ser tóxicas para pets ou crianças."),
    ("Plano grátis e My Tiny Jungle Plus", "O plano grátis permite cuidar de até 5 plantas e mostra anúncios (veja a Política de Privacidade). O My Tiny Jungle Plus é uma assinatura opcional com renovação automática que remove os anúncios e libera plantas ilimitadas e recursos extras, mensal (1,99 €) ou anual (11,99 €). Valem os preços mostrados no app na sua moeda local."),
    ("Pagamento e renovação automática", "<ul><li>O pagamento é cobrado na sua conta do ID Apple quando você confirma a compra.</li><li>A assinatura é renovada automaticamente pelo mesmo período e preço, a menos que você cancele pelo menos 24 horas antes do fim do período atual.</li><li>A renovação é cobrada nas 24 horas anteriores ao fim do período atual.</li><li>Você pode gerenciar ou cancelar em Ajustes do iPhone → seu nome → Assinaturas. O cancelamento impede a próxima renovação; você mantém o acesso até o fim do período pago.</li><li>Se houver um período de teste gratuito, a parte não usada termina quando você compra uma assinatura.</li></ul>"),
    ("Reembolsos", 'Os reembolsos são administrados pela Apple em <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a>. Seus direitos de consumidor na UE não são afetados.'),
    ("Uso aceitável", "Não faça engenharia reversa, não revenda nem use o app de forma indevida, e não o use para violar a lei."),
    ("Responsabilidade", "O app é fornecido “no estado em que se encontra”. Na medida permitida por lei, a Simple Apps Company não se responsabiliza por perdas indiretas, incluindo a perda de uma planta. Nada nestes termos limita direitos do consumidor que não possam ser excluídos."),
    ("Alterações e lei aplicável", "Podemos atualizar estes termos; a data acima indica a versão mais recente. Estes termos são regidos pela lei portuguesa, sem prejuízo das proteções da lei do seu país de residência."),
    ("Contato", f'<a href="mailto:{EMAIL}">{EMAIL}</a>'),
  ],
  "get_nav": "Baixar o app", "get_title": "Baixe o My Tiny Jungle no iPhone", "get_desc": "Grátis pra até 5 plantas. Entra no beta pelo TestFlight e suas plantas já começam a falar hoje.",
  "get_intro": "O My Tiny Jungle tá em beta aberto no iPhone. Instala o TestFlight, toca no botão e cadastra sua primeira planta em menos de um minuto.",
  "get_btn": "Entrar no beta pelo TestFlight", "get_pts": ["Grátis pra até 5 plantas, sem cartão", "Funciona no iPhone com iOS 26 ou mais novo", "Em português do Brasil e em inglês", "Suas fotos ficam no seu iPhone"],
  "nf_title": "Essa página se perdeu", "nf_desc": "A gente não achou essa página. Pode ter mudado de lugar ou o link tá com erro.", "nf_home": "Voltar pra selva",
  "updated": "Última atualização", "plus_title": "Abrindo o My Tiny Jungle", "plus_desc": "Escolhe seu plano no app.", "plus_intro": "Se o My Tiny Jungle já tá no seu iPhone, ele abre direto no plano que você escolheu. Ainda não tem? Instala de graça pelo TestFlight e toca no plano de novo.", "plus_btn": "Baixar o My Tiny Jungle no TestFlight", "plus_tip": "Tá no computador? Abre mytinyjungle.com no iPhone pra entrar.",
 },
}


def sentence_breaks(html):
    """Headlines with several sentences break between them, one sentence per line, never mid-sentence."""
    return re.sub(r"(<h[1-3][^>]*>)(.*?)(</h[1-3]>)", lambda m: m[1] + re.sub(r"([.?!])\s+(?=[A-ZÀ-Ý¿¡])", r"\1<br>", m[2]) + m[3], html, flags=re.S)


def brand_mentions(html):
    """Every 'My Tiny Jungle' in visible text is set as the brand: bolder, in the brand green. Tags, attributes and scripts untouched."""
    parts = re.split(r"(<script.*?</script>|<[^>]+>)", html, flags=re.S)
    return "".join(x if x.startswith("<") else x.replace("My Tiny Jungle", '<span class="mtj">My Tiny Jungle</span>') for x in parts)


def page(L, path, title, desc, body):
    body = brand_mentions(sentence_breaks(body))
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
<meta property="og:url" content="{canon}">{seo.head(L, path, title, desc, canon, DIST)}
<meta name="apple-itunes-app" content="app-id=6836292367">
<link rel="icon" type="image/png" sizes="64x64" href="/assets/favicon-64.png"><link rel="icon" type="image/png" sizes="192x192" href="/assets/favicon-192.png"><link rel="apple-touch-icon" href="/assets/apple-touch-icon.png"><link rel="preload" as="image" href="/assets/erty/favicon-sprite.png?v=3">
<link rel="preload" href="/fonts/Intern.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="/style.css?v={CSS_V}">
</head><body>
<script>try{{var t=localStorage.getItem("theme");if(t)document.documentElement.dataset.theme=t}}catch(e){{}}</script><script>(function(){{try{{if(/bot|crawl|spider|slurp|preview|lighthouse/i.test(navigator.userAgent))return;var s=localStorage.getItem("lang"),p=location.pathname,pt=p==="/pt"||p.indexOf("/pt/")===0;var want=s||((navigator.languages&&navigator.languages[0])||navigator.language||"en").toLowerCase().indexOf("pt")===0?"pt":"en";if(s)want=s;if(want==="pt"&&!pt)location.replace("/pt"+(p==="/"?"/":p)+location.search+location.hash);else if(want==="en"&&pt)location.replace((p.replace(/^\/pt/,"")||"/")+location.search+location.hash)}}catch(e){{}}}})()</script>
<script>try{{var t=localStorage.getItem("theme");if(t)document.documentElement.dataset.theme=t}}catch(e){{}}</script>
<header class="nav"><div class="wrap navbar">
<a class="brand" href="{p}/"><span class="bname" aria-label="My Tiny Jungle">{BRAND_NAME}</span></a>
<nav><a class="hide-s" href="{p}/#today">{n[0]}</a><a class="hide-s" href="{p}/#pricing">{n[1]}</a><a class="hide-s" href="{p}/support">{n[2]}</a>
<button class="lights" type="button" aria-label="{t['lights']}" aria-pressed="false"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3Z"/><path class="glow" d="M12 0v1M3.5 3.5l.8.8M20.5 3.5l-.8.8M0 11h1M23 11h-1"/></svg></button><a class="lang" href="{other}" hreflang="{T[t['other']]['lang']}">{t['other_label']}</a><a class="btn btn-s" href="https://testflight.apple.com/join/A8YUuUHj" rel="noopener">{n[3]}</a></nav>
</div></header>
<main>{body}</main>
<footer><div class="wrap"><span>© 2026 SimpleAppsCo LLC <img class="fsep" src="/icons/sprout.png" alt="" width="20" height="20" loading="lazy"> {t['made']}</span>
<nav><a href="{p}/get">{t['get_nav']}</a><a href="{p}/features">{f[4]}</a><a href="{p}/good-to-know">{f[3]}</a><a href="{p}/support">{f[0]}</a><a href="{p}/privacy">{f[1]}</a><a href="{p}/terms">{f[2]}</a></nav></div></footer>
<script src="/site.js?v={CSS_V}" defer></script>
</body></html>"""


def phone(img, alt, cls=""):
    return (f'<div class="phone {cls}"><div class="phone-screen"><img src="/assets/{img}" alt="{alt}" width="1100" height="2392" loading="lazy"></div>'
            f'<img class="phone-frame" src="/assets/device/iphone-frame.webp" alt="" width="588" height="1200"></div>')


def home(L):
    from home_content import render_home
    return render_home(L, T[L], page, phone, ICON["apple"])


def doc(L, path, title, desc, inner, meta=True, seo_title=None):
    t = T[L]
    m = f'<p class="meta">{t["updated"]}: {UPDATED[L]}</p>' if meta else ""
    body = f'<section class="doc"><div class="wrap"><div class="paper"><h1>{title}</h1>{m}{inner}</div></div></section>'
    return page(L, path, f"{seo_title or title} · My Tiny Jungle", desc, body)


def sections(items):
    return "".join(f"<h2>{h}</h2>{b if b.startswith('<ul>') else f'<p>{b}</p>'}" for h, b in items)


def _feat_rows(L):
    from home_content import H
    from site_pages import FEATURES
    return [(ic, FEATURES[ic][0], title, short, FEATURES[ic][1][L]) for ic, title, short in H[L]["all"]]


def feature_pages(L):
    from site_pages import UI, PLUS
    t, u, p = T[L], UI[L], T[L]["prefix"]
    rows = _feat_rows(L)
    out = {}
    for k, (ic, slug, title, short, (intro, how, qs)) in enumerate(rows):
        badge = f'<span class="fbadge">{u["plus_badge"]}</span>' if ic in PLUS else ""
        nxt = rows[(k + 1) % len(rows)]
        inner = (f'<div class="fhero"><img class="i3d" src="/icons/{ic}.png" alt="" width="88" height="88">{badge}</div>'
                 f'<p class="flead">{intro}</p><h2>{u["how"]}</h2><ul class="fhow">' + "".join(f"<li>{x}</li>" for x in how) + "</ul>"
                 f'<h2>{u["q"]}</h2><div class="faq">' + "".join(f"<details><summary>{q}</summary><p>{a}</p></details>" for q, a in qs) + "</div>"
                 f'<div class="fnav"><a href="{p}/good-to-know">{u["all_q"]}</a><a href="{p}/features/{nxt[1]}">{nxt[2]} →</a></div>' + seo.faq_ld(qs))
        out[f"features/{slug}"] = doc(L, f"/features/{slug}", title, seo.meta_desc(intro, *(x if x.endswith(".") else x + "." for x in how)), inner, meta=False,
                                         seo_title=seo.FEATURE_TITLE[L].get(slug))
    grid = '<div class="fgrid">' + "".join(
        f'<a class="fcard" href="{p}/features/{slug}"><img class="i3d" src="/icons/{ic}.png" alt="" width="56" height="56">'
        f'<span class="ft">{title}' + (f' <span class="fbadge">{u["plus_badge"]}</span>' if ic in PLUS else "") + f'</span><span class="fs">{short}</span></a>'
        for ic, slug, title, short, _ in rows) + "</div>"
    out["features"] = doc(L, "/features", u["features"], u["feat_desc"], f'<p class="flead">{u["feat_desc"]}</p>{grid}<div class="fnav"><a href="{p}/good-to-know">{u["all_q"]}</a></div>', meta=False)
    return out


def good_to_know(L):
    from site_pages import UI, GENERAL
    t, u, p = T[L], UI[L], T[L]["prefix"]
    det = lambda qs: '<div class="faq">' + "".join(f"<details><summary>{q}</summary><p>{a}</p></details>" for q, a in qs) + "</div>"
    inner = f'<p class="flead">{u["gk_intro"]}</p>' + "".join(f"<h2>{g}</h2>{det(qs)}" for g, qs in GENERAL[L])
    inner += f'<h2>{u["by_feature"]}</h2>' + "".join(
        f'<h3 class="fq"><img class="i3d" src="/icons/{ic}.png" alt="" width="32" height="32"><a href="{p}/features/{slug}">{title}</a></h3>{det(qs)}'
        for ic, slug, title, short, (intro, how, qs) in _feat_rows(L))
    return doc(L, "/good-to-know", u["gk_title"], u["gk_desc"], inner, meta=False)
    inner += seo.faq_ld([q for g, qs in GENERAL[L] for q in qs] + [q for *_, (i, h, qs) in _feat_rows(L) for q in qs])


def build():
    seo.PAGES.clear(); seo.HOME_DESC.update({L: T[L]["home_desc"] for L in T})
    if DIST.exists():
        shutil.rmtree(DIST)
    (DIST / "assets").mkdir(parents=True)
    shutil.copytree(SRC / "assets", DIST / "assets", dirs_exist_ok=True)
    for d in ("icons", "fonts"):
        shutil.copytree(SRC / d, DIST / d)
    shutil.copy(SRC / "style.css", DIST / "style.css")
    shutil.copy(SRC / "site.js", DIST / "site.js")
    shutil.copy(SRC / "favicon.ico", DIST / "favicon.ico")
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
            **feature_pages(L),
            "good-to-know": good_to_know(L),
            "plus": doc(L, "/plus", t["plus_title"], t["plus_desc"],
                        f'<p>{t["plus_intro"]}</p><p><a class="btn" href="{TESTFLIGHT}">{t["plus_btn"]}</a></p><div class="box"><p>{t["plus_tip"]}</p></div>'
                        f'<script>if(/iPhone|iPad/.test(navigator.userAgent))setTimeout(function(){{location.href="{TESTFLIGHT}"}},1500)</script>', meta=False),
        }
        out["get"] = doc(L, "/get", t["get_title"], t["get_desc"],
                        f'<p class="flead">{t["get_intro"]}</p><p><a class="btn" href="{TESTFLIGHT}" rel="noopener">{ICON["apple"]}{t["get_btn"]}</a></p>'
                        f'<ul class="fhow">' + "".join(f"<li>{x}</li>" for x in t["get_pts"]) + f'</ul><div class="fnav"><a href="{p}/features">{t["foot"][4]} →</a></div>', meta=False)
        for slug, html in out.items():
            d = DIST / p.lstrip("/") / slug
            d.mkdir(parents=True, exist_ok=True)
            (d / "index.html").write_text(html)
            urls.append(f"{SITE}{p}/{slug}".rstrip("/") if slug else f"{SITE}{p}/")
    t = T["en"]
    (DIST / "404.html").write_text(doc("en", "/404", t["nf_title"], t["nf_desc"],
        f'<p class="flead">{t["nf_desc"]}</p><p><a class="btn" href="/">{t["nf_home"]}</a></p><p><a href="/pt/">{T["pt"]["nf_title"]} · {T["pt"]["nf_home"]}</a></p>', meta=False))
    wk = DIST / ".well-known"; wk.mkdir(exist_ok=True)
    (wk / "security.txt").write_text(seo.SECURITY)
    (wk / "apple-app-site-association").write_text(json.dumps({"applinks": {"details": [{"appIDs": ["JKMB58P38J.com.simpleappscompany.mytinyjungle"], "components": [{"/": "/plus"}, {"/": "/pt/plus"}]}]}}))
    if (SRC / "app-ads.txt").exists():
        shutil.copy(SRC / "app-ads.txt", DIST / "app-ads.txt")
    (DIST / "robots.txt").write_text(seo.ROBOTS)
    (DIST / "sitemap.xml").write_text(seo.sitemap(T))
    (DIST / "llms.txt").write_text(seo.llms(T, {L: _feat_rows(L) for L in T}))
    (DIST / "site.webmanifest").write_text(seo.manifest())
    (DIST / "humans.txt").write_text(seo.HUMANS)
    (DIST / f"{seo.INDEXNOW_KEY}.txt").write_text(seo.INDEXNOW_KEY)
    (DIST / ".htaccess").write_text(seo.HTACCESS)
    print("built", len(urls), "pages")


if __name__ == "__main__":
    build()
