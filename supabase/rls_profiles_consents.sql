-- RLS policies for profiles and user_consents (client access only to own rows).

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
