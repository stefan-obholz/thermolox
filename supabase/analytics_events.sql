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

create policy "analytics_events_insert_anon"
  on public.analytics_events
  for insert
  to anon
  with check (user_id is null);

create policy "analytics_events_select_admin"
  on public.analytics_events
  for select
  to authenticated
  using (
    (auth.jwt() ->> 'is_admin') = 'true'
    or (auth.jwt() ->> 'role') = 'admin'
  );
