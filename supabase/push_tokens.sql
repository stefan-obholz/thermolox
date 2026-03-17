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
