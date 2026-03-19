-- Migration: Design Tokens – zentrale Styles für App + Website
-- Datum: 2026-03-17

CREATE TABLE IF NOT EXISTS design_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tokens JSONB NOT NULL DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER design_tokens_updated_at
  BEFORE UPDATE ON design_tokens
  FOR EACH ROW
  EXECUTE FUNCTION update_palette_colors_timestamp();

ALTER TABLE design_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read design_tokens" ON design_tokens
  FOR SELECT USING (is_active = true);

CREATE POLICY "Service write design_tokens" ON design_tokens
  FOR ALL USING (auth.role() = 'service_role');

-- Seed: EVERLOXX Design Tokens
INSERT INTO design_tokens (tokens, is_active) VALUES ('{
  "colors": {
    "primary": "#efd2a7",
    "primaryHover": "#efd2a7",
    "background": "#FFFFFF",
    "backgroundWarm": "#FFF8F5",
    "foreground": "#2D2926",
    "foregroundLight": "#FFF8F5",
    "dark": "#1A1614",
    "accent": "#efd2a7",
    "border": "#E8D5CC",
    "borderDark": "#4A4542",
    "shadow": "#2D2926",
    "error": "#C53030",
    "success": "#38A169"
  },
  "fonts": {
    "heading": "Times New Roman",
    "headingFallback": "Georgia, serif",
    "body": "Lato",
    "bodyFallback": "sans-serif",
    "headingWeight": 700,
    "bodyWeight": 400,
    "headingScale": 1.1,
    "bodyScale": 1.0
  },
  "brand": {
    "name": "EVERLOXX",
    "nameFull": "EVERLOXX Design",
    "tagline": "Dein Zuhause. Dein Style.",
    "taglineSub": "Wandfarben, die nicht nur wunderschön aussehen – sondern dein Zuhause spürbar gemütlicher machen."
  },
  "icons": {
    "color": "#efd2a7",
    "strokeWidth": 2,
    "size": 16
  },
  "buttons": {
    "radius": 40,
    "paddingX": 52,
    "paddingY": 18
  },
  "cards": {
    "radius": 12,
    "shadowOpacity": 0.06
  },
  "spacing": {
    "page": 1400,
    "sectionGap": 0,
    "gridH": 8,
    "gridV": 8
  }
}'::jsonb, true);
