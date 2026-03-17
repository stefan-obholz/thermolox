-- Core tables and RLS policies for THERMOLOX.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text,
  last_name text,
  avatar_url text,
  street text,
  house_number text,
  postal_code text,
  city text,
  country text,
  locale text,
  terms_accepted_at timestamptz,
  privacy_accepted_at timestamptz,
  marketing_accepted_at timestamptz,
  terms_version text,
  privacy_version text,
  analytics_consent boolean,
  analytics_consent_at timestamptz,
  ai_consent boolean,
  ai_consent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table if exists public.profiles
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists avatar_url text,
  add column if not exists street text,
  add column if not exists house_number text,
  add column if not exists postal_code text,
  add column if not exists city text,
  add column if not exists country text,
  add column if not exists locale text,
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists privacy_accepted_at timestamptz,
  add column if not exists marketing_accepted_at timestamptz,
  add column if not exists terms_version text,
  add column if not exists privacy_version text,
  add column if not exists analytics_consent boolean,
  add column if not exists analytics_consent_at timestamptz,
  add column if not exists ai_consent boolean,
  add column if not exists ai_consent_at timestamptz,
  add column if not exists created_at timestamptz,
  add column if not exists updated_at timestamptz;

create table if not exists public.user_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  terms_accepted_at timestamptz,
  privacy_accepted_at timestamptz,
  marketing_accepted_at timestamptz,
  analytics_accepted_at timestamptz,
  ai_accepted_at timestamptz,
  terms_version text,
  privacy_version text,
  locale text,
  source text,
  created_at timestamptz not null default now()
);

alter table if exists public.user_consents
  add column if not exists user_id uuid,
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists privacy_accepted_at timestamptz,
  add column if not exists marketing_accepted_at timestamptz,
  add column if not exists analytics_accepted_at timestamptz,
  add column if not exists ai_accepted_at timestamptz,
  add column if not exists terms_version text,
  add column if not exists privacy_version text,
  add column if not exists locale text,
  add column if not exists source text,
  add column if not exists created_at timestamptz;

create index if not exists user_consents_user_id_idx
  on public.user_consents(user_id);

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  event_name text not null,
  source text,
  session_id uuid,
  utm_source text,
  utm_medium text,
  utm_campaign text,
  utm_content text,
  utm_term text,
  referrer text,
  app_version text,
  build_number text,
  device_os text,
  device_model text,
  locale text,
  timezone text,
  payload jsonb,
  created_at timestamptz not null default now()
);

create index if not exists analytics_events_user_id_idx
  on public.analytics_events(user_id);

create index if not exists analytics_events_event_name_idx
  on public.analytics_events(event_name);

create index if not exists analytics_events_created_at_idx
  on public.analytics_events(created_at);

alter table public.analytics_events enable row level security;

drop policy if exists "analytics_events_insert_anon" on public.analytics_events;
drop policy if exists "analytics_events_insert_own" on public.analytics_events;
drop policy if exists "analytics_events_select_own" on public.analytics_events;
drop policy if exists "analytics_events_select_admin" on public.analytics_events;

create policy "analytics_events_insert_own"
  on public.analytics_events
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "analytics_events_select_own"
  on public.analytics_events
  for select
  to authenticated
  using (user_id = auth.uid());

create policy "analytics_events_select_admin"
  on public.analytics_events
  for select
  to authenticated
  using (
    (auth.jwt() ->> 'is_admin') = 'true'
    or (auth.jwt() ->> 'role') = 'admin'
  );

create or replace function public.purge_analytics_events() returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  delete from public.analytics_events
  where created_at < now() - interval '180 days';
end;
$$;

revoke all on function public.purge_analytics_events() from public;
grant execute on function public.purge_analytics_events() to service_role;

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists projects_user_id_idx
  on public.projects(user_id);

create table if not exists public.project_items (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null,
  name text not null,
  storage_path text,
  url text,
  color_hex text,
  created_at timestamptz not null default now()
);

create index if not exists project_items_project_id_idx
  on public.project_items(project_id);

create index if not exists project_items_user_id_idx
  on public.project_items(user_id);

