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
    whatsNew: 'Ready for iPhone Duo: two-page layouts open or half-open, a full month care calendar with stats, a new sign-in and onboarding layout, rooms and diet cards. Please try: add a plant, chat with it, log care from Today, open Care, scan a label, invite someone to your jungle. On iPhone Duo, try every posture and rotation.',
  },
  'pt-BR': {
    description: 'O My Tiny Jungle dá voz às suas plantas. Converse com cada uma, receba pedidos de cuidado no tempo certo pra sua casa e pro clima, escaneie uma planta ou o rótulo de um adubo, acompanhe tudo no calendário, divida a selva com quem mora com você e aprenda com guias curtinhos.',
    whatsNew: 'Pronto pro iPhone Duo: telas em duas páginas aberto ou meio aberto, calendário do mês inteiro com estatísticas, novo login e boas-vindas, cards de cômodos e de adubo. Testa aí: adicione uma planta, converse com ela, registre um cuidado no Hoje, abra Cuidados, escaneie um rótulo, convide alguém pra sua selva. No iPhone Duo, teste todas as posições e rotações.',
  },
  'pt-PT': {
    description: 'A My Tiny Jungle dá voz às suas plantas. Converse com cada uma, receba pedidos de cuidados na altura certa para a sua casa e o tempo, digitalize uma planta ou o rótulo de um adubo, acompanhe tudo no calendário, partilhe a selva com quem vive consigo e aprenda com guias curtos.',
    whatsNew: 'Pronta para o iPhone Duo: ecrãs em duas páginas aberto ou meio aberto, calendário do mês inteiro com estatísticas, novo início de sessão e boas-vindas, cartões de divisões e de adubo. Experimente: adicione uma planta, converse com ela, registe um cuidado em Hoje, abra Cuidados, digitalize um rótulo, convide alguém para a sua selva. No iPhone Duo, experimente todas as posições e rotações.',
  },
};
const notes = 'Sign-in is required: the app has no email or password account, only Sign in with Apple (and Google), so we cannot provide a demo account. Please sign in with Sign in with Apple using your own Apple ID; a new jungle is created for you and the short setup chat follows. Everything can then be tested: add a plant from the Plants tab by name or photo, chat with it, log care from Today, the Care calendar, Scan, and Me > Share your jungle. Subscriptions use the sandbox. Ads show to free users after the ATT and consent prompts. The app also adapts to iPhone Duo (open, half-open and closed).';

const shared = { feedbackEmail: 'asqgomes@gmail.com', marketingUrl: 'https://mytinyjungle.com/', privacyPolicyUrl: 'https://mytinyjungle.com/privacy' };
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
