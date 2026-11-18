#!/usr/bin/env node
// App Store Connect listing localizations (name/subtitle + description/keywords/promo/what's new).
//   node Tools/scripts/asc_listing.mjs show
//   node Tools/scripts/asc_listing.mjs push [--apply]   (copies the en-US listing structure to the languages below)
// Needs ~/.config/mydigitalmagnets/asc.env (ASC_KEY_ID, ASC_ISSUER_ID, ASC_P8_PATH).
import { readFileSync } from 'node:fs';
import { createPrivateKey, sign } from 'node:crypto';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const ROOT = "";
const env = Object.fromEntries(readFileSync(join(homedir(), '.config/mydigitalmagnets/asc.env'), 'utf8').split('\n').filter((l) => l.includes('=')).map((l) => { const i = l.indexOf('='); return [l.slice(0, i).trim(), l.slice(i + 1).trim().replace(/^["']|["']$/g, '')]; }));
const b64 = (b) => Buffer.from(b).toString('base64url');
function token() {
  const head = b64(JSON.stringify({ alg: 'ES256', kid: env.ASC_KEY_ID, typ: 'JWT' }));
  const body = b64(JSON.stringify({ iss: env.ASC_ISSUER_ID, exp: Math.floor(Date.now() / 1000) + 900, aud: 'appstoreconnect-v1' }));
  const sig = sign('sha256', Buffer.from(`${head}.${body}`), { key: createPrivateKey(readFileSync(env.ASC_P8_PATH.replace('~', homedir()))), dsaEncoding: 'ieee-p1363' });
  return `${head}.${body}.${b64(sig)}`;
}
const API = 'https://api.appstoreconnect.apple.com/v1';
async function call(method, path, body) {
  const r = await fetch(path.startsWith('http') ? path : API + path, { method, headers: { Authorization: `Bearer ${token()}`, 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
  const t = await r.text();
  if (!r.ok) throw new Error(`${method} ${path} → ${r.status} ${t.slice(0, 600)}`);
  return t ? JSON.parse(t) : {};
}
export { call };
