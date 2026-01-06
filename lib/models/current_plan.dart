import 'plan.dart';
import 'plan_feature.dart';

class CurrentPlan {
  final Plan plan;
  final Map<String, PlanFeature> features;

  const CurrentPlan({
    required this.plan,
    required this.features,
  });
}
