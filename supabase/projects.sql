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

alter table public.projects enable row level security;
alter table public.project_items enable row level security;

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

insert into storage.buckets (id, name, public)
values ('project_uploads', 'project_uploads', false)
on conflict (id) do nothing;

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
