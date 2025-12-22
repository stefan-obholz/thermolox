import '../models/plan_models.dart';

const thermoloxBasicFeatures = <PlanFeatureData>[
  PlanFeatureData(
    label: 'THERMOLOX Chatbot',
    included: true,
    description: 'Inklusive',
  ),
  PlanFeatureData(
    label: 'Farbberatung',
    included: true,
    description: 'Inklusive',
  ),
  PlanFeatureData(
    label: 'Projektmappe',
    included: false,
    description: 'Nicht enthalten',
  ),
  PlanFeatureData(
    label: 'Projektberatung',
    included: false,
    description: 'Nicht enthalten',
  ),
  PlanFeatureData(
    label: 'Virtuelle Raumgestaltung',
    included: false,
    description: 'Nicht enthalten',
  ),
];

const thermoloxProFeatures = <PlanFeatureData>[
  PlanFeatureData(
    label: 'THERMOLOX Chatbot',
    included: true,
    description: 'Inklusive',
  ),
  PlanFeatureData(
    label: 'Farbberatung',
    included: true,
    description: 'Inklusive',
  ),
  PlanFeatureData(
    label: 'Projektmappe',
    included: true,
    description: 'Inklusive',
  ),
  PlanFeatureData(
    label: 'Projektberatung',
    included: true,
    description: 'Inklusive',
  ),
  PlanFeatureData(
    label: 'Virtuelle Raumgestaltung',
    included: true,
    value: '10x',
    description: '10 Nutzungen',
  ),
];
