-- AI plant diagnosis (Plus): per-user daily usage for the cap. Photos are not stored.
create table ai_usage (
  user_id uuid not null references users(id) on delete cascade,
  day date not null default current_date,
  n int not null default 0,
  primary key (user_id, day)
);
alter table ai_usage enable row level security;
create policy self on ai_usage for all to mtj_app using (user_id = mtj_uid()) with check (user_id = mtj_uid());
grant select, insert, update on ai_usage to mtj_app;
grant select on ai_usage to mtj_admin;
