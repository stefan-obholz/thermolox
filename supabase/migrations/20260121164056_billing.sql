create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  price_eur numeric,
  currency text not null default 'eur',
  stripe_product_id text,
  stripe_price_id text,
  stripe_lookup_key text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.plan_features (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id) on delete cascade,
  feature_key text not null,
  is_enabled boolean not null default true,
  monthly_limit int,
  created_at timestamptz not null default now()
);

create unique index if not exists plan_features_plan_key_uidx
  on public.plan_features(plan_id, feature_key);

create table if not exists public.user_subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan_id uuid references public.plans(id) on delete set null,
  status text not null default 'inactive',
  stripe_customer_id text,
  stripe_subscription_id text,
  stripe_price_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_entitlements (
  user_id uuid primary key references auth.users(id) on delete cascade,
  pro_lifetime boolean not null default false,
  credits_balance int not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.stripe_customers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  customer_id text not null unique,
  created_at timestamptz not null default now()
);

create unique index if not exists stripe_customers_user_uidx
  on public.stripe_customers(user_id);

create table if not exists public.stripe_webhook_events (
  id uuid primary key default gen_random_uuid(),
  event_id text not null unique,
  event_type text,
  processed_at timestamptz not null default now()
);

alter table public.plans enable row level security;
alter table public.plan_features enable row level security;
alter table public.user_subscriptions enable row level security;
alter table public.user_entitlements enable row level security;
alter table public.stripe_customers enable row level security;
alter table public.stripe_webhook_events enable row level security;

create policy "plans_select_all"
  on public.plans
  for select
  to anon, authenticated
  using (true);

create policy "plan_features_select_all"
  on public.plan_features
  for select
  to anon, authenticated
  using (true);

create policy "user_subscriptions_select_own"
  on public.user_subscriptions
  for select
  to authenticated
  using (user_id = auth.uid());

create policy "user_subscriptions_insert_own"
  on public.user_subscriptions
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "user_subscriptions_update_own"
  on public.user_subscriptions
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "user_entitlements_select_own"
  on public.user_entitlements
  for select
  to authenticated
  using (user_id = auth.uid());

create policy "user_entitlements_insert_own"
  on public.user_entitlements
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "user_entitlements_update_own"
  on public.user_entitlements
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "stripe_customers_select_own"
  on public.stripe_customers
  for select
  to authenticated
  using (user_id = auth.uid());
