-- Privacy-first analytics: daily counts per event name, platform and app version. No user, device,
-- IP or timestamp finer than a day is stored, so nothing can be tied back to a person.
create table event_counts (
  day date not null,
  name text not null,
  platform text not null,
  app_version text not null,
  n bigint not null default 0,
  primary key (day, name, platform, app_version)
);
grant select, insert, update on event_counts to mtj_auth;
grant select on event_counts to mtj_admin;
