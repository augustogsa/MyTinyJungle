-- Weekly jungle digest: per-device opt-out (default on) and the last send.
alter table devices add column digest_on boolean not null default true, add column digest_sent_at timestamptz, add column digest_lang text;

-- Daily quotas on the brain endpoints, per user (u:<id>) and per device (d:<id>). Only counts, no content.
create table api_quota (
  day date not null default current_date,
  subject text not null,
  kind text not null,
  n int not null default 0,
  primary key (day, subject, kind)
);
grant select, insert, update, delete on api_quota to mtj_auth;
grant select on api_quota to mtj_admin;

-- Paid model calls per month (Gemini, Claude) for the spend guard (MTJ_AI_MONTHLY_CAP).
create table ai_spend (
  month date not null,
  provider text not null,
  n int not null default 0,
  blocked int not null default 0,
  primary key (month, provider)
);
grant select, insert, update on ai_spend to mtj_auth;
grant select on ai_spend to mtj_admin;
