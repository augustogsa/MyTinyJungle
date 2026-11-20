-- Server-tuned brain config (thresholds, timeouts, scan plan, copy, flags, cards, experiments): one row, edited
-- from the admin dashboard, served at GET /v1/brain/config. No build needed to change how the app's brain behaves.
create table brain_config (
  id int primary key default 1 check (id = 1),
  body jsonb not null default '{}',
  updated_at timestamptz not null default now()
);
insert into brain_config (id) values (1);
grant select on brain_config to mtj_auth;
grant select, update on brain_config to mtj_admin;

-- One row per identify / diagnose / ask answer and per species pick. No user ids, no photos, no question text:
-- species, a coarse slice (photo kinds, top answer id), the experiment variant, confidence and outcome only.
create table brain_outcomes (
  id bigserial primary key,
  day date not null default current_date,
  kind text not null check (kind in ('identify', 'diagnose', 'ask', 'pick')),
  species text not null default '',
  slice text not null default '',
  variant text not null default '',
  conf real,
  outcome text not null,
  lang text not null default '',
  ms int,
  created_at timestamptz not null default now()
);
create index brain_outcomes_day on brain_outcomes (day, kind);
grant select, insert, delete on brain_outcomes to mtj_auth;
grant usage on sequence brain_outcomes_id_seq to mtj_auth;
grant select on brain_outcomes to mtj_admin;
