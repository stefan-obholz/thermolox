class Product {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final double? price; // optional, falls noch nicht sauber gemappt

  const Product({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.price,
  });
}
