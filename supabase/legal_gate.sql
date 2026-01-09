-- Legal gate versions for AGB and Datenschutzerklaerung.
alter table if exists public.profiles
  add column if not exists terms_version text,
  add column if not exists privacy_version text;

alter table if exists public.user_consents
  add column if not exists terms_version text,
  add column if not exists privacy_version text;
