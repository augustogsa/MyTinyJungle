const env = (k: string, d?: string) => {
  const v = Deno.env.get(k) ?? d;
  if (v === undefined) throw new Error(`missing env ${k}`);
  return v;
};

export const config = {
  host: env("MTJ_HOST", "127.0.0.1"),
  port: Number(env("MTJ_PORT", "3300")),
  databaseUrl: env("DATABASE_URL", "postgres://mtj_app@127.0.0.1:5432/mytinyjungle"),
  jwtSecret: new TextEncoder().encode(env("MTJ_JWT_SECRET", "dev-only-secret-change-me-dev-only-secret")),
  issuer: "https://api.mytinyjungle.com",
  accessTtlSec: 60 * 60,
  refreshTtlDays: 90,
  appleAudiences: env("MTJ_APPLE_AUDIENCES", "com.simpleappscompany.mytinyjungle").split(","),
  googleAudiences: env("MTJ_GOOGLE_AUDIENCES", "").split(",").filter(Boolean),
  release: env("MTJ_RELEASE", "dev"),
};
