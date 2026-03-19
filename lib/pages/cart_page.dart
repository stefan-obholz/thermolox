import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/cart_model.dart';
import '../services/shopify_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_price.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _checkoutLoading = false;

  Future<void> _startCheckout(CartModel cart) async {
    final lineItems = <Map<String, dynamic>>[];
    for (final item in cart.items) {
      final variantId = item.product.variantId;
      if (variantId == null) continue;
      lineItems.add({'variantId': variantId, 'quantity': item.quantity});
    }
    if (lineItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Produkte zum Auschecken.')),
        );
      }
      return;
    }

    setState(() => _checkoutLoading = true);
    try {
      final url = await ShopifyService.createCheckoutUrl(lineItems);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('URL konnte nicht geöffnet werden.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkout-Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkoutLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartModel>(); // ✅ EINMAL holen, überall nutzbar
    final tokens = context.everloxxTokens;

    final baseSize = theme.textTheme.bodyLarge?.fontSize ?? 16;
    final totalLabelStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: baseSize * 1.2,
      fontWeight: FontWeight.w700,
    );
    final totalValueStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: baseSize * 1.2,
      fontWeight: FontWeight.w800,
    );

    return EverloxxScaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Warenkorb',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.0,
          ),
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,

      body: cart.items.isEmpty
          ? const Center(child: Text('Dein Warenkorb ist noch leer.'))
          : ListView.separated(
              padding: EdgeInsets.symmetric(
                vertical: tokens.screenPadding,
              ),
              itemCount: cart.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = cart.items[index];
                final product = item.product;
                final quantity = item.quantity;
                final price = product.price ?? 0.0;
                final lineTotal = price * quantity;

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        if (product.imageUrl != null)
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(tokens.radiusXs),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: Image.network(
                                product.imageUrl!,
                                fit: BoxFit.cover,
                                cacheWidth: 112,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusXs),
                              color: const Color(0xFFD8DEE4),
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
                                '${formatPrice(price)} × $quantity',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatPrice(lineTotal),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () => cart.decrement(product),
                                ),
                                Text(
                                  '$quantity',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () => cart.increment(product),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Entfernen',
                              onPressed: () => cart.remove(product),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

      // ✅ Footer als EINE Fläche (kein Strich zwischen "Gesamt" und Button)
      bottomNavigationBar: Material(
        color: theme.scaffoldBackgroundColor,
        elevation: 0, // ✅ KEIN Shadow/Trennkante
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.screenPadding,
                  tokens.screenPadding,
                  tokens.screenPadding,
                  12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Gesamt', style: totalLabelStyle),
                    Text(formatPrice(cart.totalPrice), style: totalValueStyle),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.screenPadding,
                  0,
                  tokens.screenPadding,
                  tokens.screenPadding,
                ),
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _checkoutLoading
                        ? null
                        : () => _startCheckout(cart),
                    child: _checkoutLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Zur Kasse'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
