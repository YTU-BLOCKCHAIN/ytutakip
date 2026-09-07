-- YK Takip veritabanı şeması
-- Supabase projende: sol menü "SQL Editor" -> "New query" -> bunu yapıştır -> Run

create table if not exists members (
  email text primary key,
  team text check (team in ('etkinlik','onboarding','sponsorluk','developer') or team is null),
  role text not null check (role in ('admin','lead'))
);

create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  team text not null check (team in ('etkinlik','onboarding','sponsorluk','developer')),
  title text not null,
  description text default '',
  assignee text default '',
  status text not null default 'will' check (status in ('will','progress','done')),
  created_by text,
  updated_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table members enable row level security;
alter table tasks enable row level security;

-- giriş yapan kişi admin mi?
create or replace function is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists(
    select 1 from members m
    where m.email = auth.jwt() ->> 'email' and m.role = 'admin'
  );
$$;

-- giriş yapan kişinin ekibi
create or replace function my_team()
returns text
language sql
security definer
set search_path = public
stable
as $$
  select team from members where email = auth.jwt() ->> 'email' limit 1;
$$;

drop policy if exists "members_select" on members;
create policy "members_select" on members for select
  using (email = auth.jwt() ->> 'email' or is_admin());

drop policy if exists "members_insert" on members;
create policy "members_insert" on members for insert
  with check (is_admin());

drop policy if exists "members_update" on members;
create policy "members_update" on members for update
  using (is_admin()) with check (is_admin());

drop policy if exists "members_delete" on members;
create policy "members_delete" on members for delete
  using (is_admin());

drop policy if exists "tasks_select" on tasks;
create policy "tasks_select" on tasks for select
  using (is_admin() or team = my_team());

drop policy if exists "tasks_insert" on tasks;
create policy "tasks_insert" on tasks for insert
  with check (is_admin() or team = my_team());

drop policy if exists "tasks_update" on tasks;
create policy "tasks_update" on tasks for update
  using (is_admin() or team = my_team())
  with check (is_admin() or team = my_team());

drop policy if exists "tasks_delete" on tasks;
create policy "tasks_delete" on tasks for delete
  using (is_admin() or team = my_team());

-- canlı güncellemeler için (birisi görev eklediğinde diğerleri anında görsün)
alter publication supabase_realtime add table tasks;

-- ekip üyeleri (verdiğin mail listesi)
insert into members (email, team, role) values
  ('REDACTED_EMAIL', null, 'admin'),
  ('REDACTED_EMAIL', 'onboarding', 'lead'),
  ('REDACTED_EMAIL', 'sponsorluk', 'lead'),
  ('REDACTED_EMAIL', 'etkinlik', 'lead'),
  ('REDACTED_EMAIL', 'developer', 'lead')
on conflict (email) do update set team = excluded.team, role = excluded.role;
