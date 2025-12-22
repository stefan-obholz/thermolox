import 'plan.dart';
import 'plan_feature.dart';

class CurrentPlan {
  final Plan plan;
  final Map<String, PlanFeature> features;
  final int? virtualRoomLimit;
  final int? virtualRoomUsed;
  final int? virtualRoomRemaining;

  const CurrentPlan({
    required this.plan,
    required this.features,
    this.virtualRoomLimit,
    this.virtualRoomUsed,
    this.virtualRoomRemaining,
  });
}
