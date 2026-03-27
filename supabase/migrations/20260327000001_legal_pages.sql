-- ============================================================
-- legal_pages: Single Source of Truth for legal content
-- Used by both the App and the Website
-- ============================================================

create table if not exists public.legal_pages (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,          -- e.g. "impressum", "agb", "datenschutz", "widerruf"
  title       text not null,                 -- Display title
  body_html   text not null default '',      -- Full HTML content
  sort_order  int not null default 0,
  updated_at  timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

-- Auto-update updated_at
create or replace function update_legal_pages_timestamp()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger legal_pages_updated_at
  before update on public.legal_pages
  for each row execute function update_legal_pages_timestamp();

-- Public read access
alter table public.legal_pages enable row level security;

create policy "legal_pages_public_read"
  on public.legal_pages for select
  to anon, authenticated
  using (true);

-- Index
create index legal_pages_slug_idx on public.legal_pages (slug);

-- ============================================================
-- Seed: Placeholder content (to be filled with real text)
-- ============================================================

insert into public.legal_pages (slug, title, body_html, sort_order) values
(
  'impressum',
  'Impressum',
  '<h2>EVERLOXX GmbH</h2>
<p>Geschäftsführer: Stefano Bholz</p>
<p>Kontakt: <a href="mailto:info@everloxx.com">info@everloxx.com</a></p>
<p>Web: <a href="https://everloxx.com">https://everloxx.com</a></p>',
  1
),
(
  'agb',
  'Allgemeine Geschäftsbedingungen',
  '<h2>Allgemeine Geschäftsbedingungen</h2>
<p>Die vollständigen AGB werden hier eingepflegt.</p>',
  2
),
(
  'datenschutz',
  'Datenschutzerklärung',
  '<h2>Datenschutzerklärung</h2>
<p>Die vollständige Datenschutzerklärung wird hier eingepflegt.</p>',
  3
),
(
  'widerruf',
  'Widerrufsbelehrung',
  '<h2>Widerrufsbelehrung</h2>
<p>Die vollständige Widerrufsbelehrung wird hier eingepflegt.</p>',
  4
)
on conflict (slug) do nothing;
