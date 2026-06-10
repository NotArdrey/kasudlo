enum SurveyFieldType {
  text,
  number,
  date,
  time,
  textarea,
  select,
  multiSelect,
  boolean,
  repeatableTable,
  note,
  heading,
  priorityRankingGroup,
  yesNoCheckbox,
  singleSelectCheckbox,
  multiSelectCheckbox,
  mealTimeGroup,
  familyName,
}

class SurveyVisibility {
  const SurveyVisibility.equals(this.fieldKey, this.value)
    : containsValue = null;

  const SurveyVisibility.contains(this.fieldKey, this.containsValue)
    : value = null;

  final String fieldKey;
  final Object? value;
  final String? containsValue;

  bool matches(Map<String, dynamic> data) {
    final currentValue = data[fieldKey];
    final expectedValue = value;
    final expectedContainedValue = containsValue;

    if (expectedContainedValue != null) {
      if (currentValue is Iterable) {
        return currentValue.any((item) => '$item' == expectedContainedValue);
      }
      return '$currentValue' == expectedContainedValue;
    }

    return '$currentValue' == '$expectedValue';
  }
}

class SurveyField {
  const SurveyField({
    required this.key,
    required this.label,
    required this.type,
    this.options = const [],
    this.fields = const [],
    this.visibleWhen,
    this.maxRows,
    this.addButtonLabel,
    this.description,
  });

  final String key;
  final String label;
  final SurveyFieldType type;
  final List<String> options;
  final List<SurveyField> fields;
  final SurveyVisibility? visibleWhen;
  final int? maxRows;
  final String? addButtonLabel;
  final String? description;
}

