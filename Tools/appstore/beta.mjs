#!/usr/bin/env node
// TestFlight: test information (all languages), review notes, What to Test, external group, Beta App Review.
//   node Tools/appstore/beta.mjs <build-number> [--apply]
import { call } from './asc.mjs';
const build = process.argv[2]; const apply = process.argv.includes('--apply');
const GROUP = '7d6eed3d-159c-4780-84d6-16ac222e3f51'; // Friends & testers (external)
const app = (await call('GET', '/apps?filter[bundleId]=com.simpleappscompany.mytinyjungle')).data[0];

const info = {
  'en-US': {
    description: 'My Tiny Jungle gives your houseplants a voice. Chat with each plant, get gentle care requests timed to your home and weather, scan a plant or a fertiliser label, keep a care calendar, share the jungle with the people you live with and learn from short how-to guides.',
    whatsNew: 'A plant brain on our own server: snap a sick leaf and get a diagnosis from our plant library that knows your room, season and local weather; ask any care question in chat; identify a plant from a photo; a care plan for where each plant lives; frost and heatwave alerts. New: Home and Lock Screen widgets, Siri shortcuts, a weekly digest with the weather for next week, add a whole shelf from one photo, Who waters (households), plant passport to share a care card by QR, supplies with low-stock alerts. Please try: widgets, AI doctor on a plant, Did this help?, ask a question in chat, Identify from photo when adding, the care plan card, Settings > Frost & heatwave alerts.',
  },
  'pt-BR': {
    description: 'O My Tiny Jungle dá voz às suas plantas. Converse com cada uma, receba pedidos de cuidado no tempo certo pra sua casa e pro clima, escaneie uma planta ou o rótulo de um adubo, acompanhe tudo no calendário, divida a selva com quem mora com você e aprenda com guias curtinhos.',
    whatsNew: 'Um cérebro de plantas no nosso próprio servidor: tira foto de uma folha doente e recebe o diagnóstico da nossa biblioteca, que sabe do seu cômodo, da estação e do clima aí; pergunta qualquer coisa no chat; identifica a planta pela foto; plano de cuidados pra onde cada planta vive; alerta de geada e onda de calor. Novidades: widgets na tela inicial e bloqueada, atalhos da Siri, resumo da semana com o clima da próxima, adicionar uma prateleira inteira numa foto só, Quem rega (casa), passaporte da planta pra compartilhar por QR e estoque de insumos com aviso. Testa aí: os widgets, o doutor de plantas, o Ajudou?, uma pergunta no chat, Identificar pela foto ao adicionar, o card do plano de cuidados e Ajustes > alertas de geada e calor.',
  },
  'pt-PT': {
    description: 'A My Tiny Jungle dá voz às suas plantas. Converse com cada uma, receba pedidos de cuidados na altura certa para a sua casa e o tempo, digitalize uma planta ou o rótulo de um adubo, acompanhe tudo no calendário, partilhe a selva com quem vive consigo e aprenda com guias curtos.',
    whatsNew: 'Um cérebro de plantas no nosso servidor: fotografe uma folha doente e receba o diagnóstico da nossa biblioteca, que conhece a divisão, a estação e o tempo local; faça qualquer pergunta no chat; identifique uma planta por foto; plano de cuidados para onde cada planta vive; alertas de geada e onda de calor. Novidades: widgets no ecrã principal e bloqueado, atalhos da Siri, resumo semanal com o tempo da próxima semana, adicionar uma prateleira inteira numa só foto, Quem rega (casa), passaporte da planta para partilhar por QR e stock de produtos com alerta. Experimente: os widgets, o doutor de plantas, Ajudou?, uma pergunta no chat, Identificar por foto, o cartão do plano de cuidados e Definições > alertas de geada e calor.',
  },
};
const notes = 'Sign-in is required: the app has no email or password account, only Sign in with Apple (and Google), so we cannot provide a demo account. Please sign in with Sign in with Apple using your own Apple ID; a new jungle is created for you and the short setup chat follows. Everything can then be tested: add a plant from the Plants tab by name or photo, chat with it, log care from Today, the Care calendar, Scan, and Me > Share your jungle. Subscriptions use the sandbox. Ads show to free users after the ATT and consent prompts. The app also adapts to iPhone Duo (open, half-open and closed).';

const shared = { feedbackEmail: 'support@simpleappscompany.com', marketingUrl: 'https://mytinyjungle.com/', privacyPolicyUrl: 'https://mytinyjungle.com/privacy' };
console.log(apply ? 'apply' : 'dry-run', 'build', build);
if (!apply) process.exit(0);

// Test information per language.
const locs = (await call('GET', `/apps/${app.id}/betaAppLocalizations`)).data;
for (const [locale, t] of Object.entries(info)) {
  const l = locs.find(x => x.attributes.locale === locale);
  const attributes = { ...shared, description: t.description };
  if (l) await call('PATCH', `/betaAppLocalizations/${l.id}`, { data: { type: 'betaAppLocalizations', id: l.id, attributes } });
  else await call('POST', '/betaAppLocalizations', { data: { type: 'betaAppLocalizations', attributes: { locale, ...attributes }, relationships: { app: { data: { type: 'apps', id: app.id } } } } });
  console.log('test info', locale);
}
// Beta review notes.
const rd = (await call('GET', `/apps/${app.id}/betaAppReviewDetail`)).data;
await call('PATCH', `/betaAppReviewDetails/${rd.id}`, { data: { type: 'betaAppReviewDetails', id: rd.id, attributes: { notes, demoAccountRequired: false } } });
console.log('review notes');

// The build: wait for processing.
let b;
for (let i = 0; i < 60; i++) {
  b = (await call('GET', `/builds?filter[app]=${app.id}&filter[version]=${build}&limit=1`)).data[0];
  if (b?.attributes.processingState === 'VALID') break;
  console.log('processing…', b?.attributes.processingState ?? 'not yet');
  await new Promise(r => setTimeout(r, 30000));
}
if (b?.attributes.processingState !== 'VALID') throw new Error('build not processed');
if (b.attributes.usesNonExemptEncryption == null) await call('PATCH', `/builds/${b.id}`, { data: { type: 'builds', id: b.id, attributes: { usesNonExemptEncryption: false } } });
const bl = (await call('GET', `/builds/${b.id}/betaBuildLocalizations`)).data;
for (const [locale, t] of Object.entries(info)) {
  const l = bl.find(x => x.attributes.locale === locale);
  if (l) await call('PATCH', `/betaBuildLocalizations/${l.id}`, { data: { type: 'betaBuildLocalizations', id: l.id, attributes: { whatsNew: t.whatsNew } } });
  else await call('POST', '/betaBuildLocalizations', { data: { type: 'betaBuildLocalizations', attributes: { locale, whatsNew: t.whatsNew }, relationships: { build: { data: { type: 'builds', id: b.id } } } } });
  console.log('what to test', locale);
}
await call('POST', `/betaGroups/${GROUP}/relationships/builds`, { data: [{ type: 'builds', id: b.id }] });
console.log('added to Friends & testers');
try {
  await call('POST', '/betaAppReviewSubmissions', { data: { type: 'betaAppReviewSubmissions', relationships: { build: { data: { type: 'builds', id: b.id } } } } });
  console.log('submitted for Beta App Review');
} catch (e) { console.log('beta review:', String(e).slice(0, 400)); }
console.log('done');
