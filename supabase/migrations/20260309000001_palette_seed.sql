-- Seed: 50 fiktive THERMOLOX Innenfarben
-- 10 Farbgruppen × 5 Töne
-- Ausführen mit Service-Role oder direkt in Supabase Studio

insert into public.palette_colors
  (hex, name, group_name, shade_index, description, is_interior, sort_order)
values
  -- ===== ROT =====
  ('#8B1A1A', 'Morgenrot',       'Rot', 1, 'Ein tiefes, erdiges Rot das Wärme und Charakter in jeden Raum bringt – ideal für Akzentwände im Wohnzimmer.', true, 10),
  ('#B22222', 'Feuerziegel',     'Rot', 2, 'Kräftiges Ziegelrot mit mediterranem Flair – verleiht Küchen und Esszimmern eine lebendige Atmosphäre.', true, 11),
  ('#CC3333', 'Karmesin',        'Rot', 3, 'Leuchtendes Karmesinrot für mutige Gestaltungsideen – setzt als Einzelwand kraftvolle Akzente.', true, 12),
  ('#E06060', 'Altrosa Dunkel',  'Rot', 4, 'Gedämpftes Altrosa mit Tiefe – kombiniert Eleganz mit Wärme, perfekt für Schlaf- und Ankleidezimmer.', true, 13),
  ('#F0A0A0', 'Rosenquarz',      'Rot', 5, 'Zartes Rosenquarz für lichtdurchflutete Räume – schafft eine sanfte, einladende Wohnatmosphäre.', true, 14),

  -- ===== ROSA =====
  ('#A0306A', 'Fuchsia Tief',    'Rosa', 1, 'Intensives Fuchsia mit violettem Unterton – ein kraftvoller Statement-Ton für moderne Interieurs.', true, 20),
  ('#C4527A', 'Himbeereis',      'Rosa', 2, 'Warmes Himbeerrosa mit Tiefe – bringt Energie und Weichheit zugleich in Jugendzimmer und Arbeitsbereiche.', true, 21),
  ('#D4758A', 'Blushing Rose',   'Rosa', 3, 'Klassisches Blushing Rose – zeitlos elegant und vielseitig kombinierbar in jedem Raumstil.', true, 22),
  ('#E89FB0', 'Pfirsichblüte',   'Rosa', 4, 'Helles Pfirsichrosa mit rosa Schimmer – wirkt freundlich und einladend in Wohn- und Kinderbereichen.', true, 23),
  ('#F5D0DA', 'Puder',           'Rosa', 5, 'Feines Puderrosa für eine romantische, luftige Stimmung – ideal als großflächiger Wandton im Schlafzimmer.', true, 24),

  -- ===== VIOLETT =====
  ('#3D1A5C', 'Mitternachtsviolett', 'Violett', 1, 'Tiefes Mitternachtsviolett für dramatische Raumwirkung – edel als Deckenfarbe oder Nische.', true, 30),
  ('#6B3A9A', 'Amethyst',            'Violett', 2, 'Satter Amethystton – verleiht Arbeitszimmern und Bibliotheken eine inspirierende, konzentrierte Atmosphäre.', true, 31),
  ('#8A5CBD', 'Lavendelfeld',         'Violett', 3, 'Warmes Lavendelviolett zwischen Ruhe und Lebendigkeit – perfekt für entspannte Wohnbereiche.', true, 32),
  ('#AD89D4', 'Flieder',              'Violett', 4, 'Zarter Fliederturm – romantisch und verspielt, ideal für Kinderzimmer und Gästebäder.', true, 33),
  ('#D4C0EA', 'Hellviolett',          'Violett', 5, 'Helles, fast neutrales Violett – erweitert optisch kleine Räume und wirkt beruhigend.', true, 34),

  -- ===== BLAU =====
  ('#0D2B5E', 'Mitternachtsblau',  'Blau', 1, 'Tiefes Mitternachtsblau – klassisch und zeitlos für Arbeitszimmer, Bibliotheken und edle Flure.', true, 40),
  ('#1A4A8A', 'Ozeanblau',         'Blau', 2, 'Kräftiges Ozeanblau mit maritimem Charakter – verleiht Bädern und Küsten-Interieurs Frische.', true, 41),
  ('#3A75C4', 'Kornblume',         'Blau', 3, 'Lebendiges Kornblumenblau – fröhlich und klar, belebt Küchen, Kinderzimmer und Hobbyräume.', true, 42),
  ('#7AAED8', 'Himmelblau',        'Blau', 4, 'Sanftes Himmelblau – öffnet Räume optisch und schafft eine entspannte, leichte Atmosphäre.', true, 43),
  ('#C0DDEF', 'Eisblau',           'Blau', 5, 'Helles, kühles Eisblau – wirkt reinigend und frisch, ideal für Bäder und Schlafzimmer.', true, 44),

  -- ===== GRÜN =====
  ('#1B3D2A', 'Waldgrün',         'Grün', 1, 'Sattes Dunkelgrün mit Erdverbundenheit – bringt die Natur ins Innere und schafft ruhige Wohlfühloasen.', true, 50),
  ('#2E6B45', 'Smaragd',          'Grün', 2, 'Strahlender Smaragdton – luxuriös und lebendig, perfekt als Akzent in modernen Wohnräumen.', true, 51),
  ('#4A9E6A', 'Frühlingsgrün',    'Grün', 3, 'Frisches Frühlingsgrün – belebt Küchen und Essbereiche mit natürlicher Vitalität.', true, 52),
  ('#8DC4A0', 'Minze',            'Grün', 4, 'Zarte Minze mit beruhigender Wirkung – ideal für Schlafzimmer, Bäder und Meditationsräume.', true, 53),
  ('#C8E6D2', 'Aquagrün Hell',    'Grün', 5, 'Helles Aquagrün – frisch und offen, erweitert kleine Räume und wirkt einladend.', true, 54),

  -- ===== GELB/OCKER =====
  ('#7A5C10', 'Ocker Dunkel',     'Gelb', 1, 'Tiefes Erdocker – warm und geerdet, verleiht mediterranen und rustikalen Räumen Authentizität.', true, 60),
  ('#B88A20', 'Goldgelb',         'Gelb', 2, 'Warmes Goldgelb – sonnig und einladend, bringt Licht in nordseitige Räume und Flure.', true, 61),
  ('#D4A830', 'Sonnenblume',      'Gelb', 3, 'Leuchtendes Sonnenblumengelb – fröhlich und energiegeladen, ideal für Küchen und Spielzimmer.', true, 62),
  ('#E8CC7A', 'Champagner',       'Gelb', 4, 'Warmer Champagnerton – elegant und vielseitig, harmoniert mit natürlichen Materialien.', true, 63),
  ('#F5ECC0', 'Cremeweiß',        'Gelb', 5, 'Warmes Cremeweiß mit Gelbstich – zeitlos freundlich und in jedem Raum einsetzbar.', true, 64),

  -- ===== ORANGE =====
  ('#7A2E10', 'Terra di Siena',   'Orange', 1, 'Dunkles Terrakottarot – toskanisches Flair für Wohn- und Esszimmer mit mediterranem Charakter.', true, 70),
  ('#C44A1A', 'Terrakotta',       'Orange', 2, 'Klassisches Terrakotta – warm, lebendig und natürlich, ideal für Wohnräume im Boho-Stil.', true, 71),
  ('#E06030', 'Safran',           'Orange', 3, 'Warmes Safran-Orange – exotisch und einladend, perfekt als Akzentwand im Esszimmer.', true, 72),
  ('#F09060', 'Pfirsich',         'Orange', 4, 'Sanftes Pfirsichorange – wärmend ohne zu überwältigen, ideal für Küchen und Wohnbereiche.', true, 73),
  ('#F5C8A8', 'Apricot',          'Orange', 5, 'Zartes Apricot – warm und freundlich, schafft eine einladende Wohlatmosphäre in jedem Raum.', true, 74),

  -- ===== BRAUN =====
  ('#2C1A0A', 'Dunkelbraun',      'Braun', 1, 'Tiefes Espressobraun – edel und geerdet, verleiht Bibliotheken und Arbeitszimmern Würde.', true, 80),
  ('#5C3520', 'Schokolade',       'Braun', 2, 'Sattes Schokoladenbraun – luxuriös und warm, perfekt für Schlafzimmer und Ankleidezimmer.', true, 81),
  ('#8C6040', 'Karamel',          'Braun', 3, 'Warmes Karamellbraun – einladend und natürlich, harmoniert wunderbar mit hellen Böden.', true, 82),
  ('#B89070', 'Sandstein',        'Braun', 4, 'Helles Sandsteinbraun – neutral und vielseitig, die perfekte Basis für jeden Einrichtungsstil.', true, 83),
  ('#D4B898', 'Latte',            'Braun', 5, 'Helles Latte-Braun – cremig und weich, schafft eine entspannte, gemütliche Atmosphäre.', true, 84),

  -- ===== GRAU =====
  ('#222222', 'Anthrazit',        'Grau', 1, 'Tiefes Anthrazit – modern und markant, ideal für Akzentwände in minimalistischen Räumen.', true, 90),
  ('#505050', 'Graphit',          'Grau', 2, 'Elegantes Graphitgrau – zeitlos und vielseitig, die perfekte neutrale Basis für moderne Interieurs.', true, 91),
  ('#808080', 'Steingrau',        'Grau', 3, 'Klassisches Steingrau – ruhig und ausgewogen, kombinierbar mit allen Einrichtungsstilen.', true, 92),
  ('#ADADAD', 'Silbergrau',       'Grau', 4, 'Helles Silbergrau – frisch und offen, lässt Räume größer wirken und reflektiert das Tageslicht.', true, 93),
  ('#D8D8D8', 'Nebelgrau',        'Grau', 5, 'Zartes Nebelgrau – fast weiß, aber mit Tiefe, die perfekte Alternative zu reinem Weiß.', true, 94),

  -- ===== WEISS/BEIGE =====
  ('#C8B89A', 'Sandbeige',        'Beige', 1, 'Warmes Sandbeige – natürlich und zeitlos, die ideale Grundfarbe für helle, freundliche Räume.', true, 100),
  ('#D8CAAC', 'Leinen',           'Beige', 2, 'Zartes Leinenbeige – warm und harmonisch, kombiniert sich mühelos mit Holz und Naturmaterialien.', true, 101),
  ('#E4D8C0', 'Cashmere',         'Beige', 3, 'Cremiges Cashmere – luxuriös und warm, verleiht großen Wohnräumen Eleganz und Tiefe.', true, 102),
  ('#F0E8D8', 'Pergament',        'Beige', 4, 'Helles Pergamentbeige – weich und einladend, ideal als Gesamtton für offene Wohnbereiche.', true, 103),
  ('#F8F4EC', 'Brokenwhite',      'Beige', 5, 'Warmweißes Gebrochenweiß – das Alternative zu reinem Weiß, freundlicher und wohnlicher.', true, 104);
