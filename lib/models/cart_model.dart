import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'product.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}

class CartModel extends ChangeNotifier {
  final List<CartItem> _items = [];

  UnmodifiableListView<CartItem> get items => UnmodifiableListView(_items);

  /// Gesamtanzahl aller Produkte (für Badge)
  int get itemCount => _items.fold<int>(0, (sum, item) => sum + item.quantity);

  /// Gesamtsumme
  double get totalPrice => _items.fold<double>(
    0.0,
    (sum, item) => sum + (item.product.price ?? 0.0) * item.quantity,
  );

/// Mülltonne, Produktanzahl im Warenkorb auf 0
  int get totalItemsOrZero {
  return items.fold<int>(0, (sum, it) => sum + it.quantity);
}

  void add(Product product) {
    final index = _items.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(product: product, quantity: 1));
    }
    notifyListeners();
  }

  void increment(Product product) {
    final index = _items.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
    }
  }

  void decrement(Product product) {
    final index = _items.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      final item = _items[index];
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void remove(Product product) {
    _items.removeWhere((it) => it.product.id == product.id);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
