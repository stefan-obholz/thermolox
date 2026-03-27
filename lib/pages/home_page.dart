import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import '../widgets/cart_icon_button.dart';
import '../theme/app_theme.dart';
import '../models/content_item.dart';
import '../models/product.dart';
import '../services/content_service.dart';
import '../services/shopify_service.dart';
import 'blog_page.dart';
import 'content_detail_page.dart';
import 'products_page.dart';
import 'product_detail_page.dart';

// ── Design constants ──

const _dark = Color(0xFF1A1614);
const _gray = Color(0xFF6B635D);
const _warmBg = Color(0xFFFAFAF9);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Product>> _productsFuture;
  late Future<List<ContentItem>> _articlesFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = ShopifyService.fetchProducts();
    _articlesFuture = ContentService.fetchArticles();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _warmBg,
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 44,
        title: SizedBox(
          height: 44,
          child: ClipRect(
            child: OverflowBox(
              maxHeight: 120,
              child: SvgPicture.asset(
                'assets/brand/EVERLOXX_LOGO.svg',
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        actions: const [CartIconButton()],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewPadding.bottom + 56 + 70,
        ),
        children: [
          const _HeroVideoSection(),
          const _UspStrip(),
          _FeaturedColorsSection(productsFuture: _productsFuture),
          const _StepsSection(),
          const _TrustStatsBar(),
          const _AppBannerSection(),
          _BlogTeaserSection(articlesFuture: _articlesFuture),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// A. Hero Video
// ─────────────────────────────────────────────────────────────────────────────

class _HeroVideoSection extends StatefulWidget {
  const _HeroVideoSection();

  @override
  State<_HeroVideoSection> createState() => _HeroVideoSectionState();
}

class _HeroVideoSectionState extends State<_HeroVideoSection> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(
        'https://cdn.shopify.com/videos/c/o/v/31a8ce5b004e491dbd5a3615c5b917c7.mp4',
      ),
    )..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller
            ..setLooping(true)
            ..setVolume(0)
            ..play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = screenHeight * 0.75;

    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video / placeholder
          if (_initialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            )
          else
            Container(color: _dark),

          // Top fade: white -> transparent
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCCFFFFFF), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),

          // Bottom gradient: black 50% -> transparent
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: heroHeight * 0.6,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0x80000000),
                    Color(0x26000000),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),

          // Text overlay
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dein',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamilyHeading,
                    fontSize: 42,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                Text(
                  'Wohlfühl-Zuhause.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamilyHeading,
                    fontSize: 42,
                    fontWeight: FontWeight.w300,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Premium-Wandfarben für Räume, die sich so gut\nanfühlen, wie sie aussehen.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProductsPage()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Text(
                      'FARBTÖNE ENTDECKEN',
                      style: TextStyle(
                        color: _dark,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// B. USP Strip
// ─────────────────────────────────────────────────────────────────────────────

class _UspStrip extends StatelessWidget {
  const _UspStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      _UspItem(Icons.palette, '132 Farbtöne', 'Kuratierte Premium-Auswahl'),
      _UspItem(Icons.home, 'Energiesparend', 'Bis zu 42 % Heizkosten sparen'),
      _UspItem(Icons.eco, '100% Wohngesund', 'Ohne Lösemittel & Weichmacher'),
      _UspItem(Icons.shield_outlined, 'Premium-Qualität', 'Beste Deckkraft & Haltbarkeit'),
      _UspItem(Icons.brush, 'Einfach selbst machen', 'Ohne Handwerker'),
    ];

    return Container(
      color: const Color(0xFF505050),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: items
              .map(
                (item) => Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, color: Colors.white, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _UspItem {
  final IconData icon;
  final String title;
  final String subtitle;
  const _UspItem(this.icon, this.title, this.subtitle);
}

// ─────────────────────────────────────────────────────────────────────────────
// C. Featured Colors (Horizontal Carousel)
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturedColorsSection extends StatelessWidget {
  final Future<List<Product>> productsFuture;
  const _FeaturedColorsSection({required this.productsFuture});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Beliebte Farbtöne',
              style: TextStyle(
                fontFamily: AppTheme.fontFamilyHeading,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Unsere meistgewählten Premium-Wandfarben',
              style: TextStyle(fontSize: 14, color: _gray),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: FutureBuilder<List<Product>>(
              future: productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const Center(
                    child: Text('Keine Farbtöne verfügbar.'),
                  );
                }
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: products.length > 10 ? 10 : products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _ProductCard(product: product);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(product: product),
        ),
      ),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or color swatch
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: product.imageUrl != null
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _colorSwatch(),
                      )
                    : _colorSwatch(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (product.price != null)
                    Text(
                      '${product.price!.toStringAsFixed(2)} \u20AC',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorSwatch() {
    final hex = product.hex;
    Color color = const Color(0xFFE0D5C8);
    if (hex != null && hex.isNotEmpty) {
      final cleaned = hex.replaceAll('#', '');
      if (cleaned.length == 6) {
        color = Color(int.parse('FF$cleaned', radix: 16));
      }
    }
    return Container(color: color);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// D. Steps Section
// ─────────────────────────────────────────────────────────────────────────────

class _StepsSection extends StatelessWidget {
  const _StepsSection();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 400;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Text(
            'So einfach geht\u2019s',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamilyHeading,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'In drei Schritten zum Wohlfühl-Zuhause',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _gray),
          ),
          const SizedBox(height: 32),
          isNarrow
              ? Column(
                  children: _buildSteps()
                      .expand((w) => [w, const SizedBox(height: 24)])
                      .toList()
                    ..removeLast(),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildSteps()
                      .map<Widget>(
                        (w) => Expanded(child: w),
                      )
                      .toList(),
                ),
        ],
      ),
    );
  }

  List<Widget> _buildSteps() {
    return const [
      _StepTile(
        icon: Icons.palette,
        number: '1',
        title: 'Farbton wählen',
        subtitle: 'Über 132 kuratierte Farbtöne',
      ),
      _StepTile(
        icon: Icons.shopping_cart,
        number: '2',
        title: 'Bestellen & Liefern',
        subtitle: 'Direkt aus der App \u2014 versandkostenfrei ab 99\u20AC',
      ),
      _StepTile(
        icon: Icons.brush,
        number: '3',
        title: 'Streichen & Genießen',
        subtitle: 'Rolle oder Pinsel \u2014 sofort wohnbereit',
      ),
    ];
  }
}

class _StepTile extends StatelessWidget {
  final IconData icon;
  final String number;
  final String title;
  final String subtitle;

  const _StepTile({
    required this.icon,
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 26, color: _dark),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: _gray, height: 1.4),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// E. Trust Stats Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TrustStatsBar extends StatelessWidget {
  const _TrustStatsBar();

  @override
  Widget build(BuildContext context) {
    const stats = [
      _StatItem('50%', 'Wärmestrahlung\nreflektiert'),
      _StatItem('42%', 'weniger Heizkosten\nmöglich'),
      _StatItem('132', 'Premium-\nFarbtöne'),
      _StatItem('0%', 'Lösemittel'),
    ];

    return Container(
      color: AppTheme.accent,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        runSpacing: 20,
        children: stats
            .map(
              (s) => SizedBox(
                width: 155,
                child: Column(
                  children: [
                    Text(
                      s.number,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamilyHeading,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _dark,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _StatItem {
  final String number;
  final String label;
  const _StatItem(this.number, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
// F. App Banner
// ─────────────────────────────────────────────────────────────────────────────

class _AppBannerSection extends StatelessWidget {
  const _AppBannerSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _dark,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/EVERLOXX_ICON.png',
              width: 80,
              height: 80,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Farben live an deiner Wand',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamilyHeading,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Teste jeden Farbton per AR-Vorschau',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Kostenlos \u00B7 132 Farbtöne \u00B7 iOS & Android',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// G. Blog Teaser
// ─────────────────────────────────────────────────────────────────────────────

class _BlogTeaserSection extends StatelessWidget {
  final Future<List<ContentItem>> articlesFuture;
  const _BlogTeaserSection({required this.articlesFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ContentItem>>(
      future: articlesFuture,
      builder: (context, snapshot) {
        final articles = snapshot.data ?? [];
        if (articles.isEmpty && snapshot.connectionState == ConnectionState.done) {
          // Static placeholder
          return _staticBlogPlaceholder(context);
        }
        if (articles.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 32, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ratgeber & Inspiration',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamilyHeading,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BlogPage()),
                      ),
                      child: Text(
                        'Alle anzeigen',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 170,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: articles.length > 6 ? 6 : articles.length,
                  itemBuilder: (context, index) {
                    final article = articles[index];
                    return _BlogCard(article: article);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _staticBlogPlaceholder(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ratgeber & Inspiration',
            style: TextStyle(
              fontFamily: AppTheme.fontFamilyHeading,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bald verfügbar \u2014 Tipps rund um Wandfarben, Raumgestaltung und Energiesparen.',
            style: TextStyle(fontSize: 14, color: _gray),
          ),
        ],
      ),
    );
  }
}

class _BlogCard extends StatelessWidget {
  final ContentItem article;
  const _BlogCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final tag = article.blogTitle ?? article.tags.firstOrNull;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContentDetailPage(item: article),
        ),
      ),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tag != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: Text(
                article.title,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
