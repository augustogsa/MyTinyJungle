-- Crash and hang reports from the apps (MetricKit on iOS, ApplicationExitInfo on Android). No user id:
-- only platform, versions and the system's own diagnostic payload. Kept 90 days (purge).
create table diagnostics (
  id bigserial primary key,
  platform text not null check (platform in ('ios', 'android')),
  app_version text not null,
  os_version text,
  kind text not null check (kind in ('crash', 'hang', 'cpu', 'disk', 'launch', 'other')),
  payload jsonb not null,
  created_at timestamptz not null default now()
);
create index on diagnostics (created_at);
grant insert on diagnostics to mtj_app;
grant usage on sequence diagnostics_id_seq to mtj_app;
grant select on diagnostics to mtj_admin;
