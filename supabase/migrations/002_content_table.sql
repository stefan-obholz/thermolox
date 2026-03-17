-- Migration: Content-Tabelle für Pages und Blog-Artikel
-- Datum: 2026-03-17
-- Zweck: Website-Content zentral in Supabase für App + Website

CREATE TABLE IF NOT EXISTS content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('page', 'article')),
  title TEXT NOT NULL,
  handle TEXT NOT NULL,
  body TEXT,
  summary TEXT,
  image_url TEXT,
  image_alt TEXT,
  tags TEXT[] DEFAULT '{}',
  blog_title TEXT,
  blog_handle TEXT,
  published_at TIMESTAMPTZ,
  sort_order INT DEFAULT 0,
  is_visible BOOLEAN DEFAULT true,
  shopify_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_content_type ON content(type);
CREATE INDEX IF NOT EXISTS idx_content_handle ON content(handle);
CREATE INDEX IF NOT EXISTS idx_content_visible ON content(is_visible);
CREATE UNIQUE INDEX IF NOT EXISTS idx_content_shopify_id ON content(shopify_id);

-- Auto-update updated_at
CREATE TRIGGER content_updated_at
  BEFORE UPDATE ON content
  FOR EACH ROW
  EXECUTE FUNCTION update_palette_colors_timestamp();

-- RLS
ALTER TABLE content ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read content" ON content
  FOR SELECT USING (is_visible = true);

CREATE POLICY "Service write content" ON content
  FOR ALL USING (auth.role() = 'service_role');
