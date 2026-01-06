-- Sperrt sensitive Shopify/Order-Tabellen für App-Zugriff (nur Server/Service-Role).
-- Ergebnis: ANON/AUTH haben keinen Zugriff mehr.
-- Hinweis: Der Service-Role Key umgeht RLS und bleibt für serverseitige Shopify-Integrationen nutzbar.
-- Wichtig: Den Service-Role Key niemals in die App einbauen.

alter table public.purchases enable row level security;
alter table public.shopify_customer_map enable row level security;
alter table public.shopify_order_events enable row level security;
alter table public.shopify_order_line_items enable row level security;
alter table public.users_app enable row level security;

revoke all on table public.purchases from anon, authenticated;
revoke all on table public.shopify_customer_map from anon, authenticated;
revoke all on table public.shopify_order_events from anon, authenticated;
revoke all on table public.shopify_order_line_items from anon, authenticated;
revoke all on table public.users_app from anon, authenticated;

-- Optional: Prüfen, ob bereits Policies existieren (falls ja, bitte im Dashboard löschen):
-- select * from pg_policies
-- where schemaname = 'public'
--   and tablename in (
--     'purchases',
--     'shopify_customer_map',
--     'shopify_order_events',
--     'shopify_order_line_items',
--     'users_app'
--   );
