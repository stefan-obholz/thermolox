// lib/config/shopify_config.dart

class ShopifyConfig {
  // Deine Shop-Domain (ohne https://)
  static const String shopDomain = 'thermolox.myshopify.com';

  // Storefront API Version – kann so bleiben
  static const String apiVersion = '2024-01';

  // DEIN Storefront Access Token
  static const String storefrontAccessToken =
      'eea79adf7c4a72d6d7074638521dcd8f';

  // GraphQL-Endpunkt
  static String get graphQLEndpoint =>
      'https://$shopDomain/api/$apiVersion/graphql.json';
}

// Eine einfache Query, um Produkte zu laden
const String queryProducts = """
{
  products(first: 20) {
    edges {
      node {
        id
        title
        description
        featuredImage {
          url
        }
        priceRange {
          minVariantPrice {
            amount
            currencyCode
          }
        }
      }
    }
  }
}
""";
