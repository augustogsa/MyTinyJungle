-- The sign-in role works across accounts by design (find identity → user, register devices, map store
-- purchases), so it gets explicit full policies on the RLS tables it touches. It has no grants on jungle data.
create policy auth_all on users for all to mtj_auth using (true) with check (true);
create policy auth_all on devices for all to mtj_auth using (true) with check (true);
create policy auth_all on entitlements for all to mtj_auth using (true) with check (true);
