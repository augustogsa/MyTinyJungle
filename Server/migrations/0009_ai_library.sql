-- The brain's library: answers already given, keyed by species + top knowledge matches + language.
-- Text only. No photo, user or device is stored.
create table ai_library (
  sig text not null,
  lang text not null,
  answer jsonb not null,
  source text not null,
  hits bigint not null default 0,
  created_at timestamptz not null default now(),
  primary key (sig, lang)
);
grant select, insert, update on ai_library to mtj_auth;
grant select on ai_library to mtj_admin;
