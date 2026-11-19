-- Owner corrections of the brain: species picks, scene fields, whether answers and diagnoses helped. No photos
-- are stored here; photo_ref only names an upload the owner already shared to their jungle (jungle/media id),
-- which the nightly learning job may add to the plant ID reference index.
create table brain_feedback (
  id bigserial primary key,
  user_id uuid not null references users(id) on delete cascade,
  day date not null default current_date,
  kind text not null check (kind in ('species', 'scene_field', 'answer_helpful', 'diagnose_helpful')),
  predicted text not null default '',
  corrected text not null default '',
  photo_ref text,
  lang text not null default 'en',
  learned_at timestamptz,
  created_at timestamptz not null default now()
);
create index brain_feedback_day on brain_feedback (day, kind);
alter table brain_feedback enable row level security;
create policy self on brain_feedback for all to mtj_app using (user_id = mtj_uid()) with check (user_id = mtj_uid());
grant select, insert on brain_feedback to mtj_app;
grant usage on sequence brain_feedback_id_seq to mtj_app;
grant select, update on brain_feedback to mtj_auth;
grant select on brain_feedback to mtj_admin;
