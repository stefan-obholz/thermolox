import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_model.dart';
import '../pages/cart_page.dart';

class CartAction extends StatelessWidget {
  const CartAction({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartModel>();
    final count = cart.totalItemsOrZero; // siehe Hinweis unten

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Transform.translate(
        offset: const Offset(-10, 0), // ~10px nach links
        child: Transform.scale(
          scale: 1.2, // 1,2x größer
          child: IconButton(
            tooltip: 'Warenkorb',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_outlined),
                if (count > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CartPage()));
            },
          ),
        ),
      ),
    );
  }
}
