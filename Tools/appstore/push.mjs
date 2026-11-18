#!/usr/bin/env node
// Pushes App Store listing metadata for one locale from Tools/appstore/<locale>.json.
//   node Tools/appstore/push.mjs pt-BR [--apply]
// whatsNew is pushed only for updates (ASC refuses it on the first version).
import { readFileSync } from 'node:fs';
import { call } from './asc.mjs';
const locale = process.argv[2]; const apply = process.argv.includes('--apply');
const m = JSON.parse(readFileSync(new URL(`./${locale}.json`, import.meta.url), 'utf8'));
const app = (await call('GET', '/apps?filter[bundleId]=com.simpleappscompany.mytinyjungle')).data[0];
const vers = (await call('GET', `/apps/${app.id}/appStoreVersions?limit=5`)).data;
const version = vers.find(v => ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED'].includes(v.attributes.appStoreState));
const info = (await call('GET', `/apps/${app.id}/appInfos`)).data.find(i => (i.attributes.appStoreState ?? i.attributes.state) !== 'READY_FOR_SALE');
const firstVersion = vers.length === 1;
const ver = { description: m.description, keywords: m.keywords, promotionalText: m.promotionalText, marketingUrl: 'https://mytinyjungle.com/', supportUrl: 'https://mytinyjungle.com/support', ...(firstVersion ? {} : { whatsNew: m.whatsNew }) };
const inf = { name: m.name, subtitle: m.subtitle, privacyPolicyUrl: 'https://mytinyjungle.com/privacy' };
for (const [k, max] of [['subtitle', 30], ['keywords', 100], ['promotionalText', 170], ['description', 4000], ['name', 30]]) if ((m[k] ?? '').length > max) throw new Error(`${k} too long`);
console.log(apply ? 'push' : 'dry-run', locale, version.attributes.versionString, firstVersion ? '(first version: whatsNew skipped)' : '');
if (!apply) process.exit(0);
const vl = (await call('GET', `/appStoreVersions/${version.id}/appStoreVersionLocalizations`)).data.find(l => l.attributes.locale === locale);
if (vl) await call('PATCH', `/appStoreVersionLocalizations/${vl.id}`, { data: { type: 'appStoreVersionLocalizations', id: vl.id, attributes: ver } });
else await call('POST', '/appStoreVersionLocalizations', { data: { type: 'appStoreVersionLocalizations', attributes: { locale, ...ver }, relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } } } });
const il = (await call('GET', `/appInfos/${info.id}/appInfoLocalizations`)).data.find(l => l.attributes.locale === locale);
if (il) await call('PATCH', `/appInfoLocalizations/${il.id}`, { data: { type: 'appInfoLocalizations', id: il.id, attributes: inf } });
else await call('POST', '/appInfoLocalizations', { data: { type: 'appInfoLocalizations', attributes: { locale, ...inf }, relationships: { appInfo: { data: { type: 'appInfos', id: info.id } } } } });
console.log('done', locale);
// Subscription group + products (My Tiny Jungle Plus). Locked while in review: reported, not fatal.
const soft = async (label, f) => { try { await f(); console.log('ok', label); } catch (e) { console.log('locked', label, String(e).match(/\d{3}/)?.[0]); } };
if (m.subscription) {
  const groups = (await call('GET', `/apps/${app.id}/subscriptionGroups`)).data;
  for (const g of groups) {
    const gl = (await call('GET', `/subscriptionGroups/${g.id}/subscriptionGroupLocalizations`)).data.find(l => l.attributes.locale === locale);
    const ga = { name: m.subscription.groupName };
    await soft('group', async () => { if (gl) await call('PATCH', `/subscriptionGroupLocalizations/${gl.id}`, { data: { type: 'subscriptionGroupLocalizations', id: gl.id, attributes: ga } });
    else await call('POST', '/subscriptionGroupLocalizations', { data: { type: 'subscriptionGroupLocalizations', attributes: { locale, ...ga }, relationships: { subscriptionGroup: { data: { type: 'subscriptionGroups', id: g.id } } } } }); });
    for (const s of (await call('GET', `/subscriptionGroups/${g.id}/subscriptions`)).data) {
      const sl = (await call('GET', `/subscriptions/${s.id}/subscriptionLocalizations`)).data.find(l => l.attributes.locale === locale);
      const sa = { name: m.subscription.displayName, description: m.subscription.description };
      await soft(s.attributes.productId, async () => { if (sl) await call('PATCH', `/subscriptionLocalizations/${sl.id}`, { data: { type: 'subscriptionLocalizations', id: sl.id, attributes: sa } });
      else await call('POST', '/subscriptionLocalizations', { data: { type: 'subscriptionLocalizations', attributes: { locale, ...sa }, relationships: { subscription: { data: { type: 'subscriptions', id: s.id } } } } }); });
    }
  }
  console.log('subscriptions', locale);
}
