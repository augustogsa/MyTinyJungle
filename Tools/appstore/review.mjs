#!/usr/bin/env node
// Pushes App Review notes from Tools/appstore/review-notes.txt.  node Tools/appstore/review.mjs [--apply]
import { readFileSync } from 'node:fs';
import { call } from './asc.mjs';
const notes = readFileSync(new URL('./review-notes.txt', import.meta.url), 'utf8').trim();
if (notes.length > 4000) throw new Error('notes too long');
const app = (await call('GET', '/apps?filter[bundleId]=com.simpleappscompany.mytinyjungle')).data[0];
const v = (await call('GET', `/apps/${app.id}/appStoreVersions?limit=5`)).data.find(v => v.attributes.appStoreState === 'PREPARE_FOR_SUBMISSION');
const rd = (await call('GET', `/appStoreVersions/${v.id}/appStoreReviewDetail`)).data;
if (!process.argv.includes('--apply')) { console.log('dry-run', notes.length); process.exit(0); }
await call('PATCH', `/appStoreReviewDetails/${rd.id}`, { data: { type: 'appStoreReviewDetails', id: rd.id, attributes: { notes, demoAccountRequired: false } } });
console.log('review notes pushed');
