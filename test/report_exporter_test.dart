import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasudlo/src/models.dart';
import 'package:kasudlo/src/services/report_exporter.dart';
import 'package:kasudlo/src/services/report_exporter_miniword.dart';
import 'package:kasudlo/src/survey_schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('report exporter writes Word files for selected records', () async {
    final submission = HealthSubmission(
      clientSubmissionId: 'one',
      respondentName: 'Ana Cruz',
      respondentAge: 30,
      address: 'Barangay 1',
      familyMembersCount: 4,
      familyMembers: const [
        FamilyMember(
          name: 'Nico Cruz',
          age: 8,
          relationship: 'Child',
          healthProblems: ['Cough or fever'],
          vaccinationStatus: 'Incomplete',
          nutritionalStatus: 'At risk',
        ),
      ],
      healthProblems: const ['Hypertension', 'Diabetes'],
      vaccinationStatus: 'Complete',
      waterSanitation: 'Safe water and sanitary toilet',
      nutritionalStatus: 'Normal',
      communityConcerns: const ['Dengue risk'],
      consentGiven: true,
      notes: 'Follow up next week.',
      createdAt: DateTime(2026, 5, 23, 9),
      syncStatus: SyncStatus.synced,
      surveyData: _sampleSurveyData(),
    );

    final templateDocs = await exportReportRecords(
      submissions: [submission],
      format: ReportExportFormat.templateDocs,
      exportedAt: DateTime(2026, 5, 24, 13, 5),
      docmosisRenderer:
          ({required submission, required fields, required fileName}) async {
            expect(submission.respondentName, 'Ana Cruz');
            expect(fileName, contains('kasudlo-community-survey-template'));
            expect(fields['control_no'], 'CTRL-001');
            expect(fields['respondentName'], 'Ana Cruz');
            expect(fields['address'], 'Barangay 1');
            expect(fields['surveyed_by'], 'Nurse Li');
            expect(fields['priority_food'], '1');
            expect(fields['priority_savings'], '6');
            expect(fields['expenditure_15001_20000'], true);
            return utf8.encode('docmosis:${fields['control_no']}:$fileName');
          },
    );
    addTearDown(() {
      for (final path in [templateDocs.savedLocation]) {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      }
    });

    expect(templateDocs.fileName, contains('template'));
    expect(templateDocs.fileName, endsWith('.docx'));
    expect(File(templateDocs.savedLocation).existsSync(), isTrue);

    final templateBytes = File(templateDocs.savedLocation).readAsStringSync();
    expect(templateBytes, contains('docmosis:CTRL-001'));
    expect(templateBytes, contains(templateDocs.fileName));
  });

  test('template fields normalize dietary recall rows for docx tags', () {
    Map<String, dynamic> fieldsFor(Object foodRecall) {
      final surveyData = _sampleSurveyData();
      surveyData['food_recall_24_hour'] = foodRecall;
      return docmosisTemplateFields(
        HealthSubmission(
          clientSubmissionId: 'dietary',
          respondentName: 'Ana Cruz',
          respondentAge: 30,
          address: 'Barangay 1',
          familyMembersCount: 4,
          familyMembers: const [],
          healthProblems: const [],
          vaccinationStatus: 'Complete',
          waterSanitation: 'Safe water and sanitary toilet',
          nutritionalStatus: 'Normal',
          communityConcerns: const [],
          consentGiven: true,
          notes: '',
          createdAt: DateTime(2026, 5, 23, 9),
          syncStatus: SyncStatus.synced,
          surveyData: surveyData,
        ),
      );
    }

    final manualFields = fieldsFor([
      {'time_of_day': 'Breakfast', 'food_taken': 'Rice and egg'},
      {'time_of_day': 'AM Snack', 'food_taken': 'Banana'},
      {'time_of_day': 'Lunch', 'food_taken': 'Fish and vegetables'},
      {'time_of_day': 'PM Snack', 'food_taken': 'Bread'},
      {'time_of_day': 'Dinner', 'food_taken': 'Soup'},
      {'time_of_day': 'Midnight Snack', 'food_taken': 'Milk'},
    ]);

    expect(manualFields['breakfast_food'], 'Rice and egg');
    expect(manualFields['snack1_food'], 'Banana');
    expect(manualFields['lunch_food'], 'Fish and vegetables');
    expect(manualFields['snack2_food'], 'Bread');
    expect(manualFields['dinner_food'], 'Soup');
    expect(manualFields['midnight_snack_food'], 'Milk');

    final directMealFields = fieldsFor([
      {
        'Breakfast': 'Rice porridge',
        'AM Snack': 'Fruit',
        'Lunch': 'Chicken',
        'PM Snack': 'Crackers',
        'Dinner': 'Rice and soup',
        'Midnight Snack': 'Water',
      },
    ]);

    expect(directMealFields['breakfast_food'], 'Rice porridge');
    expect(directMealFields['snack1_food'], 'Fruit');
    expect(directMealFields['lunch_food'], 'Chicken');
    expect(directMealFields['snack2_food'], 'Crackers');
    expect(directMealFields['dinner_food'], 'Rice and soup');
    expect(directMealFields['midnight_snack_food'], 'Water');
    expect(directMealFields['food_recall_24_hour'], hasLength(6));
  });

  test('template fields keep repeat tables flexible for extra rows', () {
    final surveyData = _sampleSurveyData();
    List<Map<String, dynamic>> repeatedRows(
      String key,
      int count, {
      String? labelKey,
      String labelPrefix = 'Row',
    }) {
      final base = Map<String, dynamic>.from(
        (surveyData[key] as List).single as Map,
      );
      return List.generate(
        count,
        (index) => {
          ...base,
          if (labelKey != null) labelKey: '$labelPrefix ${index + 1}',
        },
      );
    }

    final familyBase = Map<String, dynamic>.from(
      (surveyData['family_members'] as List).single as Map,
    );
    surveyData['family_members'] = List.generate(
      12,
      (index) => {
        ...familyBase,
        'member_no': index + 1,
        'name_of_family_member': 'Member ${index + 1}',
      },
    );
    surveyData['drug_users'] = List.generate(
      3,
      (index) => {
        'name': 'Drug User ${index + 1}',
        'age': 20 + index,
        'age_started_using_drugs': 18 + index,
        'types_of_drugs': 'Type ${index + 1}',
        'reason': 'Reason ${index + 1}',
      },
    );
    surveyData['alcohol_drinkers'] = List.generate(
      4,
      (index) => {
        'name': 'Alcohol Drinker ${index + 1}',
        'age': 30 + index,
        'age_started_drinking_alcohol': 19 + index,
        'frequency': 'Frequency ${index + 1}',
        'reason': 'Reason ${index + 1}',
      },
    );
    surveyData['income_earners'] = repeatedRows(
      'income_earners',
      5,
      labelKey: 'family_member_name',
      labelPrefix: 'Income Earner',
    );
    surveyData['cigarette_smokers'] = repeatedRows(
      'cigarette_smokers',
      6,
      labelKey: 'name',
      labelPrefix: 'Smoker',
    );
    surveyData['anthropometric_data_under_5'] = repeatedRows(
      'anthropometric_data_under_5',
      7,
      labelKey: 'name',
      labelPrefix: 'Anthro Child',
    );
    surveyData['immunization_records'] = repeatedRows(
      'immunization_records',
      8,
      labelKey: 'name',
      labelPrefix: 'Immun Child',
    );
    surveyData['antenatal_registrations'] = repeatedRows(
      'antenatal_registrations',
      3,
      labelKey: 'name',
      labelPrefix: 'Antenatal Patient',
    );
    surveyData['morbidity_records'] = repeatedRows(
      'morbidity_records',
      4,
      labelKey: 'name',
      labelPrefix: 'Morbidity Patient',
    );
    surveyData['mortality_records'] = repeatedRows(
      'mortality_records',
      3,
      labelKey: 'name',
      labelPrefix: 'Mortality Patient',
    );
    surveyData['non_communicable_disease_records'] = repeatedRows(
      'non_communicable_disease_records',
      3,
      labelKey: 'name',
      labelPrefix: 'NCD Patient',
    );
    surveyData['communicable_disease_records'] = repeatedRows(
      'communicable_disease_records',
      3,
      labelKey: 'name',
      labelPrefix: 'CD Patient',
    );
    surveyData['blood_pressure_records'] = repeatedRows(
      'blood_pressure_records',
      3,
      labelKey: 'name',
      labelPrefix: 'BP Patient',
    );
    surveyData['rabies_carrier_animals'] = repeatedRows(
      'rabies_carrier_animals',
      3,
      labelKey: 'animal_kind',
      labelPrefix: 'Animal',
    );
    surveyData['food_recall_24_hour'] = repeatedRows(
      'food_recall_24_hour',
      3,
      labelKey: 'food_taken',
      labelPrefix: 'Meal',
    );

    final fields = docmosisTemplateFields(
      HealthSubmission(
        clientSubmissionId: 'many-rows',
        respondentName: 'Ana Cruz',
        respondentAge: 30,
        address: 'Barangay 1',
        familyMembersCount: 12,
        familyMembers: const [],
        healthProblems: const [],
        vaccinationStatus: 'Complete',
        waterSanitation: 'Safe water and sanitary toilet',
        nutritionalStatus: 'Normal',
        communityConcerns: const [],
        consentGiven: true,
        notes: '',
        createdAt: DateTime(2026, 5, 23, 9),
        syncStatus: SyncStatus.synced,
        surveyData: surveyData,
      ),
    );

    final familyRows = fields['family_members'] as List;
    expect(familyRows, hasLength(12));
    expect(
      familyRows.map((row) => (row as Map)['name_of_family_member']),
      contains('Member 12'),
    );
    expect(
      familyRows.map((row) => (row as Map)['member_name']),
      contains('Member 12'),
    );

    final drugRows = fields['drug_users'] as List;
    expect(drugRows, hasLength(3));
    expect((drugRows.last as Map)['name'], 'Drug User 3');
    expect((drugRows.last as Map)['drug_user_name'], 'Drug User 3');

    final alcoholRows = fields['alcohol_drinkers'] as List;
    expect(alcoholRows, hasLength(4));
    expect((alcoholRows.last as Map)['name'], 'Alcohol Drinker 4');
    expect((alcoholRows.last as Map)['drinker_name'], 'Alcohol Drinker 4');

    expect(fields['income_earners'], hasLength(5));
    expect(fields['food_recall_24_hour'], hasLength(3));

    final smokerRows = fields['smokers'] as List;
    expect(fields['cigarette_smokers'], hasLength(6));
    expect(smokerRows, hasLength(6));
    expect((smokerRows.last as Map)['name'], 'Smoker 6');
    expect((smokerRows.last as Map)['smoker_name'], 'Smoker 6');

    final anthroRows = fields['anthropometric'] as List;
    expect(fields['anthropometric_data_under_5'], hasLength(7));
    expect(anthroRows, hasLength(7));
    expect((anthroRows.last as Map)['name'], 'Anthro Child 7');
    expect((anthroRows.last as Map)['anthro_name'], 'Anthro Child 7');

    final immunRows = fields['immunizations'] as List;
    expect(fields['immunization_records'], hasLength(8));
    expect(immunRows, hasLength(8));
    expect((immunRows.last as Map)['name'], 'Immun Child 8');
    expect((immunRows.last as Map)['immun_name'], 'Immun Child 8');

    final antenatalRows = fields['antenatal'] as List;
    expect(fields['antenatal_registrations'], hasLength(3));
    expect(antenatalRows, hasLength(3));
    expect((antenatalRows.last as Map)['name'], 'Antenatal Patient 3');
    expect(
      (antenatalRows.last as Map)['antenatal_name'],
      'Antenatal Patient 3',
    );

    final morbidityRows = fields['morbidity'] as List;
    expect(fields['morbidity_records'], hasLength(4));
    expect(morbidityRows, hasLength(4));
    expect((morbidityRows.last as Map)['name'], 'Morbidity Patient 4');
    expect(
      (morbidityRows.last as Map)['morbidity_name'],
      'Morbidity Patient 4',
    );

    final mortalityRows = fields['mortality'] as List;
    expect(fields['mortality_records'], hasLength(3));
    expect(mortalityRows, hasLength(3));
    expect((mortalityRows.last as Map)['name'], 'Mortality Patient 3');
    expect(
      (mortalityRows.last as Map)['mortality_name'],
      'Mortality Patient 3',
    );

    final ncdRows = fields['ncd_history'] as List;
    expect(fields['non_communicable_disease_records'], hasLength(3));
    expect(ncdRows, hasLength(3));
    expect((ncdRows.last as Map)['name'], 'NCD Patient 3');
    expect((ncdRows.last as Map)['ncd_name'], 'NCD Patient 3');

    final cdRows = fields['cd_history'] as List;
    expect(fields['communicable_disease_records'], hasLength(3));
    expect(cdRows, hasLength(3));
    expect((cdRows.last as Map)['name'], 'CD Patient 3');
    expect((cdRows.last as Map)['cd_name'], 'CD Patient 3');

    final bpRows = fields['bp_records'] as List;
    expect(fields['blood_pressure_records'], hasLength(3));
    expect(bpRows, hasLength(3));
    expect((bpRows.last as Map)['name'], 'BP Patient 3');
    expect((bpRows.last as Map)['bp_name'], 'BP Patient 3');

    final rabiesRows = fields['rabies_animals'] as List;
    expect(fields['rabies_carrier_animals'], hasLength(3));
    expect(rabiesRows, hasLength(3));
    expect((rabiesRows.last as Map)['animal_kind'], 'Animal 3');
    expect((rabiesRows.last as Map)['kind'], 'Animal 3');
  });

  test('manual Word exporter replaces split tags and schema aliases', () async {
    final submission = HealthSubmission(
      clientSubmissionId: 'manual-one',
      respondentName: 'Ana Cruz',
      respondentAge: 30,
      address: 'Barangay 1',
      familyMembersCount: 4,
      familyMembers: const [
        FamilyMember(
          name: 'Nico Cruz',
          age: 8,
          relationship: 'Child',
          healthProblems: ['Cough or fever'],
          vaccinationStatus: 'Incomplete',
          nutritionalStatus: 'At risk',
        ),
      ],
      healthProblems: const ['Hypertension', 'Diabetes'],
      vaccinationStatus: 'Complete',
      waterSanitation: 'Safe water and sanitary toilet',
      nutritionalStatus: 'Normal',
      communityConcerns: const ['Dengue risk'],
      consentGiven: true,
      notes: 'Follow up next week.',
      createdAt: DateTime(2026, 5, 23, 9),
      syncStatus: SyncStatus.synced,
      surveyData: _sampleSurveyData(),
    );

    final result = await exportReportRecordsMiniword(
      submissions: [submission],
      format: ReportExportFormatLegacy.docs,
      exportedAt: DateTime(2026, 5, 24, 13, 5),
    );
    addTearDown(() {
      final file = File(result.savedLocation);
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    final documentText = _docxDocumentText(File(result.savedLocation));
    expect(documentText, isNot(contains('{{')));
    expect(documentText, contains('3 sticks/day'));
    expect(documentText, contains('Stress'));
    expect(documentText, contains('Mediation by elders'));
    expect(documentText, contains('Nurse Li'));
    expect(documentText, contains('BHW, midwife, nurse'));
    expect(documentText, contains('One midwife per barangay'));
    expect(documentText, contains('1 team per 5,000 residents'));
    expect(documentText, contains('Quarterly barangay health nurse training'));
    expect(documentText, contains('Exported Information Table'));
    expect(documentText, contains('Control No'));
    expect(documentText, contains('CTRL-001'));
    expect(documentText, contains('Priority Food Rank'));
  });

  test('sample survey data covers every schema field key', () {
    final schemaKeys = <String>{};
    void collectSchemaFields(List<SurveyField> fields) {
      for (final field in fields) {
        if (field.type == SurveyFieldType.heading) {
          continue;
        }
        schemaKeys.add(field.key);
        collectSchemaFields(field.fields);
      }
    }

    for (final section in surveySections) {
      collectSchemaFields(section.fields);
    }

    final sampleKeys = <String>{};
    void collectSampleKeys(Object? value) {
      if (value is Map) {
        for (final entry in value.entries) {
          sampleKeys.add('${entry.key}');
          collectSampleKeys(entry.value);
        }
      } else if (value is Iterable) {
        for (final item in value) {
          collectSampleKeys(item);
        }
      }
    }

    collectSampleKeys(_sampleSurveyData());

    expect(sampleKeys, containsAll(schemaKeys));
  });
}

String _docxDocumentText(File file) {
  final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
  final documentXml = archive.findFile('word/document.xml');
  expect(documentXml, isNotNull);

  final content = utf8.decode(documentXml!.content);
  return content.replaceAll(RegExp(r'<[^>]+>'), '');
}

Map<String, dynamic> _sampleSurveyData() {
  return {
    'control_no': 'CTRL-001',
    'number_of_family': 4,
    'address': 'Barangay 1',
    'first_visit_date': '2026-05-20',
    'second_visit_date': '2026-05-21',
    'third_visit_date': '2026-05-22',
    'informant': 'Ana Cruz',
    'surveyed_by': 'Nurse Li',
    'time_started': '08:30',
    'time_finished': '10:00',
    'status_of_last_visit': 'Completed',
    'family_members': [
      {
        'member_no': 1,
        'name_of_family_member': 'Ana Cruz',
        'relationship_to_head': 'Head',
        'gender': 'Female',
        'age': 30,
        'birthdate_month': 4,
        'birthdate_day': 9,
        'birthdate_year': 1996,
        'marital_status': 'Married',
        'religion': 'Others',
        'religion_other': 'Aglipayan',
        'highest_educational_completed': 'College Graduate',
        'occupation_status': 'Employed',
        'employment_type_if_employed': 'Regular Full-time',
        'place_of_work_location': 'Within the municipality/city',
        'place_of_work_category': 'Office',
        'place_of_origin': 'Central Luzon',
        'length_of_residence': '10 years',
      },
    ],
    'family_composition_type': ['Nuclear'],
    'family_locus_of_power': 'Egalitarian',
    'family_place_of_residence': 'Neolocal',
    'family_descent': 'Bilateral',
    'dialect_frequently_used': 'Tagalog',
    'services_in_community': ['Religious services', 'Health Services'],
    'institutional_facilities': ['Brgy. Hall', 'Health Station'],
    'organizations': ['Others'],
    'organizations_other': 'Ateneo health mission',
    'traditions_customs': ['Bayanihan', 'Others'],
    'traditions_customs_other': 'Community clean-up',
    'recreational_facilities': ['Plaza', 'Others'],
    'recreational_facilities_other': 'Covered court',
    'mode_of_transportation': ['Tricycle', 'Private vehicle'],
    'mode_of_communication': ['Internet', 'Others'],
    'mode_of_communication_other': 'Messenger group',
    'income_earner_count': 1,
    'income_earners': [
      {
        'earner_no': 1,
        'family_member_no': 1,
        'family_member_name': 'Ana Cruz',
        'family_position': 'Head',
        'income_php': 24000,
      },
    ],
    'monthly_family_income_combined': '20,001-25,000',
    'financial_sources': ['Employment', 'Others'],
    'financial_sources_other': 'Small sari-sari store',
    'monthly_family_expenditures': '15,001-20,000',
    'priorities_and_expenditure_note':
        'Rank 1 as highest priority and 7 as lowest priority.',
    'priorities_ranking': 'Food: 1; Education: 2; Utilities: 3',
    'priority_food_rank': 1,
    'priority_clothing_rank': 5,
    'priority_education_rank': 2,
    'priority_utilities_rank': 3,
    'priority_health_rank': 4,
    'priority_recreation_rank': 7,
    'priority_savings_rank': 6,
    'family_income_adequacy': 'Adequate',
    'cultural_orientation_illness': ['Others'],
    'cultural_orientation_illness_other': 'Stress and fatigue',
    'cultural_belief_health_restoration': [
      'Health can be restored by health personnel, e.g. doctors, nurses',
    ],
    'cultural_perception_health_practices':
        'Sometimes practices local cultural practices about health matters',
    'community_involvement':
        'Actively joins fiesta, religious procession, local cultural practices',
    'home_ownership': 'Owned',
    'home_construction_materials': 'Strong/Concrete',
    'sleeping_rooms_count': '2',
    'home_space_adequacy': 'Adequate',
    'lighting_facility': 'Others',
    'lighting_facility_other': 'Solar lamp',
    'lighting_adequacy': 'Adequate',
    'ventilation_adequacy': 'Adequate',
    'general_sanitary_condition': 'Generally clean',
    'water_supply_ownership': 'Private',
    'water_source_cooking': 'Others',
    'water_source_cooking_other': 'Rainwater filtration',
    'water_source_drinking': 'Others',
    'water_source_drinking_other': 'Filtered refill',
    'water_source_bathing_cr_flushing': 'Others',
    'water_source_bathing_cr_flushing_other': 'Rain barrel',
    'water_potability_key_informant': 'Yes',
    'water_storage': 'Others',
    'water_storage_other': 'Sealed water jug',
    'water_source_distance_from_house': '12 meters',
    'food_storage_cover_status': 'Covered',
    'food_storage_type': ['Refrigerator', 'Cabinet'],
    'cooking_facility': ['Gas stove', 'Others'],
    'cooking_facility_other': 'Induction cooker',
    'cooking_area_sanitary_condition': 'Generally clean',
    'garbage_storage': 'Container',
    'waste_segregation': 'Practiced',
    'waste_disposal_method_if_practiced': ['Collected', 'Composting'],
    'reason_for_practicing_waste_segregation': ['Others'],
    'reason_for_practicing_waste_segregation_other': 'School campaign',
    'waste_disposal_method_if_not_practiced': ['Open dumping', 'Open burning'],
    'reason_for_not_practicing_waste_segregation': ['No time to do it'],
    'toilet_ownership': 'Owned',
    'toilet_type': 'Other',
    'toilet_type_other': 'Septic tank',
    'toilet_location_from_water_source': '20 ft. beyond',
    'toilet_sanitary_condition': 'Generally clean',
    'drainage_system': 'Open drainage',
    'drainage_condition': 'Flowing',
    'has_rabies_carrier_animals': 'Yes',
    'rabies_carrier_animals': [
      {
        'animal_kind': 'Dog',
        'animal_number': 1,
        'kept_inside_yard': true,
        'kept_free_outside': false,
        'with_regular_vaccination': true,
        'without_vaccination': false,
      },
    ],
    'vector_control_measures': ['Fumigation', 'Cleaning the yard'],
    'has_breeding_sites_observed': 'No',
    'housing_congestion_observed': 'No',
    'has_industrial_establishment_or_factory_observed': 'No',
    'uses_safety_devices_when_necessary': 'Practice',
    'has_cigarette_smoker_in_family': 'Yes',
    'smoking_frequency_sticks_or_packs_per_day': '3 sticks/day',
    'cigarette_smokers': [
      {
        'name': 'Mario Cruz',
        'age': 35,
        'age_started_smoking': 18,
        'reason': 'Stress',
      },
    ],
    'uses_prohibited_or_dangerous_drugs': 'Yes',
    'types_of_drugs': 'Solvent',
    'drug_users': [
      {
        'name': 'Sample User',
        'age': 20,
        'age_started_using_drugs': 19,
        'reason': 'Peer influence',
      },
    ],
    'has_alcohol_drinker': 'Yes',
    'alcohol_drinkers': [
      {
        'name': 'Mario Cruz',
        'age': 35,
        'age_started_drinking_alcohol': 21,
        'frequency': 'Weekly',
        'reason': 'Social events',
      },
    ],
    'has_children_under_5': 'Yes',
    'anthropometric_data_under_5': [
      {
        'name': 'Mika Cruz',
        'age_in_months': 42,
        'weight_kg': 15,
        'height_m': 0.96,
        'bmi': 16.3,
        'bmi_remarks': 'Normal',
        'waist_circumference_cm': 48,
        'hip_circumference_cm': 50,
        'waist_hip_ratio': 0.96,
        'waist_hip_ratio_remarks': 'Normal',
        'mid_upper_arm_circumference': 14,
        'mid_upper_arm_remarks': 'Normal',
      },
    ],
    'food_recall_date': '2026-05-20',
    'food_recall_24_hour': [
      {
        'date': '2026-05-20',
        'time_of_day': 'Breakfast',
        'food_taken': 'Rice, egg, and banana',
      },
    ],
    'first_food_choice': 'Others',
    'first_food_choice_other': 'Chicken',
    'first_food_choice_servings': '2-3',
    'second_food_choice': 'Others',
    'second_food_choice_other': 'Shrimp',
    'second_food_choice_servings': '1',
    'reason_for_food_choices': ['It is healthy', 'Affordable'],
    'reason_for_not_choosing_other_food_options': ['Not affordable'],
    'food_intake_frequency': 'Others',
    'food_intake_frequency_other': 'Three times a week',
    'food_prepared_for_mealtime': 'Bought outside',
    'food_preparation_frequency': 'Others',
    'food_preparation_frequency_other': 'Weekends',
    'bought_food_source': ['Carinderia'],
    'reason_for_bought_food_option': ['Convenient', 'Others'],
    'reason_for_bought_food_option_other': 'Late work schedule',
    'canned_preserved_food_frequency': 'Sometimes',
    'grilled_food_frequency': 'Every week',
    'carbonated_beverage_frequency': 'Occasionally',
    'personnel_consulted_during_illness': ['Doctor', 'Midwife'],
    'measures_taken_during_illness': ['Consult a Rural Health Team'],
    'medication_treatment_during_illness': ['Others'],
    'medication_treatment_during_illness_other': 'Herbal tea after consult',
    'medical_checkup_frequency': 'Once a year',
    'dental_checkup_frequency': 'More than a year',
    'barangay_health_center_services_available': ['RHU', 'BHC', 'Others'],
    'barangay_health_center_services_available_other': 'Nutrition counseling',
    'immunization_records': [
      {
        'name': 'Mika Cruz',
        'age_in_mos': 42,
        'gender': 'Female',
        'bcg': '2026-01-10',
        'dpt_1': '2026-02-10',
        'dpt_2': '2026-03-10',
        'dpt_3': '2026-04-10',
        'hepa_b_1': '2026-02-12',
        'hepa_b_2': '2026-03-12',
        'hepa_b_3': '2026-04-12',
        'opv_1': '2026-02-14',
        'opv_2': '2026-03-14',
        'opv_3': '2026-04-14',
        'measles': '2026-05-10',
        'complete_according_to_age': true,
        'incomplete_according_to_age': false,
        'fully_immunized_child': true,
      },
    ],
    'has_pregnant_woman': 'Yes',
    'antenatal_registrations': [
      {
        'name': 'Ana Cruz',
        'aog': '16 weeks',
        'prenatal_checkup_with_regular': true,
        'prenatal_checkup_with_not_regular': false,
        'prenatal_checkup_without': false,
        'tetanus_vaccination_with': true,
        'tetanus_vaccination_without': false,
      },
    ],
    'family_planning_eligible': true,
    'family_planning_status': 'Acceptor',
    'family_planning_acceptor_reasons': ['Others'],
    'family_planning_acceptor_reason_other': 'Birth spacing',
    'family_planning_non_acceptor_reasons': [
      'Bad for health of family',
      'Others',
    ],
    'family_planning_non_acceptor_reason_other': 'Partner concern',
    'permanent_method_female_sterilization_btl': false,
    'permanent_method_male_sterilization_vasectomy': false,
    'supply_method_pills': true,
    'supply_method_iud': false,
    'supply_method_injectable': false,
    'supply_method_condoms': true,
    'supply_method_implant': false,
    'fertility_method_cervical_mucus_billings': false,
    'fertility_method_basal_body_temperature': false,
    'fertility_method_sympto_thermal': false,
    'fertility_method_standard_days': false,
    'fertility_method_lactational_amenorrhea': false,
    'morbidity_records': [
      {
        'name': 'Ana Cruz',
        'age': 30,
        'gender': 'Female',
        'cause': 'Hypertension',
        'intervention_with': true,
        'intervention_without': false,
        'admitted': false,
        'not_admitted': true,
      },
    ],
    'has_mortality_past_12_months': 'Yes',
    'mortality_records': [
      {
        'name': 'Juan Cruz Sr.',
        'age': 75,
        'gender': 'Male',
        'cause_of_death': 'Stroke',
      },
    ],
    'non_communicable_disease_records': [
      {'name': 'Ana Cruz', 'age': 30, 'gender': 'Female', 'ncd': 'Diabetes'},
    ],
    'communicable_disease_records': [
      {'name': 'Nico Cruz', 'age': 8, 'gender': 'Male', 'cd': 'Cough'},
    ],
    'blood_pressure_records': [
      {'name': 'Mario Cruz', 'age': 35, 'gender': 'Male', 'bp': '120/80'},
    ],
    'awareness_of_bhc_rhu_health_services': 'Aware',
    'health_manpower_categories_available': 'BHW, midwife, nurse',
    'health_manpower_geographical_distribution': 'One midwife per barangay',
    'rhu_team_per_population_summary': '1 team per 5,000 residents',
    'physician_count_per_population': '1:5000',
    'nurse_count_per_population': '1:2500',
    'midwife_count_per_population': '1:1000',
    'other_rhu_team_count_per_population': '2 BHWs per purok',
    'existing_manpower_development_policies':
        'Quarterly barangay health nurse training',
    'rhu_physicians_schedule': 'Monday 9 AM',
    'rhu_nurse_schedule': 'Tuesday 9 AM',
    'bhc_midwife_schedule': 'Wednesday 9 AM',
    'health_budget_expenditures_availability': 'Available',
    'health_budget_amount_per_year_php': 100000,
    'supplies_equipment_availability': 'Limited Supplies',
    'recognized_formal_elected_leaders': ['Captain', 'Kagawad'],
    'recognized_non_formal_leaders': ['BHW', 'Religious leader'],
    'social_conflict_causes': ['Gossip', 'Others'],
    'social_conflict_causes_other': 'Parking disputes',
    'conflict_resolution_approaches': ['Brgy. hearing', 'Others'],
    'conflict_resolution_approaches_other': 'Mediation by elders',
    'general_lifestyle_area_concerns_suggestions':
        'Need street lighting and better drainage.',
  };
}
