// Applies migrations/NNNN_*.sql in order, once each, inside a transaction.
import { pool } from "../src/db.ts";

const dir = new URL("../migrations/", import.meta.url);
await pool.query(`create table if not exists schema_migrations (name text primary key, applied_at timestamptz default now())`);
const done = new Set((await pool.query(`select name from schema_migrations`)).rows.map((r: { name: string }) => r.name));
const files = [...Deno.readDirSync(dir)].map((e) => e.name).filter((n) => /^\d{4}_.*\.sql$/.test(n)).sort();
for (const f of files) {
  if (done.has(f)) continue;
  const c = await pool.connect();
  try {
    await c.query("begin");
    await c.query(await Deno.readTextFile(new URL(f, dir)));
    await c.query(`insert into schema_migrations (name) values ($1)`, [f]);
    await c.query("commit");
    console.log("applied", f);
  } catch (e) {
    await c.query("rollback");
    throw e;
  } finally {
    c.release();
  }
}
await pool.end();
