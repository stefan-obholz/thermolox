-- Consent fields for optional analytics and AI features.
alter table if exists public.profiles
  add column if not exists analytics_consent boolean,
  add column if not exists analytics_consent_at timestamptz,
  add column if not exists ai_consent boolean,
  add column if not exists ai_consent_at timestamptz;

alter table if exists public.user_consents
  add column if not exists analytics_accepted_at timestamptz,
  add column if not exists ai_accepted_at timestamptz;
