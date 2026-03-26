-- Update design tokens from CLIMALOX to EVERLOXX
-- Run this in Supabase SQL Editor or via supabase db push

UPDATE design_tokens
SET tokens = jsonb_set(
  jsonb_set(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(
                jsonb_set(
                  jsonb_set(
                    jsonb_set(
                      jsonb_set(
                        jsonb_set(
                          jsonb_set(
                            jsonb_set(
                              jsonb_set(
                                jsonb_set(
                                  jsonb_set(
                                    tokens,
                                    '{brand,name}', '"EVERLOXX"'
                                  ),
                                  '{brand,nameFull}', '"EVERLOXX"'
                                ),
                                '{brand,tagline}', '"energy stays..."'
                              ),
                              '{brand,taglineSub}', '"Premium-Wandfarben für Räume, die sich so gut anfühlen, wie sie aussehen."'
                            ),
                            '{fonts,body}', '"Montserrat"'
                          ),
                          '{fonts,heading}', '"Playfair Display"'
                        ),
                        '{colors,accent}', '"#efd2a7"'
                      ),
                      '{colors,primary}', '"#efd2a7"'
                    ),
                    '{colors,primaryHover}', '"#d4b88a"'
                  ),
                  '{colors,dark}', '"#1A1614"'
                ),
                '{colors,footer}', '"#1A1614"'
              ),
              '{colors,foreground}', '"#2D2926"'
            ),
            '{colors,header}', '"#2D2926"'
          ),
          '{colors,shadow}', '"#2D2926"'
        ),
        '{colors,accent2}', '"#2D2926"'
      ),
      '{colors,border}', '"#E8E6E3"'
    ),
    '{colors,backgroundWarm}', '"#FAFAF9"'
  ),
  '{colors,foregroundLight}', '"#6B635D"'
),
updated_at = now()
WHERE is_active = true;
