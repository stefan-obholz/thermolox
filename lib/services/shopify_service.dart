import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/shopify_config.dart';
import '../models/product.dart';

class ShopifyService {
  /// Holt Produkte aus der Storefront API und mappt sie auf `Product`.
  static Future<List<Product>> fetchProducts() async {
    final response = await http.post(
      Uri.parse(ShopifyConfig.graphQLEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token':
            ShopifyConfig.storefrontAccessToken,
      },
      body: jsonEncode({'query': _productsQuery}),
    );

    if (response.statusCode != 200) {
      throw Exception('Fehler bei Shopify: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // edges = List<dynamic>
    final List<dynamic> edges =
        data['data']?['products']?['edges'] as List<dynamic>? ?? const [];

    return edges.map<Product>((edge) {
      // node = Map<String, dynamic>
      final Map<String, dynamic> node = edge['node'] as Map<String, dynamic>;

      // Bilder
      final List<dynamic> imageEdges =
          node['images']?['edges'] as List<dynamic>? ?? const [];

      final Map<String, dynamic>? firstImageNode = imageEdges.isNotEmpty
          ? imageEdges.first['node'] as Map<String, dynamic>?
          : null;

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
      );
    }).toList();
  }

  static double? _extractPrice(Map<String, dynamic> node) {
    try {
      final List<dynamic>? variants =
          node['variants']?['edges'] as List<dynamic>?;

      if (variants == null || variants.isEmpty) return null;

      final Map<String, dynamic> firstVariant =
          variants.first['node'] as Map<String, dynamic>;
      final Map<String, dynamic>? priceV2 =
          firstVariant['priceV2'] as Map<String, dynamic>?;

      if (priceV2 == null) return null;

      final String? amountStr = priceV2['amount'] as String?;
      if (amountStr == null) return null;

      return double.parse(amountStr);
    } catch (_) {
      return null;
    }
  }
}

/// Dein Query (falls du noch keinen separaten hast)
const String _productsQuery = r'''
{
  products(first: 20) {
    edges {
      node {
        id
        title
        handle
        tags
        description
        images(first: 1) {
          edges {
            node {
              url
            }
          }
        }
        variants(first: 1) {
          edges {
            node {
              priceV2 {
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
