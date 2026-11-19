-- Multi-day weather patterns: one push per device per pattern per ISO week (week = Monday).
create table weather_pattern_sent (
  device_id uuid not null references devices(id) on delete cascade,
  pattern text not null,
  week date not null,
  sent_at timestamptz not null default now(),
  primary key (device_id, pattern, week)
);
grant select, insert, delete on weather_pattern_sent to mtj_auth;
grant select on weather_pattern_sent to mtj_admin;

-- Households: people who care for one jungle's plants together. Owners manage; carers water.
create table households (
  id uuid primary key default gen_random_uuid(),
  jungle_id uuid not null unique references jungles(id) on delete cascade,
  owner_id uuid not null references users(id) on delete cascade,
  name text not null default '',
  created_at timestamptz not null default now()
);
create table household_members (
  household_id uuid not null references households(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  role text not null check (role in ('owner', 'carer')),
  joined_at timestamptz not null default now(),
  primary key (household_id, user_id)
);
create index on household_members (user_id);
create table household_invites (
  code text primary key,
  household_id uuid not null references households(id) on delete cascade,
  role text not null default 'carer' check (role in ('owner', 'carer')),
  created_by uuid not null references users(id) on delete cascade,
  expires_at timestamptz not null,
  used_by uuid references users(id) on delete set null
);
create table household_assignments (
  household_id uuid not null references households(id) on delete cascade,
  plant_id uuid not null,
  user_id uuid not null references users(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  primary key (household_id, plant_id)
);

create function mtj_my_households() returns setof uuid language sql stable security definer set search_path = public as
  $$ select household_id from household_members where user_id = mtj_uid() $$;
create function mtj_household_owner(h uuid) returns boolean language sql stable security definer set search_path = public as
  $$ select exists (select 1 from households where id = h and owner_id = mtj_uid())
         or exists (select 1 from household_members where household_id = h and user_id = mtj_uid() and role = 'owner') $$;

-- Join a household by code. Also joins its jungle (member) so the plants sync to the new carer.
create function mtj_redeem_household_invite(p_code text) returns uuid language plpgsql security definer set search_path = public as $$
declare inv household_invites; j uuid;
begin
  select * into inv from household_invites where code = p_code and used_by is null and expires_at > now() for update;
  if not found then raise exception 'invite_invalid' using errcode = 'P0001'; end if;
  insert into household_members (household_id, user_id, role) values (inv.household_id, mtj_uid(), inv.role)
    on conflict (household_id, user_id) do update set role = excluded.role;
  select jungle_id into j from households where id = inv.household_id;
  insert into jungle_members (jungle_id, user_id, role) values (j, mtj_uid(), 'member')
    on conflict (jungle_id, user_id) do update set until = null where jungle_members.role <> 'owner';
  update household_invites set used_by = mtj_uid() where code = p_code;
  return inv.household_id;
end $$;

create function mtj_household_members(h uuid) returns table (user_id uuid, display_name text, role text, joined_at timestamptz)
  language sql stable security definer set search_path = public as
  $$ select m.user_id, u.display_name, m.role, m.joined_at from household_members m join users u on u.id = m.user_id
     where m.household_id = h and h in (select mtj_my_households()) order by m.joined_at $$;

-- Remove a member (an owner removing someone, or anyone leaving): membership, assignments and the jungle seat.
create function mtj_household_drop(h uuid, u uuid) returns boolean language plpgsql security definer set search_path = public as $$
declare j uuid; creator uuid;
begin
  select jungle_id, owner_id into j, creator from households where id = h;
  if not found or u = creator or not (u = mtj_uid() or mtj_household_owner(h)) or h not in (select mtj_my_households()) then return false; end if;
  delete from household_assignments where household_id = h and user_id = u;
  delete from household_members where household_id = h and user_id = u;
  if not found then return false; end if;
  delete from jungle_members where jungle_id = j and user_id = u and role <> 'owner';
  return true;
end $$;

alter table households enable row level security;
alter table household_members enable row level security;
alter table household_invites enable row level security;
alter table household_assignments enable row level security;
create policy reach on households for select to mtj_app using (id in (select mtj_my_households()) or owner_id = mtj_uid());
create policy own on households for insert to mtj_app with check (owner_id = mtj_uid() and mtj_owns_jungle(jungle_id));
create policy own_upd on households for update to mtj_app using (mtj_household_owner(id)) with check (mtj_household_owner(id));
create policy own_del on households for delete to mtj_app using (owner_id = mtj_uid());
create policy reach on household_members for select to mtj_app using (household_id in (select mtj_my_households()));
create policy owner_manage on household_members for all to mtj_app
  using (mtj_household_owner(household_id) or user_id = mtj_uid())
  with check (mtj_household_owner(household_id));
create policy owner_manage on household_invites for all to mtj_app using (mtj_household_owner(household_id)) with check (mtj_household_owner(household_id));
create policy reach on household_assignments for select to mtj_app using (household_id in (select mtj_my_households()));
create policy owner_manage on household_assignments for all to mtj_app using (mtj_household_owner(household_id)) with check (mtj_household_owner(household_id));
grant select, insert, update, delete on households, household_members, household_invites, household_assignments to mtj_app;
grant execute on function mtj_my_households(), mtj_household_owner(uuid), mtj_redeem_household_invite(text), mtj_household_members(uuid), mtj_household_drop(uuid, uuid) to mtj_app;
revoke execute on function mtj_household_drop(uuid, uuid) from public;
revoke execute on function mtj_redeem_household_invite(text) from public;
revoke execute on function mtj_household_members(uuid) from public;

-- Plant passport: a public care card behind an unguessable token. Species and care only, no names or people.
create table plant_passports (
  token text primary key,
  user_id uuid not null references users(id) on delete cascade,
  plant_id uuid not null,
  card jsonb not null,
  views bigint not null default 0,
  imports bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, plant_id)
);
alter table plant_passports enable row level security;
create policy self on plant_passports for all to mtj_app using (user_id = mtj_uid()) with check (user_id = mtj_uid());
create policy auth_all on plant_passports for all to mtj_auth using (true) with check (true);
grant select, insert, update, delete on plant_passports to mtj_app;
grant select, update on plant_passports to mtj_auth;

-- Supplies the owner keeps (soil, fertiliser, pots...), with a low-stock reminder.
create table supplies (
  id uuid primary key,
  user_id uuid not null references users(id) on delete cascade,
  kind text not null check (kind in ('soil', 'fertiliser', 'pot', 'pesticide', 'other')),
  name text not null,
  qty numeric not null default 0,
  unit text not null default '',
  low_at numeric,
  updated_at timestamptz not null default now(),
  low_notified_at timestamptz
);
create index on supplies (user_id);
alter table supplies enable row level security;
create policy self on supplies for all to mtj_app using (user_id = mtj_uid()) with check (user_id = mtj_uid());
create policy auth_all on supplies for all to mtj_auth using (true) with check (true);
grant select, insert, update, delete on supplies to mtj_app;
grant select, update on supplies to mtj_auth;

-- Identify feedback: daily counts only (confirmed = owner kept our top guess, corrected = picked another).
create table identify_feedback (
  day date not null default current_date,
  outcome text not null check (outcome in ('confirmed', 'corrected', 'rejected')),
  n bigint not null default 0,
  primary key (day, outcome)
);
grant select, insert, update on identify_feedback to mtj_auth;

grant select on all tables in schema public to mtj_admin;
