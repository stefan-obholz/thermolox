import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/cart_model.dart';
import '../theme/app_theme.dart';
import '../utils/thermolox_overlay.dart';
import '../utils/format_price.dart';
import '../widgets/cart_icon_button.dart';

class ProductDetailPage extends StatelessWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartModel>();
    final tokens = context.thermoloxTokens;

    return ThermoloxScaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'THERMOLOX',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.0,
          ),
        ),
        actions: const [CartIconButton()],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          vertical: tokens.screenPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.imageUrl != null)
              Hero(
                tag: 'product-image-${product.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radiusCard),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(product.imageUrl!, fit: BoxFit.cover),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(product.title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              formatPrice(product.price ?? 0.0),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            if (product.description != null &&
                product.description!.trim().isNotEmpty)
              Text(product.description!, style: theme.textTheme.bodyMedium)
            else
              Text(
                'Keine ausführliche Beschreibung vorhanden.',
                style: theme.textTheme.bodyMedium,
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.screenPadding,
            vertical: tokens.screenPadding,
          ),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(
                'In den Warenkorb – ${formatPrice(product.price ?? 0.0)}',
              ),
              onPressed: () {
                cart.add(product);
                ThermoloxOverlay.showSnack(
                  context,
                  'Produkt zum Warenkorb hinzugefügt.',
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
