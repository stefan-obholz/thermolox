-- ClimaLox 132-Color Palette Seed
-- 11 Collections x 12 Colors each
-- Collections: Natural, Urban, Earth, Rose, Red, Sun, Botanical, Sky, Ocean, Velvet, Black
-- Run with Service-Role or directly in Supabase Studio

DELETE FROM public.palette_colors;

insert into public.palette_colors
  (hex, name, group_name, shade_index, description, is_interior, sort_order)
values
  -- ===== NATURAL COLLECTION (Beige tones) =====
  ('#F5EDE0', 'Silk Cremebeige',       'Natural', 1, 'Ein heller, weicher Beigeton mit eleganter Ruhe und zeitloser Leichtigkeit. Diese hochwertige ClimaLox Wandfarbe passt perfekt zu Holz, Leinen, Kaschmir und hellen Wohnkonzepten und verleiht Räumen eine warme, gepflegte und stilvolle Ausstrahlung.', true, 10),
  ('#EADBC4', 'Tropical Sandbeige',    'Natural', 2, 'Ein warmer Sandbeigeton, der an feinen, sonnengewärmten Sand erinnert und sofort Behaglichkeit schafft. Die moderne Innenfarbe harmoniert ideal mit Naturmaterialien, hellen Hölzern und stilvollen Beige-Nuancen.', true, 11),
  ('#E4D5BF', 'Natural Leinenbeige',   'Natural', 3, 'Ein natürlicher Beigeton mit ruhiger, harmonischer Ausstrahlung und zeitloser Eleganz. Diese Premium-Wandfarbe eignet sich ideal für skandinavische Einrichtungen, klassische Wohnstile und moderne Interiors.', true, 12),
  ('#EDE4D6', 'Pearl Muschelbeige',    'Natural', 4, 'Ein feiner Muschelbeigeton mit weicher Wirkung und dezenter Luxus-Ausstrahlung. Die elegante Designfarbe passt besonders schön zu hellen Böden, Steinoptiken und soften Wohntextilien.', true, 13),
  ('#DDD0BA', 'Pure Naturbeige',       'Natural', 5, 'Ein harmonischer Beigeton mit warmer, ausgeglichener Wirkung und viel Wohnlichkeit. Diese vielseitige Innenfarbe lässt sich mit nahezu jedem Einrichtungsstil kombinieren und macht Räume freundlich, ruhig und modern.', true, 14),
  ('#CFC3AE', 'Stone Kieselbeige',     'Natural', 6, 'Ein eleganter Naturton mit feiner, mineralischer Ausstrahlung und ruhigem Charakter. Die hochwertige Wandfarbe harmoniert besonders schön mit Holz, Creme und modernen Erdfarben.', true, 15),
  ('#D8CBAF', 'Luxury Kaschmirbeige',  'Natural', 7, 'Ein weicher, edler Beigeton mit besonders hochwertiger und wohnlicher Wirkung. Diese stilvolle ClimaLox Designfarbe verleiht Räumen ein sanftes Luxusgefühl mit angenehmer Wärme.', true, 16),
  ('#C5BAA7', 'Urban Greigebeige',     'Natural', 8, 'Eine moderne Mischung aus Beige und Grau mit urbanem Designcharakter. Die stilvolle Wandfarbe passt hervorragend zu klaren Linien, schwarzen Akzenten und zeitgemäßen Wohnkonzepten.', true, 17),
  ('#B9A98E', 'Velvet Taupebeige',     'Natural', 9, 'Ein eleganter Ton mit warmer Tiefe, moderner Ruhe und besonders softer Wirkung. Diese Premium-Innenfarbe harmoniert ideal mit Naturholz, Bronze und sandigen Farbwelten.', true, 18),
  ('#F0E5CF', 'Golden Elfenbeinbeige', 'Natural', 10, 'Ein heller Beigeton mit zarter Wärme, feiner Eleganz und freundlicher Ausstrahlung. Die hochwertige Wandfarbe lässt Räume offen, sonnig und besonders gepflegt erscheinen.', true, 19),
  ('#C8AD82', 'Desert Sahara-Beige',   'Natural', 11, 'Ein warmer, charaktervoller Farbton mit natürlicher Wüsteninspiration und stilvoller Tiefe. Diese ausdrucksstarke Designfarbe bringt Ruhe, Charakter und besondere Wärme an die Wand.', true, 20),
  ('#BFA06E', 'Caramel Glow Beige',    'Natural', 12, 'Ein ausdrucksstarker Beigeton mit sanfter Karamellnote und wohnlicher Tiefe. Die elegante Innenfarbe schafft eine warme, stilvolle und geborgene Wohnatmosphäre.', true, 21),

  -- ===== URBAN COLLECTION (Grey tones) =====
  ('#E0E2E4', 'Crystal Lichtgrau',       'Urban', 1, 'Ein heller Grauton mit eleganter Klarheit und moderner Frische. Diese stilvolle ClimaLox Wandfarbe öffnet Räume optisch und wirkt ruhig, gepflegt und hochwertig.', true, 30),
  ('#CCCED2', 'Soft Nebelgrau',          'Urban', 2, 'Ein sanfter Grauton mit feiner Ausstrahlung und harmonischer Balance. Die moderne Innenfarbe passt hervorragend zu Weiß, Holz, Glas und minimalistischen Wohnwelten.', true, 31),
  ('#B3B7BD', 'Silver Silbergrau',       'Urban', 3, 'Ein kühler Grauton mit eleganter Ausstrahlung und hochwertigem Charakter. Diese Designfarbe bringt urbane Klasse und moderne Präzision an die Wand.', true, 32),
  ('#9A9EA5', 'Stone Steingrau',         'Urban', 4, 'Ein souveräner Grauton mit natürlicher Tiefe und architektonischer Wirkung. Die Premium-Wandfarbe harmoniert ideal mit Beton, Holz und schwarzen Akzenten.', true, 33),
  ('#6E7279', 'Urban Schiefergrau',      'Urban', 5, 'Ein moderner Schieferton mit markanter, aber angenehm wohnlicher Wirkung. Diese hochwertige Innenfarbe setzt stilvolle Statements und bleibt dabei ruhig und elegant.', true, 34),
  ('#A09890', 'Harmony Warmgrau',        'Urban', 6, 'Ein warmes Grau mit weicher, wohnlicher Balance und eleganter Zurückhaltung. Die stilvolle Wandfarbe verbindet moderne Klarheit mit behaglichem Raumgefühl.', true, 35),
  ('#8A8D91', 'Concrete Betongrau',      'Urban', 7, 'Ein klarer, moderner Grauton mit architektonischer Stärke und zeitloser Wirkung. Diese hochwertige Designfarbe passt perfekt zu Eiche, Schwarz und puristischen Formen.', true, 36),
  ('#555960', 'Noble Graphitgrau',       'Urban', 8, 'Ein tiefer Grauton mit edler Präsenz und souveräner Ruhe. Die elegante Innenfarbe schenkt Räumen Tiefe, Struktur und eine stilvolle Stärke.', true, 37),
  ('#A8A098', 'Modern Greigegrau',       'Urban', 9, 'Die perfekte Balance aus Grau und Beige für ein modernes, wohnliches Ambiente. Diese Premium-Wandfarbe wirkt weich, hochwertig und vielseitig kombinierbar.', true, 38),
  ('#4A4E54', 'Signature Anthrazit Soft','Urban', 10, 'Ein markanter Farbton mit sanfter Tiefe und besonders hochwertiger Wirkung. Die Designfarbe bringt Stärke und Ruhe in perfekte Balance.', true, 39),
  ('#5C6066', 'Prestige Architekturgrau','Urban', 11, 'Ein exklusiver Designer-Grauton mit urbanem Charakter und moderner Wirkung. Diese hochwertige Wandfarbe verleiht Räumen Klasse, Souveränität und stilvolle Klarheit.', true, 40),
  ('#363A40', 'Architectural Tiefanthrazit','Urban', 12, 'Ein ausdrucksstarker Anthrazitton für moderne Räume mit klarer Haltung. Die intensive Innenfarbe schafft Tiefe, Stil und beeindruckende Eleganz.', true, 41),

  -- ===== EARTH COLLECTION (Brown tones) =====
  ('#C8B494', 'Terra Sandstein',      'Earth', 1, 'Ein warmer Naturton mit stilvoller Erdigkeit und sanfter Tiefe. Diese hochwertige Wandfarbe passt wunderbar zu Stein, Holz und natürlichen Textilien.', true, 50),
  ('#BF9A4E', 'Golden Ockerbraun',    'Earth', 2, 'Ein sonniger Erdton mit eleganter Wärme und kraftvoller Ausstrahlung. Die stilvolle Innenfarbe bringt Behaglichkeit und Charakter in moderne Wohnräume.', true, 51),
  ('#C4A882', 'Soft Camel',           'Earth', 3, 'Ein weicher, moderner Braunton mit wohnlicher und eleganter Ausstrahlung. Diese ClimaLox Designfarbe harmoniert perfekt mit Kaschmir, Leinen und hellen Hölzern.', true, 52),
  ('#9E8E7A', 'Velvet Taupe',         'Earth', 4, 'Ein edler Taupeton mit luxuriöser Zurückhaltung und moderner Wohnlichkeit. Die elegante Wandfarbe schafft ein ruhiges, zeitloses und hochwertiges Raumgefühl.', true, 53),
  ('#A08060', 'Natural Lehmbraun',    'Earth', 5, 'Ein authentischer Erdton mit warmer, natürlicher Ausstrahlung. Diese Premium-Innenfarbe bringt Ruhe, Erdung und natürliche Eleganz ins Zuhause.', true, 54),
  ('#6E4E35', 'Noble Nussbraun',      'Earth', 6, 'Ein edler Braunton mit kraftvoller Tiefe und wohnlicher Wärme. Die hochwertige Wandfarbe passt besonders schön zu Leder, Creme und dunklen Hölzern.', true, 55),
  ('#8B5E3C', 'Terra Terrabraun',     'Earth', 7, 'Ein charakterstarker Braunton mit erdiger Kraft und besonderer Präsenz. Diese ausdrucksstarke Designfarbe bringt Natürlichkeit und starke Wohnlichkeit an die Wand.', true, 56),
  ('#5C3D28', 'Deep Umbra Soft',      'Earth', 8, 'Ein tiefer Braunton mit sanfter Eleganz und ruhiger Stärke. Die stilvolle Innenfarbe verleiht dem Raum Wärme, Ruhe und ausdrucksstarke Tiefe.', true, 57),
  ('#C9B599', 'Warm Erdbeige',        'Earth', 9, 'Eine harmonische Verbindung aus Helligkeit und natürlicher Erdigkeit. Diese moderne Wandfarbe schafft ein ausgewogenes, gepflegtes und wohnliches Ambiente.', true, 58),
  ('#5A3E28', 'Noble Walnuss',        'Earth', 10, 'Ein intensiver Braunton mit edlem, natürlichem Charakter. Die Premium-Wandfarbe bringt Wärme, Tiefe und stilvolle Geborgenheit in den Raum.', true, 59),
  ('#4A2E1A', 'Luxury Schokobraun',   'Earth', 11, 'Ein satter Braunton mit luxuriöser Eleganz und wohnlicher Wirkung. Diese hochwertige Innenfarbe macht Räume warm, stilvoll und besonders einladend.', true, 60),
  ('#3C2415', 'Espresso Earth',       'Earth', 12, 'Ein dunkler Erdton mit urbaner Eleganz und markanter Tiefe. Die ausdrucksstarke Designfarbe verleiht Räumen Kraft, Ruhe und Exklusivität.', true, 61),

  -- ===== ROSE COLLECTION =====
  ('#F2DAD8', 'Rosy Powder',          'Rose', 1, 'Ein zarter Rosaton mit weicher, femininer Eleganz und feiner Leichtigkeit. Diese hochwertige Wandfarbe verleiht Räumen eine stilvolle Wärme und sanfte Ausstrahlung.', true, 70),
  ('#D4A0A0', 'Vintage Altrosa',      'Rose', 2, 'Ein sanfter Altrosaton mit edlem, zeitlosem Charakter. Die elegante Innenfarbe passt perfekt zu Holz, Messing und soften Stoffen.', true, 71),
  ('#C4A8AD', 'Dusty Rosegrau',       'Rose', 3, 'Eine moderne Mischung aus Rosa und Grau mit besonders feiner Wirkung. Diese stilvolle Designfarbe schafft eine ruhige, hochwertige und moderne Wohnatmosphäre.', true, 72),
  ('#E8B8A8', 'Peach Blossom',        'Rose', 4, 'Ein warmer Rosaton mit leichter Pfirsichnote und freundlicher Ausstrahlung. Die frische Wandfarbe bringt Leichtigkeit und einen wohnlichen Charme in den Raum.', true, 73),
  ('#B8849A', 'Mauve Romance',        'Rose', 5, 'Ein stilvoller Rosaton mit eleganter Tiefe und feiner Raffinesse. Diese hochwertige Innenfarbe schenkt dem Raum eine sanfte, moderne Sinnlichkeit.', true, 74),
  ('#F0C8CA', 'Soft Bloom Pink',      'Rose', 6, 'Ein leichter, zarter Pinkton mit einladender und sanfter Wirkung. Die stilvolle Wandfarbe schafft eine ruhige und liebevolle Atmosphäre im Zuhause.', true, 75),
  ('#CCAA9E', 'Nude Harmony',         'Rose', 7, 'Ein zurückhaltender Rosaton mit natürlichem, modernem Charakter. Diese elegante Designfarbe macht Räume weich, stilvoll und zeitlos schön.', true, 76),
  ('#D4B0A4', 'Rose Sand',            'Rose', 8, 'Eine harmonische Verbindung aus Rose und Beige mit warmer, feiner Wirkung. Die hochwertige Innenfarbe bringt Ruhe und ein gepflegtes Wohngefühl an die Wand.', true, 77),
  ('#C09090', 'Dusty Rose',           'Rose', 9, 'Ein gedämpfter Rosaton mit moderner Zurückhaltung und stilvollem Charme. Diese ClimaLox Wandfarbe wirkt fein, hochwertig und angenehm wohnlich.', true, 78),
  ('#A87878', 'Rosewood Soft',        'Rose', 10, 'Ein eleganter Rosaton mit warmer, leicht holziger Tiefe. Die stilvolle Innenfarbe verleiht Räumen Charakter und eine feine, hochwertige Wärme.', true, 79),
  ('#B8607A', 'Berry Rose',           'Rose', 11, 'Ein lebendiger Rosaton mit moderner Frische und edler Ausstrahlung. Diese Designfarbe bringt stilvolle Energie und elegante Wärme in den Raum.', true, 80),
  ('#9E4868', 'Power Rose',           'Rose', 12, 'Ein ausdrucksstarker Rosaton mit Tiefe, Charakter und Designwirkung. Die markante Wandfarbe setzt ein stilvolles Statement mit femininer Stärke.', true, 81),

  -- ===== SIGNATURE RED COLLECTION =====
  ('#A0604A', 'Brick Elegance',       'Red', 1, 'Ein warmer Rotton mit natürlicher Tiefe und stilvoller Erdigkeit. Diese hochwertige Wandfarbe bringt Charakter und Behaglichkeit in moderne Wohnräume.', true, 90),
  ('#C07050', 'Terra Terracotta',     'Red', 2, 'Ein sonniger Terrakottaton mit mediterraner Wärme und wohnlicher Wirkung. Die stilvolle Innenfarbe schenkt Räumen eine lebendige und elegante Ausstrahlung.', true, 91),
  ('#A85A3A', 'Rust Harmony',         'Red', 3, 'Ein rostiger Rotton mit urbanem Charme und warmer Tiefe. Diese moderne Designfarbe schafft ein markantes Ambiente mit stilvoller Wärme.', true, 92),
  ('#944030', 'Clay Brick Red',       'Red', 4, 'Ein kräftiger, angenehm gedämpfter Rotton mit moderner Natürlichkeit. Die Premium-Wandfarbe verleiht dem Raum Persönlichkeit und ausdrucksstarke Tiefe.', true, 93),
  ('#722838', 'Bordeaux Velvet',      'Red', 5, 'Ein eleganter Rotton mit weicher, luxuriöser Wirkung. Diese hochwertige Innenfarbe bringt exklusive Wärme und stilvolle Tiefe an die Wand.', true, 94),
  ('#B03040', 'Ruby Mood',            'Red', 6, 'Ein moderner Rotton mit feiner Strahlkraft und urbaner Eleganz. Die Designfarbe setzt einen stilvollen Farbakzent mit besonderem Charakter.', true, 95),
  ('#8A3828', 'Classic Oxide Red',    'Red', 7, 'Ein charaktervoller Rotton mit natürlicher, mineralischer Ausstrahlung. Diese stilvolle Wandfarbe wirkt kraftvoll, warm und zeitlos.', true, 96),
  ('#7A3020', 'Klinker Chic',         'Red', 8, 'Ein markanter Rotton mit architektonischer Stärke und wohnlicher Wärme. Die hochwertige Innenfarbe bringt Stil, Charakter und Wertigkeit in den Raum.', true, 97),
  ('#6A2030', 'Wine Red Touch',       'Red', 9, 'Ein edler, gedämpfter Rotton mit eleganter Zurückhaltung. Diese Designfarbe schenkt dem Raum gemütliche Tiefe und stilvolle Ruhe.', true, 98),
  ('#6E3028', 'Mahogany Glow',        'Red', 10, 'Ein warmer Rotbraunton mit luxuriöser, holziger Anmutung. Die Premium-Wandfarbe verleiht Räumen ein exquisites und wohnliches Flair.', true, 99),
  ('#CC2030', 'Signal Red Design',    'Red', 11, 'Ein klarer, kraftvoller Rotton mit modernem Designcharakter. Diese ausdrucksstarke Innenfarbe bringt Energie, Stil und starke Akzente in den Raum.', true, 100),
  ('#8B1020', 'Deep Crimson',         'Red', 12, 'Ein intensiver Rotton mit beeindruckender Tiefe und starker Präsenz. Die markante Wandfarbe macht Räume mutig, stilvoll und unverwechselbar.', true, 101),

  -- ===== SUN COLLECTION (Yellow tones) =====
  ('#F8F0DC', 'Ivory Light',          'Sun', 1, 'Ein heller Gelbton mit sanfter Leuchtkraft und feinwarmer Wirkung. Diese hochwertige Wandfarbe bringt dezente Sonnigkeit und freundliche Offenheit ins Zuhause.', true, 110),
  ('#F5E8B8', 'Pastel Sun',           'Sun', 2, 'Ein zarter Gelbton mit leichter, frischer Ausstrahlung. Die stilvolle Innenfarbe verleiht Räumen Helligkeit, Leichtigkeit und gute Stimmung.', true, 111),
  ('#DCC88A', 'Sand Gold',            'Sun', 3, 'Ein warmer Gelbton mit sandiger Natürlichkeit und softer Tiefe. Diese elegante Designfarbe schafft eine freundliche und stilvolle Atmosphäre.', true, 112),
  ('#C8A854', 'Ocher Glow',           'Sun', 4, 'Ein charaktervoller Gelbton mit mineralischer Eleganz und angenehmer Wärme. Die hochwertige Wandfarbe schenkt Räumen Ausdruck und natürliche Behaglichkeit.', true, 113),
  ('#D4A84C', 'Honey Touch',          'Sun', 5, 'Ein honigwarmer Farbton mit freundlichem und wohnlichem Charakter. Diese moderne Innenfarbe bringt Wärme und Leichtigkeit an die Wand.', true, 114),
  ('#F2E8CC', 'Vanilla Silk',         'Sun', 6, 'Ein weicher, cremiger Gelbton mit edler Zurückhaltung. Die stilvolle Designfarbe macht Räume hell, warm und elegant.', true, 115),
  ('#DDD0A0', 'Wheat Harmony',        'Sun', 7, 'Ein natürlicher Gelbton mit sanfter, reifer Ausstrahlung. Diese hochwertige Wandfarbe schafft ein ruhiges und gepflegtes Wohngefühl.', true, 116),
  ('#C49830', 'Golden Ocher',         'Sun', 8, 'Ein warmer Goldgelbton mit stilvoller Tiefe und Charakter. Die elegante Innenfarbe bringt Sonnigkeit und eine besondere Wertigkeit in den Raum.', true, 117),
  ('#F5E4B0', 'Creamy Yellow',        'Sun', 9, 'Ein heller Gelbton mit feiner Leichtigkeit und moderner Wärme. Diese frische Wandfarbe eignet sich ideal für offene, freundliche Wohnräume.', true, 118),
  ('#E0D4A4', 'Straw Light',          'Sun', 10, 'Ein zurückhaltender Gelbton mit natürlicher und ruhiger Ausstrahlung. Die stilvolle Innenfarbe wirkt leicht, harmonisch und angenehm wohnlich.', true, 119),
  ('#B89020', 'Mustard Chic',         'Sun', 11, 'Ein markanter Gelbton mit modernem Charakter und stilvoller Tiefe. Diese ausdrucksstarke Designfarbe setzt elegante und wohnliche Akzente.', true, 120),
  ('#D48A10', 'Saffron Glow',         'Sun', 12, 'Ein kräftiger Gelbton mit exklusiver Wärme und starker Präsenz. Die hochwertige Wandfarbe bringt Licht, Energie und Stil in jeden Raum.', true, 121),

  -- ===== BOTANICAL COLLECTION (Green tones) =====
  ('#B8C4A8', 'Sage Whisper',         'Botanical', 1, 'Ein sanftes Salbeigrün mit ruhiger, natürlicher Eleganz. Diese hochwertige Wandfarbe schafft eine entspannte und stilvolle Wohlfühlatmosphäre.', true, 130),
  ('#8A9A60', 'Olive Grace',          'Botanical', 2, 'Ein warmer Grünton mit mediterraner Ruhe und natürlichem Charakter. Die elegante Innenfarbe bringt Gelassenheit und Stil in moderne Wohnräume.', true, 131),
  ('#6B7A4A', 'Moss Harmony',         'Botanical', 3, 'Ein weiches Moosgrün mit wohnlicher Tiefe und beruhigender Wirkung. Diese Designfarbe verleiht dem Zuhause Ruhe und natürliche Geborgenheit.', true, 132),
  ('#7A8A78', 'Urban Green Grey',     'Botanical', 4, 'Eine moderne Mischung aus Grün und Grau mit stilvoller Zurückhaltung. Die hochwertige Wandfarbe wirkt elegant, ruhig und besonders hochwertig.', true, 133),
  ('#4A6E4A', 'Soft Pine',            'Botanical', 5, 'Ein tiefer Grünton mit klarer, natürlicher Ausstrahlung. Diese moderne Innenfarbe bringt Charakter und ruhige Stärke an die Wand.', true, 134),
  ('#C4D8A8', 'Pistachio Light',      'Botanical', 6, 'Ein heller Grünton mit freundlicher Frische und natürlicher Leichtigkeit. Die sanfte Wandfarbe schafft eine belebende und harmonische Atmosphäre.', true, 135),
  ('#7A9468', 'Reed Green',           'Botanical', 7, 'Ein ausgewogener Grünton mit ruhigem und natürlichem Charakter. Diese stilvolle Innenfarbe schenkt Räumen Tiefe und Gelassenheit.', true, 136),
  ('#2E5A38', 'Forest Mood',          'Botanical', 8, 'Ein sattes Grün mit eleganter Naturwirkung und stilvoller Stärke. Die hochwertige Designfarbe bringt Ruhe und luxuriöse Erdung in den Raum.', true, 137),
  ('#88AE98', 'Eucalyptus Soft',      'Botanical', 9, 'Ein moderner Grünton mit frischer und gepflegter Ausstrahlung. Diese ClimaLox Wandfarbe wirkt leicht, stilvoll und entspannend.', true, 138),
  ('#6A7A50', 'Khaki Nature',         'Botanical', 10, 'Ein markanter Naturton mit warmer, moderner Tiefe. Die elegante Innenfarbe verleiht Räumen Charakter und ruhige Stärke.', true, 139),
  ('#1E4A28', 'Deep Pine Design',     'Botanical', 11, 'Ein kräftiger Grünton mit exklusiver Präsenz und moderner Eleganz. Diese Designfarbe bringt Tiefe, Ruhe und echte Designstaerke ins Zuhause.', true, 140),
  ('#0E3A20', 'Midnight Forest',      'Botanical', 12, 'Ein intensiver Grünton mit geheimnisvoller Tiefe und luxuriöser Wirkung. Die ausdrucksstarke Wandfarbe macht Räume besonders, mutig und hochwertig.', true, 141),

  -- ===== SKY COLLECTION (Blue tones) =====
  ('#C8D8E8', 'Misty Blue',           'Sky', 1, 'Ein sanfter Blauton mit leichter, beruhigender Ausstrahlung. Diese hochwertige Wandfarbe bringt Ruhe und Frische in moderne Wohnräume.', true, 150),
  ('#7090A8', 'Steel Blue',           'Sky', 2, 'Ein moderner Blauton mit klarer, urbaner Wirkung. Die elegante Innenfarbe verleiht der Wand Tiefe und eine stilvolle Kühle.', true, 151),
  ('#B0C4D8', 'Dove Blue',            'Sky', 3, 'Ein heller Blauton mit feiner, weicher Eleganz. Diese stilvolle Designfarbe schafft eine ruhige und hochwertige Wohnatmosphäre.', true, 152),
  ('#5A7A98', 'Slate Blue',           'Sky', 4, 'Ein ausdrucksstarker Blauton mit architektonischem Charakter. Die hochwertige Wandfarbe wirkt modern, souverän und besonders edel.', true, 153),
  ('#6A8090', 'Smoky Blue',           'Sky', 5, 'Ein gedämpfter Blauton mit stilvoller Tiefe und viel Ruhe. Diese elegante Innenfarbe schenkt dem Raum eine entspannte und moderne Eleganz.', true, 154),
  ('#D8E8F0', 'Ice Blue',             'Sky', 6, 'Ein frischer, heller Blauton mit luftiger und gepflegter Wirkung. Die sanfte Wandfarbe lässt Räume offen, freundlich und stilvoll erscheinen.', true, 155),
  ('#1E3A5A', 'Navy Mood',            'Sky', 7, 'Ein dunkler Blauton mit edler Zurückhaltung und moderner Stärke. Diese hochwertige Designfarbe verleiht dem Raum Tiefe und eine exklusive Wirkung.', true, 156),
  ('#7A98AA', 'Grey Fjord Blue',      'Sky', 8, 'Ein feiner Blauton mit nordischer Ruhe und stilvoller Klarheit. Die elegante Innenfarbe schafft eine entspannte und hochwertige Atmosphäre.', true, 157),
  ('#4878A0', 'Fjord Blue',           'Sky', 9, 'Ein ausgewogener Blauton mit frischer Tiefe und modernem Charakter. Diese stilvolle Wandfarbe bringt Gelassenheit und Design in den Raum.', true, 158),
  ('#1A3058', 'Night Blue Soft',      'Sky', 10, 'Ein intensiver Blauton mit ruhiger und eleganter Präsenz. Die hochwertige Innenfarbe schenkt Räumen Stil und faszinierende Tiefe.', true, 159),
  ('#1844A0', 'Sapphire Blue',        'Sky', 11, 'Ein kräftiger Blauton mit edler Klarheit und designstarker Wirkung. Diese moderne Wandfarbe setzt ein ausdrucksstarkes und stilvolles Statement.', true, 160),
  ('#1838B0', 'Royal Blue Touch',     'Sky', 12, 'Ein markanter Blauton mit luxuriösem Charakter und beeindruckender Tiefe. Die exklusive Innenfarbe macht Räume souverän, kraftvoll und besonders.', true, 161),

  -- ===== OCEAN COLLECTION (Petrol/Turquoise tones) =====
  ('#8AB8C0', 'Ice Petrol',           'Ocean', 1, 'Ein kühler Petrolton mit frischer Eleganz und moderner Leichtigkeit. Diese hochwertige Wandfarbe bringt Ruhe und besonderen Designcharakter in den Raum.', true, 170),
  ('#7A9EA0', 'Turquoise Grey',       'Ocean', 2, 'Eine moderne Mischung aus Türkis und Grau mit ruhiger Raffinesse. Die stilvolle Innenfarbe wirkt entspannt, hochwertig und zeitgemäß.', true, 171),
  ('#3A8088', 'Petrol Soft',          'Ocean', 3, 'Ein ausgewogener Petrolton mit angenehmer Tiefe und urbanem Charakter. Diese elegante Designfarbe schenkt dem Raum Ruhe und moderne Eleganz.', true, 172),
  ('#388880', 'Sea Green Petrol',     'Ocean', 4, 'Ein frischer Farbton zwischen Meergrün und Petrol mit natürlicher Raffinesse. Die hochwertige Wandfarbe bringt Frische, Stil und Leichtigkeit an die Wand.', true, 173),
  ('#1A5A68', 'Deep Petrol',          'Ocean', 5, 'Ein markanter Petrolton mit ausdrucksstarker Tiefe und hochwertiger Wirkung. Diese moderne Innenfarbe setzt elegante und starke Designakzente.', true, 174),
  ('#3A6068', 'Smoky Petrol',         'Ocean', 6, 'Ein gedämpfter Petrolton mit ruhiger Eleganz und raffinierter Zurückhaltung. Die stilvolle Designfarbe schenkt dem Zuhause Tiefe und entspannte Klasse.', true, 175),
  ('#70C0C4', 'Soft Turquoise',       'Ocean', 7, 'Ein sanfter Türkiston mit luftiger Frische und leichter Eleganz. Diese frische Wandfarbe bringt eine freundliche und moderne Atmosphäre in den Raum.', true, 176),
  ('#0E4850', 'Ocean Petrol',         'Ocean', 8, 'Ein tiefer, maritimer Ton mit moderner Stärke und klarer Wirkung. Die hochwertige Innenfarbe macht Räume stilvoll, ruhig und besonders.', true, 177),
  ('#406870', 'Mineral Petrol',       'Ocean', 9, 'Ein feiner Petrolton mit kühler Mineralität und eleganter Ruhe. Diese Designfarbe verleiht der Wand eine hochwertige, architektonische Ausstrahlung.', true, 178),
  ('#185868', 'Atlantic Petrol',      'Ocean', 10, 'Ein kräftiger Petrolton mit maritimer Tiefe und urbaner Eleganz. Die stilvolle Wandfarbe bringt Stärke und Designanspruch in moderne Wohnwelten.', true, 179),
  ('#18B0B8', 'Caribbean Turquoise',  'Ocean', 11, 'Ein frischer, lebendiger Türkiston mit exklusiver Leuchtkraft. Diese hochwertige Innenfarbe bringt Leichtigkeit, Frische und ein stilvolles Urlaubsgefühl ins Zuhause.', true, 180),
  ('#084048', 'Power Petrol',         'Ocean', 12, 'Ein intensiver Petrolton mit starker Präsenz und moderner Luxusanmutung. Die markante Designfarbe verleiht Räumen Charakter, Tiefe und echtes Designerflair.', true, 181),

  -- ===== VELVET COLLECTION (Violet tones) =====
  ('#A898B0', 'Lilac Grey',           'Velvet', 1, 'Ein sanfter Violettton mit grauer Eleganz und moderner Ruhe. Diese hochwertige Wandfarbe schafft eine stilvolle und entspannte Atmosphäre.', true, 190),
  ('#B08898', 'Mauve Touch',          'Velvet', 2, 'Ein feiner Violettton mit warmer, weicher Raffinesse. Die elegante Innenfarbe bringt Romantik und Stil in eine moderne Wohnwelt.', true, 191),
  ('#C0B0D0', 'Lavender Soft',        'Velvet', 3, 'Ein heller Lavendelton mit sanfter Frische und leichter Eleganz. Diese Designfarbe wirkt freundlich, gepflegt und wunderbar entspannend.', true, 192),
  ('#7A5080', 'Plum Mood',            'Velvet', 4, 'Ein tieferer Violettton mit stilvoller Wärme und besonderem Charakter. Die hochwertige Wandfarbe verleiht dem Raum Tiefe und moderne Sinnlichkeit.', true, 193),
  ('#5A3060', 'Aubergine Soft',       'Velvet', 5, 'Ein eleganter dunkler Violettton mit luxuriöser Ruhe. Diese exklusive Innenfarbe schafft ein wohnliches und stilvolles Ambiente.', true, 194),
  ('#7A6888', 'Urban Violet Grey',    'Velvet', 6, 'Eine moderne Mischung aus Violett und Grau mit klarer Designwirkung. Die stilvolle Wandfarbe wirkt edel, ruhig und außergewöhnlich hochwertig.', true, 195),
  ('#C488A8', 'Rose Violet',          'Velvet', 7, 'Ein feiner Farbton zwischen Rose und Violett mit sanfter Eleganz. Diese hochwertige Innenfarbe bringt Weichheit und Raffinesse in den Raum.', true, 196),
  ('#686080', 'Slate Lilac',          'Velvet', 8, 'Ein kühler Violettton mit moderner Zurückhaltung und architektonischer Tiefe. Die elegante Designfarbe verleiht Räumen Charakter und stilvolle Ruhe.', true, 197),
  ('#5A2858', 'Blackberry Mood',      'Velvet', 9, 'Ein satter Violettton mit fruchtiger Tiefe und luxuriöser Ausstrahlung. Diese ausdrucksstarke Wandfarbe macht Räume elegant und unverwechselbar.', true, 198),
  ('#9090A8', 'Lavender Grey',        'Velvet', 10, 'Ein ausgewogener Violettton mit sanfter und ruhiger Modernität. Die hochwertige Innenfarbe schafft eine entspannte und gepflegte Wohnatmosphäre.', true, 199),
  ('#5A1878', 'Velvet Violet',        'Velvet', 11, 'Ein intensiver Violettton mit edler Tiefe und weicher Luxuswirkung. Diese markante Designfarbe bringt glamouröse Eleganz an die Wand.', true, 200),
  ('#3A0858', 'Deep Violet',          'Velvet', 12, 'Ein kraftvoller Violettton mit starker Präsenz und ausdrucksstarker Tiefe. Die exklusive Wandfarbe setzt ein stilvolles Statement mit Charakter.', true, 201),

  -- ===== SIGNATURE BLACK COLLECTION =====
  ('#484848', 'Graphite Touch',       'Black', 1, 'Ein eleganter Dunkelton mit moderner Ruhe und klarer Tiefe. Diese hochwertige Wandfarbe verleiht Räumen Struktur und stilvolle Stärke.', true, 210),
  ('#3A3E44', 'Slate Anthracite',     'Black', 2, 'Ein markanter Dunkelton mit architektonischer Wirkung und urbanem Charakter. Die moderne Innenfarbe macht Räume souverän und hochwertig.', true, 211),
  ('#333638', 'Pure Anthracite',      'Black', 3, 'Ein zeitloser Anthrazitton mit ruhiger, kraftvoller Eleganz. Diese stilvolle Designfarbe bringt Tiefe, Stil und klare Wohnästhetik an die Wand.', true, 212),
  ('#282C30', 'Deep Anthracite',      'Black', 4, 'Ein intensiver Dunkelton mit luxuriöser Präsenz und moderner Stärke. Die hochwertige Wandfarbe schenkt dem Raum Tiefe und eine exklusive Wirkung.', true, 213),
  ('#2A2A2E', 'Onyx Grey',            'Black', 5, 'Ein dunkler Grauton mit edler Onyx-Anmutung und stilvoller Ruhe. Diese Premium-Innenfarbe wirkt kraftvoll, hochwertig und außergewöhnlich elegant.', true, 214),
  ('#302824', 'Warm Black Grey',      'Black', 6, 'Ein warmer Dunkelton mit wohnlicher Tiefe und sanfter Stärke. Die hochwertige Wandfarbe macht Räume dunkel, aber dennoch angenehm und einladend.', true, 215),
  ('#222020', 'Smoky Black',          'Black', 7, 'Ein gedämpfter Schwarzton mit weicher und stilvoller Ausstrahlung. Diese Designfarbe bringt Tiefe und raffinierte Ruhe in moderne Wohnräume.', true, 216),
  ('#1C2028', 'Cool Black',           'Black', 8, 'Ein kühler Schwarzton mit klarer, moderner Wirkung. Die elegante Innenfarbe verleiht der Wand eine präzise und starke Designwirkung.', true, 217),
  ('#1E1E22', 'Metallic Black',       'Black', 9, 'Ein besonderer Dunkelton mit technischer Raffinesse und edlem Charakter. Diese hochwertige Wandfarbe wirkt modern, exklusiv und außergewöhnlich.', true, 218),
  ('#141418', 'Deep Black Soft',      'Black', 10, 'Ein intensiver Dunkelton mit sanfter Tiefe und eleganter Präsenz. Die stilvolle Innenfarbe bringt Ruhe, Luxus und moderne Stärke in den Raum.', true, 219),
  ('#101014', 'Designer Black',       'Black', 11, 'Ein markanter Schwarzton mit starker Designwirkung und moderner Exklusivität. Diese Premium-Wandfarbe setzt ein klares Statement mit Klasse.', true, 220),
  ('#0A0A0E', 'Intense Black',        'Black', 12, 'Ein kraftvoller Schwarzton mit maximaler Tiefe und beeindruckender Präsenz. Die ausdrucksstarke Innenfarbe macht Räume elegant, mutig und unverwechselbar.', true, 221);
