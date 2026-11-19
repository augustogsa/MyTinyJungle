import { Hono } from "hono";
import { requireAdmin, requireAuth } from "./auth.ts";
import { q } from "./db.ts";

export const adminRoutes = new Hono()
  .use(requireAuth, requireAdmin)
  .get("/stats", async (c) => {
    const [s] = await q(`select
      (select count(*) from users where deleted_at is null)::int as users,
      (select count(*) from users where created_at > now() - interval '7 days')::int as new_users_7d,
      (select count(*) from devices where last_seen_at > now() - interval '1 day')::int as active_devices_24h,
      (select count(*) from devices where platform = 'ios')::int as ios_devices,
      (select count(*) from devices where platform = 'android')::int as android_devices,
      (select count(*) from jungles where not is_personal)::int as shared_jungles,
      (select count(*) from records where entity = 'plant' and not deleted)::int as plants,
      (select count(*) from entitlements where status = 'active')::int as plus_active`);
    return c.json(s);
  })
  .get("/users", async (c) => {
    const search = `%${c.req.query("q") ?? ""}%`;
    return c.json(
      await q(
        `select u.id, u.email, u.display_name, u.role, u.created_at, u.deleted_at,
           (select max(last_seen_at) from devices d where d.user_id = u.id) as last_seen,
           (select string_agg(distinct platform, ',') from devices d where d.user_id = u.id) as platforms
         from users u where coalesce(u.email,'') ilike $1 or u.id::text ilike $1
         order by u.created_at desc limit 200`,
        [search],
      ),
    );
  })
  .get("/users/:id", async (c) => {
    const id = c.req.param("id");
    const [user] = await q(`select * from users where id = $1`, [id]);
    return c.json({
      user,
      identities: await q(`select provider, email, created_at from identities where user_id = $1`, [id]),
      devices: await q(`select * from devices where user_id = $1`, [id]),
      jungles: await q(
        `select j.*, m.role, m.until from jungle_members m join jungles j on j.id = m.jungle_id where m.user_id = $1`,
        [id],
      ),
      entitlements: await q(`select * from entitlements where user_id = $1`, [id]),
    });
  })
  .get("/notifications", async (c) =>
    c.json(await q(`select id, store, received_at, processed_at, payload from store_notifications order by id desc limit 100`))
  );
