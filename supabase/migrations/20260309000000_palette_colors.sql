-- Farbpaletten-Tabelle
create table if not exists public.palette_colors (
  id           uuid primary key default gen_random_uuid(),
  hex          text not null,
  name         text not null,
  group_name   text not null,
  shade_index  int  not null,
  description  text,
  is_interior  boolean not null default true,
  sort_order   int  not null default 0,
  created_at   timestamptz not null default now()
);

-- Öffentlich lesbar (kein Login nötig für Palette)
alter table public.palette_colors enable row level security;

create policy "palette_colors_select_all"
  on public.palette_colors for select
  using (true);

-- Nur Service-Role darf schreiben
create policy "palette_colors_insert_service"
  on public.palette_colors for insert
  with check (false);

create policy "palette_colors_update_service"
  on public.palette_colors for update
  using (false);

create policy "palette_colors_delete_service"
  on public.palette_colors for delete
  using (false);

create index if not exists palette_colors_group_idx
  on public.palette_colors(group_name, shade_index);

create index if not exists palette_colors_interior_idx
  on public.palette_colors(is_interior, sort_order);
