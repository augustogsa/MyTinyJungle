-- Where the brain falls short: daily counts of normalized keywords from questions and diagnoses it could not
-- answer well. Only knowledge words are kept (no free text, user or device), so the library grows where owners need it.
create table brain_gaps (
  day date not null default current_date,
  kind text not null,
  words text not null,
  n bigint not null default 0,
  primary key (day, kind, words)
);
grant select, insert, update on brain_gaps to mtj_auth;
grant select on brain_gaps to mtj_admin;
