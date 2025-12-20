import '../models/plan_models.dart';
import 'plan_features.dart';

const thermoloxPlanCards = <PlanCardData>[
  PlanCardData(
    id: 'basic',
    title: 'THERMOLOX Basic',
    price: 'Kostenlos',
    subline: 'Für den Einstieg',
    features: thermoloxBasicFeatures,
  ),
  PlanCardData(
    id: 'pro',
    title: 'THERMOLOX Pro',
    price: '10€',
    subline: 'Für ambitionierte Projekte',
    features: thermoloxProFeatures,
  ),
];
