-- My Tiny Jungle schema v1 (Go server). Three login roles, least privilege:
--   mtj_owner  owns everything, runs migrations only
--   mtj_auth   sign-in, sessions, store intake; no access to jungle data
--   mtj_app    signed-in requests; row-level security keyed on mtj.uid
--   mtj_admin  dashboard reads; BYPASSRLS, read-only except audit_log
create extension if not exists pgcrypto;

create function mtj_uid() returns uuid language sql stable as
  $$ select nullif(current_setting('mtj.uid', true), '')::uuid $$;

create table users (
  id uuid primary key default gen_random_uuid(),
  email text,
  display_name text,
  locale text,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table identities (
  provider text not null check (provider in ('apple', 'google')),
  subject text not null,
  user_id uuid not null references users(id) on delete cascade,
  email text,
  created_at timestamptz not null default now(),
  primary key (provider, subject)
);
create index on identities (user_id);

create table devices (
  id uuid primary key,
  user_id uuid not null references users(id) on delete cascade,
  platform text not null check (platform in ('ios', 'android', 'web')),
  model text,
  app_version text,
  push_token text,
  last_seen_at timestamptz not null default now()
);
create index on devices (user_id);

-- Refresh tokens rotate on every use. A family is one sign-in on one device; presenting an already
-- used token means it was stolen, so every session of that user is revoked.
create table sessions (
  token_hash bytea primary key,
  family_id uuid not null,
  user_id uuid not null references users(id) on delete cascade,
  device_id uuid not null,
  used_at timestamptz,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index on sessions (user_id);
create index on sessions (family_id);

create table jungles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references users(id) on delete cascade,
  name text not null default '',
  is_personal boolean not null default false,
  created_at timestamptz not null default now()
);
create unique index jungles_one_personal on jungles (owner_id) where is_personal;

create table jungle_members (
  jungle_id uuid not null references jungles(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member', 'sitter')),
  until timestamptz,
  joined_at timestamptz not null default now(),
  primary key (jungle_id, user_id)
);
create index on jungle_members (user_id);

create table invites (
  code text primary key,
  jungle_id uuid not null references jungles(id) on delete cascade,
  role text not null default 'member' check (role in ('member', 'sitter')),
  until timestamptz,
  created_by uuid not null references users(id) on delete cascade,
  expires_at timestamptz not null,
  used_by uuid references users(id) on delete set null
);

create sequence record_version_seq;
create table records (
  jungle_id uuid not null references jungles(id) on delete cascade,
  entity text not null,
  id uuid not null,
  data jsonb not null,
  deleted boolean not null default false,
  version bigint not null default nextval('record_version_seq'),
  updated_by uuid references users(id) on delete set null,
  updated_device uuid,
  client_updated_at timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (jungle_id, entity, id)
);
create index on records (jungle_id, version);

create table media (
  jungle_id uuid not null references jungles(id) on delete cascade,
  id uuid not null,
  content_type text not null,
  bytes bigint not null,
  created_by uuid references users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (jungle_id, id)
);

create table entitlements (
  store text not null check (store in ('app_store', 'play')),
  original_transaction_id text not null,
  user_id uuid references users(id) on delete cascade,
  product_id text not null,
  expires_at timestamptz,
  status text not null check (status in ('active', 'expired', 'revoked', 'grace')),
  environment text,
  updated_at timestamptz not null default now(),
  primary key (store, original_transaction_id)
);
create index on entitlements (user_id);

create table store_notifications (
  id bigserial primary key,
  store text not null,
  notification_type text,
  verified boolean not null,
  received_at timestamptz not null default now(),
  payload jsonb not null
);

create table audit_log (
  id bigserial primary key,
  actor text,
  action text not null,
  target text,
  detail jsonb,
  at timestamptz not null default now()
);

-- Jungles the current user can reach right now (sitters drop out after `until`). Security definer so
-- policies on jungle_members can use it without recursing into themselves.
create function mtj_my_jungles() returns setof uuid language sql stable security definer set search_path = public as
  $$ select jungle_id from jungle_members where user_id = mtj_uid() and (until is null or until > now()) $$;

create function mtj_owns_jungle(j uuid) returns boolean language sql stable security definer set search_path = public as
  $$ select exists (select 1 from jungles where id = j and owner_id = mtj_uid()) $$;

-- Redeem an invite as the current user. Security definer: the joiner is not yet a member.
create function mtj_redeem_invite(p_code text) returns uuid language plpgsql security definer set search_path = public as $$
declare inv invites;
begin
  select * into inv from invites where code = p_code and used_by is null and expires_at > now() for update;
  if not found then raise exception 'invite_invalid' using errcode = 'P0001'; end if;
  insert into jungle_members (jungle_id, user_id, role, until) values (inv.jungle_id, mtj_uid(), inv.role, inv.until)
    on conflict (jungle_id, user_id) do update set role = excluded.role, until = excluded.until;
  update invites set used_by = mtj_uid() where code = p_code;
  return inv.jungle_id;
end $$;

-- Co-members see each other's display name only (never email).
create function mtj_jungle_members(j uuid) returns table (user_id uuid, display_name text, role text, until timestamptz)
  language sql stable security definer set search_path = public as
  $$ select m.user_id, u.display_name, m.role, m.until from jungle_members m join users u on u.id = m.user_id
     where m.jungle_id = j and j in (select mtj_my_jungles()) order by m.joined_at $$;

alter table users enable row level security;
alter table devices enable row level security;
alter table jungles enable row level security;
alter table jungle_members enable row level security;
alter table invites enable row level security;
alter table records enable row level security;
alter table media enable row level security;
alter table entitlements enable row level security;

create policy self on users for all to mtj_app using (id = mtj_uid()) with check (id = mtj_uid());
create policy self on devices for all to mtj_app using (user_id = mtj_uid()) with check (user_id = mtj_uid());
create policy self on entitlements for select to mtj_app using (user_id = mtj_uid());
create policy reach on jungles for select to mtj_app using (id in (select mtj_my_jungles()) or owner_id = mtj_uid());
create policy own on jungles for insert to mtj_app with check (owner_id = mtj_uid());
create policy own_upd on jungles for update to mtj_app using (owner_id = mtj_uid()) with check (owner_id = mtj_uid());
create policy own_del on jungles for delete to mtj_app using (owner_id = mtj_uid() and not is_personal);
create policy reach on jungle_members for select to mtj_app using (jungle_id in (select mtj_my_jungles()));
create policy owner_manage on jungle_members for all to mtj_app
  using (mtj_owns_jungle(jungle_id) or user_id = mtj_uid())          -- owner manages, anyone can leave
  with check (mtj_owns_jungle(jungle_id));
create policy owner_manage on invites for all to mtj_app using (mtj_owns_jungle(jungle_id)) with check (mtj_owns_jungle(jungle_id));
create policy reach on records for all to mtj_app
  using (jungle_id in (select mtj_my_jungles())) with check (jungle_id in (select mtj_my_jungles()));
create policy reach on media for all to mtj_app
  using (jungle_id in (select mtj_my_jungles())) with check (jungle_id in (select mtj_my_jungles()));

grant usage on schema public to mtj_auth, mtj_app, mtj_admin;
revoke create on schema public from public;

grant select, insert, update on users to mtj_auth;
grant select, insert, delete on identities to mtj_auth;
grant select, insert, update on devices to mtj_auth;
grant select, insert, update, delete on sessions to mtj_auth;
grant select, insert, update on entitlements to mtj_auth;
grant select, insert on store_notifications to mtj_auth;
grant usage on sequence store_notifications_id_seq to mtj_auth;
grant insert on audit_log to mtj_auth, mtj_app, mtj_admin;
grant usage on sequence audit_log_id_seq to mtj_auth, mtj_app, mtj_admin;

grant select, update on users to mtj_app;
grant select, update on devices to mtj_app;
grant select on entitlements, identities to mtj_app;
grant select, insert, update, delete on jungles, jungle_members, invites, records, media to mtj_app;
grant usage on sequence record_version_seq to mtj_app;
grant execute on function mtj_uid(), mtj_my_jungles(), mtj_owns_jungle(uuid), mtj_redeem_invite(text), mtj_jungle_members(uuid) to mtj_app;
revoke execute on function mtj_jungle_members(uuid) from public;
revoke execute on function mtj_redeem_invite(text) from public;

grant select on all tables in schema public to mtj_admin;