create table if not exists public.project_measurements (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  method text not null default 'manual',
  length_m numeric,
  width_m numeric,
  height_m numeric,
  openings jsonb,
  confidence numeric,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists project_measurements_project_id_idx
  on public.project_measurements(project_id);

create index if not exists project_measurements_user_id_idx
  on public.project_measurements(user_id);

alter table public.projects enable row level security;
alter table public.project_items enable row level security;
alter table public.project_measurements enable row level security;

drop policy if exists "projects_select_own" on public.projects;
drop policy if exists "projects_insert_own" on public.projects;
drop policy if exists "projects_update_own" on public.projects;
drop policy if exists "projects_delete_own" on public.projects;

create policy "projects_select_own"
  on public.projects
  for select
  to authenticated
  using (user_id = auth.uid());

create policy "projects_insert_own"
  on public.projects
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "projects_update_own"
  on public.projects
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "projects_delete_own"
  on public.projects
  for delete
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "project_items_select_own" on public.project_items;
drop policy if exists "project_items_insert_own" on public.project_items;
drop policy if exists "project_items_update_own" on public.project_items;
drop policy if exists "project_items_delete_own" on public.project_items;

create policy "project_items_select_own"
  on public.project_items
  for select
  to authenticated
  using (user_id = auth.uid());

create policy "project_items_insert_own"
  on public.project_items
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "project_items_update_own"
  on public.project_items
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "project_items_delete_own"
  on public.project_items
  for delete
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "project_measurements_select_own"
  on public.project_measurements;
drop policy if exists "project_measurements_insert_own"
  on public.project_measurements;
drop policy if exists "project_measurements_update_own"
  on public.project_measurements;
drop policy if exists "project_measurements_delete_own"
  on public.project_measurements;

create policy "project_measurements_select_own"
  on public.project_measurements
  for select
  to authenticated
  using (user_id = auth.uid());

create policy "project_measurements_insert_own"
  on public.project_measurements
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "project_measurements_update_own"
  on public.project_measurements
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "project_measurements_delete_own"
  on public.project_measurements
  for delete
  to authenticated
  using (user_id = auth.uid());

insert into storage.buckets (id, name, public)
values ('project_uploads', 'project_uploads', false)
on conflict (id) do nothing;

drop policy if exists "project_uploads_read_own" on storage.objects;
drop policy if exists "project_uploads_insert_own" on storage.objects;
drop policy if exists "project_uploads_update_own" on storage.objects;
drop policy if exists "project_uploads_delete_own" on storage.objects;

create policy "project_uploads_read_own"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'project_uploads'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "project_uploads_insert_own"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'project_uploads'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "project_uploads_update_own"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'project_uploads'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'project_uploads'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "project_uploads_delete_own"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'project_uploads'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists push_tokens_token_uidx
  on public.push_tokens(token);

create index if not exists push_tokens_user_id_idx
  on public.push_tokens(user_id);

alter table public.push_tokens enable row level security;

drop policy if exists "push_tokens_select_own" on public.push_tokens;
drop policy if exists "push_tokens_insert_own" on public.push_tokens;
drop policy if exists "push_tokens_update_own" on public.push_tokens;
drop policy if exists "push_tokens_delete_own" on public.push_tokens;

create policy "push_tokens_select_own"
  on public.push_tokens
  for select
  to authenticated
  using (user_id = auth.uid());

create policy "push_tokens_insert_own"
  on public.push_tokens
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "push_tokens_update_own"
  on public.push_tokens
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "push_tokens_delete_own"
  on public.push_tokens
  for delete
  to authenticated
  using (user_id = auth.uid());

alter table if exists public.profiles enable row level security;
alter table if exists public.user_consents enable row level security;

do $$
declare
  has_id boolean;
  has_user_id boolean;
  profile_cond text;
begin
  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'id'
  ) into has_id;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'user_id'
  ) into has_user_id;

  if has_id and has_user_id then
    profile_cond := '(id = auth.uid() and (user_id is null or user_id = auth.uid()))';
  elsif has_id then
    profile_cond := 'id = auth.uid()';
  elsif has_user_id then
    profile_cond := 'user_id = auth.uid()';
  else
    raise notice 'profiles: no id/user_id column found, skipping policies';
  end if;

  if profile_cond is not null then
    if not exists (
      select 1 from pg_policies
      where schemaname = 'public'
        and tablename = 'profiles'
        and policyname = 'profiles_select_own'
    ) then
      execute format(
        'create policy "profiles_select_own" on public.profiles for select to authenticated using (%s)',
        profile_cond
      );
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public'
        and tablename = 'profiles'
        and policyname = 'profiles_insert_own'
    ) then
      execute format(
        'create policy "profiles_insert_own" on public.profiles for insert to authenticated with check (%s)',
        profile_cond
      );
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public'
        and tablename = 'profiles'
        and policyname = 'profiles_update_own'
    ) then
      execute format(
        'create policy "profiles_update_own" on public.profiles for update to authenticated using (%s) with check (%s)',
        profile_cond,
        profile_cond
      );
    end if;
  end if;
end $$;

do $$
declare
  has_user_id boolean;
  has_id boolean;
  consent_cond text;
begin
  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'user_consents'
      and column_name = 'user_id'
  ) into has_user_id;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'user_consents'
      and column_name = 'id'
  ) into has_id;

  if has_user_id then
    consent_cond := 'user_id = auth.uid()';
  elsif has_id then
    consent_cond := 'id = auth.uid()';
  else
    raise notice 'user_consents: no user_id/id column found, skipping policies';
  end if;

  if consent_cond is not null then
    if not exists (
      select 1 from pg_policies
      where schemaname = 'public'
        and tablename = 'user_consents'
        and policyname = 'user_consents_select_own'
    ) then
      execute format(
        'create policy "user_consents_select_own" on public.user_consents for select to authenticated using (%s)',
        consent_cond
      );
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public'
        and tablename = 'user_consents'
        and policyname = 'user_consents_insert_own'
    ) then
      execute format(
        'create policy "user_consents_insert_own" on public.user_consents for insert to authenticated with check (%s)',
        consent_cond
      );
    end if;
  end if;
end $$;
