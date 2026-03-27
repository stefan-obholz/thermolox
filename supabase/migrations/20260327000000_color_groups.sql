-- ============================================================
-- color_groups: Single Source of Truth for filter categories
-- Used by both the App and the Website
-- ============================================================

create table if not exists public.color_groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,          -- Display name, e.g. "Rosa"
  slug        text not null unique,          -- URL/filter key, e.g. "rosa"
  hex         text not null,                 -- Dot color for filter UI, e.g. "#C4A8AD"
  sort_order  int not null default 0,
  created_at  timestamptz not null default now()
);

-- Public read access (anon + authenticated)
alter table public.color_groups enable row level security;

create policy "color_groups_public_read"
  on public.color_groups for select
  to anon, authenticated
  using (true);

-- Index for ordering
create index color_groups_sort_idx on public.color_groups (sort_order);

-- ============================================================
-- Seed: Color groups matching palette_colors.group_name values
-- ============================================================

insert into public.color_groups (name, slug, hex, sort_order) values
  ('Rot',     'rot',     '#A85A3A',  1),
  ('Rosa',    'rosa',    '#C4A8AD',  2),
  ('Orange',  'orange',  '#D4874D',  3),
  ('Gelb',    'gelb',    '#C8A854',  4),
  ('Grün',    'grün',    '#7A8A78',  5),
  ('Blau',    'blau',    '#5A7A98',  6),
  ('Violett', 'violett', '#5A3060',  7),
  ('Beige',   'beige',   '#EDE4D6',  8),
  ('Braun',   'braun',   '#8B5E3C',  9),
  ('Grau',    'grau',    '#A09890', 10)
on conflict (name) do nothing;
