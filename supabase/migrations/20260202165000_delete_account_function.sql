-- Delete account cleanup function for Edge Function.

create or replace function public.delete_user_data(p_user_id uuid) returns void
language plpgsql
security definer
set search_path = public, storage
set row_security = off
as $$
begin
  delete from storage.objects
  where bucket_id = 'project_uploads'
    and (storage.foldername(name))[1] = p_user_id::text;

  if to_regclass('public.analytics_events') is not null then
    execute 'delete from public.analytics_events where user_id = $1'
    using p_user_id;
  end if;

  if to_regclass('public.push_tokens') is not null then
    execute 'delete from public.push_tokens where user_id = $1'
    using p_user_id;
  end if;

  if to_regclass('public.stripe_customers') is not null then
    execute 'delete from public.stripe_customers where user_id = $1'
    using p_user_id;
  end if;

  if to_regclass('public.project_measurements') is not null then
    execute 'delete from public.project_measurements where user_id = $1'
    using p_user_id;
  end if;

  if to_regclass('public.project_items') is not null then
    execute 'delete from public.project_items where user_id = $1'
    using p_user_id;
  end if;

  if to_regclass('public.projects') is not null then
    execute 'delete from public.projects where user_id = $1'
    using p_user_id;
  end if;

  if to_regclass('public.user_subscriptions') is not null then
    execute 'delete from public.user_subscriptions where user_id = $1'
    using p_user_id;
  end if;

  if to_regclass('public.user_entitlements') is not null then
    execute 'delete from public.user_entitlements where user_id = $1'
    using p_user_id;
  end if;

  if to_regclass('public.user_consents') is not null then
    execute 'delete from public.user_consents where user_id = $1'
    using p_user_id;
  end if;

  if to_regclass('public.profiles') is not null then
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'user_id'
    ) then
      execute 'delete from public.profiles where id = $1 or user_id = $1'
      using p_user_id;
    else
      execute 'delete from public.profiles where id = $1'
      using p_user_id;
    end if;
  end if;
end;
$$;

revoke all on function public.delete_user_data(uuid) from public;
grant execute on function public.delete_user_data(uuid) to service_role;
