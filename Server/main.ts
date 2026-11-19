import { Hono } from "hono";
import { logger } from "hono/logger";
import { ZodError } from "zod";
import { adminRoutes } from "./src/admin.ts";
import { authRoutes, linkRoute } from "./src/auth.ts";
import { config } from "./src/config.ts";
import { q } from "./src/db.ts";
import { meRoutes } from "./src/me.ts";
import { storeRoutes } from "./src/storekit.ts";
import { syncRoutes } from "./src/sync.ts";

export const app = new Hono();
app.use(logger());
app.onError((err, c) => {
  if (err instanceof ZodError) return c.json({ error: "invalid_request", issues: err.issues }, 400);
  console.error(err);
  return c.json({ error: "internal" }, 500);
});

app.get("/health", async (c) => {
  const db = await q(`select 1 as ok`).then(() => true).catch(() => false);
  return c.json({ service: "mytinyjungle-api", release: config.release, db }, db ? 200 : 503);
});
app.route("/v1/auth", authRoutes);
app.route("/v1/auth/link", linkRoute);
app.route("/v1/me", meRoutes);
app.route("/v1/sync", syncRoutes);
app.route("/v1/admin", adminRoutes);
app.route("/", storeRoutes);
app.get("/admin", async (c) => c.html(await Deno.readTextFile(new URL("./admin/index.html", import.meta.url))));

if (import.meta.main) {
  Deno.serve({ hostname: config.host, port: config.port }, app.fetch);
}
