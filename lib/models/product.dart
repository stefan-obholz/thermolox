class Product {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final double? price; // optional, falls noch nicht sauber gemappt
  final String? handle;
  final List<String> tags;

  const Product({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.price,
    this.handle,
    this.tags = const [],
  });
}
