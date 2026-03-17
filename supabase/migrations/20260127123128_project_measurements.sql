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

alter table public.project_measurements enable row level security;

drop policy if exists project_measurements_select_own
  on public.project_measurements;

drop policy if exists project_measurements_insert_own
  on public.project_measurements;

drop policy if exists project_measurements_update_own
  on public.project_measurements;

drop policy if exists project_measurements_delete_own
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
