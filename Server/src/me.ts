import { Hono } from "hono";
import { z } from "zod";
import { type Claims, requireAuth } from "./auth.ts";
import { q } from "./db.ts";

export const meRoutes = new Hono()
  .use(requireAuth)
  .get("/", async (c) => {
    const { sub } = c.get("claims") as Claims;
    const [user] = await q(`select id, email, display_name, role, locale, created_at from users where id = $1`, [sub]);
    const identities = await q(`select provider, email from identities where user_id = $1`, [sub]);
    const devices = await q(
      `select id, platform, model, app_version, last_seen_at from devices where user_id = $1 order by last_seen_at desc`,
      [sub],
    );
    const ent = await q(
      `select product_id, store, expires_at, status from entitlements
       where user_id = $1 and status = 'active' and (expires_at is null or expires_at > now())`,
      [sub],
    );
    return c.json({ user, identities, devices, plus: ent.length > 0, entitlements: ent });
  })
  .patch("/", async (c) => {
    const { sub } = c.get("claims") as Claims;
    const b = z.object({ displayName: z.string().max(60).optional(), locale: z.string().max(10).optional() })
      .parse(await c.req.json());
    await q(`update users set display_name = coalesce($2, display_name), locale = coalesce($3, locale) where id = $1`, [
      sub, b.displayName ?? null, b.locale ?? null,
    ]);
    return c.json({ ok: true });
  })
  .put("/push-token", async (c) => {
    const { dev } = c.get("claims") as Claims;
    const { token } = z.object({ token: z.string().max(400) }).parse(await c.req.json());
    await q(`update devices set push_token = $2 where id = $1`, [dev, token]);
    return c.json({ ok: true });
  })
  // App Store 5.1.1(v): in-app account deletion. Soft-delete now, purge job removes data after 30 days.
  .delete("/", async (c) => {
    const { sub } = c.get("claims") as Claims;
    await q(`update users set deleted_at = now() where id = $1`, [sub]);
    await q(`delete from sessions where user_id = $1`, [sub]);
    await q(`insert into audit_log (actor, action, target) values ($1, 'account.delete', $1)`, [sub]);
    return c.json({ ok: true });
  });
