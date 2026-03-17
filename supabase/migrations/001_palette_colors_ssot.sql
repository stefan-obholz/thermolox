-- Migration: Erweitere palette_colors zur Single Source of Truth
-- Datum: 2026-03-17
-- Zweck: Alle Produktdaten zentral in Supabase speichern

ALTER TABLE palette_colors
  ADD COLUMN IF NOT EXISTS price_eur NUMERIC(10,2) DEFAULT 149.00,
  ADD COLUMN IF NOT EXISTS sku TEXT,
  ADD COLUMN IF NOT EXISTS shopify_product_id TEXT,
  ADD COLUMN IF NOT EXISTS shopify_variant_id TEXT,
  ADD COLUMN IF NOT EXISTS product_type TEXT DEFAULT 'Wandfarbe',
  ADD COLUMN IF NOT EXISTS collection_name TEXT,
  ADD COLUMN IF NOT EXISTS collection_description TEXT,
  ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS image_url_1 TEXT,
  ADD COLUMN IF NOT EXISTS image_url_2 TEXT,
  ADD COLUMN IF NOT EXISTS image_url_3 TEXT,
  ADD COLUMN IF NOT EXISTS image_url_4 TEXT,
  ADD COLUMN IF NOT EXISTS image_url_5 TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Index für Shopify-Sync
CREATE INDEX IF NOT EXISTS idx_palette_colors_shopify_id ON palette_colors(shopify_product_id);
CREATE INDEX IF NOT EXISTS idx_palette_colors_sku ON palette_colors(sku);
CREATE INDEX IF NOT EXISTS idx_palette_colors_group ON palette_colors(group_name);
CREATE INDEX IF NOT EXISTS idx_palette_colors_status ON palette_colors(status);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_palette_colors_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS palette_colors_updated_at ON palette_colors;
CREATE TRIGGER palette_colors_updated_at
  BEFORE UPDATE ON palette_colors
  FOR EACH ROW
  EXECUTE FUNCTION update_palette_colors_timestamp();

-- RLS: Alle können lesen, nur authentifizierte können schreiben
ALTER TABLE palette_colors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read palette_colors" ON palette_colors;
CREATE POLICY "Public read palette_colors" ON palette_colors
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Service write palette_colors" ON palette_colors;
CREATE POLICY "Service write palette_colors" ON palette_colors
  FOR ALL USING (auth.role() = 'service_role');
