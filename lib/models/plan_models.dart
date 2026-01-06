class PlanCardData {
  final String id;
  final String title;
  final String price;
  final String? priceSubline;
  final String subline;
  final List<PlanFeatureData> features;
  final bool showActionButton;

  const PlanCardData({
    required this.id,
    required this.title,
    required this.price,
    required this.subline,
    this.priceSubline,
    this.features = const [],
    this.showActionButton = true,
  });
}

class PlanFeatureData {
  final String label;
  final bool included;
  final String? value;
  final String? description;
  final String? actionLabel;
  final bool actionEnabled;

  const PlanFeatureData({
    required this.label,
    required this.included,
    this.value,
    this.description,
    this.actionLabel,
    this.actionEnabled = false,
  });
}
