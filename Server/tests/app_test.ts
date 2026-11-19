import { app } from "../main.ts";

Deno.test("protected routes need a token", async () => {
  for (const p of ["/v1/me", "/v1/sync/pull", "/v1/admin/stats"]) {
    const r = await app.request(p);
    if (r.status !== 401) throw new Error(`${p} -> ${r.status}`);
  }
});

Deno.test("signin validates body", async () => {
  const r = await app.request("/v1/auth/signin", { method: "POST", body: "{}", headers: { "content-type": "application/json" } });
  if (r.status !== 400) throw new Error(`got ${r.status}`);
});
