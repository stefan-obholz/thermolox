class PlanFeatureDescriptor {
  final String key;
  final String label;

  const PlanFeatureDescriptor(this.key, this.label);
}

const planFeatureOrder = <PlanFeatureDescriptor>[
  PlanFeatureDescriptor('chatbot', 'THERMOLOX Chatbot'),
  PlanFeatureDescriptor('color_advice', 'Farbberatung'),
  PlanFeatureDescriptor('project_folder', 'Projektmappe'),
  PlanFeatureDescriptor('project_consulting', 'Projektberatung'),
  PlanFeatureDescriptor('virtual_room', 'Virtuelle Raumgestaltung'),
];

const planFeatureLabels = <String, String>{
  'chatbot': 'THERMOLOX Chatbot',
  'color_advice': 'Farbberatung',
  'project_folder': 'Projektmappe',
  'project_consulting': 'Projektberatung',
  'virtual_room': 'Virtuelle Raumgestaltung',
};

String? labelForFeatureKey(String key) => planFeatureLabels[key];
