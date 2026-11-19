-- Data export reads the caller's own sign-in providers.
create policy self_read on identities for select to mtj_app using (user_id = mtj_uid());
