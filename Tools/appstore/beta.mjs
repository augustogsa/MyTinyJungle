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
    whatsNew: 'Scan your plant without a frame: just take the photo, near or far. Plant ID answers again (the server reply was being dropped) and is much faster. Add several photos of one plant for a surer answer. Darker, calmer dark mode with no card outlines. Archive or delete a plant from its menu. Please try: Scan a plant from close and from far, add more photos, dark mode, and the plant menu.',
  },
  'pt-BR': {
    description: 'O My Tiny Jungle dá voz às suas plantas. Converse com cada uma, receba pedidos de cuidado no tempo certo pra sua casa e pro clima, escaneie uma planta ou o rótulo de um adubo, acompanhe tudo no calendário, divida a selva com quem mora com você e aprenda com guias curtinhos.',
    whatsNew: 'Escaneia a planta sem moldura: é só tirar a foto, de perto ou de longe. A identificação voltou a responder (a resposta do servidor estava se perdendo) e ficou bem mais rápida. Manda várias fotos da mesma planta pra uma resposta mais certeira. Modo escuro mais bonito e sem contorno nos cards. Arquiva ou apaga uma planta pelo menu dela. Testa aí: escanear de perto e de longe, mandar mais fotos, o modo escuro e o menu da planta.',
  },
  'pt-PT': {
    description: 'A My Tiny Jungle dá voz às suas plantas. Converse com cada uma, receba pedidos de cuidados na altura certa para a sua casa e o tempo, digitalize uma planta ou o rótulo de um adubo, acompanhe tudo no calendário, partilhe a selva com quem vive consigo e aprenda com guias curtos.',
    whatsNew: 'Digitalize a planta sem moldura: basta tirar a foto, de perto ou de longe. A identificação voltou a responder (a resposta do servidor estava a perder-se) e está muito mais rápida. Envie várias fotos da mesma planta para uma resposta mais certa. Modo escuro mais calmo e sem contorno nos cartões. Arquive ou apague uma planta no menu dela. Experimente: digitalizar de perto e de longe, enviar mais fotos, o modo escuro e o menu da planta.',
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
