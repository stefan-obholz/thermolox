class PlanFeature {
  final String featureKey;
  final bool isEnabled;
  final int? monthlyLimit;

  const PlanFeature({
    required this.featureKey,
    required this.isEnabled,
    this.monthlyLimit,
  });
}
