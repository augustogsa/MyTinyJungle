import { Hono } from "hono";
import { z } from "zod";
import { type Claims, requireAuth } from "./auth.ts";
import { q, tx } from "./db.ts";

export const ENTITIES = ["plant", "care_event", "chat_message", "owned_product", "space", "care_task", "observation"] as const;

/** Jungles the user can read/write right now (sitters lose access after `until`). */
export async function jungleIds(userId: string): Promise<string[]> {
  const rows = await q<{ jungle_id: string }>(
    `select jungle_id from jungle_members where user_id = $1 and (until is null or until > now())`,
    [userId],
  );
  return rows.map((r) => r.jungle_id);
}

export async function ensurePersonalJungle(userId: string): Promise<string> {
  return await tx(async (db) => {
    const r = await db.query(`select id from jungles where owner_id = $1 and is_personal`, [userId]);
    if (r.rows[0]) return r.rows[0].id;
    const id = (await db.query(`insert into jungles (owner_id) values ($1) returning id`, [userId])).rows[0].id;
    await db.query(`insert into jungle_members (jungle_id, user_id, role) values ($1,$2,'owner')`, [id, userId]);
    return id;
  });
}

const Change = z.object({
  jungleId: z.string().uuid(),
  entity: z.enum(ENTITIES),
  id: z.string().uuid(),
  data: z.record(z.string(), z.unknown()),
  deleted: z.boolean().default(false),
  baseVersion: z.number().int().nonnegative().nullable(), // version the client last saw; null = new
  clientUpdatedAt: z.string().datetime(),
});

export const syncRoutes = new Hono()
  .use(requireAuth)
  .get("/bootstrap", async (c) => {
    const claims = c.get("claims") as Claims;
    const personal = await ensurePersonalJungle(claims.sub);
    const jungles = await q(
      `select j.id, j.name, j.is_personal, m.role, m.until from jungles j
       join jungle_members m on m.jungle_id = j.id
       where m.user_id = $1 and (m.until is null or m.until > now())`,
      [claims.sub],
    );
    return c.json({ personalJungleId: personal, jungles });
  })
  // Pull every change after the cursor across all the user's jungles.
  .get("/pull", async (c) => {
    const claims = c.get("claims") as Claims;
    const since = Number(c.req.query("since") ?? 0);
    const limit = Math.min(Number(c.req.query("limit") ?? 500), 1000);
    const ids = await jungleIds(claims.sub);
    const rows = await q<{ version: string }>(
      `select jungle_id as "jungleId", entity, id, data, deleted, version, updated_at as "updatedAt"
       from records where jungle_id = any($1) and version > $2 order by version limit $3`,
      [ids, since, limit + 1],
    );
    const more = rows.length > limit;
    const changes = rows.slice(0, limit);
    const cursor = changes.length ? Number(changes[changes.length - 1].version) : since;
    return c.json({ changes, cursor, more });
  })
  // Push changes. Last writer wins by clientUpdatedAt; a stale write is returned as a conflict with the server copy.
  .post("/push", async (c) => {
    const claims = c.get("claims") as Claims;
    const { changes } = z.object({ changes: z.array(Change).max(500) }).parse(await c.req.json());
    const allowed = new Set(await jungleIds(claims.sub));
    const results = await tx(async (db) => {
      const out: unknown[] = [];
      for (const ch of changes) {
        if (!allowed.has(ch.jungleId)) {
          out.push({ id: ch.id, status: "forbidden" });
          continue;
        }
        const cur = (await db.query(
          `select version, client_updated_at, data, deleted from records
           where jungle_id = $1 and entity = $2 and id = $3 for update`,
          [ch.jungleId, ch.entity, ch.id],
        )).rows[0];
        const stale = cur && ch.baseVersion !== Number(cur.version) &&
          new Date(cur.client_updated_at) > new Date(ch.clientUpdatedAt);
        if (stale) {
          out.push({ id: ch.id, status: "conflict", server: { ...cur, version: Number(cur.version) } });
          continue;
        }
        const r = await db.query(
          `insert into records (jungle_id, entity, id, data, deleted, updated_by, updated_device, client_updated_at)
           values ($1,$2,$3,$4,$5,$6,$7,$8)
           on conflict (jungle_id, entity, id) do update set data = excluded.data, deleted = excluded.deleted,
             version = nextval('record_version_seq'), updated_by = excluded.updated_by,
             updated_device = excluded.updated_device, client_updated_at = excluded.client_updated_at, updated_at = now()
           returning version`,
          [ch.jungleId, ch.entity, ch.id, ch.data, ch.deleted, claims.sub, claims.dev, ch.clientUpdatedAt],
        );
        out.push({ id: ch.id, status: "ok", version: Number(r.rows[0].version) });
      }
      return out;
    });
    return c.json({ results });
  });
