class Product {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final double? price;
  final String? handle;
  final List<String> tags;
  final String? variantId;

  // New SSOT fields from Supabase
  final String? hex;
  final String? sku;
  final String? groupName;
  final String? collectionName;
  final String? collectionDescription;
  final String? productType;
  final bool isInterior;
  final List<String> imageUrls;
  final String? shopifyProductId;
  final String? shopifyVariantId;

  const Product({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.price,
    this.handle,
    this.tags = const [],
    this.variantId,
    this.hex,
    this.sku,
    this.groupName,
    this.collectionName,
    this.collectionDescription,
    this.productType,
    this.isInterior = true,
    this.imageUrls = const [],
    this.shopifyProductId,
    this.shopifyVariantId,
  });

  /// Creates a Product from a Supabase palette_colors row.
  factory Product.fromSupabase(Map<String, dynamic> row) {
    final images = <String>[
      if (row['image_url_1'] != null) row['image_url_1'] as String,
      if (row['image_url_2'] != null) row['image_url_2'] as String,
      if (row['image_url_3'] != null) row['image_url_3'] as String,
      if (row['image_url_4'] != null) row['image_url_4'] as String,
      if (row['image_url_5'] != null) row['image_url_5'] as String,
    ];

    final tagsList = (row['tags'] as List<dynamic>?)
            ?.map((t) => t.toString())
            .toList() ??
        const [];

    return Product(
      id: row['id'] as String,
      title: row['name'] as String,
      description: row['description'] as String?,
      imageUrl: images.isNotEmpty ? images.first : null,
      price: (row['price_eur'] as num?)?.toDouble(),
      handle: (row['name'] as String?)
          ?.toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      tags: tagsList,
      variantId: row['shopify_variant_id'] as String?,
      hex: row['hex'] as String?,
      sku: row['sku'] as String?,
      groupName: row['group_name'] as String?,
      collectionName: row['collection_name'] as String?,
      collectionDescription: row['collection_description'] as String?,
      productType: row['product_type'] as String?,
      isInterior: row['is_interior'] as bool? ?? true,
      imageUrls: images,
      shopifyProductId: row['shopify_product_id'] as String?,
      shopifyVariantId: row['shopify_variant_id'] as String?,
    );
  }
}