class SurveySection {
  const SurveySection({
    required this.title,
    required this.fields,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<SurveyField> fields;
}

SurveyField textField(
  String key,
  String label, {
  SurveyVisibility? visibleWhen,
}) => SurveyField(
  key: key,
  label: label,
  type: SurveyFieldType.text,
  visibleWhen: visibleWhen,
);

SurveyField numberField(
  String key,
  String label, {
  SurveyVisibility? visibleWhen,
}) => SurveyField(
  key: key,
  label: label,
  type: SurveyFieldType.number,
  visibleWhen: visibleWhen,
);

SurveyField dateField(String key, String label) =>
    SurveyField(key: key, label: label, type: SurveyFieldType.date);

SurveyField timeField(String key, String label) =>
    SurveyField(key: key, label: label, type: SurveyFieldType.time);

SurveyField textareaField(
  String key,
  String label, {
  SurveyVisibility? visibleWhen,
}) => SurveyField(
  key: key,
  label: label,
  type: SurveyFieldType.textarea,
  visibleWhen: visibleWhen,
);

SurveyField selectField(
  String key,
  String label,
  List<String> options, {
  SurveyVisibility? visibleWhen,
}) => SurveyField(
  key: key,
  label: label,
  type: SurveyFieldType.select,
  options: options,
  visibleWhen: visibleWhen,
);

SurveyField multiSelectField(
  String key,
  String label,
  List<String> options, {
  SurveyVisibility? visibleWhen,
}) => SurveyField(
  key: key,
  label: label,
  type: SurveyFieldType.multiSelect,
  options: options,
  visibleWhen: visibleWhen,
);

SurveyField booleanField(
  String key,
  String label, {
  SurveyVisibility? visibleWhen,
}) => SurveyField(
  key: key,
  label: label,
  type: SurveyFieldType.boolean,
  visibleWhen: visibleWhen,
);

SurveyField tableField(
  String key,
  String label,
  List<SurveyField> fields, {
  int? maxRows,
  SurveyVisibility? visibleWhen,
  String? addButtonLabel,
}) => SurveyField(
  key: key,
  label: label,
  type: SurveyFieldType.repeatableTable,
  fields: fields,
  maxRows: maxRows,
  visibleWhen: visibleWhen,
  addButtonLabel: addButtonLabel,
);

SurveyField noteField(
  String key,
  String label, {
  String? description,
  SurveyVisibility? visibleWhen,
}) => SurveyField(
  key: key,
  label: label,
  type: SurveyFieldType.note,
  description: description,
  visibleWhen: visibleWhen,
);

SurveyField headingField(
  String key,
  String label, {
  SurveyVisibility? visibleWhen,
}) => SurveyField(
  key: key,
  label: label,
  type: SurveyFieldType.heading,
  visibleWhen: visibleWhen,
);

SurveyField yesNoCheckboxField(
  String key,
  String label, {
  SurveyVisibility? visibleWhen,
}) => SurveyField(
  key: key,
  label: label,
  type: SurveyFieldType.yesNoCheckbox,
  visibleWhen: visibleWhen,
);

SurveyField singleSelectCheckboxField(
  String key,
  String label,
  List<String> options, {
  SurveyVisibility? visibleWhen,
}) => SurveyField(
  key: key,
  label: label,
  type: SurveyFieldType.singleSelectCheckbox,
  options: options,
  visibleWhen: visibleWhen,
);

SurveyField multiSelectCheckboxField(
  String key,
  String label,
  List<String> options, {
  SurveyVisibility? visibleWhen,
}) => SurveyField(
  key: key,
  label: label,
  type: SurveyFieldType.multiSelectCheckbox,
  options: options,
  visibleWhen: visibleWhen,
);

SurveyField priorityRankingGroupField(
  String key,
  String label, {
  SurveyVisibility? visibleWhen,
}) {
  return SurveyField(
    key: key,
    label: label,
    type: SurveyFieldType.priorityRankingGroup,
    visibleWhen: visibleWhen,
  );
}

SurveyField mealTimeGroupField(
  String key,
  String label, {
  SurveyVisibility? visibleWhen,
}) {
  return SurveyField(
    key: key,
    label: label,
    type: SurveyFieldType.mealTimeGroup,
    visibleWhen: visibleWhen,
  );
}

SurveyField familyNameField(
  String key,
  String label, {
  SurveyVisibility? visibleWhen,
}) {
  return SurveyField(
    key: key,
    label: label,
    type: SurveyFieldType.familyName,
    visibleWhen: visibleWhen,
  );
}

List<Map<String, dynamic>> surveyMapRows(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
  return const [];
}

List<Map<String, dynamic>> normalizedIncomeEarnerRows(
  Object? value, {
  bool keepBlankRows = true,
}) {
  final rows = keepBlankRows
      ? surveyMapRows(value)
      : surveyMapRows(value).where(_hasIncomeEarnerContent).toList();
  return [
    for (var index = 0; index < rows.length; index++)
      {...rows[index], 'earner_no': index + 1},
  ];
}

int incomeEarnerCountFromRows(Object? value) {
  return surveyMapRows(value).where(_hasIncomeEarnerContent).length;
}

String vaccinationStatusFromSurveyData(
  Map<String, dynamic> data, {
  String fallback = 'Unknown',
}) {
  final rows = surveyMapRows(data['immunization_records']);
  if (rows.isEmpty) {
    return fallback.trim().isEmpty ? 'Unknown' : fallback;
  }

  final hasIncomplete = rows.any(
    (row) => _truthy(row['incomplete_according_to_age']),
  );
  if (hasIncomplete) {
    return 'Incomplete';
  }

  final hasComplete = rows.any(
    (row) =>
        _truthy(row['complete_according_to_age']) ||
        _truthy(row['fully_immunized_child']),
  );
  if (hasComplete) {
    return 'Complete';
  }

  return fallback.trim().isEmpty ? 'Unknown' : fallback;
}

bool _hasIncomeEarnerContent(Map<String, dynamic> row) {
  return _hasSurveyValue(row['family_member_no']) ||
      _hasSurveyValue(row['family_member_name']) ||
      _hasSurveyValue(row['family_position']) ||
      _hasSurveyValue(row['income_php']);
}

bool _hasSurveyValue(Object? value) {
  if (value == null) {
    return false;
  }
  if (value is String) {
    return value.trim().isNotEmpty;
  }
  if (value is List) {
    return value.isNotEmpty;
  }
  if (value is Map) {
    return value.isNotEmpty;
  }
  return true;
}

bool _truthy(Object? value) {
  if (value is bool) {
    return value;
  }
  final normalized = '${value ?? ''}'.trim().toLowerCase();
  return normalized == 'true' || normalized == 'yes' || normalized == '1';
}

const yesNoOptions = ['Yes', 'No'];
const adequateOptions = ['Adequate', 'Inadequate'];
const cleanDirtyOptions = ['Generally clean', 'Dirty'];
const monthlyIncomeOptions = [
  'Less than 5,000',
  '5,001-10,000',
  '10,001-15,000',
  '15,001-20,000',
  '20,001-25,000',
  '25,001-30,000',
  '30,001-35,000',
  '35,001-40,000',
  '40,001-45,000',
  '45,001-50,000',
  '50,001 and above',
];
const waterSourceOptions = [
  'Deep well',
  'Local Water District',
  'Commercial',
  'Others',
];
const foodFrequencyOptions = [
  'Everyday',
  'Twice a week',
  'Once a week',
  'Others',
];
const preservedFoodFrequencyOptions = [
  'Everyday',
  'Every other day',
  'Every week',
  'Sometimes',
  'Never',
];

final surveyHeaderFields = [
  textField('control_no', 'Control no.'),
  numberField('number_of_family', 'Family members'),
  textField('address', 'Address'),
  dateField('first_visit_date', '1st visit date'),
  dateField('second_visit_date', '2nd visit date'),
  dateField('third_visit_date', '3rd visit date'),
  textField('informant', 'Informant'),
  textField('surveyed_by', 'Surveyed by'),
  selectField('status_of_last_visit', 'Status of last visit', [
    'Completed',
    'For follow-up',
    'Rescheduled',
    'No informant',
    'Refused',
  ]),
];

final familyMemberFields = [
  numberField('member_no', 'Member no.'),
  textField('name_of_family_member', 'Member name'),
  textField('relationship_to_head', 'Relationship'),
  selectField('gender', 'Gender', ['Male', 'Female']),
  numberField('age', 'Age'),
  numberField('birthdate_month', 'Birth month'),
  numberField('birthdate_day', 'Birth day'),
  numberField('birthdate_year', 'Birth year'),
  selectField('marital_status', 'Marital status', [
    'Child',
    'Single',
    'Married',
    'Married but Separated',
    'Widow',
    'Widower',
  ]),
  selectField('religion', 'Religion', [
    'Roman Catholic',
    'Muslim',
    'Iglesia ni Cristo',
    'Born Again Christian',
    'Jehovah\'s Witness',
    'Protestant: Methodist / Evangelical / Baptist / Adventist',
    'Others',
  ]),
  textField(
    'religion_other',
    'Other religion',
    visibleWhen: const SurveyVisibility.equals('religion', 'Others'),
  ),
  selectField('highest_educational_completed', 'Highest education completed', [
    'Pre-elementary',
    'Elementary Level',
    'Elementary Graduate',
    'High School Level',
    'High School Graduate',
    'Vocational',
    'Short Course',
    'College Level',
    'College Graduate',
    'Post-Graduate',
    'Over 7 years old without formal schooling',
    'Less than 5 years old',
    'SPED',
  ]),
  selectField('occupation_status', 'Occupation status', [
    'Employed',
    'Unemployed',
    'Minor, below 18 years old',
  ]),
  selectField(
    'employment_type_if_employed',
    'Employment type',
    [
      'Regular Full-time',
      'Regular Part-time',
      'Contractual 6 months',
      'Contractual every week',
      'Contractual everyday',
      'Self-employed',
      'Seasonal',
      'OFW',
      'Contractual by job offer',
    ],
    visibleWhen: const SurveyVisibility.equals('occupation_status', 'Employed'),
  ),
  selectField('place_of_work_location', 'Place of work location', [
    'Within the community',
    'Within the municipality/city',
    'Outside the municipality/city',
    'OFW - outside the country',
  ]),
  selectField('place_of_work_category', 'Place of work category', [
    'In-House',
    'Field',
    'Office',
  ]),
  selectField('place_of_origin', 'Place of origin', [
    'Metro Manila',
    'Central Luzon',
    'Northern Luzon',
    'Southern Luzon',
    'Visayas Region',
    'Mindanao Region',
  ]),
  textField('length_of_residence', 'Length of residence'),
];

final familyProfileFields = [
  headingField('family_type_heading', 'a. Type of Family'),
  multiSelectField('family_composition_type', 'Family composition type', [
    'Nuclear',
    'Extended',
    'Dyad',
    'Homosexual/Same Sex',
    'Cohabiting/Communal',
    'Blended Family',
    'Living with Grandparent(s)',
    'Single-parent',
  ]),
  selectField('family_locus_of_power', 'Family locus of power', [
    'Patrifocal/Patriarchal',
    'Matrifocal/Matriarchal',
    'Egalitarian',
    'Matricentric',
  ]),
  selectField('family_place_of_residence', 'Family place of residence', [
    'Patrilocal',
    'Matrilocal',
    'Bilocal/Ambilocal',
    'Neolocal',
  ]),
  selectField('family_descent', 'Family descent', [
    'Patrilineal',
    'Matrilineal',
    'Bilateral',
  ]),
  textField('dialect_frequently_used', 'Dialect frequently used'),
];

final socialIndicatorFields = [
  headingField('social_indicators_heading', '1. Social Indicators'),
  multiSelectField('services_in_community', 'Services in the community', [
    'Religious services',
    'Livelihood Services',
    'Health Services',
    'Garbage collection',
    'Peace and Order',
  ]),
  multiSelectField('institutional_facilities', 'Institutional facilities', [
    'Brgy. Hall',
    'Health Station',
    'Church',
    'School',
  ]),
  multiSelectField('organizations', 'Organizations', [
    'Senior Citizen',
    'Youth',
    'Others',
  ]),
  textField(
    'organizations_other',
    'Other organization',
    visibleWhen: const SurveyVisibility.contains('organizations', 'Others'),
  ),
  multiSelectField('traditions_customs', 'Traditions/customs', [
    'Bayanihan',
    'Palabra de Honor',
    'Pakikisama',
    'Ningas Kugon',
    'Fiestas',
    'Close family ties',
    'Respect for elderly',
    'Others',
  ]),
  textField(
    'traditions_customs_other',
    'Other tradition/custom',
    visibleWhen: const SurveyVisibility.contains(
      'traditions_customs',
      'Others',
    ),
  ),
  multiSelectField('recreational_facilities', 'Recreational facilities', [
    'Volleyball/Basketball court',
    'Playground',
    'Plaza',
    'Others',
  ]),
  textField(
    'recreational_facilities_other',
    'Other recreational facility',
    visibleWhen: const SurveyVisibility.contains(
      'recreational_facilities',
      'Others',
    ),
  ),
  multiSelectField('mode_of_transportation', 'Mode of transportation', [
    'Tricycle',
    'Jeep',
    'PUJ/PUV',
    'Bicycle',
    'Private vehicle',
  ]),
  multiSelectField('mode_of_communication', 'Mode of communication', [
    'Postal system',
    'Internet',
    'Telephone',
    'Cell phone',
    'Two-way radio',
    'Others',
  ]),
  textField(
    'mode_of_communication_other',
    'Other mode of communication',
    visibleWhen: const SurveyVisibility.contains(
      'mode_of_communication',
      'Others',
    ),
  ),
];

final economicIndicatorFields = [
  headingField('economic_indicator_heading', '2. Economic Indicator'),
  tableField(
    'income_earners',
    'Income earners',
    [
      numberField('earner_no', 'No.'),
      numberField('family_member_no', 'Family member no.'),
      textField('family_member_name', 'Family member'),
      textField('family_position', 'Family position'),
      numberField('income_php', 'Income PHP'),
    ],
    maxRows: 4,
    addButtonLabel: 'Add Income Earner',
  ),
  selectField(
    'monthly_family_income_combined',
    'Monthly family income',
    monthlyIncomeOptions,
  ),
  multiSelectField('financial_sources', 'Financial source for expenditures', [
    'Employment',
    'Business',
    'Pension',
    'Help from relative/friends',
    'Others',
  ]),
  textField(
    'financial_sources_other',
    'Other financial source',
    visibleWhen: const SurveyVisibility.contains('financial_sources', 'Others'),
  ),
  selectField(
    'monthly_family_expenditures',
    'Monthly family expenditures',
    monthlyIncomeOptions,
  ),
  noteField(
    'priorities_and_expenditure_note',
    'Priorities and Expenditure',
    description:
        "Family's priority by ranking 1-7 where 1 is the highest priority.",
  ),
  priorityRankingGroupField(
    'priorities_ranking',
    'Priorities and Expenditure Ranking',
  ),
  selectField('family_income_adequacy', 'Adequacy of family income', [
    'Adequate',
    'Not Adequate',
  ]),
];

final culturalIndicatorFields = [
  headingField('cultural_indicator_heading', '3. Cultural Indicator'),
  multiSelectField(
    'cultural_orientation_illness',
    'Cultural orientation regarding illness',
    [
      'Illness is caused by physiologic factor, e.g. infection',
      'Illness is caused by supernatural phenomenon, e.g. kulam, balis',
      'Illness is a punishment from God',
      'Illness is caused by other person',
      'Illness is caused by change in weather',
      'Others',
    ],
  ),
  textField(
    'cultural_orientation_illness_other',
    'Other illness orientation',
    visibleWhen: const SurveyVisibility.contains(
      'cultural_orientation_illness',
      'Others',
    ),
  ),
  multiSelectField(
    'cultural_belief_health_restoration',
    'Cultural belief about health restoration',
    [
      'Health can be restored by God/other spiritual faith',
      'Health can be restored by faith healers',
      'Health can be restored by supernatural power, e.g. tawas, hilot, hula',
      'Health can be restored by health personnel, e.g. doctors, nurses',
    ],
  ),
  selectField(
    'cultural_perception_health_practices',
    'Cultural perception about health practices',
    [
      'Always practices local cultural practices about health matters',
      'Sometimes practices local cultural practices about health matters',
      'Does not practice any local cultural practices about health matters',
    ],
  ),
  selectField('community_involvement', 'Community involvement', [
    'Actively joins fiesta, religious procession, local cultural practices',
    'Does not actively join',
  ]),
];

final environmentalIndicatorFields = [
  headingField('environmental_indicator_heading', '4. Environmental Indicator'),
  headingField('home_heading', 'A. Home'),
  selectField('home_ownership', 'Home ownership', [
    'Owned',
    'Rented',
    'Rent-free',
    'Lease/Least to own',
    'Squatting/informal settlers',
    'Professional squatters',
  ]),
  selectField('home_construction_materials', 'Home construction materials', [
    'Light',
    'Mixed',
    'Strong/Concrete',
  ]),
  selectField('sleeping_rooms_count', 'Sleeping rooms count', [
    '1',
    '2',
    '3',
    '4',
    '5',
    'None/no partition',
  ]),
  selectField('home_space_adequacy', 'Home space adequacy', adequateOptions),
  selectField('lighting_facility', 'Lighting facility', [
    'Electricity',
    'Kerosene',
    'Others',
  ]),
  textField(
    'lighting_facility_other',
    'Other lighting facility',
    visibleWhen: const SurveyVisibility.equals('lighting_facility', 'Others'),
  ),
  selectField('lighting_adequacy', 'Lighting adequacy', adequateOptions),
  selectField('ventilation_adequacy', 'Ventilation adequacy', adequateOptions),
  selectField(
    'general_sanitary_condition',
    'General sanitary condition',
    cleanDirtyOptions,
  ),
  headingField('water_supply_heading', 'B. Water Supply'),
  selectField('water_supply_ownership', 'Water supply ownership', [
    'Private',
    'Public',
  ]),
  selectField(
    'water_source_cooking',
    'Water source for cooking',
    waterSourceOptions,
  ),
  textField(
    'water_source_cooking_other',
    'Other cooking water source',
    visibleWhen: const SurveyVisibility.equals(
      'water_source_cooking',
      'Others',
    ),
  ),
  selectField(
    'water_source_drinking',
    'Water source for drinking',
    waterSourceOptions,
  ),
  textField(
    'water_source_drinking_other',
    'Other drinking water source',
    visibleWhen: const SurveyVisibility.equals(
      'water_source_drinking',
      'Others',
    ),
  ),
  selectField(
    'water_source_bathing_cr_flushing',
    'Water source for bathing/CR flushing',
    waterSourceOptions,
  ),
  textField(
    'water_source_bathing_cr_flushing_other',
    'Other bathing/CR flushing water source',
    visibleWhen: const SurveyVisibility.equals(
      'water_source_bathing_cr_flushing',
      'Others',
    ),
  ),
  selectField(
    'water_potability_key_informant',
    'Water potability',
    yesNoOptions,
  ),
  selectField('water_storage', 'Water storage', [
    'None/direct from faucet or pipe',
    'Large covered container with faucet',
    'Large uncovered container with faucet',
    'Large covered container without faucet',
    'Large uncovered container without faucet',
    'Others',
  ]),
  textField(
    'water_storage_other',
    'Other water storage',
    visibleWhen: const SurveyVisibility.equals('water_storage', 'Others'),
  ),
  textField(
    'water_source_distance_from_house',
    'Water source distance from house',
  ),
  headingField(
    'food_storage_cooking_heading',
    'C. Food Storage / Cooking Facilities',
  ),
  selectField('food_storage_cover_status', 'Food storage cover status', [
    'Covered',
    'Uncovered',
  ]),
  multiSelectField('food_storage_type', 'Food storage type', [
    'Refrigerator',
    'Cabinet',
    'Basket',
    'Table',
  ]),
  multiSelectField('cooking_facility', 'Cooking facility', [
    'Electric stove',
    'Gas stove',
    'Firewood/charcoal',
    'Others',
  ]),
  textField(
    'cooking_facility_other',
    'Other cooking facility',
    visibleWhen: const SurveyVisibility.contains('cooking_facility', 'Others'),
  ),
  selectField(
    'cooking_area_sanitary_condition',
    'Cooking area sanitary condition',
    cleanDirtyOptions,
  ),
  headingField('waste_disposal_heading', 'D. Waste Disposal'),
  headingField('refuse_garbage_heading', 'a. Refuse and Garbage'),
  selectField('garbage_storage', '1. Storage', ['Container', 'None']),
  selectField('waste_segregation', '2. Waste Segregation', [
    'Practiced',
    'Not Practiced',
  ]),
  multiSelectField(
    'waste_disposal_method_if_practiced',
    '2.1 If practiced, method of disposal',
    [
      'Hog-feeding',
      'Open dumping',
      'Burial in pit',
      'Collected',
      'Composting',
      'Open burning',
    ],
  ),
  multiSelectField(
    'reason_for_practicing_waste_segregation',
    '2.2 Reason for practicing',
    [
      'Environmentally friendly',
      'Barangay ordinance which is strictly monitored',
      'Use for business',
      'Others',
    ],
  ),
  textField(
    'reason_for_practicing_waste_segregation_other',
    'Other reason for practicing waste segregation',
    visibleWhen: const SurveyVisibility.contains(
      'reason_for_practicing_waste_segregation',
      'Others',
    ),
  ),
  multiSelectField(
    'waste_disposal_method_if_not_practiced',
    '2.3 If not practiced, method of disposal',
    [
      'Hog-feeding',
      'Open dumping',
      'Burial in pit',
      'Collected',
      'Composting',
      'Open burning',
    ],
  ),
  multiSelectField(
    'reason_for_not_practicing_waste_segregation',
    '2.4 Reason for not practicing',
    [
      'Not aware of effects',
      'No time to do it',
      'Long-time practice of family',
      'No barangay/municipality ordinance',
    ],
  ),
  selectField('toilet_ownership', 'Toilet ownership', [
    'Owned',
    'Shared/Public',
    'None',
  ]),
  selectField('toilet_type', 'Toilet type', [
    'Ballot system',
    'Pail system',
    'Overhung latrine',
    'Water-sealed',
    'Flush type',
    'None',
    'Other',
  ]),
  textField(
    'toilet_type_other',
    'Other toilet type',
    visibleWhen: const SurveyVisibility.equals('toilet_type', 'Other'),
  ),
  selectField(
    'toilet_location_from_water_source',
    'Toilet location from water source',
    ['Less than 20 ft.', '20 ft. beyond'],
  ),
  selectField(
    'toilet_sanitary_condition',
    'Toilet sanitary condition',
    cleanDirtyOptions,
  ),
  selectField('drainage_system', 'Drainage system', [
    'Open drainage',
    'Blind drainage',
    'None',
  ]),
  selectField('drainage_condition', 'Drainage condition', [
    'Flowing',
    'Stagnant',
  ]),
  headingField(
    'rabies_carrier_animals_heading',
    'E. Presence of Animals that are Rabies carriers',
  ),
  selectField(
    'has_rabies_carrier_animals',
    'Presence of rabies carrier animals',
    yesNoOptions,
  ),
  headingField('rabies_animals_raised_heading', 'a. If yes, animals raised'),
  tableField('rabies_carrier_animals', 'Animals raised', [
    textField('animal_kind', 'Kind'),
    numberField('animal_number', 'Number'),
    booleanField('kept_inside_yard', 'Kept where: Inside the Yard'),
    booleanField('kept_free_outside', 'Kept where: Free Outside'),
    booleanField('with_regular_vaccination', 'With regular vaccination'),
    booleanField('without_vaccination', 'Without vaccination'),
  ], addButtonLabel: 'Add Animal'),
  multiSelectField(
    'vector_control_measures',
    'b. Practices measures done to control insects/vectors of diseases',
    [
      'Fumigation',
      'Insecticides',
      'Setting traps',
      'Cleaning the yard',
      'None',
    ],
  ),
  selectField(
    'has_breeding_sites_observed',
    'c. Presence of breeding sites (for observation)',
    yesNoOptions,
  ),
  selectField(
    'housing_congestion_observed',
    'F. Housing Congestion (for observation)',
    yesNoOptions,
  ),
  selectField(
    'has_industrial_establishment_or_factory_observed',
    'G. Presence of Industrial establishment/factory/ies (for observation)',
    yesNoOptions,
  ),
];

final lifestylePracticeFields = [
  headingField('lifestyle_practices_heading', '1. Lifestyle Practices'),
  headingField('safety_precaution_heading', 'A. Use of Safety Precaution'),
  singleSelectCheckboxField(
    'uses_safety_devices_when_necessary',
    '1. Use safety devices when necessary e.g. Helmet, safety belts',
    ['Practice', 'Not Practiced'],
  ),
  yesNoCheckboxField(
    'has_cigarette_smoker_in_family',
    'B. Is there a member of the family who is a cigarette smoker?',
  ),
  textField(
    'smoking_frequency_sticks_or_packs_per_day',
    'Frequency/sticks or packs per day',
    visibleWhen: const SurveyVisibility.equals(
      'has_cigarette_smoker_in_family',
      'Yes',
    ),
  ),
  tableField(
    'cigarette_smokers',
    'Cigarette smoking details',
    [
      familyNameField('name', 'Name'),
      numberField('age', 'Age'),
      numberField('age_started_smoking', 'Age started smoking'),
      textField('reason', 'Reason'),
    ],
    addButtonLabel: 'Add Smoker',
    visibleWhen: const SurveyVisibility.equals(
      'has_cigarette_smoker_in_family',
      'Yes',
    ),
  ),
  yesNoCheckboxField(
    'uses_prohibited_or_dangerous_drugs',
    'C. Use of prohibited / dangerous drugs',
  ),
  textField(
    'types_of_drugs',
    'Types of drugs',
    visibleWhen: const SurveyVisibility.equals(
      'uses_prohibited_or_dangerous_drugs',
      'Yes',
    ),
  ),
  tableField(
    'drug_users',
    'Prohibited / dangerous drug use details',
    [
      familyNameField('name', 'Name'),
      numberField('age', 'Age'),
      numberField('age_started_using_drugs', 'Age started using drugs'),
      textField('reason', 'Reason'),
    ],
    addButtonLabel: 'Add Drug User',
    visibleWhen: const SurveyVisibility.equals(
      'uses_prohibited_or_dangerous_drugs',
      'Yes',
    ),
  ),
  yesNoCheckboxField('has_alcohol_drinker', 'D. Drinks alcoholic beverages'),
  tableField(
    'alcohol_drinkers',
    'Alcoholic beverages drinker details',
    [
      familyNameField('name', 'Name'),
      numberField('age', 'Age'),
      numberField(
        'age_started_drinking_alcohol',
        'Age started drinking alcohol',
      ),
      textField('frequency', 'Frequency'),
      textField('reason', 'Reason'),
    ],
    addButtonLabel: 'Add Drinker',
    visibleWhen: const SurveyVisibility.equals('has_alcohol_drinker', 'Yes'),
  ),
];

final nutritionalStatusFields = [
  headingField('nutritional_status_heading', '2. Nutritional Status'),
  yesNoCheckboxField(
    'has_children_under_5',
    'Do you have any children aged 5 years old or below currently living in your household?',
  ),
  tableField(
    'anthropometric_data_under_5',
    'A. Anthropometric Data (5 years below)',
    [
      familyNameField('name', 'Name'),
      numberField('age_in_months', 'Age in mos.'),
      numberField('weight_kg', 'Wt. in kg.'),
      numberField('height_m', 'Ht. in m'),
      numberField('bmi', 'BMI (Wt. in kg / Ht. in m2)'),
      textField('bmi_remarks', 'Remarks'),
      numberField('waist_circumference_cm', 'Waist Circumference (WC) in cm.'),
      numberField('hip_circumference_cm', 'Hips Circumference (HC) in cm.'),
      numberField('waist_hip_ratio', 'Waist Hips Ratio (WC/HC)'),
      textField('waist_hip_ratio_remarks', 'Remarks'),
      numberField('mid_upper_arm_circumference', 'Mid Upper Arm Circular'),
      textField('mid_upper_arm_remarks', 'Remarks'),
    ],
    addButtonLabel: 'Add Child',
    visibleWhen: const SurveyVisibility.equals('has_children_under_5', 'Yes'),
  ),
  dateField('food_recall_date', 'Date of Food Recall'),
  mealTimeGroupField(
    'food_recall_24_hour',
    'B. Dietary History: 24-Hour Food Recall',
  ),
  headingField(
    'food_usually_most_taken_heading',
    'C. Food usually/most taken (General)',
  ),
  singleSelectCheckboxField('first_food_choice', 'a. First food choice', [
    'Meat only',
    'Fish',
    'Vegetable',
    'Mixed',
    'Others',
  ]),
  textField(
    'first_food_choice_other',
    'Other first food choice',
    visibleWhen: const SurveyVisibility.equals('first_food_choice', 'Others'),
  ),
  singleSelectCheckboxField(
    'first_food_choice_servings',
    'b. Number of servings',
    ['1', '2-3', '4-5 and above'],
  ),
  singleSelectCheckboxField('second_food_choice', 'c. Second choice', [
    'Meat',
    'Fish',
    'Vegetable',
    'Mixed',
    'Others',
  ]),
  textField(
    'second_food_choice_other',
    'Other second food choice',
    visibleWhen: const SurveyVisibility.equals('second_food_choice', 'Others'),
  ),
  singleSelectCheckboxField(
    'second_food_choice_servings',
    'd. Number of servings',
    ['1', '2-3', '4-5 and above'],
  ),
  multiSelectCheckboxField('reason_for_food_choices', 'D. Reason for choices', [
    'It is healthy',
    'Own preference',
    'Affordable',
    'Personal belief/practices',
    'Health condition',
  ]),
  multiSelectCheckboxField(
    'reason_for_not_choosing_other_food_options',
    'E. Reason for not choosing other options',
    [
      'Not healthy',
      'Own preference',
      'Not affordable',
      'Personal belief/religious practices',
      'Health condition',
    ],
  ),
  singleSelectCheckboxField(
    'food_intake_frequency',
    'F. From the above response, how frequent is the intake?',
    foodFrequencyOptions,
  ),
  textField(
    'food_intake_frequency_other',
    'Other food intake frequency',
    visibleWhen: const SurveyVisibility.equals(
      'food_intake_frequency',
      'Others',
    ),
  ),
  singleSelectCheckboxField(
    'food_prepared_for_mealtime',
    'G. How is food prepared for mealtime?',
    ['Prepared at home', 'Bought outside'],
  ),
  singleSelectCheckboxField(
    'food_preparation_frequency',
    'H. How often?',
    foodFrequencyOptions,
  ),
  textField(
    'food_preparation_frequency_other',
    'Other food preparation frequency',
    visibleWhen: const SurveyVisibility.equals(
      'food_preparation_frequency',
      'Others',
    ),
  ),
  multiSelectCheckboxField(
    'bought_food_source',
    'I. If bought outside, is it from the',
    [
      'Restaurant/Fast food',
      'Carinderia',
      'Food cart, e.g. fried chicken sa kanto, provent, calamares',
    ],
  ),
  multiSelectCheckboxField(
    'reason_for_bought_food_option',
    'J. Reason for the above option',
    ['Convenient', 'Cheaper', 'Healthy', 'Variety of choices', 'Others'],
  ),
  textField(
    'reason_for_bought_food_option_other',
    'Other bought food reason',
    visibleWhen: const SurveyVisibility.contains(
      'reason_for_bought_food_option',
      'Others',
    ),
  ),
  singleSelectCheckboxField(
    'canned_preserved_food_frequency',
    'K. Takes/eat canned/preserved food',
    preservedFoodFrequencyOptions,
  ),
  singleSelectCheckboxField(
    'grilled_food_frequency',
    'L. Takes/eat grilled foods',
    preservedFoodFrequencyOptions,
  ),
  singleSelectCheckboxField(
    'carbonated_beverage_frequency',
    'M. Drinks carbonated beverages',
    [
      'Everyday',
      'Every other day',
      'Every week',
      'Occasionally',
      'Sometimes',
      'Never',
    ],
  ),
];

final beliefsPracticeFields = [
  headingField('beliefs_practices_heading', '3. Beliefs and Practices'),
  multiSelectCheckboxField(
    'personnel_consulted_during_illness',
    'Personnel consulted during illness',
    [
      'Doctor',
      'Nurse',
      'Midwife',
      'Hilot',
      'Albularyo',
      'Faith Healer',
      'Elderly',
    ],
  ),
  multiSelectCheckboxField(
    'measures_taken_during_illness',
    'Measures taken during illness',
    [
      'Consult a private health worker',
      'See a known community healer',
      'Consult a Rural Health Team',
      'Self-Medication',
      'None',
    ],
  ),
  multiSelectCheckboxField(
    'medication_treatment_during_illness',
    'Medication/treatment during illness',
    ['Prescribed by Doctor', 'Self-Medication/OTC drugs', 'Herbals', 'Others'],
  ),
  textField(
    'medication_treatment_during_illness_other',
    'Other medication/treatment',
    visibleWhen: const SurveyVisibility.contains(
      'medication_treatment_during_illness',
      'Others',
    ),
  ),
  singleSelectCheckboxField('medical_checkup_frequency', 'Medical check-up', [
    'Once a year',
    'Twice a year',
    'More than a year',
  ]),
  singleSelectCheckboxField('dental_checkup_frequency', 'Dental check-up', [
    'Once a year',
    'Twice a year',
    'More than a year',
  ]),
];

final communityHealthProgramFields = [
  headingField(
    'community_health_programs_heading',
    '4. Community Health Programs',
  ),
  multiSelectCheckboxField(
    'barangay_health_center_services_available',
    'Available health services at barangay health center',
    ['RHU', 'BHC', 'Others'],
  ),
  textField(
    'barangay_health_center_services_available_other',
    'Other health services',
    visibleWhen: const SurveyVisibility.contains(
      'barangay_health_center_services_available',
      'Others',
    ),
  ),
  tableField('immunization_records', 'Immunization records', [
    familyNameField('name', 'Name'),
    numberField('age_in_mos', 'Age in mos'),
    selectField('gender', 'Gender', ['Male', 'Female']),
    booleanField('bcg', 'BCG'),
    booleanField('dpt_1', 'DPT 1'),
    booleanField('dpt_2', 'DPT 2'),
    booleanField('dpt_3', 'DPT 3'),
    booleanField('hepa_b_1', 'Hepa B 1'),
    booleanField('hepa_b_2', 'Hepa B 2'),
    booleanField('hepa_b_3', 'Hepa B 3'),
    booleanField('opv_1', 'OPV 1'),
    booleanField('opv_2', 'OPV 2'),
    booleanField('opv_3', 'OPV 3'),
    booleanField('measles', 'Measles'),
    booleanField('complete_according_to_age', 'Complete according to Age'),
    booleanField('incomplete_according_to_age', 'Incomplete accdg to Age'),
    booleanField('fully_immunized_child', 'Fully Immunized Child'),
  ], addButtonLabel: 'Add Record'),
  yesNoCheckboxField(
    'has_pregnant_woman',
    'Is there any pregnant woman living in the house?',
  ),
  tableField(
    'antenatal_registrations',
    'Ante-natal registrations',
    [
      familyNameField('name', 'Name'),
      textField('aog', 'AOG'),
      booleanField(
        'prenatal_checkup_with_regular',
        'With regular prenatal check-up',
      ),
      booleanField(
        'prenatal_checkup_with_not_regular',
        'With not regular prenatal check-up',
      ),
      booleanField('prenatal_checkup_without', 'Without prenatal check-up'),
      booleanField('tetanus_vaccination_with', 'With tetanus vaccination'),
      booleanField(
        'tetanus_vaccination_without',
        'Without tetanus vaccination',
      ),
    ],
    addButtonLabel: 'Add Registration',
    visibleWhen: const SurveyVisibility.equals('has_pregnant_woman', 'Yes'),
  ),
  yesNoCheckboxField('family_planning_eligible', 'Family planning eligible'),
  singleSelectCheckboxField(
    'family_planning_status',
    'Family planning status',
    ['Acceptor', 'Non-Acceptor'],
  ),
  multiSelectCheckboxField(
    'family_planning_acceptor_reasons',
    'Acceptor reasons',
    [
      'Good for health of family',
      'Religious belief',
      'Personal belief',
      'Influence by others',
      'Others',
    ],
    visibleWhen: const SurveyVisibility.equals(
      'family_planning_status',
      'Acceptor',
    ),
  ),
  textField(
    'family_planning_acceptor_reason_other',
    'Other acceptor reason',
    visibleWhen: const SurveyVisibility.contains(
      'family_planning_acceptor_reasons',
      'Others',
    ),
  ),
  multiSelectCheckboxField(
    'family_planning_non_acceptor_reasons',
    'Non-acceptor reasons',
    [
      'Bad for health of family',
      'Religious belief',
      'Personal belief',
      'Influence by others',
      'Others',
    ],
    visibleWhen: const SurveyVisibility.equals(
      'family_planning_status',
      'Non-Acceptor',
    ),
  ),
  textField(
    'family_planning_non_acceptor_reason_other',
    'Other non-acceptor reason',
    visibleWhen: const SurveyVisibility.contains(
      'family_planning_non_acceptor_reasons',
      'Others',
    ),
  ),
  headingField('modern_methods_used_heading', '2. Modern Methods Used'),
  headingField('permanent_method_heading', 'A. Permanent method Like'),
  booleanField(
    'permanent_method_female_sterilization_btl',
    'Female sterilization / Bilateral Tubal Ligation',
  ),
  booleanField(
    'permanent_method_male_sterilization_vasectomy',
    'Male sterilization / Vasectomy',
  ),
  headingField('temporary_method_heading', 'B. Temporary method'),
  headingField('supply_methods_heading', 'a. Supply Methods Like'),
  booleanField('supply_method_pills', 'Pills'),
  booleanField('supply_method_iud', 'IUD'),
  booleanField('supply_method_injectable', 'Injectable'),
  booleanField('supply_method_condoms', 'Condoms'),
  booleanField('supply_method_implant', 'Implant'),
  headingField(
    'fertility_awareness_based_method_heading',
    'b. Fertility Awareness-Based Method Like',
  ),
  booleanField(
    'fertility_method_cervical_mucus_billings',
    'Cervical Mucus Method / Billings Ovulation Method',
  ),
  booleanField(
    'fertility_method_basal_body_temperature',
    'Basal Body Temperature (BBT)',
  ),
  booleanField('fertility_method_sympto_thermal', 'Sympto-Thermal Method'),
  booleanField('fertility_method_standard_days', 'Standard Days Method (SDM)'),
  booleanField(
    'fertility_method_lactational_amenorrhea',
    'Lactational Amenorrhea Method (LAM)',
  ),
];

final healthIndicatorFields = [
  headingField('health_indicators_heading', '5. Health Indicators'),
  tableField('morbidity_records', 'A. Morbidity records', [
    familyNameField('name', 'Name'),
    selectField('age', 'Age', [
      '< 1',
      ...List.generate(100, (i) => (i + 1).toString()),
    ]),
    selectField('gender', 'Gender', ['Male', 'Female']),
    textField('cause', 'Cause (Specify)'),
    booleanField('intervention_with', 'With Intervention'),
    booleanField('intervention_without', 'Without Intervention'),
    booleanField('admitted', 'Admitted'),
    booleanField('not_admitted', 'Not Admitted'),
  ], addButtonLabel: 'Add Record'),
  yesNoCheckboxField(
    'has_mortality_past_12_months',
    'Is there any reported mortality over the past 12 months?',
  ),
  tableField(
    'mortality_records',
    'B. Mortality records',
    [
      familyNameField('name', 'Name'),
      selectField('age', 'Age', [
        '< 1',
        ...List.generate(100, (i) => (i + 1).toString()),
      ]),
      selectField('gender', 'Gender', ['Male', 'Female']),
      textField('cause_of_death', 'Cause of death (Specify)'),
    ],
    addButtonLabel: 'Add Record',
    visibleWhen: const SurveyVisibility.equals(
      'has_mortality_past_12_months',
      'Yes',
    ),
  ),
  tableField(
    'non_communicable_disease_records',
    'C. History/ Presence of Non Communicable Disease in the Family',
    [
      familyNameField('name', 'Name'),
      selectField('age', 'Age', [
        '< 1',
        ...List.generate(100, (i) => (i + 1).toString()),
      ]),
      selectField('gender', 'Gender', ['Male', 'Female']),
      textField('ncd', 'NCD (Specify)'),
    ],
    addButtonLabel: 'Add Record',
  ),
  tableField(
    'communicable_disease_records',
    'D. History / Presence of Communicable Disease in the Family',
    [
      familyNameField('name', 'Name'),
      selectField('age', 'Age', [
        '< 1',
        ...List.generate(100, (i) => (i + 1).toString()),
      ]),
      selectField('gender', 'Gender', ['Male', 'Female']),
      textField('cd', 'CD (Specify)'),
    ],
    addButtonLabel: 'Add Record',
  ),
  tableField(
    'blood_pressure_records',
    'E. Blood Pressure Record for Ages 35 and above',
    [
      familyNameField('name', 'Name'),
      selectField('age', 'Age', List.generate(66, (i) => (i + 35).toString())),
      selectField('gender', 'Gender', ['Male', 'Female']),
      textField('bp', 'BP'),
    ],
    addButtonLabel: 'Add Record',
  ),
  selectField(
    'awareness_of_bhc_rhu_health_services',
    'Awareness of BHC/RHU health services',
    ['Aware', 'Unaware'],
  ),
];

final healthResourceFields = [
  textareaField(
    'health_manpower_categories_available',
    'Categories of health manpower available',
  ),
  textareaField(
    'health_manpower_geographical_distribution',
    'Geographical distribution of health manpower',
  ),
  textareaField(
    'rhu_team_per_population_summary',
    'RHU team per population summary',
  ),
  textField('physician_count_per_population', 'Physician count per population'),
  textField('nurse_count_per_population', 'Nurse count per population'),
  textField('midwife_count_per_population', 'Midwife count per population'),
  textField(
    'other_rhu_team_count_per_population',
    'Other RHU team count per population',
  ),
  textareaField(
    'existing_manpower_development_policies',
    'Existing manpower development/policies',
  ),
  textField('rhu_physicians_schedule', 'RHU physicians schedule'),
  textField('rhu_nurse_schedule', 'RHU nurse schedule'),
  textField('bhc_midwife_schedule', 'BHC midwife schedule'),
  selectField(
    'health_budget_expenditures_availability',
    'Health budget expenditures',
    ['Available', 'Not Available'],
  ),
  numberField(
    'health_budget_amount_per_year_php',
    'Health budget amount per year PHP',
  ),
  selectField(
    'supplies_equipment_availability',
    'Supplies and equipment availability',
    ['Available 100%', 'Limited Supplies', 'Not Available'],
  ),
];

final politicalLeadershipPatternFields = [
  multiSelectField(
    'recognized_formal_elected_leaders',
    'Recognized formal/elected leaders',
    ['Captain', 'Kagawad'],
  ),
  multiSelectField(
    'recognized_non_formal_leaders',
    'Recognized non-formal leaders',
    ['Elderly', 'BHW', 'Influential person', 'Religious leader', 'Neighbor'],
  ),
  multiSelectField(
    'social_conflict_causes',
    'Conditions/events/issues causing social conflicts',
    [
      'Gossip',
      'Family conflict',
      'Drugs',
      'Riot',
      'Alcohol drinking',
      'Others',
    ],
  ),
  textField(
    'social_conflict_causes_other',
    'Other social conflict cause',
    visibleWhen: const SurveyVisibility.contains(
      'social_conflict_causes',
      'Others',
    ),
  ),
  multiSelectField(
    'conflict_resolution_approaches',
    'Effective practices/approaches in setting issues',
    [
      'Settlement among involved parties',
      'Brgy. hearing',
      'Endorsed to local police',
      'Others',
    ],
  ),
  textField(
    'conflict_resolution_approaches_other',
    'Other conflict resolution approach',
    visibleWhen: const SurveyVisibility.contains(
      'conflict_resolution_approaches',
      'Others',
    ),
  ),
];

final lifestyleConcernSuggestionFields = [
  textareaField(
    'general_lifestyle_area_concerns_suggestions',
    'Concerns/suggestions regarding life style in the area',
  ),
];

final leadershipFields = [
  ...politicalLeadershipPatternFields,
  ...lifestyleConcernSuggestionFields,
];

final surveySections = [
  SurveySection(
    title: 'I. Demographic Variable',
    fields: [
      ...surveyHeaderFields,
      tableField(
        'family_members',
        'Family members',
        familyMemberFields,
        addButtonLabel: 'Add Member',
      ),
      ...familyProfileFields,
    ],
  ),
  SurveySection(
    title: 'II. Socio-economic, Cultural and Environmental',
    fields: [
      ...socialIndicatorFields,
      ...economicIndicatorFields,
      ...culturalIndicatorFields,
      ...environmentalIndicatorFields,
    ],
  ),
  SurveySection(
    title: 'III. Health and Illness Pattern',
    fields: [
      ...lifestylePracticeFields,
      ...nutritionalStatusFields,
      ...beliefsPracticeFields,
      ...communityHealthProgramFields,
      ...healthIndicatorFields,
    ],
  ),
  SurveySection(title: 'IV. Health Resource', fields: healthResourceFields),
  SurveySection(
    title: 'V. Political/Leadership Patterns',
    fields: politicalLeadershipPatternFields,
  ),
  SurveySection(
    title:
        'VI. Any concerns/suggestions regarding the life style in the area in general',
    fields: lifestyleConcernSuggestionFields,
  ),
];
