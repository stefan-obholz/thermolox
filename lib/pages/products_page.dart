import 'package:flutter/material.dart';

import '../config/shopify_config.dart';
import '../models/product.dart';
import '../services/shopify_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_price.dart';
import '../widgets/cart_icon_button.dart';
import 'product_detail_page.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = ShopifyService.fetchProducts();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.thermoloxTokens;

    return ThermoloxScaffold(
      // ➜ AppBar MIT globalem Warenkorb (wie Referenz)
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Produkte',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.0,
          ),
        ),
        actions: const [CartIconButton()],
      ),

      backgroundColor: theme.scaffoldBackgroundColor,

      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Fehler beim Laden der Produkte:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final products = snapshot.data ?? [];
          final visibleProducts = products
              .where((product) => !_isHiddenProduct(product))
              .toList();

          if (visibleProducts.isEmpty) {
            return const Center(child: Text('Noch keine Produkte gefunden.'));
          }

          return ListView.separated(
            padding: EdgeInsets.symmetric(
              vertical: tokens.screenPadding,
            ),
            itemCount: visibleProducts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final product = visibleProducts[index];

              return InkWell(
                borderRadius: BorderRadius.circular(tokens.radiusCard),
                onTap: () => _openProduct(product),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusCard),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        if (product.imageUrl != null)
                          Hero(
                            tag: 'product-image-${product.id}',
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: Image.network(
                                  product.imageUrl!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                              color: Colors.grey.shade300,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_not_supported),
                          ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.title,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatPrice(product.price ?? 0.0),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (product.description != null &&
                                  product.description!.trim().isNotEmpty)
                                Text(
                                  product.description!,
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),

                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
