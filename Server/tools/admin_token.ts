// Mints a 12h admin access token for the dashboard: deno task admin-token <email>
import { SignJWT } from "jose";
import { config } from "../src/config.ts";
import { pool } from "../src/db.ts";

const email = Deno.args[0];
const r = await pool.query(`select id from users where email = $1 and role = 'admin' and deleted_at is null`, [email]);
await pool.end();
if (!r.rows[0]) throw new Error(`no admin user ${email}`);
console.log(
  await new SignJWT({ role: "admin", dev: "00000000-0000-0000-0000-000000000000" }).setProtectedHeader({ alg: "HS256" })
    .setSubject(r.rows[0].id).setIssuer(config.issuer).setIssuedAt().setExpirationTime("12h").sign(config.jwtSecret),
);
