#!/usr/bin/env node
// Uploads App Store screenshots from Assets/AppStore/screenshots to the editable version, replacing what's there.
//   node Tools/appstore/shots.mjs [--apply]
// iphone69 → APP_IPHONE_67 (6.9"), duo → APP_IPHONE_DUO. Framed shots come from Tools/appstore/frame.py.
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { call } from './asc.mjs';
const apply = process.argv.includes('--apply');
const ROOT = new URL('../../Assets/AppStore/screenshots/', import.meta.url).pathname;
const kinds = { iphone69: 'APP_IPHONE_67', duo: 'APP_IPHONE_DUO' };
const dirFor = { 'en-US': 'en-US', 'pt-BR': 'pt-BR', 'pt-PT': 'pt-PT' };
const app = (await call('GET', '/apps?filter[bundleId]=com.simpleappscompany.mytinyjungle')).data[0];
const version = (await call('GET', `/apps/${app.id}/appStoreVersions?limit=5`)).data.find(v => v.attributes.appStoreState === 'PREPARE_FOR_SUBMISSION');
for (const loc of (await call('GET', `/appStoreVersions/${version.id}/appStoreVersionLocalizations`)).data) {
  const locale = loc.attributes.locale; const dir = dirFor[locale]; if (!dir) continue;
  const sets = (await call('GET', `/appStoreVersionLocalizations/${loc.id}/appScreenshotSets`)).data;
  for (const [kind, type] of Object.entries(kinds)) {
    const folder = `${ROOT}${dir}/${kind}`; if (!existsSync(folder)) continue;
    const files = readdirSync(folder).filter(f => f.endsWith('.png')).sort().slice(0, 10);
    console.log(apply ? 'upload' : 'dry-run', locale, type, files.length);
    if (!apply) continue;
    let set = sets.find(s => s.attributes.screenshotDisplayType === type);
    if (!set) set = (await call('POST', '/appScreenshotSets', { data: { type: 'appScreenshotSets', attributes: { screenshotDisplayType: type }, relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: loc.id } } } } })).data;
    for (const old of (await call('GET', `/appScreenshotSets/${set.id}/appScreenshots`)).data) await call('DELETE', `/appScreenshots/${old.id}`);
    for (const f of files) {
      const bytes = readFileSync(`${folder}/${f}`);
      const shot = (await call('POST', '/appScreenshots', { data: { type: 'appScreenshots', attributes: { fileName: f, fileSize: bytes.length }, relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: set.id } } } } })).data;
      for (const op of shot.attributes.uploadOperations) {
        const r = await fetch(op.url, { method: op.method, headers: Object.fromEntries(op.requestHeaders.map(h => [h.name, h.value])), body: bytes.subarray(op.offset, op.offset + op.length) });
        if (!r.ok) throw new Error(`upload ${f} → ${r.status}`);
      }
      await call('PATCH', `/appScreenshots/${shot.id}`, { data: { type: 'appScreenshots', id: shot.id, attributes: { uploaded: true, sourceFileChecksum: createHash('md5').update(bytes).digest('hex') } } });
      console.log('  ok', f);
    }
  }
}
// Verify: every set COMPLETE with the right count.
await new Promise(r => setTimeout(r, apply ? 20000 : 0));
for (const loc of (await call('GET', `/appStoreVersions/${version.id}/appStoreVersionLocalizations`)).data) {
  for (const s of (await call('GET', `/appStoreVersionLocalizations/${loc.id}/appScreenshotSets`)).data) {
    const sh = (await call('GET', `/appScreenshotSets/${s.id}/appScreenshots`)).data;
    console.log('check', loc.attributes.locale, s.attributes.screenshotDisplayType, sh.length, [...new Set(sh.map(x => x.attributes.assetDeliveryState?.state))].join(','), sh.map(x => x.attributes.fileName).join(' '));
  }
}
console.log('done');
