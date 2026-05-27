import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasudlo/src/models.dart';
import 'package:kasudlo/src/services/report_exporter.dart';
import 'package:kasudlo/src/survey_schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'report exporter writes PDF and Docs files for selected records',
    () async {
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

      final pdf = await exportReportRecords(
        submissions: [submission],
        format: ReportExportFormat.pdf,
        exportedAt: DateTime(2026, 5, 24, 13, 5),
      );
      final docs = await exportReportRecords(
        submissions: [submission],
        format: ReportExportFormat.docs,
        exportedAt: DateTime(2026, 5, 24, 13, 5),
      );
      addTearDown(() {
        for (final path in [pdf.savedLocation, docs.savedLocation]) {
          final file = File(path);
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
      });

      expect(pdf.fileName, endsWith('.pdf'));
      expect(File(pdf.savedLocation).existsSync(), isTrue);
      final pdfBytes = File(pdf.savedLocation).readAsBytesSync();
      final keepPdfPath = Platform.environment['KASUDLO_KEEP_EXPORT_PDF'];
      if (keepPdfPath != null && keepPdfPath.trim().isNotEmpty) {
        File(keepPdfPath).writeAsBytesSync(pdfBytes);
      }
      expect(ascii.decode(pdfBytes.take(5).toList()), '%PDF-');
      final pdfRaw = latin1.decode(pdfBytes, allowInvalid: true);
      expect(pdfRaw, contains('/Image'));
      final pageCount = int.parse(
        RegExp(r'/Count (\d+)').firstMatch(pdfRaw)!.group(1)!,
      );
      expect(pageCount, 6);

      expect(docs.fileName, endsWith('.docx'));
      expect(File(docs.savedLocation).existsSync(), isTrue);
      final archive = ZipDecoder().decodeBytes(
        File(docs.savedLocation).readAsBytesSync(),
      );
      final documentXml = utf8.decode(
        archive.findFile('word/document.xml')!.readBytes()!,
      );
      expect(documentXml, contains('COMMUNITY SURVEY TOOL'));
      expect(documentXml, contains('<w:drawing>'));
      expect(documentXml, contains('Ana Cruz'));
      expect(documentXml, contains('Nico Cruz'));
      expect(documentXml, contains('Barangay 1'));
      expect(documentXml, contains('Safe water and sanitary toilet'));
      expect(documentXml, contains('Hypertension, Diabetes'));
      expect(documentXml, contains('Cough or fever'));
      expect(documentXml, contains('Captured PDF Field Responses'));
      expect(documentXml, contains('CTRL-001'));
      expect(documentXml, contains('Nurse Li'));
      expect(documentXml, contains('Religious services, Health Services'));
      expect(documentXml, contains('Family members row 1 - Member name'));
      expect(documentXml, contains('Income earners row 1 - Income PHP'));
      expect(documentXml, contains('Animals raised row 1 - Kind'));
      expect(documentXml, contains('Dog'));
      expect(
        documentXml,
        contains('Cigarette smoking details row 1 - Age started smoking'),
      );
      expect(
        documentXml,
        contains('A. Anthropometric Data (5 years below) row 1 - BMI'),
      );
      expect(documentXml, contains('Immunization records row 1 - BCG date'));
      expect(documentXml, contains('2026-01-10'));
      expect(documentXml, contains('Ateneo health mission'));
      expect(
        documentXml,
        contains('Need street lighting and better drainage.'),
      );
      expect(documentXml, contains('Rainwater filtration'));
      expect(documentXml, contains('Rain barrel'));
      expect(documentXml, contains('Open dumping, Open burning'));
      expect(documentXml, contains('No time to do it'));
      expect(documentXml, contains('Shrimp'));
      expect(documentXml, contains('Bad for health of family, Others'));
      expect(documentXml, contains('Partner concern'));
      expect(archive.findFile('word/media/college-of-nursing.png'), isNotNull);
      expect(
        archive.findFile('word/media/bulacan-state-university.png'),
        isNotNull,
      );
    },
  );

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
    'alcohol_drinkers': [
      {
        'name': 'Mario Cruz',
        'age': 35,
        'age_started_drinking_alcohol': 21,
        'frequency': 'Weekly',
        'reason': 'Social events',
      },
    ],
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
    'barangay_health_center_services_available':
        'Immunization, prenatal care, and nutrition counseling',
    'immunization_records': [
      {
        'name': 'Mika Cruz',
        'age_in_months': 42,
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
