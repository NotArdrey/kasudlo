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
  textField('informant', 'Name'),
  textField('surveyed_by', 'Surveyed by'),
  timeField('time_started', 'Time started'),
  timeField('time_finished', 'Time finished'),
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
  numberField('income_earner_count', 'Income earner count'),
  tableField(
    'income_earners',
    'Income earners',
    [
      numberField('earner_no', 'No.'),
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
  numberField('priority_food_rank', 'Food priority rank'),
  numberField('priority_clothing_rank', 'Clothing priority rank'),
  numberField('priority_education_rank', 'Education priority rank'),
  numberField('priority_utilities_rank', 'Utilities priority rank'),
  numberField('priority_health_rank', 'Health priority rank'),
  numberField('priority_recreation_rank', 'Recreation priority rank'),
  numberField('priority_savings_rank', 'Savings priority rank'),
  selectField('family_income_adequacy', 'Adequacy of family income', [
    'Adequate',
    'Not Adequate',
  ]),
];

final culturalIndicatorFields = [
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
  selectField('garbage_storage', 'Garbage storage', ['Container', 'None']),
  selectField('waste_segregation', 'Waste segregation', [
    'Practiced',
    'Not Practiced',
  ]),
  multiSelectField(
    'waste_disposal_method_if_practiced',
    'Waste disposal method if practiced',
    [
      'Hog-feeding',
      'Open dumping',
      'Burial in pit',
      'Collected',
      'Composting',
      'Open burning',
    ],
    visibleWhen: const SurveyVisibility.equals(
      'waste_segregation',
      'Practiced',
    ),
  ),
  multiSelectField(
    'reason_for_practicing_waste_segregation',
    'Reason for practicing waste segregation',
    [
      'Environmentally friendly',
      'Barangay ordinance which is strictly monitored',
      'Use for business',
      'Others',
    ],
    visibleWhen: const SurveyVisibility.equals(
      'waste_segregation',
      'Practiced',
    ),
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
    'Waste disposal method if not practiced',
    [
      'Hog-feeding',
      'Open dumping',
      'Burial in pit',
      'Collected',
      'Composting',
      'Open burning',
    ],
    visibleWhen: const SurveyVisibility.equals(
      'waste_segregation',
      'Not Practiced',
    ),
  ),
  multiSelectField(
    'reason_for_not_practicing_waste_segregation',
    'Reason for not practicing waste segregation',
    [
      'Not aware of effects',
      'No time to do it',
      'Long-time practice of family',
      'No barangay/municipality ordinance',
    ],
    visibleWhen: const SurveyVisibility.equals(
      'waste_segregation',
      'Not Practiced',
    ),
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
  selectField(
    'has_rabies_carrier_animals',
    'Presence of rabies carrier animals',
    yesNoOptions,
  ),
  tableField(
    'rabies_carrier_animals',
    'Rabies carrier animals',
    [
      textField('animal_kind', 'Animal kind'),
      numberField('animal_number', 'Number'),
      booleanField('kept_inside_yard', 'Kept inside yard'),
      booleanField('kept_free_outside', 'Kept free outside'),
      booleanField('with_regular_vaccination', 'With regular vaccination'),
      booleanField('without_vaccination', 'Without vaccination'),
    ],
    visibleWhen: const SurveyVisibility.equals(
      'has_rabies_carrier_animals',
      'Yes',
    ),
    addButtonLabel: 'Add Animal',
  ),
  multiSelectField('vector_control_measures', 'Control of insects/vectors', [
    'Fumigation',
    'Insecticides',
    'Setting traps',
    'Cleaning the yard',
    'None',
  ]),
  selectField(
    'has_breeding_sites_observed',
    'Breeding sites observed',
    yesNoOptions,
  ),
  selectField(
    'housing_congestion_observed',
    'Housing congestion observed',
    yesNoOptions,
  ),
  selectField(
    'has_industrial_establishment_or_factory_observed',
    'Industrial establishment/factory observed',
    yesNoOptions,
  ),
];

final lifestylePracticeFields = [
  selectField(
    'uses_safety_devices_when_necessary',
    'Uses safety devices when necessary',
    ['Practice', 'Not Practiced'],
  ),
  selectField(
    'has_cigarette_smoker_in_family',
    'Cigarette smoker in family',
    yesNoOptions,
  ),
  textField(
    'smoking_frequency_sticks_or_packs_per_day',
    'Smoking frequency, sticks or packs per day',
    visibleWhen: const SurveyVisibility.equals(
      'has_cigarette_smoker_in_family',
      'Yes',
    ),
  ),
  tableField(
    'cigarette_smokers',
    'Cigarette smokers',
    [
      textField('name', 'Name'),
      numberField('age', 'Age'),
      numberField('age_started_smoking', 'Age started smoking'),
      textField('reason', 'Reason'),
    ],
    visibleWhen: const SurveyVisibility.equals(
      'has_cigarette_smoker_in_family',
      'Yes',
    ),
    addButtonLabel: 'Add Smoker',
  ),
  selectField(
    'uses_prohibited_or_dangerous_drugs',
    'Uses prohibited/dangerous drugs',
    yesNoOptions,
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
    'Drug users',
    [
      textField('name', 'Name'),
      numberField('age', 'Age'),
      numberField('age_started_using_drugs', 'Age started using drugs'),
      textField('reason', 'Reason'),
    ],
    visibleWhen: const SurveyVisibility.equals(
      'uses_prohibited_or_dangerous_drugs',
      'Yes',
    ),
    addButtonLabel: 'Add Drug User',
  ),
  tableField('alcohol_drinkers', 'Alcohol drinkers', [
    textField('name', 'Name'),
    numberField('age', 'Age'),
    numberField('age_started_drinking_alcohol', 'Age started drinking alcohol'),
    textField('frequency', 'Frequency'),
    textField('reason', 'Reason'),
  ], addButtonLabel: 'Add Drinker'),
];

final nutritionalStatusFields = [
  tableField(
    'anthropometric_data_under_5',
    'Anthropometric data, 5 years below',
    [
      textField('name', 'Name'),
      numberField('age_in_months', 'Age in months'),
      numberField('weight_kg', 'Weight kg'),
      numberField('height_m', 'Height m'),
      numberField('bmi', 'BMI'),
      textField('bmi_remarks', 'BMI remarks'),
      numberField('waist_circumference_cm', 'Waist circumference cm'),
      numberField('hip_circumference_cm', 'Hip circumference cm'),
      numberField('waist_hip_ratio', 'Waist-hip ratio'),
      textField('waist_hip_ratio_remarks', 'Waist-hip ratio remarks'),
      numberField('mid_upper_arm_circumference', 'Mid-upper arm circumference'),
      textField('mid_upper_arm_remarks', 'Mid-upper arm remarks'),
    ],
    addButtonLabel: 'Add Child',
  ),
  tableField('food_recall_24_hour', '24-hour food recall', [
    dateField('date', 'Date'),
    selectField('time_of_day', 'Time of day', [
      'Breakfast',
      'Snack',
      'Lunch',
      'Dinner',
      'Midnight snack',
    ]),
    textareaField('food_taken', 'Food taken'),
  ], addButtonLabel: 'Add Food Recall'),
  selectField('first_food_choice', 'First food choice', [
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
  selectField('first_food_choice_servings', 'First food choice servings', [
    '1',
    '2-3',
    '4-5 and above',
  ]),
  selectField('second_food_choice', 'Second food choice', [
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
  selectField('second_food_choice_servings', 'Second food choice servings', [
    '1',
    '2-3',
    '4-5 and above',
  ]),
  multiSelectField('reason_for_food_choices', 'Reason for food choices', [
    'It is healthy',
    'Own preference',
    'Affordable',
    'Personal belief/practices',
    'Health condition',
  ]),
  multiSelectField(
    'reason_for_not_choosing_other_food_options',
    'Reason for not choosing other food options',
    [
      'Not healthy',
      'Own preference',
      'Not affordable',
      'Personal belief/religious practices',
      'Health condition',
    ],
  ),
  selectField(
    'food_intake_frequency',
    'Food intake frequency',
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
  selectField('food_prepared_for_mealtime', 'Food prepared for mealtime', [
    'Prepared at home',
    'Bought outside',
  ]),
  selectField(
    'food_preparation_frequency',
    'Food preparation frequency',
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
  multiSelectField(
    'bought_food_source',
    'Bought outside source',
    [
      'Restaurant/Fast food',
      'Carinderia',
      'Food cart, e.g. fried chicken sa kanto, provent, calamares',
    ],
    visibleWhen: const SurveyVisibility.equals(
      'food_prepared_for_mealtime',
      'Bought outside',
    ),
  ),
  multiSelectField(
    'reason_for_bought_food_option',
    'Reason for bought food option',
    ['Convenient', 'Cheaper', 'Healthy', 'Variety of choices', 'Others'],
    visibleWhen: const SurveyVisibility.equals(
      'food_prepared_for_mealtime',
      'Bought outside',
    ),
  ),
  textField(
    'reason_for_bought_food_option_other',
    'Other bought food reason',
    visibleWhen: const SurveyVisibility.contains(
      'reason_for_bought_food_option',
      'Others',
    ),
  ),
  selectField(
    'canned_preserved_food_frequency',
    'Canned/preserved food intake',
    preservedFoodFrequencyOptions,
  ),
  selectField(
    'grilled_food_frequency',
    'Grilled foods intake',
    preservedFoodFrequencyOptions,
  ),
  selectField('carbonated_beverage_frequency', 'Carbonated beverages intake', [
    'Everyday',
    'Every other day',
    'Every week',
    'Occasionally',
    'Sometimes',
    'Never',
  ]),
];

final beliefsPracticeFields = [
  multiSelectField(
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
  multiSelectField(
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
  multiSelectField(
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
  selectField('medical_checkup_frequency', 'Medical check-up', [
    'Once a year',
    'Twice a year',
    'More than a year',
  ]),
  selectField('dental_checkup_frequency', 'Dental check-up', [
    'Once a year',
    'Twice a year',
    'More than a year',
  ]),
];

final communityHealthProgramFields = [
  textareaField(
    'barangay_health_center_services_available',
    'Available health services at barangay health center',
  ),
  tableField(
    'immunization_records',
    'Immunization records',
    [
      textField('name', 'Name'),
      numberField('age_in_months', 'Age in months'),
      selectField('gender', 'Gender', ['Male', 'Female']),
      dateField('bcg', 'BCG date'),
      dateField('dpt_1', 'DPT 1 date'),
      dateField('dpt_2', 'DPT 2 date'),
      dateField('dpt_3', 'DPT 3 date'),
      dateField('hepa_b_1', 'Hepa B 1 date'),
      dateField('hepa_b_2', 'Hepa B 2 date'),
      dateField('hepa_b_3', 'Hepa B 3 date'),
      dateField('opv_1', 'OPV 1 date'),
      dateField('opv_2', 'OPV 2 date'),
      dateField('opv_3', 'OPV 3 date'),
      dateField('measles', 'Measles date'),
      booleanField('complete_according_to_age', 'Complete according to age'),
      booleanField(
        'incomplete_according_to_age',
        'Incomplete according to age',
      ),
      booleanField('fully_immunized_child', 'Fully immunized child'),
    ],
    addButtonLabel: 'Add Immunization Record',
  ),
  tableField(
    'antenatal_registrations',
    'Ante-natal registrations',
    [
      textField('name', 'Name'),
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
  ),
  booleanField('family_planning_eligible', 'Family planning eligible'),
  selectField('family_planning_status', 'Family planning status', [
    'Acceptor',
    'Non-Acceptor',
  ]),
  multiSelectField(
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
  multiSelectField(
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
  booleanField(
    'permanent_method_female_sterilization_btl',
    'Permanent method: female sterilization/BTL',
  ),
  booleanField(
    'permanent_method_male_sterilization_vasectomy',
    'Permanent method: male sterilization/vasectomy',
  ),
  booleanField('supply_method_pills', 'Supply method: pills'),
  booleanField('supply_method_iud', 'Supply method: IUD'),
  booleanField('supply_method_injectable', 'Supply method: injectable'),
  booleanField('supply_method_condoms', 'Supply method: condoms'),
  booleanField('supply_method_implant', 'Supply method: implant'),
  booleanField(
    'fertility_method_cervical_mucus_billings',
    'Fertility method: cervical mucus/Billings',
  ),
  booleanField(
    'fertility_method_basal_body_temperature',
    'Fertility method: basal body temperature',
  ),
  booleanField(
    'fertility_method_sympto_thermal',
    'Fertility method: sympto-thermal',
  ),
  booleanField(
    'fertility_method_standard_days',
    'Fertility method: standard days',
  ),
  booleanField(
    'fertility_method_lactational_amenorrhea',
    'Fertility method: lactational amenorrhea',
  ),
];

final healthIndicatorFields = [
  tableField('morbidity_records', 'Morbidity records', [
    textField('name', 'Name'),
    numberField('age', 'Age'),
    selectField('gender', 'Gender', ['Male', 'Female']),
    textField('cause', 'Cause'),
    booleanField('intervention_with', 'With intervention'),
    booleanField('intervention_without', 'Without intervention'),
    booleanField('admitted', 'Admitted'),
    booleanField('not_admitted', 'Not admitted'),
  ], addButtonLabel: 'Add Morbidity Record'),
  tableField(
    'mortality_records',
    'Mortality records, past 12 months',
    [
      textField('name', 'Name'),
      numberField('age', 'Age'),
      selectField('gender', 'Gender', ['Male', 'Female']),
      textField('cause_of_death', 'Cause of death'),
    ],
    addButtonLabel: 'Add Mortality Record',
  ),
  tableField(
    'non_communicable_disease_records',
    'Non-communicable disease records',
    [
      textField('name', 'Name'),
      numberField('age', 'Age'),
      selectField('gender', 'Gender', ['Male', 'Female']),
      textField('ncd', 'NCD'),
    ],
    addButtonLabel: 'Add NCD Record',
  ),
  tableField(
    'communicable_disease_records',
    'Communicable disease records',
    [
      textField('name', 'Name'),
      numberField('age', 'Age'),
      selectField('gender', 'Gender', ['Male', 'Female']),
      textField('cd', 'CD'),
    ],
    addButtonLabel: 'Add CD Record',
  ),
  tableField(
    'blood_pressure_records',
    'Blood pressure records, ages 35 and above',
    [
      textField('name', 'Name'),
      numberField('age', 'Age'),
      selectField('gender', 'Gender', ['Male', 'Female']),
      textField('bp', 'BP'),
    ],
    addButtonLabel: 'Add BP Record',
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
    'Effective practices/approaches in settling issues',
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
