import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/shopify_config.dart';
import '../models/product.dart';
import '../services/shopify_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_price.dart';
import '../widgets/cart_icon_button.dart';
import 'product_detail_page.dart';

// ── Model for a color group from Supabase ──

class ColorGroup {
  final String name;
  final String slug;
  final String hex;
  final int sortOrder;

  const ColorGroup({
    required this.name,
    required this.slug,
    required this.hex,
    required this.sortOrder,
  });

  factory ColorGroup.fromJson(Map<String, dynamic> json) => ColorGroup(
        name: json['name'] as String,
        slug: json['slug'] as String,
        hex: json['hex'] as String,
        sortOrder: json['sort_order'] as int,
      );

  Color get color {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    return const Color(0xFFCCCCCC);
  }
}

const _dark = Color(0xFF1A1614);

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late Future<List<Product>> _productsFuture;
  late Future<List<ColorGroup>> _groupsFuture;
  String? _activeGroup; // null = "Alle"

  @override
  void initState() {
    super.initState();
    _productsFuture = ShopifyService.fetchProducts();
    _groupsFuture = _fetchColorGroups();
  }

  static Future<List<ColorGroup>> _fetchColorGroups() async {
    try {
      final response = await Supabase.instance.client
          .from('color_groups')
          .select()
          .order('sort_order')
          .timeout(const Duration(seconds: 10));

      final rows = response as List<dynamic>;
      return rows
          .map((r) => ColorGroup.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)),
    );
  }

  bool _isHiddenProduct(Product product) {
    final title = product.title.toLowerCase();
    for (final keyword in ShopifyConfig.hiddenProductTitleKeywords) {
      final match = keyword.trim().toLowerCase();
      if (match.isEmpty) continue;
      if (title.contains(match)) return true;
    }

    final handle = product.handle?.toLowerCase();
    if (handle != null &&
        ShopifyConfig.hiddenProductHandles.contains(handle)) {
      return true;
    }

    for (final tag in product.tags) {
      final lowerTag = tag.toLowerCase();
      if (ShopifyConfig.hiddenProductTags.contains(lowerTag)) {
        return true;
      }
    }

    return false;
  }

  List<Product> _applyFilter(List<Product> products) {
    if (_activeGroup == null) return products;
    return products.where((p) => p.groupName == _activeGroup).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navBarPadding =
        MediaQuery.of(context).viewPadding.bottom + 56 + 70;

    return EverloxxScaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Farbtöne',
          style: TextStyle(
            fontFamily: AppTheme.fontFamilyHeading,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: theme.textTheme.headlineLarge?.color,
          ),
        ),
        actions: const [CartIconButton()],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: FutureBuilder<List<Object>>(
        future: Future.wait([_productsFuture, _groupsFuture]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Fehler beim Laden:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final data = snapshot.data!;
          final products = data[0] as List<Product>;
          final groups = data[1] as List<ColorGroup>;
          final visibleProducts =
              products.where((p) => !_isHiddenProduct(p)).toList();
          final filtered = _applyFilter(visibleProducts);

          return Column(
            children: [
              // ── Farbfilter-Leiste (aus Supabase) ──
              _ColorFilterBar(
                groups: groups,
                activeGroup: _activeGroup,
                productCount: filtered.length,
                onSelected: (group) =>
                    setState(() => _activeGroup = group),
              ),

              // ── Produkt-Grid ──
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _productsFuture = ShopifyService.fetchProducts();
                      _groupsFuture = _fetchColorGroups();
                    });
                    await Future.wait([_productsFuture, _groupsFuture]);
                  },
                  child: filtered.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Text(
                                'Keine Farbtöne in dieser Kategorie.',
                                style: TextStyle(color: Color(0xFF6B635D)),
                              ),
                            ),
                          ],
                        )
                      : GridView.builder(
                          padding:
                              EdgeInsets.fromLTRB(12, 12, 12, navBarPadding),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.68,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _ProductCard(
                              product: filtered[index],
                              onTap: () => _openProduct(filtered[index]),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Farbfilter-Leiste (Daten aus Supabase color_groups)
// ─────────────────────────────────────────────────────────────────────────────

class _ColorFilterBar extends StatelessWidget {
  final List<ColorGroup> groups;
  final String? activeGroup;
  final int productCount;
  final ValueChanged<String?> onSelected;

  const _ColorFilterBar({
    required this.groups,
    required this.activeGroup,
    required this.productCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE8E4E0), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '$productCount Farbtöne',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B635D),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: groups.length + 1, // +1 for "Alle"
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                // Index 0 = "Alle", rest = groups
                final isAlleButton = index == 0;
                final isActive = isAlleButton
                    ? activeGroup == null
                    : groups[index - 1].name == activeGroup;
                final label =
                    isAlleButton ? 'Alle' : groups[index - 1].name;

                return GestureDetector(
                  onTap: () => onSelected(
                      isAlleButton ? null : groups[index - 1].name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? _dark : Colors.transparent,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: isActive ? _dark : const Color(0xFFD0CBC5),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Farb-Dot
                        if (isAlleButton)
                          Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  Color(0xFFC4A8AD),
                                  Color(0xFFA85A3A),
                                  Color(0xFFC8A854),
                                  Color(0xFF7A8A78),
                                  Color(0xFF5A7A98),
                                  Color(0xFF5A3060),
                                  Color(0xFFC4A8AD),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: groups[index - 1].color,
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isActive ? Colors.white : _dark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Produkt-Karte (Website-Style)
// ─────────────────────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bild
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: product.imageUrl != null
                    ? Hero(
                        tag: 'product-image-${product.id}',
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.contain,
                          cacheWidth: 400,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.broken_image,
                                color: Color(0xFFBDB5AD)),
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.image_not_supported,
                            color: Color(0xFFBDB5AD)),
                      ),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _dark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPrice(product.price ?? 0.0),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B635D),
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
}
