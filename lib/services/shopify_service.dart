import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/shopify_config.dart';
import '../models/product.dart';

class ShopifyService {
  static List<Product>? _cache;
  static const _diskKey = 'product_catalog_cache';

  /// Holt Produkte: Supabase (SSOT) → Disk-Cache → Shopify (Fallback).
  static Future<List<Product>> fetchProducts() async {
    if (_cache != null) return _cache!;

    // 1. Try Supabase (Single Source of Truth)
    try {
      final response = await Supabase.instance.client
          .from('palette_colors')
          .select()
          .eq('status', 'active')
          .order('sort_order')
          .timeout(const Duration(seconds: 10));

      final rows = response as List<dynamic>;
      if (rows.isNotEmpty) {
        final products =
            rows.map((r) => Product.fromSupabase(r as Map<String, dynamic>)).toList();
        _cache = products;
        _saveToDisk(products);
        if (kDebugMode) debugPrint('Products loaded from Supabase: ${products.length}');
        return products;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Supabase product fetch failed: $e');
    }

    // 2. Try Disk Cache
    final cached = await _loadFromDisk();
    if (cached.isNotEmpty) {
      _cache = cached;
      if (kDebugMode) debugPrint('Products loaded from disk cache: ${cached.length}');
      return cached;
    }

    // 3. Fallback: Shopify Storefront API
    if (kDebugMode) debugPrint('Falling back to Shopify Storefront API');
    return _fetchFromShopify();
  }

  /// Creates a Shopify Storefront checkout and returns the web URL.
  /// If [customerAccessToken] is provided, associates the checkout with
  /// the logged-in Shopify customer account.
  static Future<String> createCheckoutUrl(
      List<Map<String, dynamic>> lineItems,
      {String? customerAccessToken}) async {
    final mutation = '''
mutation {
  checkoutCreate(input: {
    lineItems: [
      ${lineItems.map((item) => '{ variantId: "${item['variantId']}", quantity: ${item['quantity']} }').join(',\n      ')}
    ]
  }) {
    checkout {
      webUrl
    }
    checkoutUserErrors {
      message
      field
    }
  }
}
''';

    final response = await http.post(
      Uri.parse(ShopifyConfig.graphQLEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token':
            ShopifyConfig.storefrontAccessToken,
      },
      body: jsonEncode({'query': mutation}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Shopify Checkout-Fehler: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final errors = data['data']?['checkoutCreate']?['checkoutUserErrors']
        as List<dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      final msg = errors.map((e) => e['message']).join(', ');
      throw Exception('Checkout-Fehler: $msg');
    }

    final webUrl =
        data['data']?['checkoutCreate']?['checkout']?['webUrl'] as String?;
    if (webUrl == null) {
      throw Exception('Keine Checkout-URL erhalten.');
    }

    // If a Shopify customer access token is available, append it so the
    // checkout page can pre-fill customer details.
    if (customerAccessToken != null && customerAccessToken.isNotEmpty) {
      final uri = Uri.parse(webUrl);
      final updatedUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'logged_in_customer_id': customerAccessToken,
      });
      return updatedUri.toString();
    }

    return webUrl;
  }

  static void invalidate() => _cache = null;

  // ---- Shopify Fallback ----

  static Future<List<Product>> _fetchFromShopify() async {
    final response = await http.post(
      Uri.parse(ShopifyConfig.graphQLEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token':
            ShopifyConfig.storefrontAccessToken,
      },
      body: jsonEncode({'query': _productsQuery}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Fehler bei Shopify: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> edges =
        data['data']?['products']?['edges'] as List<dynamic>? ?? const [];

    final products = edges.map<Product>((edge) {
      final Map<String, dynamic> node =
          edge['node'] as Map<String, dynamic>;

      final List<dynamic> imageEdges =
          node['images']?['edges'] as List<dynamic>? ?? const [];
      final Map<String, dynamic>? firstImageNode = imageEdges.isNotEmpty
          ? imageEdges.first['node'] as Map<String, dynamic>?
          : null;

      String? variantId;
      final List<dynamic>? variantEdges =
          node['variants']?['edges'] as List<dynamic>?;
      if (variantEdges != null && variantEdges.isNotEmpty) {
        final Map<String, dynamic>? variantNode =
            variantEdges.first['node'] as Map<String, dynamic>?;
        variantId = variantNode?['id'] as String?;
      }

      return Product(
        id: node['id'] as String,
        title: node['title'] as String? ?? '',
        description: node['description'] as String?,
        imageUrl: firstImageNode != null
            ? firstImageNode['url'] as String?
            : null,
        price: _extractPrice(node),
        handle: node['handle'] as String?,
        tags: (node['tags'] as List<dynamic>? ?? const [])
            .map((tag) => tag.toString())
            .toList(),
        variantId: variantId,
      );
    }).toList();

    _cache = products;
    return products;
  }

  static double? _extractPrice(Map<String, dynamic> node) {
    try {
      final variants =
          node['variants']?['edges'] as List<dynamic>?;
      if (variants == null || variants.isEmpty) return null;
      final firstVariant =
          variants.first['node'] as Map<String, dynamic>;
      final price = firstVariant['price'] as Map<String, dynamic>?;
      if (price == null) return null;
      final amountStr = price['amount'] as String?;
      if (amountStr == null) return null;
      return double.parse(amountStr);
    } catch (_) {
      return null;
    }
  }

  // ---- Disk Cache ----

  static Future<void> _saveToDisk(List<Product> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = products
          .map((p) => {
                'id': p.id,
                'name': p.title,
                'description': p.description,
                'hex': p.hex,
                'price_eur': p.price,
                'sku': p.sku,
                'group_name': p.groupName,
                'collection_name': p.collectionName,
                'collection_description': p.collectionDescription,
                'product_type': p.productType,
                'is_interior': p.isInterior,
                'tags': p.tags,
                'image_url_1': p.imageUrl,
                'shopify_product_id': p.shopifyProductId,
                'shopify_variant_id': p.variantId,
                'status': 'active',
              })
          .toList();
      await prefs.setString(_diskKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  static Future<List<Product>> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskKey);
      if (raw == null) return [];
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Product.fromSupabase(e as Map<String, dynamic>))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }
}

const String _productsQuery = r'''
{
  products(first: 250) {
    edges {
      node {
        id
        title
        handle
        tags
        description
        images(first: 5) {
          edges {
            node {
              url
            }
          }
        }
        variants(first: 1) {
          edges {
            node {
              id
              price {
                amount
                currencyCode
              }
            }
          }
        }
      }
    }
  }
}
''';
