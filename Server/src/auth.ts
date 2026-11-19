import { Hono } from "hono";
import type { Context, Next } from "hono";
import { createRemoteJWKSet, jwtVerify, SignJWT } from "jose";
import { z } from "zod";
import { config } from "./config.ts";
import { q, tx } from "./db.ts";

const appleJWKS = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
const googleJWKS = createRemoteJWKSet(new URL("https://www.googleapis.com/oauth2/v3/certs"));

export type Claims = { sub: string; role: string; dev: string };

async function sha256(s: string) {
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(h)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Verifies an Apple or Google identity token and returns the provider subject and email. */
export async function verifyProvider(provider: "apple" | "google", idToken: string) {
  if (provider === "apple") {
    const { payload } = await jwtVerify(idToken, appleJWKS, {
      issuer: "https://appleid.apple.com",
      audience: config.appleAudiences,
    });
    return { subject: String(payload.sub), email: (payload.email as string | undefined) ?? null };
  }
  const { payload } = await jwtVerify(idToken, googleJWKS, {
    issuer: ["https://accounts.google.com", "accounts.google.com"],
    audience: config.googleAudiences,
  });
  return { subject: String(payload.sub), email: (payload.email as string | undefined) ?? null };
}

export async function issueTokens(userId: string, role: string, deviceId: string) {
  const access = await new SignJWT({ role, dev: deviceId })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(userId)
    .setIssuer(config.issuer)
    .setIssuedAt()
    .setExpirationTime(`${config.accessTtlSec}s`)
    .sign(config.jwtSecret);
  const refresh = crypto.randomUUID() + crypto.randomUUID();
  await q(
    `insert into sessions (user_id, device_id, refresh_hash, expires_at)
     values ($1, $2, $3, now() + make_interval(days => $4))`,
    [userId, deviceId, await sha256(refresh), config.refreshTtlDays],
  );
  return { accessToken: access, refreshToken: refresh, expiresIn: config.accessTtlSec };
}

export async function requireAuth(c: Context, next: Next) {
  const h = c.req.header("authorization") ?? "";
  if (!h.startsWith("Bearer ")) return c.json({ error: "unauthorized" }, 401);
  try {
    const { payload } = await jwtVerify(h.slice(7), config.jwtSecret, { issuer: config.issuer });
    c.set("claims", { sub: payload.sub!, role: String(payload.role), dev: String(payload.dev) } as Claims);
  } catch {
    return c.json({ error: "unauthorized" }, 401);
  }
  await next();
}

export async function requireAdmin(c: Context, next: Next) {
  const claims = c.get("claims") as Claims | undefined;
  if (claims?.role !== "admin") return c.json({ error: "forbidden" }, 403);
  await next();
}

const Device = z.object({
  deviceId: z.string().uuid(),
  platform: z.enum(["ios", "android", "web"]),
  model: z.string().max(80).optional(),
  appVersion: z.string().max(40).optional(),
});

export const authRoutes = new Hono()
  .post("/signin", async (c) => {
    const body = Device.extend({ provider: z.enum(["apple", "google"]), idToken: z.string().min(20) })
      .parse(await c.req.json());
    const { subject, email } = await verifyProvider(body.provider, body.idToken);
    const user = await tx(async (db) => {
      const found = await db.query(
        `select u.id, u.role from identities i join users u on u.id = i.user_id
         where i.provider = $1 and i.subject = $2 and u.deleted_at is null`,
        [body.provider, subject],
      );
      let row = found.rows[0];
      if (!row) {
        row = (await db.query(`insert into users (email) values ($1) returning id, role`, [email])).rows[0];
        await db.query(`insert into identities (user_id, provider, subject, email) values ($1,$2,$3,$4)`, [
          row.id, body.provider, subject, email,
        ]);
      }
      await db.query(
        `insert into devices (id, user_id, platform, model, app_version, last_seen_at)
         values ($1,$2,$3,$4,$5, now())
         on conflict (id) do update set user_id = excluded.user_id, platform = excluded.platform,
           model = excluded.model, app_version = excluded.app_version, last_seen_at = now()`,
        [body.deviceId, row.id, body.platform, body.model ?? null, body.appVersion ?? null],
      );
      return row as { id: string; role: string };
    });
    return c.json({ userId: user.id, ...(await issueTokens(user.id, user.role, body.deviceId)) });
  })
  .post("/refresh", async (c) => {
    const { refreshToken } = z.object({ refreshToken: z.string().min(20) }).parse(await c.req.json());
    const hash = await sha256(refreshToken);
    const rows = await q<{ user_id: string; device_id: string; role: string }>(
      `delete from sessions s using users u
       where s.refresh_hash = $1 and s.expires_at > now() and u.id = s.user_id and u.deleted_at is null
       returning s.user_id, s.device_id, u.role`,
      [hash],
    );
    if (!rows[0]) return c.json({ error: "invalid_refresh" }, 401);
    return c.json(await issueTokens(rows[0].user_id, rows[0].role, rows[0].device_id));
  })
  .post("/signout", requireAuth, async (c) => {
    const claims = c.get("claims") as Claims;
    await q(`delete from sessions where user_id = $1 and device_id = $2`, [claims.sub, claims.dev]);
    return c.json({ ok: true });
  });

/** Link a second provider (e.g. Google on Android) to the signed-in account so both platforms share it. */
export const linkRoute = new Hono().post("/", requireAuth, async (c) => {
  const claims = c.get("claims") as Claims;
  const body = z.object({ provider: z.enum(["apple", "google"]), idToken: z.string() }).parse(await c.req.json());
  const { subject, email } = await verifyProvider(body.provider, body.idToken);
  const taken = await q(`select user_id from identities where provider = $1 and subject = $2`, [body.provider, subject]);
  if (taken[0] && taken[0].user_id !== claims.sub) return c.json({ error: "identity_in_use" }, 409);
  await q(
    `insert into identities (user_id, provider, subject, email) values ($1,$2,$3,$4) on conflict do nothing`,
    [claims.sub, body.provider, subject, email],
  );
  return c.json({ ok: true });
});

declare module "hono" {
  interface ContextVariableMap {
    claims: Claims;
  }
}
