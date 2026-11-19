-- My Tiny Jungle core schema. Own auth, own roles; no Supabase-style anon/authenticated layer (MDM lesson 107).
create extension if not exists pgcrypto;

create table users (
  id uuid primary key default gen_random_uuid(),
  email text,
  display_name text,
  role text not null default 'user' check (role in ('user', 'admin')),
  locale text,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table identities (
  user_id uuid not null references users(id) on delete cascade,
  provider text not null check (provider in ('apple', 'google', 'email')),
  subject text not null,
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

create table sessions (
  refresh_hash text primary key,
  user_id uuid not null references users(id) on delete cascade,
  device_id uuid not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index on sessions (user_id);

-- A jungle is a sync scope: a personal jungle per user, or a shared one (household / plant sitter).
create table jungles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references users(id) on delete cascade,
  name text not null default '',
  is_personal boolean not null default true,
  created_at timestamptz not null default now()
);

create table jungle_members (
  jungle_id uuid not null references jungles(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member', 'sitter')),
  until timestamptz,                   -- plant sitters step back on their own
  joined_at timestamptz not null default now(),
  primary key (jungle_id, user_id)
);
create index on jungle_members (user_id);

create table invites (
  code text primary key,
  jungle_id uuid not null references jungles(id) on delete cascade,
  role text not null default 'member',
  until timestamptz,
  created_by uuid not null references users(id),
  expires_at timestamptz not null,
  used_by uuid references users(id)
);

-- Generic synced records (Plant, CareEvent, ChatMessage, OwnedProduct, Space, CareTask...).
-- version comes from one global sequence so a single cursor pulls every change after it.
create sequence record_version_seq;
create table records (
  jungle_id uuid not null references jungles(id) on delete cascade,
  entity text not null,
  id uuid not null,
  data jsonb not null,
  deleted boolean not null default false,
  version bigint not null default nextval('record_version_seq'),
  updated_by uuid references users(id),
  updated_device uuid,
  client_updated_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (jungle_id, entity, id)
);
create index on records (jungle_id, version);

-- Photos and other blobs live in object storage; records point at them by key.
create table media (
  key text primary key,
  jungle_id uuid not null references jungles(id) on delete cascade,
  content_type text not null,
  bytes bigint not null,
  created_by uuid references users(id),
  created_at timestamptz not null default now()
);

-- Entitlements from App Store and Google Play, unified per user (Plus works on every device).
create table entitlements (
  user_id uuid references users(id) on delete cascade,
  store text not null check (store in ('app_store', 'play')),
  product_id text not null,
  original_transaction_id text not null,
  expires_at timestamptz,
  status text not null,
  raw jsonb,
  updated_at timestamptz not null default now(),
  primary key (store, original_transaction_id)
);
create index on entitlements (user_id);

create table store_notifications (
  id bigserial primary key,
  store text not null,
  received_at timestamptz not null default now(),
  payload jsonb not null,
  processed_at timestamptz
);

create table audit_log (
  id bigserial primary key,
  actor uuid,
  action text not null,
  target text,
  detail jsonb,
  at timestamptz not null default now()
);
