do $$
begin
  if to_regclass('public.plans') is not null then
    alter table public.plans
      add column if not exists price_eur numeric,
      add column if not exists currency text default 'eur',
      add column if not exists stripe_product_id text,
      add column if not exists stripe_price_id text,
      add column if not exists stripe_lookup_key text,
      add column if not exists is_active boolean not null default true,
      add column if not exists created_at timestamptz not null default now(),
      add column if not exists updated_at timestamptz not null default now();
  end if;
end $$;

do $$
begin
  if to_regclass('public.user_subscriptions') is not null then
    alter table public.user_subscriptions
      add column if not exists status text default 'inactive',
      add column if not exists stripe_customer_id text,
      add column if not exists stripe_subscription_id text,
      add column if not exists stripe_price_id text,
      add column if not exists current_period_start timestamptz,
      add column if not exists current_period_end timestamptz,
      add column if not exists cancel_at_period_end boolean default false,
      add column if not exists created_at timestamptz not null default now(),
      add column if not exists updated_at timestamptz not null default now();
  end if;
end $$;

do $$
begin
  if to_regclass('public.user_entitlements') is not null then
    alter table public.user_entitlements
      add column if not exists pro_lifetime boolean not null default false,
      add column if not exists credits_balance int not null default 0,
      add column if not exists updated_at timestamptz not null default now();
  end if;
end $$;
