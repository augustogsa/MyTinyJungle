import { Hono } from "hono";
import { decodeJwt } from "jose";
import { q } from "./db.ts";

// App Store Server Notifications V2 land here (URL already set in ASC). Stored raw first, so nothing is lost;
// signature-chain verification + entitlement upsert is the next step (appAccountToken = our user id).
export const storeRoutes = new Hono()
  .post("/storekit/notifications", async (c) => {
    const body = await c.req.json<{ signedPayload?: string }>();
    if (!body.signedPayload) return c.json({ error: "bad_request" }, 400);
    const payload = decodeJwt(body.signedPayload);
    await q(`insert into store_notifications (store, payload) values ('app_store', $1)`, [payload]);
    return c.json({ ok: true });
  })
  .post("/play/rtdn", async (c) => {
    await q(`insert into store_notifications (store, payload) values ('play', $1)`, [await c.req.json()]);
    return c.json({ ok: true });
  });
