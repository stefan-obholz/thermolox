-- Lock down Shopify-related tables for anon/auth access (service role only).

do $$
declare
  table_name text;
  tables text[] := array[
    'purchases',
    'shopify_customer_map',
    'shopify_order_events',
    'shopify_order_line_items',
    'users_app'
  ];
begin
  foreach table_name in array tables loop
    if to_regclass(format('public.%I', table_name)) is not null then
      execute format('alter table public.%I enable row level security', table_name);
      execute format('revoke all on table public.%I from anon, authenticated', table_name);
    end if;
  end loop;
end $$;
