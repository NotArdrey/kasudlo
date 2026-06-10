// ignore_for_file: unused_element

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

import '../models.dart';
import '../survey_schema.dart';
import 'docmosis_template_renderer.dart';
import 'report_file_saver_stub.dart'
    if (dart.library.html) 'report_file_saver_web.dart';

const _collegeLogoAsset = 'assets/template/college-of-nursing.png';
const _universityLogoAsset = 'assets/template/bulacan-state-university.png';

enum ReportExportFormat { templateDocs }

extension ReportExportFormatLabel on ReportExportFormat {
  String get label => switch (this) {
    ReportExportFormat.templateDocs => 'Export Word',
  };

  String get fileExtension => switch (this) {
    ReportExportFormat.templateDocs => 'docx',
  };

  String get mimeType => switch (this) {
    ReportExportFormat.templateDocs =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };
}

class ReportExportResult {
  const ReportExportResult({
    required this.fileName,
    required this.savedLocation,
    required this.recordCount,
    required this.format,
  });

  final String fileName;
  final String savedLocation;
  final int recordCount;
  final ReportExportFormat format;
}

typedef DocmosisReportRenderer =
    Future<List<int>> Function({
      required HealthSubmission submission,
      required Map<String, dynamic> fields,
      required String fileName,
    });

Future<ReportExportResult> exportReportRecords({
  required List<HealthSubmission> submissions,
  required ReportExportFormat format,
  DateTime? exportedAt,
  DocmosisReportRenderer? docmosisRenderer,
}) async {
  final exportTime = exportedAt ?? DateTime.now();
  final sortedSubmissions = submissions.toList()
    ..sort((a, b) => a.respondentName.compareTo(b.respondentName));
  if (format == ReportExportFormat.templateDocs &&
      sortedSubmissions.length != 1) {
    throw ArgumentError('Docmosis Word export requires exactly one record.');
  }
  final fileSlug = switch (format) {
    ReportExportFormat.templateDocs => 'kasudlo-community-survey-template',
  };
  final fileName =
      '$fileSlug-${DateFormat('yyyyMMdd-HHmmss').format(exportTime)}.${format.fileExtension}';
  final bytes = switch (format) {
    ReportExportFormat.templateDocs => await _buildDocmosisDocxBytes(
      sortedSubmissions.single,
      fileName,
      docmosisRenderer,
    ),
  };
  final savedLocation = await saveExportFile(
    bytes: bytes,
    fileName: fileName,
    mimeType: format.mimeType,
  );

  return ReportExportResult(
    fileName: fileName,
    savedLocation: savedLocation,
    recordCount: sortedSubmissions.length,
    format: format,
  );
}

Future<List<int>> _buildDocxBytes(List<HealthSubmission> submissions) async {
  final archive = Archive();
  void addFile(String name, String content) {
    archive.addFile(ArchiveFile.string(name, content));
  }

  Future<void> addAssetFile(String name, String assetPath) async {
    archive.addFile(ArchiveFile.bytes(name, await _loadAssetBytes(assetPath)));
  }

  addFile('[Content_Types].xml', _contentTypesXml);
  addFile('_rels/.rels', _packageRelsXml);
  addFile('docProps/app.xml', _appPropsXml);
  addFile('docProps/core.xml', _corePropsXml());
  addFile('word/_rels/document.xml.rels', _documentRelsXml);
  addFile('word/styles.xml', _stylesXml);
  addFile('word/document.xml', _documentXml(submissions));
  await addAssetFile('word/media/college-of-nursing.png', _collegeLogoAsset);
  await addAssetFile(
    'word/media/bulacan-state-university.png',
    _universityLogoAsset,
  );

  return ZipEncoder().encode(archive);
}

Future<List<int>> _buildDocmosisDocxBytes(
  HealthSubmission submission,
  String fileName,
  DocmosisReportRenderer? renderer,
) {
  final fields = docmosisTemplateFields(submission);
  final render = renderer ?? renderDocmosisTemplate;
  return render(submission: submission, fields: fields, fileName: fileName);
}

Map<String, dynamic> docmosisTemplateFields(HealthSubmission submission) {
  final data = submission.surveyData;

  String value(String key) => _surveyString(data, key);
  String fallback(String key, String fallbackValue) {
    final explicitValue = value(key);
    return explicitValue.isEmpty ? fallbackValue : explicitValue;
  }

  final incomeRows = _surveyMapRows(data['income_earners']);
  String earnerPosition(int index) {
    if (index >= incomeRows.length) {
      return '';
    }
    final row = incomeRows[index];
    final explicitPosition = _surveyRowValue(row, 'family_position');
    if (explicitPosition.isNotEmpty) {
      return explicitPosition;
    }
    return _incomeEarnerName(submission, row);
  }

  final fields = <String, dynamic>{
    ..._jsonSafeMap(data),
    'submission': _jsonSafeValue(submission.toJson()),
    'survey_data': _jsonSafeMap(data),
    'client_submission_id': submission.clientSubmissionId,
    'respondent_name': submission.respondentName,
    'respondentName': submission.respondentName,
    'respondent_age': submission.respondentAge,
    'respondentAge': submission.respondentAge,
    'family_members_count': submission.familyMembersCount,
    'familyMembersCount': submission.familyMembersCount,
    'family_members': submission.familyMembers
        .map((member) => _jsonSafeMap(member.toJson()))
        .toList(),
    'health_problems': submission.healthProblems,
    'vaccination_status': submission.vaccinationStatus,
    'water_sanitation': submission.waterSanitation,
    'nutritional_status': submission.nutritionalStatus,
    'community_concerns': submission.communityConcerns,
    'consent_given': submission.consentGiven,
    'notes': submission.notes,
    'created_at': submission.createdAt.toIso8601String(),
    'created_date': _dateOnly(submission.createdAt),
    'sync_status': submission.syncStatus.name,
    'control_no': value('control_no'),
    'number_of_family': fallback(
      'number_of_family',
      '${submission.familyMembersCount}',
    ),
    'address': fallback('address', submission.address),
    'first_visit_date': fallback(
      'first_visit_date',
      _dateOnly(submission.createdAt),
    ),
    'second_visit_date': value('second_visit_date'),
    'third_visit_date': value('third_visit_date'),
    'informant': fallback('informant', submission.respondentName),
    'surveyed_by': value('surveyed_by'),
    'time_started': value('time_started'),
    'time_finished': value('time_finished'),
    'status_of_last_visit': fallback(
      'status_of_last_visit',
      submission.syncStatus.name,
    ),
    'dialect_frequently_used': value('dialect_frequently_used'),
    'organizations_other': value('organizations_other'),
    'traditions_customs_other': value('traditions_customs_other'),
    'recreational_facilities_other': value('recreational_facilities_other'),
    'mode_of_communication_other': value('mode_of_communication_other'),
    'earner1_position': earnerPosition(0),
    'earner2_position': earnerPosition(1),
    'earner3_position': earnerPosition(2),
    'earner4_position': earnerPosition(3),
    'water_source_distance_from_house': value(
      'water_source_distance_from_house',
    ),
    'smoking_frequency_sticks_or_packs_per_day': value(
      'smoking_frequency_sticks_or_packs_per_day',
    ),
    'rhu_physicians_schedule': value('rhu_physicians_schedule'),
    'rhu_nurse_schedule': value('rhu_nurse_schedule'),
    'bhc_midwife_schedule': value('bhc_midwife_schedule'),
    'health_budget_amount_per_year_php': value(
      'health_budget_amount_per_year_php',
    ),
    'general_lifestyle_area_concerns_suggestions': value(
      'general_lifestyle_area_concerns_suggestions',
    ),
  };

  void applyFallback(
    List<SurveyField> surveyFields,
    Map<String, dynamic> targetMap,
  ) {
    for (final field in surveyFields) {
      if (field.type == SurveyFieldType.heading ||
          field.type == SurveyFieldType.note) {
        continue;
      }
      if (field.type == SurveyFieldType.repeatableTable) {
        final list = targetMap[field.key];
        if (list is List) {
          for (final item in list) {
            if (item is Map<String, dynamic>) {
              applyFallback(field.fields, item);
            }
          }
        }
      } else {
        final val = targetMap[field.key];

        if (field.type == SurveyFieldType.select ||
            field.type == SurveyFieldType.multiSelect ||
            field.type == SurveyFieldType.singleSelectCheckbox ||
            field.type == SurveyFieldType.multiSelectCheckbox) {
          final valList = val is List
              ? val.map((e) => '$e').toList()
              : [if (val != null && val != '') '$val'];

          for (final option in field.options) {
            final cleanOption = option.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
            targetMap['${field.key}_$cleanOption'] = valList.contains(option);

            // Also add the exact text with an equals sign for Docmosis templates
            // so that `<<cs_key=value>>` works out-of-the-box without modifying the doc.
            targetMap['${field.key}=$option'] = valList.contains(option);
            targetMap['{${field.key}=$option}'] = valList.contains(
              option,
            ); // Handle potential `{}` wrappers
          }
        }

        if (val == null ||
            (val is String && val.trim().isEmpty) ||
            (val is List && val.isEmpty)) {
          targetMap[field.key] = 'N/A';
        }
      }
    }
  }

  for (final section in surveySections) {
    applyFallback(section.fields, fields);
  }

  // --- START OF CUSTOM TAG MAPPING FOR DOCX TEMPLATE ---

  fields['alcohol_drinkers'] = _surveyMapRows(data['alcohol_drinkers'])
      .map(
        (row) => {
          'name': _surveyRowValue(row, 'name'),
          'age': _surveyRowValue(row, 'age'),
          'age_started_drinking_alcohol': _surveyRowValue(
            row,
            'age_started_drinking_alcohol',
          ),
          'frequency': _surveyRowValue(row, 'frequency'),
          'reason': _surveyRowValue(row, 'reason'),
          'drinker_name': _surveyRowValue(row, 'name'),
          'drinker_age': _surveyRowValue(row, 'age'),
          'drinker_age_started': _surveyRowValue(
            row,
            'age_started_drinking_alcohol',
          ),
          'drinker_frequency': _surveyRowValue(row, 'frequency'),
          'drinker_reason': _surveyRowValue(row, 'reason'),
        },
      )
      .toList();

  fields['antenatal'] = _surveyMapRows(data['antenatal_registrations'])
      .map(
        (row) => {
          'name': _surveyRowValue(row, 'name'),
          'aog': _surveyRowValue(row, 'aog'),
          'prenatal_checkup_with_regular': _surveyRowValue(
            row,
            'prenatal_checkup_with_regular',
          ),
          'prenatal_checkup_with_not_regular': _surveyRowValue(
            row,
            'prenatal_checkup_with_not_regular',
          ),
          'prenatal_checkup_without': _surveyRowValue(
            row,
            'prenatal_checkup_without',
          ),
          'tetanus_vaccination_with': _surveyRowValue(
            row,
            'tetanus_vaccination_with',
          ),
          'tetanus_vaccination_without': _surveyRowValue(
            row,
            'tetanus_vaccination_without',
          ),
          'antenatal_name': _surveyRowValue(row, 'name'),
          'antenatal_aog': _surveyRowValue(row, 'aog'),
          'prenatal_regular': _surveyRowValue(
            row,
            'prenatal_checkup_with_regular',
          ),
          'prenatal_not_regular': _surveyRowValue(
            row,
            'prenatal_checkup_with_not_regular',
          ),
          'prenatal_without': _surveyRowValue(row, 'prenatal_checkup_without'),
          'tetanus_with': _surveyRowValue(row, 'tetanus_vaccination_with'),
          'tetanus_without': _surveyRowValue(
            row,
            'tetanus_vaccination_without',
          ),
        },
      )
      .toList();

  fields['anthropometric'] = _surveyMapRows(data['anthropometric_data_under_5'])
      .map(
        (row) => {
          'anthro_name': _surveyRowValue(row, 'name'),
          'anthro_age_mos': _surveyRowValue(row, 'age_in_months'),
          'anthro_weight_kg': _surveyRowValue(row, 'weight_kg'),
          'anthro_height_m': _surveyRowValue(row, 'height_m'),
          'anthro_bmi': _surveyRowValue(row, 'bmi'),
          'anthro_bmi_remarks': _surveyRowValue(row, 'bmi_remarks'),
          'anthro_waist_cm': _surveyRowValue(row, 'waist_circumference_cm'),
          'anthro_hips_cm': _surveyRowValue(row, 'hip_circumference_cm'),
          'anthro_whr': _surveyRowValue(row, 'waist_hip_ratio'),
          'anthro_whr_remarks': _surveyRowValue(row, 'waist_hip_ratio_remarks'),
          'anthro_muac': _surveyRowValue(row, 'mid_upper_arm_circumference'),
          'anthro_muac_remarks': _surveyRowValue(row, 'mid_upper_arm_remarks'),
        },
      )
      .toList();

  fields['bp_records'] = _surveyMapRows(data['blood_pressure_records'])
      .map(
        (row) => {
          'name': _surveyRowValue(row, 'name'),
          'age': _surveyRowValue(row, 'age'),
          'gender': _surveyRowValue(row, 'gender'),
          'bp': _surveyRowValue(row, 'bp'),
          'bp_name': _surveyRowValue(row, 'name'),
          'bp_age': _surveyRowValue(row, 'age'),
          'bp_gender': _surveyRowValue(row, 'gender'),
          'bp_value': _surveyRowValue(row, 'bp'),
        },
      )
      .toList();

  fields['cd_history'] = _surveyMapRows(data['communicable_disease_records'])
      .map(
        (row) => {
          'cd_name': _surveyRowValue(row, 'name'),
          'cd_age': _surveyRowValue(row, 'age'),
          'cd_gender': _surveyRowValue(row, 'gender'),
          'cd_type': _surveyRowValue(row, 'cd'),
        },
      )
      .toList();

  fields['drug_users'] = _surveyMapRows(data['drug_users'])
      .map(
        (row) => {
          'name': _surveyRowValue(row, 'name'),
          'age': _surveyRowValue(row, 'age'),
          'age_started_using_drugs': _surveyRowValue(
            row,
            'age_started_using_drugs',
          ),
          'types_of_drugs': _surveyRowValue(row, 'reason', ['types_of_drugs']),
          'reason': _surveyRowValue(row, 'reason'),
          'drug_user_name': _surveyRowValue(row, 'name'),
          'drug_user_age': _surveyRowValue(row, 'age'),
          'drug_user_age_started': _surveyRowValue(
            row,
            'age_started_using_drugs',
          ),
          'drug_types': _surveyRowValue(row, 'reason', ['types_of_drugs']),
          'drug_user_reason': _surveyRowValue(row, 'reason'),
        },
      )
      .toList();

  fields['family_members'] = _demographicTemplateRows(submission)
      .map(
        (row) => {
          'member_no': row[0],
          'name_of_family_member': row[1],
          'member_name': row[1],
          'relationship_to_head': row[2],
          'gender': row[3],
          'age': row[4],
          'birthdate_month': row[5],
          'birth_month': row[5],
          'birthdate_day': row[6],
          'birth_day': row[6],
          'birthdate_year': row[7],
          'birth_year': row[7],
          'marital_status': row[8],
          'religion_other': row[9],
          'religion_other_legend': row[9],
          'highest_educational_completed': row[10],
          'highest_education': row[10],
          'occupation_status': row[11],
          'work_status': row[11],
          'employment_type_if_employed': row[12],
          'work_type': row[12],
          'place_of_work_location': row[13],
          'work_location': row[13],
          'place_of_work_category': row[14],
          'work_category': row[14],
          'place_of_origin': row[15],
          'work_place_origin': row[15],
          'length_of_residence': row[16],
          'residence_length': row[16],
          'religion': row[17],
        },
      )
      .toList();

  fields['immunizations'] = _surveyMapRows(data['immunization_records'])
      .map(
        (row) => {
          'immun_name': _surveyRowValue(row, 'name'),
          'immun_age_mos': _surveyRowValue(row, 'age_in_mos'),
          'immun_gender': _surveyRowValue(row, 'gender'),
          'immun_bcg': _surveyRowValue(row, 'bcg'),
          'immun_dpt1': _surveyRowValue(row, 'dpt_1'),
          'immun_dpt2': _surveyRowValue(row, 'dpt_2'),
          'immun_dpt3': _surveyRowValue(row, 'dpt_3'),
          'immun_hepa_b1': _surveyRowValue(row, 'hepa_b_1'),
          'immun_hepa_b2': _surveyRowValue(row, 'hepa_b_2'),
          'immun_hepa_b3': _surveyRowValue(row, 'hepa_b_3'),
          'immun_opv1': _surveyRowValue(row, 'opv_1'),
          'immun_opv2': _surveyRowValue(row, 'opv_2'),
          'immun_opv3': _surveyRowValue(row, 'opv_3'),
          'immun_measles': _surveyRowValue(row, 'measles'),
          'immun_complete_age': _surveyRowValue(
            row,
            'complete_according_to_age',
          ),
          'immun_incomplete_age': _surveyRowValue(
            row,
            'incomplete_according_to_age',
          ),
          'immun_fully_immunized': _surveyRowValue(
            row,
            'fully_immunized_child',
          ),
        },
      )
      .toList();

  fields['morbidity'] = _surveyMapRows(data['morbidity_records'])
      .map(
        (row) => {
          'name': _surveyRowValue(row, 'name'),
          'age': _surveyRowValue(row, 'age'),
          'gender': _surveyRowValue(row, 'gender'),
          'cause': _surveyRowValue(row, 'cause'),
          'intervention_with': _surveyRowValue(row, 'intervention_with'),
          'intervention_without': _surveyRowValue(row, 'intervention_without'),
          'admitted': _surveyRowValue(row, 'admitted'),
          'not_admitted': _surveyRowValue(row, 'not_admitted'),
          'morbidity_name': _surveyRowValue(row, 'name'),
          'morbidity_age': _surveyRowValue(row, 'age'),
          'morbidity_gender': _surveyRowValue(row, 'gender'),
          'morbidity_cause': _surveyRowValue(row, 'cause'),
          'morbidity_intervention_with': _surveyRowValue(
            row,
            'intervention_with',
          ),
          'morbidity_intervention_without': _surveyRowValue(
            row,
            'intervention_without',
          ),
          'morbidity_admitted': _surveyRowValue(row, 'admitted'),
          'morbidity_not_admitted': _surveyRowValue(row, 'not_admitted'),
        },
      )
      .toList();

  fields['mortality'] = _surveyMapRows(data['mortality_records'])
      .map(
        (row) => {
          'mortality_name': _surveyRowValue(row, 'name'),
          'mortality_age': _surveyRowValue(row, 'age'),
          'mortality_gender': _surveyRowValue(row, 'gender'),
          'mortality_cause_death': _surveyRowValue(row, 'cause_of_death'),
        },
      )
      .toList();

  fields['ncd_history'] =
      _surveyMapRows(data['non_communicable_disease_records'])
          .map(
            (row) => {
              'ncd_name': _surveyRowValue(row, 'name'),
              'ncd_age': _surveyRowValue(row, 'age'),
              'ncd_gender': _surveyRowValue(row, 'gender'),
              'ncd_type': _surveyRowValue(row, 'ncd'),
            },
          )
          .toList();

  fields['rabies_animals'] = _surveyMapRows(data['rabies_carrier_animals'])
      .map(
        (row) => {
          'animal_kind': _surveyRowValue(row, 'animal_kind'),
          'animal_number': _surveyRowValue(row, 'animal_number'),
          'animal_inside_yard': _surveyRowValue(row, 'kept_inside_yard'),
          'animal_free_outside': _surveyRowValue(row, 'kept_free_outside'),
          'animal_with_vaccine': _surveyRowValue(
            row,
            'with_regular_vaccination',
          ),
          'animal_without_vaccine': _surveyRowValue(row, 'without_vaccination'),
        },
      )
      .toList();

  fields['smokers'] = _surveyMapRows(data['cigarette_smokers'])
      .map(
        (row) => {
          'name': _surveyRowValue(row, 'name'),
          'age': _surveyRowValue(row, 'age'),
          'age_started_smoking': _surveyRowValue(row, 'age_started_smoking'),
          'reason': _surveyRowValue(row, 'reason'),
          'smoker_name': _surveyRowValue(row, 'name'),
          'smoker_age': _surveyRowValue(row, 'age'),
          'smoker_age_started': _surveyRowValue(row, 'age_started_smoking'),
          'smoker_reason': _surveyRowValue(row, 'reason'),
        },
      )
      .toList();

  // Custom Scalar Mappings
  fields['dialect_used'] = value('dialect_frequently_used');
  fields['bought_food_frequency_others'] = value(
    'food_preparation_frequency_other',
  );
  fields['bought_food_reason_others'] = value(
    'reason_for_bought_food_option_other',
  );
  fields['communication_others'] = value('mode_of_communication_other');
  fields['cooking_facility_others'] = value('cooking_facility_other');
  fields['dietary_recall_date'] = value('food_recall_date');

  final mealRecall = _mealRecallRows(data['food_recall_24_hour']);
  final mealMap = _mealRecallMap(mealRecall);
  fields['food_recall_24_hour'] = mealRecall;
  fields['breakfast_food'] = mealMap['Breakfast'] ?? '';
  fields['lunch_food'] = mealMap['Lunch'] ?? '';
  fields['dinner_food'] = mealMap['Dinner'] ?? '';
  fields['snack1_food'] = mealMap['AM Snack'] ?? '';
  fields['snack2_food'] = mealMap['PM Snack'] ?? '';
  fields['midnight_snack_food'] = mealMap['Midnight Snack'] ?? '';

  fields['family_type_composition'] = value('family_composition_type');
  fields['family_type_power'] = value('family_locus_of_power');
  fields['financial_source_others'] = value('financial_sources_other');
  fields['food_first_choice_others'] = value('first_food_choice_other');
  fields['food_intake_frequency_others'] = value('food_intake_frequency_other');
  fields['food_second_choice_others'] = value('second_food_choice_other');
  fields['fp_acceptor_reason_others'] = value(
    'family_planning_acceptor_reason_other',
  );
  fields['general_concerns_suggestions'] = value(
    'general_lifestyle_area_concerns_suggestions',
  );
  fields['health_budget_amount'] = value('health_budget_amount_per_year_php');
  fields['illness_cause_others'] = value('cultural_orientation_illness_other');
  fields['medication_others'] = value(
    'medication_treatment_during_illness_other',
  );
  fields['org_others'] = value('organizations_other');
  fields['bhc_health_services'] = value(
    'barangay_health_center_services_available',
  );
  fields['health_manpower_categories'] = value(
    'health_manpower_categories_available',
  );
  fields['health_manpower_distribution'] = value(
    'health_manpower_geographical_distribution',
  );
  fields['rhu_team_population'] = value('rhu_team_per_population_summary');
  if ('${fields['rhu_team_population']}'.trim().isEmpty) {
    fields['rhu_team_population'] = [
      value('physician_count_per_population'),
      value('nurse_count_per_population'),
      value('midwife_count_per_population'),
      value('other_rhu_team_count_per_population'),
    ].where((part) => part.isNotEmpty).join('; ');
  }
  fields['manpower_policies'] = value('existing_manpower_development_policies');

  final safetyDevices = value('uses_safety_devices_when_necessary');
  fields['safety_devices_practiced'] = safetyDevices == 'Practice' ? 'X' : ' ';
  fields['safety_devices_not_practiced'] = safetyDevices == 'Not Practiced'
      ? 'X'
      : ' ';

  final seg1 = value('reason_for_practicing_waste_segregation_other');
  final seg2 = value('reason_for_not_practicing_waste_segregation_other');
  fields['segregation_reason_others'] = seg1.isNotEmpty ? seg1 : seg2;

  fields['social_conflict_others'] = value('social_conflict_causes_other');
  fields['solvent_type'] = value('types_of_drugs');

  fields['water_bathing_others'] = value(
    'water_source_bathing_cr_flushing_other',
  );
  fields['water_cooking_others'] = value('water_source_cooking_other');
  fields['water_drinking_others'] = value('water_source_drinking_other');
  fields['water_storage_others'] = value('water_storage_other');

  fields['last_visit_status'] = fallback(
    'status_of_last_visit',
    submission.syncStatus.name,
  );

  fields['control_no'] = value('control_no');
  fields['number_of_family'] = value('number_of_family');
  fields['address'] = fallback('address', submission.address);
  fields['first_visit_date'] = value('first_visit_date');
  fields['second_visit_date'] = value('second_visit_date');
  fields['third_visit_date'] = value('third_visit_date');
  fields['informant'] = fallback('informant', submission.respondentName);
  fields['surveyed_by'] = value('surveyed_by');
  fields['time_started'] = value('time_started');
  fields['time_finished'] = value('time_finished');

  fields['religion_other_legend'] = value('religion_other');
  fields['tradition_custom_other'] = value('traditions_customs_other');
  fields['recreational_others'] = value('recreational_facilities_other');
  fields['lighting_others'] = value('lighting_facility_other');
  fields['water_source_distance'] = value('water_source_distance_from_house');
  fields['toilet_type_other'] = value('toilet_type_other');
  fields['smoking_frequency'] = value(
    'smoking_frequency_sticks_or_packs_per_day',
  );
  fields['drug_types'] = value('types_of_drugs');
  fields['fp_nonacceptor_reason_others'] = value(
    'family_planning_non_acceptor_reason_other',
  );
  fields['community_settlement_others'] = value('community_settlement_other');

  for (int i = 0; i < 4; i++) {
    if (i < incomeRows.length) {
      final row = incomeRows[i];
      fields['earner${i + 1}'] = _incomeEarnerName(submission, row);
      fields['earner${i + 1}_position'] = _surveyRowValue(
        row,
        'family_position',
        ['position'],
      );
      fields['earner${i + 1}_income'] = _surveyRowValue(row, 'income_php', [
        'income',
        'monthly_income_php',
      ]);
    } else {
      fields['earner${i + 1}'] = '';
      fields['earner${i + 1}_position'] = '';
      fields['earner${i + 1}_income'] = '';
    }
  }
  fields['bought_reason_cheaper'] = value(
    'reason_for_bought_food_option',
  ).contains('Cheaper');
  fields['bought_reason_convenient'] = value(
    'reason_for_bought_food_option',
  ).contains('Convenient');
  fields['bought_reason_healthy'] = value(
    'reason_for_bought_food_option',
  ).contains('Healthy');
  fields['bought_reason_others_checked'] = value(
    'reason_for_bought_food_option',
  ).contains('Others');
  fields['bought_reason_variety'] = value(
    'reason_for_bought_food_option',
  ).contains('Variety of choices');
  fields['breeding_sites_no'] = value('has_breeding_sites_observed') == 'No';
  fields['breeding_sites_yes'] = value('has_breeding_sites_observed') == 'Yes';
  fields['canned_food_every_other_day'] =
      value('canned_preserved_food_frequency') == 'Every other day';
  fields['canned_food_every_week'] =
      value('canned_preserved_food_frequency') == 'Every week';
  fields['canned_food_everyday'] =
      value('canned_preserved_food_frequency') == 'Everyday';
  fields['canned_food_never'] =
      value('canned_preserved_food_frequency') == 'Never';
  fields['canned_food_sometimes'] =
      value('canned_preserved_food_frequency') == 'Sometimes';
  fields['carbonated_every_other_day'] =
      value('carbonated_beverage_frequency') == 'Every other day';
  fields['carbonated_every_week'] =
      value('carbonated_beverage_frequency') == 'Every week';
  fields['carbonated_everyday'] =
      value('carbonated_beverage_frequency') == 'Everyday';
  fields['carbonated_never'] =
      value('carbonated_beverage_frequency') == 'Never';
  fields['carbonated_occasionally'] =
      value('carbonated_beverage_frequency') == 'Occasionally';
  fields['carbonated_sometimes'] =
      value('carbonated_beverage_frequency') == 'Sometimes';
  fields['communication_internet'] = value(
    'mode_of_communication',
  ).contains('Internet');
  fields['communication_others_checked'] = value(
    'mode_of_communication',
  ).contains('Others');
  fields['communication_telephone'] = value(
    'mode_of_communication',
  ).contains('Telephone');
  fields['communication_two_way_radio'] = value(
    'mode_of_communication',
  ).contains('Two-way radio');
  fields['community_services_health'] = value(
    'services_in_community',
  ).contains('Health Services');
  fields['community_services_livelihood'] = value(
    'services_in_community',
  ).contains('Livelihood Services');
  fields['community_services_religious'] = value(
    'services_in_community',
  ).contains('Religious services');
  fields['cooking_electric_stove'] =
      value('cooking_facility') == 'Electric stove';
  fields['cooking_firewood_charcoal'] =
      value('cooking_facility') == 'Firewood/charcoal';
  fields['cooking_gas_stove'] = value('cooking_facility') == 'Gas stove';
  fields['cooking_others_checked'] = value('cooking_facility') == 'Others';
  fields['dental_checkup_more_than_year'] =
      value('dental_checkup_frequency') == 'More than a year';
  fields['dental_checkup_once_year'] =
      value('dental_checkup_frequency') == 'Once a year';
  fields['dental_checkup_twice_year'] =
      value('dental_checkup_frequency') == 'Twice a year';
  fields['drainage_blind'] = value('drainage_system') == 'Blind drainage';
  fields['drainage_none'] = value('drainage_system') == 'None';
  fields['drainage_open'] = value('drainage_system') == 'Open drainage';
  fields['expenditure_10001_15000'] =
      value('monthly_family_expenditures') == '10,001-15,000';
  fields['expenditure_15001_20000'] =
      value('monthly_family_expenditures') == '15,001-20,000';
  fields['expenditure_20001_25000'] =
      value('monthly_family_expenditures') == '20,001-25,000';
  fields['expenditure_25001_30000'] =
      value('monthly_family_expenditures') == '25,001-30,000';
  fields['expenditure_30001_35000'] =
      value('monthly_family_expenditures') == '30,001-35,000';
  fields['expenditure_35001_40000'] =
      value('monthly_family_expenditures') == '35,001-40,000';
  fields['expenditure_40001_45000'] =
      value('monthly_family_expenditures') == '40,001-45,000';
  fields['expenditure_45001_50000'] =
      value('monthly_family_expenditures') == '45,001-50,000';
  fields['expenditure_50001_above'] =
      value('monthly_family_expenditures') == '50,001 and above';
  fields['expenditure_5001_10000'] =
      value('monthly_family_expenditures') == '5,001-10,000';
  fields['expenditure_less_5000'] =
      value('monthly_family_expenditures') == 'Less than 5,000';
  fields['financial_source_business'] = value(
    'financial_sources',
  ).contains('Business');
  fields['financial_source_employment'] = value(
    'financial_sources',
  ).contains('Employment');
  fields['financial_source_others_checked'] = value(
    'financial_sources',
  ).contains('Others');
  fields['financial_source_others'] = value('financial_sources_other');
  fields['financial_source_pension'] = value(
    'financial_sources',
  ).contains('Pension');
  fields['food_bought_outside'] =
      value('food_prepared_for_mealtime') == 'Bought outside';
  fields['food_prepared_home'] =
      value('food_prepared_for_mealtime') == 'Prepared at home';
  fields['food_storage_covered'] =
      value('food_storage_cover_status') == 'Covered';
  fields['food_storage_uncovered'] =
      value('food_storage_cover_status') == 'Uncovered';
  fields['garbage_storage_container'] = value('garbage_storage') == 'Container';
  fields['garbage_storage_none'] = value('garbage_storage') == 'None';
  fields['grilled_food_every_other_day'] =
      value('grilled_food_frequency') == 'Every other day';
  fields['grilled_food_every_week'] =
      value('grilled_food_frequency') == 'Every week';
  fields['grilled_food_everyday'] =
      value('grilled_food_frequency') == 'Everyday';
  fields['grilled_food_never'] = value('grilled_food_frequency') == 'Never';
  fields['grilled_food_sometimes'] =
      value('grilled_food_frequency') == 'Sometimes';
  fields['health_budget_amount'] = value('health_budget_amount_per_year_php');
  fields['health_budget_available'] =
      value('health_budget_expenditures_availability') == 'Available';
  fields['health_budget_not_available'] =
      value('health_budget_expenditures_availability') == 'Not Available';
  fields['health_restored_by_faith_healers'] = value(
    'cultural_belief_health_restoration',
  ).contains('Health can be restored by faith healers');
  fields['health_restored_by_god_faith'] = value(
    'cultural_belief_health_restoration',
  ).contains('Health can be restored by God/other spiritual faith');
  fields['health_restored_by_health_personnel'] =
      value('cultural_belief_health_restoration').contains(
        'Health can be restored by health personnel, e.g. doctors, nurses',
      );
  fields['health_restored_by_supernatural_power'] =
      value('cultural_belief_health_restoration').contains(
        'Health can be restored by supernatural power, e.g. tawas, hilot, hula',
      );
  fields['home_lease_to_own'] = value('home_ownership') == 'Lease/Least to own';
  fields['home_owned'] = value('home_ownership') == 'Owned';
  fields['home_professional_squatters'] =
      value('home_ownership') == 'Professional squatters';
  fields['home_rent_free'] = value('home_ownership') == 'Rent-free';
  fields['home_rented'] = value('home_ownership') == 'Rented';
  fields['home_squatting_informal_settlers'] =
      value('home_ownership') == 'Squatting/informal settlers';
  fields['housing_congestion_no'] =
      value('housing_congestion_observed') == 'No';
  fields['housing_congestion_yes'] =
      value('housing_congestion_observed') == 'Yes';
  fields['illness_cause_other_person'] = value(
    'cultural_orientation_illness',
  ).contains('Illness is caused by other person');
  fields['illness_cause_others_checked'] = value(
    'cultural_orientation_illness',
  ).contains('Others');
  fields['illness_cause_others'] = value('cultural_orientation_illness_other');
  fields['illness_cause_physiologic'] = value(
    'cultural_orientation_illness',
  ).contains('Illness is caused by physiologic factor, e.g. infection');
  fields['illness_cause_punishment_from_god'] = value(
    'cultural_orientation_illness',
  ).contains('Illness is a punishment from God');
  fields['illness_cause_supernatural'] = value(
    'cultural_orientation_illness',
  ).contains('Illness is caused by supernatural phenomenon, e.g. kulam, balis');
  fields['illness_cause_weather_change'] = value(
    'cultural_orientation_illness',
  ).contains('Illness is caused by change in weather');
  fields['income_10001_15000'] =
      value('monthly_family_income_combined') == '10,001-15,000';
  fields['income_15001_20000'] =
      value('monthly_family_income_combined') == '15,001-20,000';
  fields['income_20001_25000'] =
      value('monthly_family_income_combined') == '20,001-25,000';
  fields['income_25001_30000'] =
      value('monthly_family_income_combined') == '25,001-30,000';
  fields['income_30001_35000'] =
      value('monthly_family_income_combined') == '30,001-35,000';
  fields['income_35001_40000'] =
      value('monthly_family_income_combined') == '35,001-40,000';
  fields['income_40001_45000'] =
      value('monthly_family_income_combined') == '40,001-45,000';
  fields['income_45001_50000'] =
      value('monthly_family_income_combined') == '45,001-50,000';
  fields['income_50001_above'] =
      value('monthly_family_income_combined') == '50,001 and above';
  fields['income_5001_10000'] =
      value('monthly_family_income_combined') == '5,001-10,000';
  fields['income_adequate'] = value('family_income_adequacy') == 'Adequate';
  fields['income_less_5000'] =
      value('monthly_family_income_combined') == 'Less than 5,000';
  fields['income_not_adequate'] =
      value('family_income_adequacy') == 'Not Adequate';
  fields['industrial_establishment_no'] =
      value('has_industrial_establishment_or_factory_observed') == 'No';
  fields['industrial_establishment_yes'] =
      value('has_industrial_establishment_or_factory_observed') == 'Yes';
  fields['institution_brgy_hall'] = value(
    'institutional_facilities',
  ).contains('Brgy. Hall');
  fields['institution_church'] = value(
    'institutional_facilities',
  ).contains('Church');
  fields['institution_health_station'] = value(
    'institutional_facilities',
  ).contains('Health Station');
  fields['institution_school'] = value(
    'institutional_facilities',
  ).contains('School');
  fields['leader_bhw'] = value('recognized_non_formal_leaders').contains('BHW');
  fields['leader_captain'] = value(
    'recognized_formal_elected_leaders',
  ).contains('Captain');
  fields['leader_elderly'] = value(
    'recognized_non_formal_leaders',
  ).contains('Elderly');
  fields['leader_influential_person'] = value(
    'recognized_non_formal_leaders',
  ).contains('Influential person');
  fields['leader_kagawad'] = value(
    'recognized_formal_elected_leaders',
  ).contains('Kagawad');
  fields['leader_neighbor'] = value(
    'recognized_non_formal_leaders',
  ).contains('Neighbor');
  fields['leader_religious'] = value(
    'recognized_non_formal_leaders',
  ).contains('Religious leader');
  fields['lighting_adequate'] = value('lighting_adequacy') == 'Adequate';
  fields['lighting_electricity'] = value('lighting_facility') == 'Electricity';
  fields['lighting_inadequate'] = value('lighting_adequacy') == 'Inadequate';
  fields['lighting_kerosene'] = value('lighting_facility') == 'Kerosene';
  fields['lighting_others_checked'] = value('lighting_facility') == 'Others';
  fields['lighting_others'] = value('lighting_facility_other');
  fields['measure_community_healer'] = value(
    'measures_taken_during_illness',
  ).contains('See a known community healer');
  fields['measure_none'] = value(
    'measures_taken_during_illness',
  ).contains('None');
  fields['measure_private_health_worker'] = value(
    'measures_taken_during_illness',
  ).contains('Consult a private health worker');
  fields['measure_rural_health_team'] = value(
    'measures_taken_during_illness',
  ).contains('Consult a Rural Health Team');
  fields['measure_self_medication'] = value(
    'measures_taken_during_illness',
  ).contains('Self-Medication');
  fields['medical_checkup_more_than_year'] =
      value('medical_checkup_frequency') == 'More than a year';
  fields['medical_checkup_once_year'] =
      value('medical_checkup_frequency') == 'Once a year';
  fields['medical_checkup_twice_year'] =
      value('medical_checkup_frequency') == 'Twice a year';
  fields['medication_herbals'] = value(
    'medication_treatment_during_illness',
  ).contains('Herbals');
  fields['medication_others_checked'] = value(
    'medication_treatment_during_illness',
  ).contains('Others');
  fields['medication_others'] = value(
    'medication_treatment_during_illness_other',
  );
  fields['medication_prescribed_doctor'] = value(
    'medication_treatment_during_illness',
  ).contains('Prescribed by Doctor');
  fields['medication_self_medication_otc'] = value(
    'medication_treatment_during_illness',
  ).contains('Self-Medication/OTC drugs');
  fields['no_segregation_long_time_practice'] =
      value('reason_for_not_practicing_waste_segregation') ==
      'Long-time practice of family';
  fields['no_segregation_no_ordinance'] =
      value('reason_for_not_practicing_waste_segregation') ==
      'No barangay/municipality ordinance';
  fields['no_segregation_no_time'] =
      value('reason_for_not_practicing_waste_segregation') ==
      'No time to do it';
  fields['no_segregation_not_aware'] =
      value('reason_for_not_practicing_waste_segregation') ==
      'Not aware of effects';
  fields['org_others'] = value('organizations_other');
  fields['organization_others_checked'] = value(
    'organizations',
  ).contains('Others');
  fields['organization_senior_citizen'] = value(
    'organizations',
  ).contains('Senior Citizen');
  fields['organization_youth'] = value('organizations').contains('Youth');
  fields['rabies_animals_no'] = value('has_rabies_carrier_animals') == 'No';
  fields['rabies_animals_yes'] = value('has_rabies_carrier_animals') == 'Yes';
  fields['reason_choice_affordable'] = value(
    'reason_for_food_choices',
  ).contains('Affordable');
  fields['reason_choice_health_condition'] = value(
    'reason_for_food_choices',
  ).contains('Health condition');
  fields['reason_choice_healthy'] = value(
    'reason_for_food_choices',
  ).contains('It is healthy');
  fields['reason_choice_personal_belief'] = value(
    'reason_for_food_choices',
  ).contains('Personal belief/practices');
  fields['reason_choice_preference'] = value(
    'reason_for_food_choices',
  ).contains('Own preference');
  fields['reason_not_choose_health_condition'] = value(
    'reason_for_not_choosing_other_food_options',
  ).contains('Health condition');
  fields['reason_not_choose_not_affordable'] = value(
    'reason_for_not_choosing_other_food_options',
  ).contains('Not affordable');
  fields['reason_not_choose_not_healthy'] = value(
    'reason_for_not_choosing_other_food_options',
  ).contains('Not healthy');
  fields['reason_not_choose_personal_belief'] = value(
    'reason_for_not_choosing_other_food_options',
  ).contains('Personal belief/religious practices');
  fields['reason_not_choose_preference'] = value(
    'reason_for_not_choosing_other_food_options',
  ).contains('Own preference');
  fields['recreation_basketball_volleyball_court'] = value(
    'recreational_facilities',
  ).contains('Volleyball/Basketball court');
  fields['recreation_others_checked'] = value(
    'recreational_facilities',
  ).contains('Others');
  fields['recreation_playground'] = value(
    'recreational_facilities',
  ).contains('Playground');
  fields['recreation_plaza'] = value(
    'recreational_facilities',
  ).contains('Plaza');
  fields['recreational_others'] = value('recreational_facilities_other');
  fields['safety_devices_not_practiced'] =
      value('uses_safety_devices_when_necessary') == 'Not Practiced';
  fields['safety_devices_practiced'] =
      value('uses_safety_devices_when_necessary') == 'Practice';
  fields['sanitary_dirty'] = value('general_sanitary_condition') == 'Dirty';
  fields['sanitary_generally_clean'] =
      value('general_sanitary_condition') == 'Generally clean';
  fields['segregation_reason_barangay_ordinance'] =
      value('reason_for_practicing_waste_segregation') ==
      'Barangay ordinance which is strictly monitored';
  fields['segregation_reason_business'] =
      value('reason_for_practicing_waste_segregation') == 'Use for business';
  fields['segregation_reason_environment_friendly'] =
      value('reason_for_practicing_waste_segregation') ==
      'Environmentally friendly';
  fields['segregation_reason_others_checked'] =
      value('reason_for_practicing_waste_segregation') == 'Others';
  fields['segregation_reason_others'] = value(
    'reason_for_practicing_waste_segregation_other',
  );
  fields['sleeping_rooms_1'] = value('sleeping_rooms_count') == '1';
  fields['sleeping_rooms_2'] = value('sleeping_rooms_count') == '2';
  fields['sleeping_rooms_3'] = value('sleeping_rooms_count') == '3';
  fields['sleeping_rooms_4'] = value('sleeping_rooms_count') == '4';
  fields['sleeping_rooms_5'] = value('sleeping_rooms_count') == '5';
  fields['sleeping_rooms_none'] =
      value('sleeping_rooms_count') == 'None/no partition';
  fields['space_adequate'] = value('home_space_adequacy') == 'Adequate';
  fields['space_inadequate'] = value('home_space_adequacy') == 'Inadequate';
  fields['storage_basket'] = value('food_storage_type') == 'Basket';
  fields['storage_cabinet'] = value('food_storage_type') == 'Cabinet';
  fields['storage_refrigerator'] = value('food_storage_type') == 'Refrigerator';
  fields['storage_table'] = value('food_storage_type') == 'Table';
  fields['supplies_available_100'] =
      value('supplies_equipment_availability') == 'Available 100%';
  fields['supplies_limited'] =
      value('supplies_equipment_availability') == 'Limited Supplies';
  fields['supplies_not_available'] =
      value('supplies_equipment_availability') == 'Not Available';
  fields['toilet_ballot_system'] = value('toilet_type') == 'Ballot system';
  fields['toilet_flush_type'] = value('toilet_type') == 'Flush type';
  fields['toilet_location_20ft_beyond'] =
      value('toilet_location_from_water_source') == '20 ft. beyond';
  fields['toilet_location_less_20ft'] =
      value('toilet_location_from_water_source') == 'Less than 20 ft.';
  fields['toilet_none'] = value('toilet_ownership') == 'None';
  fields['toilet_other_checked'] = value('toilet_type') == 'Other';
  fields['toilet_overhung_latrine'] =
      value('toilet_type') == 'Overhung latrine';
  fields['toilet_owned'] = value('toilet_ownership') == 'Owned';
  fields['toilet_pail_system'] = value('toilet_type') == 'Pail system';
  fields['toilet_sanitary_clean'] =
      value('toilet_sanitary_condition') == 'Generally clean';
  fields['toilet_sanitary_dirty'] =
      value('toilet_sanitary_condition') == 'Dirty';
  fields['toilet_shared_public'] = value('toilet_ownership') == 'Shared/Public';
  fields['toilet_type_none'] = value('toilet_type') == 'None';
  fields['toilet_type_other'] = value('toilet_type_other');
  fields['toilet_water_sealed'] = value('toilet_type') == 'Water-sealed';
  fields['tradition_bayanihan'] = value(
    'traditions_customs',
  ).contains('Bayanihan');
  fields['tradition_close_family_ties'] = value(
    'traditions_customs',
  ).contains('Close family ties');
  fields['tradition_custom_other'] = value('traditions_customs_other');
  fields['tradition_fiestas'] = value('traditions_customs').contains('Fiestas');
  fields['tradition_ningas_kugon'] = value(
    'traditions_customs',
  ).contains('Ningas Kugon');
  fields['tradition_others_checked'] = value(
    'traditions_customs',
  ).contains('Others');
  fields['tradition_pakikisama'] = value(
    'traditions_customs',
  ).contains('Pakikisama');
  fields['tradition_palabra_de_honor'] = value(
    'traditions_customs',
  ).contains('Palabra de Honor');
  fields['tradition_respect_for_elderly'] = value(
    'traditions_customs',
  ).contains('Respect for elderly');
  fields['transport_bicycle'] = value(
    'mode_of_transportation',
  ).contains('Bicycle');
  fields['transport_jeep'] = value('mode_of_transportation').contains('Jeep');
  fields['transport_private_vehicle'] = value(
    'mode_of_transportation',
  ).contains('Private vehicle');
  fields['transport_puj_puv'] = value(
    'mode_of_transportation',
  ).contains('PUJ/PUV');
  fields['transport_tricycle'] = value(
    'mode_of_transportation',
  ).contains('Tricycle');
  fields['vector_control_cleaning_yard'] = value(
    'vector_control_measures',
  ).contains('Cleaning the yard');
  fields['vector_control_fumigation'] = value(
    'vector_control_measures',
  ).contains('Fumigation');
  fields['vector_control_insecticides'] = value(
    'vector_control_measures',
  ).contains('Insecticides');
  fields['vector_control_none'] = value(
    'vector_control_measures',
  ).contains('None');
  fields['vector_control_traps'] = value(
    'vector_control_measures',
  ).contains('Setting traps');
  fields['ventilation_adequate'] = value('ventilation_adequacy') == 'Adequate';
  fields['ventilation_inadequate'] =
      value('ventilation_adequacy') == 'Inadequate';
  fields['waste_segregation_not_practiced'] =
      value('waste_segregation') == 'Not Practiced';
  fields['waste_segregation_practiced'] =
      value('waste_segregation') == 'Practiced';
  fields['water_bathing_commercial'] =
      value('water_source_bathing_cr_flushing') == 'Commercial';
  fields['water_bathing_deep_well'] =
      value('water_source_bathing_cr_flushing') == 'Deep well';
  fields['water_bathing_local_district'] =
      value('water_source_bathing_cr_flushing') == 'Local Water District';
  fields['water_bathing_others_checked'] =
      value('water_source_bathing_cr_flushing') == 'Others';
  fields['water_bathing_others'] = value(
    'water_source_bathing_cr_flushing_other',
  );
  fields['water_cooking_commercial'] =
      value('water_source_cooking') == 'Commercial';
  fields['water_cooking_deep_well'] =
      value('water_source_cooking') == 'Deep well';
  fields['water_cooking_local_district'] =
      value('water_source_cooking') == 'Local Water District';
  fields['water_cooking_others_checked'] =
      value('water_source_cooking') == 'Others';
  fields['water_cooking_others'] = value('water_source_cooking_other');
  fields['water_drinking_commercial'] =
      value('water_source_drinking') == 'Commercial';
  fields['water_drinking_deep_well'] =
      value('water_source_drinking') == 'Deep well';
  fields['water_drinking_local_district'] =
      value('water_source_drinking') == 'Local Water District';
  fields['water_drinking_others_checked'] =
      value('water_source_drinking') == 'Others';
  fields['water_drinking_others'] = value('water_source_drinking_other');
  fields['water_ownership_private'] =
      value('water_supply_ownership') == 'Private';
  fields['water_ownership_public'] =
      value('water_supply_ownership') == 'Public';
  fields['water_potable_no'] = value('water_potability_key_informant') == 'No';
  fields['water_potable_yes'] =
      value('water_potability_key_informant') == 'Yes';
  fields['water_source_distance'] = value('water_source_distance_from_house');
  fields['water_storage_large_covered_with_faucet'] =
      value('water_storage') == 'Large covered container with faucet';
  fields['water_storage_large_covered_without_faucet'] =
      value('water_storage') == 'Large covered container without faucet';
  fields['water_storage_large_uncovered_with_faucet'] =
      value('water_storage') == 'Large uncovered container with faucet';
  fields['water_storage_large_uncovered_without_faucet'] =
      value('water_storage') == 'Large uncovered container without faucet';
  fields['water_storage_none_direct'] =
      value('water_storage') == 'None/direct from faucet or pipe';
  fields['water_storage_others_checked'] = value('water_storage') == 'Others';
  fields['water_storage_others'] = value('water_storage_other');

  fields['bhc_services_aware'] =
      value('awareness_of_health_services') == 'Aware';
  fields['bhc_services_unaware'] =
      value('awareness_of_health_services') == 'Unaware';
  fields['bought_food_everyday'] =
      value('food_preparation_frequency') == 'Everyday';
  fields['bought_food_once_week'] =
      value('food_preparation_frequency') == 'Once a week';
  fields['bought_food_others_checked'] =
      value('food_preparation_frequency') == 'Others';
  fields['bought_food_twice_week'] =
      value('food_preparation_frequency') == 'Twice a week';
  fields['bought_from_carinderia'] = value(
    'bought_food_source',
  ).contains('Carinderia');
  fields['bought_from_food_cart'] = value(
    'bought_food_source',
  ).contains('Food cart');
  fields['bought_from_restaurant_fastfood'] = value(
    'bought_food_source',
  ).contains('Restaurant/Fast food');
  fields['communication_cellphone'] = value(
    'mode_of_communication',
  ).contains('Cell phone');
  fields['communication_postal'] = value(
    'mode_of_communication',
  ).contains('Postal system');
  fields['community_involvement_active'] =
      value('community_involvement') ==
      'Actively joins fiesta, religious procession, local cultural practices';
  fields['community_involvement_not_active'] =
      value('community_involvement') == 'Does not actively join';
  fields['community_services_garbage_collection'] = value(
    'services_in_community',
  ).contains('Garbage collection');
  fields['community_services_livelihood_duplicate'] = value(
    'services_in_community',
  ).contains('Livelihood Services');
  fields['community_services_peace_order'] = value(
    'services_in_community',
  ).contains('Peace and Order');
  fields['construction_light'] =
      value('home_construction_materials') == 'Light';
  fields['construction_mixed'] =
      value('home_construction_materials') == 'Mixed';
  fields['construction_strong_concrete'] =
      value('home_construction_materials') == 'Strong/Concrete';
  fields['consult_albularyo'] = value(
    'personnel_consulted_during_illness',
  ).contains('Albularyo');
  fields['consult_doctor'] = value(
    'personnel_consulted_during_illness',
  ).contains('Doctor');
  fields['consult_elderly'] = value(
    'personnel_consulted_during_illness',
  ).contains('Elderly');
  fields['consult_faith_healer'] = value(
    'personnel_consulted_during_illness',
  ).contains('Faith Healer');
  fields['consult_hilot'] = value(
    'personnel_consulted_during_illness',
  ).contains('Hilot');
  fields['consult_midwife'] = value(
    'personnel_consulted_during_illness',
  ).contains('Midwife');
  fields['consult_nurse'] = value(
    'personnel_consulted_during_illness',
  ).contains('Nurse');
  fields['cooking_sanitary_dirty'] =
      value('cooking_area_sanitary_condition') == 'Dirty';
  fields['cooking_sanitary_generally_clean'] =
      value('cooking_area_sanitary_condition') == 'Generally clean';
  fields['cultural_practices_always'] =
      value('cultural_perception_health_practices') ==
      'Always practices local cultural practices about health matters';
  fields['cultural_practices_does_not_practice'] =
      value('cultural_perception_health_practices') ==
      'Does not practice any local cultural practices about health matters';
  fields['cultural_practices_sometimes'] =
      value('cultural_perception_health_practices') ==
      'Sometimes practices local cultural practices about health matters';
  fields['disposal_not_practiced_burial_pit'] =
      value('waste_disposal_method_if_not_practiced') == 'Burial in pit';
  fields['disposal_not_practiced_collected'] =
      value('waste_disposal_method_if_not_practiced') == 'Collected';
  fields['disposal_not_practiced_composting'] =
      value('waste_disposal_method_if_not_practiced') == 'Composting';
  fields['disposal_not_practiced_hog_feeding'] =
      value('waste_disposal_method_if_not_practiced') == 'Hog-feeding';
  fields['disposal_not_practiced_open_burning'] =
      value('waste_disposal_method_if_not_practiced') == 'Open burning';
  fields['disposal_not_practiced_open_dumping'] =
      value('waste_disposal_method_if_not_practiced') == 'Open dumping';
  fields['disposal_practiced_burial_pit'] =
      value('waste_disposal_method_if_practiced') == 'Burial in pit';
  fields['disposal_practiced_collected'] =
      value('waste_disposal_method_if_practiced') == 'Collected';
  fields['disposal_practiced_composting'] =
      value('waste_disposal_method_if_practiced') == 'Composting';
  fields['disposal_practiced_hog_feeding'] =
      value('waste_disposal_method_if_practiced') == 'Hog-feeding';
  fields['disposal_practiced_open_burning'] =
      value('waste_disposal_method_if_practiced') == 'Open burning';
  fields['disposal_practiced_open_dumping'] =
      value('waste_disposal_method_if_practiced') == 'Open dumping';
  fields['drainage_flowing'] = value('drainage_condition') == 'Flowing';
  fields['drainage_stagnant'] = value('drainage_condition') == 'Stagnant';
  fields['drug_types_checked'] = value('family_member_uses_drugs') == 'Yes';
  fields['drug_use_no'] = value('family_member_uses_drugs') == 'No';
  fields['drug_use_yes'] = value('family_member_uses_drugs') == 'Yes';
  fields['family_composition_nuclear'] = value(
    'family_composition_type',
  ).contains('Nuclear');
  fields['family_composition_extended'] = value(
    'family_composition_type',
  ).contains('Extended');
  fields['family_composition_dyad'] = value(
    'family_composition_type',
  ).contains('Dyad');
  fields['family_composition_same_sex'] = value(
    'family_composition_type',
  ).contains('Homosexual/Same Sex');
  fields['family_composition_cohabiting_communal'] = value(
    'family_composition_type',
  ).contains('Cohabiting/Communal');
  fields['family_composition_blended'] = value(
    'family_composition_type',
  ).contains('Blended Family');
  fields['family_composition_living_with_grandparents'] = value(
    'family_composition_type',
  ).contains('Living with Grandparent(s)');
  fields['family_composition_single_parent'] = value(
    'family_composition_type',
  ).contains('Single-parent');

  fields['family_power_patrifocal_patriarchal'] = value(
    'locus_of_power',
  ).contains('Patrifocal/Patriarchal');
  fields['family_power_matrifocal_matriarchal'] = value(
    'locus_of_power',
  ).contains('Matrifocal/Matriarchal');
  fields['family_power_egalitarian'] = value(
    'locus_of_power',
  ).contains('Egalitarian');
  fields['family_power_matricentric'] = value(
    'locus_of_power',
  ).contains('Matricentric');

  fields['family_residence_patrilocal'] = value(
    'place_of_residence',
  ).contains('Patrilocal');
  fields['family_residence_matrilocal'] = value(
    'place_of_residence',
  ).contains('Matrilocal');
  fields['family_residence_bilocal_ambilocal'] = value(
    'place_of_residence',
  ).contains('Bilocal (Ambilocal)');
  fields['family_residence_neolocal'] = value(
    'place_of_residence',
  ).contains('Neolocal');
  fields['financial_source_help_relative_friends'] = value(
    'financial_sources',
  ).contains('Help from relative/friends');
  fields['food_first_fish'] = value('first_food_choice') == 'Fish';
  fields['food_first_meat_only'] = value('first_food_choice') == 'Meat only';
  fields['food_first_mixed'] = value('first_food_choice') == 'Mixed';
  fields['food_first_others_checked'] = value('first_food_choice') == 'Others';
  fields['food_first_serving_1'] = value('first_food_choice_servings') == '1';
  fields['food_first_serving_2_3'] =
      value('first_food_choice_servings') == '2-3';
  fields['food_first_serving_4_5_above'] =
      value('first_food_choice_servings') == '4-5 and above';
  fields['food_first_vegetable'] = value('first_food_choice') == 'Vegetable';
  fields['food_intake_everyday'] = value('food_intake_frequency') == 'Everyday';
  fields['food_intake_once_week'] =
      value('food_intake_frequency') == 'Once a week';
  fields['food_intake_others_checked'] =
      value('food_intake_frequency') == 'Others';
  fields['food_intake_twice_week'] =
      value('food_intake_frequency') == 'Twice a week';
  fields['food_second_fish'] = value('second_food_choice') == 'Fish';
  fields['food_second_meat'] = value('second_food_choice') == 'Meat';
  fields['food_second_mixed'] = value('second_food_choice') == 'Mixed';
  fields['food_second_others_checked'] =
      value('second_food_choice') == 'Others';
  fields['food_second_serving_1'] = value('second_food_choice_servings') == '1';
  fields['food_second_serving_2_3'] =
      value('second_food_choice_servings') == '2-3';
  fields['food_second_serving_4_5_above'] =
      value('second_food_choice_servings') == '4-5 and above';
  fields['food_second_vegetable'] = value('second_food_choice') == 'Vegetable';
  fields['fp_acceptor_good_for_health'] = value(
    'reason_for_using_family_planning_method',
  ).contains('Good for health');
  fields['fp_acceptor_others_checked'] = value(
    'reason_for_using_family_planning_method',
  ).contains('Others');
  fields['fp_basal_body_temperature'] =
      value('family_planning_fertility_awareness_method') ==
      'Basal Body Temperature (BBT)';
  fields['fp_cervical_mucus'] =
      value('family_planning_fertility_awareness_method') ==
      'Cervical Mucus Method / Billings Ovu. Method';
  fields['fp_condoms'] = value('family_planning_supply_method') == 'Condoms';
  fields['fp_female_sterilization'] =
      value('family_planning_permanent_method') ==
      'Female sterilization / Bilateral Tubal Ligation';
  fields['fp_fertility_awareness_method'] =
      value('family_planning_temporary_method') ==
      'Fertility Awareness-Based Method';
  fields['fp_implant'] = value('family_planning_supply_method') == 'Implant';
  fields['fp_injectable'] =
      value('family_planning_supply_method') == 'Injectable';
  fields['fp_iud'] = value('family_planning_supply_method') == 'IUD';
  fields['fp_lactational_amenorrhea'] =
      value('family_planning_fertility_awareness_method') ==
      'Lactational Amenorrhea Method (LAM)';
  fields['fp_male_sterilization'] =
      value('family_planning_permanent_method') ==
      'Male sterilization / Vasectomy';
  fields['fp_nonacceptor_bad_for_health'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Bad for health');
  fields['fp_nonacceptor_influenced_by_others'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Influenced by others');
  fields['fp_nonacceptor_others_checked'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Others');
  fields['fp_nonacceptor_personal_belief'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Personal belief');
  fields['fp_nonacceptor_religious_belief'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Religious belief');
  fields['fp_permanent_method'] =
      value('modern_family_planning_method_used') == 'Permanent method';
  fields['fp_pills'] = value('family_planning_supply_method') == 'Pills';
  fields['fp_standard_days'] =
      value('family_planning_fertility_awareness_method') ==
      'Standard Days Method (SDM)';
  fields['fp_supply_methods'] =
      value('family_planning_temporary_method') == 'Supply Methods';
  fields['fp_sympto_thermal'] =
      value('family_planning_fertility_awareness_method') ==
      'Sympto-Thermal Method';
  fields['fp_temporary_method'] =
      value('modern_family_planning_method_used') == 'Temporary method';
  fields['priority_clothing'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Clothing');
  fields['priority_education'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Education');
  fields['priority_food'] =
      value('priorities_and_expenditure_ranking').contains('1. Food') ||
      value('priorities_and_expenditure_ranking').contains('Food');
  fields['priority_health'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Health');
  fields['priority_recreation'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Recreation');
  fields['priority_savings'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Savings');
  fields['priority_utilities'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Utilities');
  fields['settlement_barangay_hearing'] = value(
    'effective_practices_setting_issues',
  ).contains('Brgy. hearing');
  fields['settlement_local_police'] = value(
    'effective_practices_setting_issues',
  ).contains('Endorsed to local police');
  fields['settlement_others_checked'] = value(
    'effective_practices_setting_issues',
  ).contains('Others');
  fields['settlement_parties'] = value(
    'effective_practices_setting_issues',
  ).contains('Settlement among involved parties');
  fields['smoker_frequency_checked'] =
      value('family_member_is_cigarette_smoker') == 'Yes';
  fields['smoker_no'] = value('family_member_is_cigarette_smoker') == 'No';
  fields['smoker_yes'] = value('family_member_is_cigarette_smoker') == 'Yes';
  fields['social_conflict_alcohol'] = value(
    'source_of_social_conflict',
  ).contains('Alcohol');
  fields['social_conflict_drugs'] = value(
    'source_of_social_conflict',
  ).contains('Drugs');
  fields['social_conflict_family'] = value(
    'source_of_social_conflict',
  ).contains('Family dispute');
  fields['social_conflict_gossip'] = value(
    'source_of_social_conflict',
  ).contains('Gossip');
  fields['social_conflict_others_checked'] = value(
    'source_of_social_conflict',
  ).contains('Others');
  fields['social_conflict_riot'] = value(
    'source_of_social_conflict',
  ).contains('Riot');

  bool hasChoiceFromAny(Iterable<String> keys, String choice) {
    return keys.any((key) => _surveyHasChoice(data, key, choice));
  }

  bool hasExactValueFromAny(Iterable<String> keys, String choice) {
    final normalizedChoice = _normalizeSurveyChoice(choice);
    return keys.any(
      (key) => _normalizeSurveyChoice(value(key)) == normalizedChoice,
    );
  }

  bool hasYesFromAny(Iterable<String> keys) {
    return hasExactValueFromAny(keys, 'Yes');
  }

  bool hasNoFromAny(Iterable<String> keys) {
    return hasExactValueFromAny(keys, 'No');
  }

  bool isChecked(String key) => hasYesFromAny([key]);

  fields['bhc_services_aware'] =
      value('awareness_of_health_services') == 'Aware';
  fields['bhc_services_unaware'] =
      value('awareness_of_health_services') == 'Unaware';
  fields['bought_food_everyday'] =
      value('food_preparation_frequency') == 'Everyday';
  fields['bought_food_once_week'] =
      value('food_preparation_frequency') == 'Once a week';
  fields['bought_food_others_checked'] =
      value('food_preparation_frequency') == 'Others';
  fields['bought_food_twice_week'] =
      value('food_preparation_frequency') == 'Twice a week';
  fields['bought_from_carinderia'] = value(
    'bought_food_source',
  ).contains('Carinderia');
  fields['bought_from_food_cart'] = value(
    'bought_food_source',
  ).contains('Food cart');
  fields['bought_from_restaurant_fastfood'] = value(
    'bought_food_source',
  ).contains('Restaurant/Fast food');
  fields['communication_cellphone'] = value(
    'mode_of_communication',
  ).contains('Cell phone');
  fields['communication_postal'] = value(
    'mode_of_communication',
  ).contains('Postal system');
  fields['community_involvement_active'] =
      value('community_involvement') ==
      'Actively joins fiesta, religious procession, local cultural practices';
  fields['community_involvement_not_active'] =
      value('community_involvement') == 'Does not actively join';
  fields['community_services_garbage_collection'] = value(
    'services_in_community',
  ).contains('Garbage collection');
  fields['community_services_livelihood_duplicate'] = value(
    'services_in_community',
  ).contains('Livelihood Services');
  fields['community_services_peace_order'] = value(
    'services_in_community',
  ).contains('Peace and Order');
  fields['construction_light'] =
      value('home_construction_materials') == 'Light';
  fields['construction_mixed'] =
      value('home_construction_materials') == 'Mixed';
  fields['construction_strong_concrete'] =
      value('home_construction_materials') == 'Strong/Concrete';
  fields['consult_albularyo'] = value(
    'personnel_consulted_during_illness',
  ).contains('Albularyo');
  fields['consult_doctor'] = value(
    'personnel_consulted_during_illness',
  ).contains('Doctor');
  fields['consult_elderly'] = value(
    'personnel_consulted_during_illness',
  ).contains('Elderly');
  fields['consult_faith_healer'] = value(
    'personnel_consulted_during_illness',
  ).contains('Faith Healer');
  fields['consult_hilot'] = value(
    'personnel_consulted_during_illness',
  ).contains('Hilot');
  fields['consult_midwife'] = value(
    'personnel_consulted_during_illness',
  ).contains('Midwife');
  fields['consult_nurse'] = value(
    'personnel_consulted_during_illness',
  ).contains('Nurse');
  fields['cooking_sanitary_dirty'] =
      value('cooking_area_sanitary_condition') == 'Dirty';
  fields['cooking_sanitary_generally_clean'] =
      value('cooking_area_sanitary_condition') == 'Generally clean';
  fields['cultural_practices_always'] =
      value('cultural_perception_health_practices') ==
      'Always practices local cultural practices about health matters';
  fields['cultural_practices_does_not_practice'] =
      value('cultural_perception_health_practices') ==
      'Does not practice any local cultural practices about health matters';
  fields['cultural_practices_sometimes'] =
      value('cultural_perception_health_practices') ==
      'Sometimes practices local cultural practices about health matters';
  fields['disposal_not_practiced_burial_pit'] =
      value('waste_disposal_method_if_not_practiced') == 'Burial in pit';
  fields['disposal_not_practiced_collected'] =
      value('waste_disposal_method_if_not_practiced') == 'Collected';
  fields['disposal_not_practiced_composting'] =
      value('waste_disposal_method_if_not_practiced') == 'Composting';
  fields['disposal_not_practiced_hog_feeding'] =
      value('waste_disposal_method_if_not_practiced') == 'Hog-feeding';
  fields['disposal_not_practiced_open_burning'] =
      value('waste_disposal_method_if_not_practiced') == 'Open burning';
  fields['disposal_not_practiced_open_dumping'] =
      value('waste_disposal_method_if_not_practiced') == 'Open dumping';
  fields['disposal_practiced_burial_pit'] =
      value('waste_disposal_method_if_practiced') == 'Burial in pit';
  fields['disposal_practiced_collected'] =
      value('waste_disposal_method_if_practiced') == 'Collected';
  fields['disposal_practiced_composting'] =
      value('waste_disposal_method_if_practiced') == 'Composting';
  fields['disposal_practiced_hog_feeding'] =
      value('waste_disposal_method_if_practiced') == 'Hog-feeding';
  fields['disposal_practiced_open_burning'] =
      value('waste_disposal_method_if_practiced') == 'Open burning';
  fields['disposal_practiced_open_dumping'] =
      value('waste_disposal_method_if_practiced') == 'Open dumping';
  fields['drainage_flowing'] = value('drainage_condition') == 'Flowing';
  fields['drainage_stagnant'] = value('drainage_condition') == 'Stagnant';
  fields['drug_types_checked'] = value('family_member_uses_drugs') == 'Yes';
  fields['drug_use_no'] = value('family_member_uses_drugs') == 'No';
  fields['drug_use_yes'] = value('family_member_uses_drugs') == 'Yes';
  fields['family_composition_blended'] =
      value('type_of_family_composition') == 'Blended Family';
  fields['family_composition_cohabiting_communal'] =
      value('type_of_family_composition') == 'Cohabiting/Communal';
  fields['family_composition_dyad'] =
      value('type_of_family_composition') == 'Dyad';
  fields['family_composition_extended'] =
      value('type_of_family_composition') == 'Extended';
  fields['family_composition_living_with_grandparents'] =
      value('type_of_family_composition') == 'Living with Grandparent(s)';
  fields['family_composition_nuclear'] =
      value('type_of_family_composition') == 'Nuclear';
  fields['family_composition_same_sex'] =
      value('type_of_family_composition') == 'Homosexual/Same Sex';
  fields['family_composition_single_parent'] =
      value('type_of_family_composition') == 'Single- parent';
  fields['family_descent_bilateral'] =
      value('type_of_family_descent') == 'Bilateral';
  fields['family_descent_matrilineal'] =
      value('type_of_family_descent') == 'Matrilineal';
  fields['family_descent_patrilineal'] =
      value('type_of_family_descent') == 'Patrilineal';
  fields['family_power_egalitarian'] =
      value('type_of_family_locus_of_power') == 'Egalitarian';
  fields['family_power_matricentric'] =
      value('type_of_family_locus_of_power') == 'Matricentric';
  fields['family_power_matrifocal_matriarchal'] =
      value('type_of_family_locus_of_power') == 'Matrifocal/Matriarchal';
  fields['family_power_patrifocal_patriarchal'] =
      value('type_of_family_locus_of_power') == 'Patrifocal/Patriarchal';
  fields['family_residence_bilocal_ambilocal'] =
      value('type_of_family_place_of_residence') == 'Bilocal (Ambilocal)';
  fields['family_residence_matrilocal'] =
      value('type_of_family_place_of_residence') == 'Matrilocal';
  fields['family_residence_neolocal'] =
      value('type_of_family_place_of_residence') == 'Neolocal';
  fields['family_residence_patrilocal'] =
      value('type_of_family_place_of_residence') == 'Patrilocal';
  fields['financial_source_help_relative_friends'] = value(
    'financial_sources',
  ).contains('Help from relative/friends');
  fields['food_first_fish'] = value('first_food_choice') == 'Fish';
  fields['food_first_meat_only'] = value('first_food_choice') == 'Meat only';
  fields['food_first_mixed'] = value('first_food_choice') == 'Mixed';
  fields['food_first_others_checked'] = value('first_food_choice') == 'Others';
  fields['food_first_serving_1'] = value('first_food_choice_servings') == '1';
  fields['food_first_serving_2_3'] =
      value('first_food_choice_servings') == '2-3';
  fields['food_first_serving_4_5_above'] =
      value('first_food_choice_servings') == '4-5 and above';
  fields['food_first_vegetable'] = value('first_food_choice') == 'Vegetable';
  fields['food_intake_everyday'] = value('food_intake_frequency') == 'Everyday';
  fields['food_intake_once_week'] =
      value('food_intake_frequency') == 'Once a week';
  fields['food_intake_others_checked'] =
      value('food_intake_frequency') == 'Others';
  fields['food_intake_twice_week'] =
      value('food_intake_frequency') == 'Twice a week';
  fields['food_second_fish'] = value('second_food_choice') == 'Fish';
  fields['food_second_meat'] = value('second_food_choice') == 'Meat';
  fields['food_second_mixed'] = value('second_food_choice') == 'Mixed';
  fields['food_second_others_checked'] =
      value('second_food_choice') == 'Others';
  fields['food_second_serving_1'] = value('second_food_choice_servings') == '1';
  fields['food_second_serving_2_3'] =
      value('second_food_choice_servings') == '2-3';
  fields['food_second_serving_4_5_above'] =
      value('second_food_choice_servings') == '4-5 and above';
  fields['food_second_vegetable'] = value('second_food_choice') == 'Vegetable';
  fields['fp_acceptor_good_for_health'] = value(
    'reason_for_using_family_planning_method',
  ).contains('Good for health');
  fields['fp_acceptor_others_checked'] = value(
    'reason_for_using_family_planning_method',
  ).contains('Others');
  fields['fp_basal_body_temperature'] =
      value('family_planning_fertility_awareness_method') ==
      'Basal Body Temperature (BBT)';
  fields['fp_cervical_mucus'] =
      value('family_planning_fertility_awareness_method') ==
      'Cervical Mucus Method / Billings Ovu. Method';
  fields['fp_condoms'] = value('family_planning_supply_method') == 'Condoms';
  fields['fp_female_sterilization'] =
      value('family_planning_permanent_method') ==
      'Female sterilization / Bilateral Tubal Ligation';
  fields['fp_fertility_awareness_method'] =
      value('family_planning_temporary_method') ==
      'Fertility Awareness-Based Method';
  fields['fp_implant'] = value('family_planning_supply_method') == 'Implant';
  fields['fp_injectable'] =
      value('family_planning_supply_method') == 'Injectable';
  fields['fp_iud'] = value('family_planning_supply_method') == 'IUD';
  fields['fp_lactational_amenorrhea'] =
      value('family_planning_fertility_awareness_method') ==
      'Lactational Amenorrhea Method (LAM)';
  fields['fp_male_sterilization'] =
      value('family_planning_permanent_method') ==
      'Male sterilization / Vasectomy';
  fields['fp_nonacceptor_bad_for_health'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Bad for health');
  fields['fp_nonacceptor_influenced_by_others'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Influenced by others');
  fields['fp_nonacceptor_others_checked'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Others');
  fields['fp_nonacceptor_personal_belief'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Personal belief');
  fields['fp_nonacceptor_religious_belief'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Religious belief');
  fields['fp_permanent_method'] =
      value('modern_family_planning_method_used') == 'Permanent method';
  fields['fp_pills'] = value('family_planning_supply_method') == 'Pills';
  fields['fp_standard_days'] =
      value('family_planning_fertility_awareness_method') ==
      'Standard Days Method (SDM)';
  fields['fp_supply_methods'] =
      value('family_planning_temporary_method') == 'Supply Methods';
  fields['fp_sympto_thermal'] =
      value('family_planning_fertility_awareness_method') ==
      'Sympto-Thermal Method';
  fields['fp_temporary_method'] =
      value('modern_family_planning_method_used') == 'Temporary method';
  fields['priority_clothing'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Clothing');
  fields['priority_education'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Education');
  fields['priority_food'] =
      value('priorities_and_expenditure_ranking').contains('1. Food') ||
      value('priorities_and_expenditure_ranking').contains('Food');
  fields['priority_health'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Health');
  fields['priority_recreation'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Recreation');
  fields['priority_savings'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Savings');
  fields['priority_utilities'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Utilities');
  fields['settlement_barangay_hearing'] = value(
    'effective_practices_setting_issues',
  ).contains('Brgy. hearing');
  fields['settlement_local_police'] = value(
    'effective_practices_setting_issues',
  ).contains('Endorsed to local police');
  fields['settlement_others_checked'] = value(
    'effective_practices_setting_issues',
  ).contains('Others');
  fields['settlement_parties'] = value(
    'effective_practices_setting_issues',
  ).contains('Settlement among involved parties');
  fields['smoker_frequency_checked'] =
      value('family_member_is_cigarette_smoker') == 'Yes';
  fields['smoker_no'] = value('family_member_is_cigarette_smoker') == 'No';
  fields['smoker_yes'] = value('family_member_is_cigarette_smoker') == 'Yes';
  fields['social_conflict_alcohol'] = value(
    'source_of_social_conflict',
  ).contains('Alcohol');
  fields['social_conflict_drugs'] = value(
    'source_of_social_conflict',
  ).contains('Drugs');
  fields['social_conflict_family'] = value(
    'source_of_social_conflict',
  ).contains('Family dispute');
  fields['social_conflict_gossip'] = value(
    'source_of_social_conflict',
  ).contains('Gossip');
  fields['social_conflict_others_checked'] = value(
    'source_of_social_conflict',
  ).contains('Others');
  fields['social_conflict_riot'] = value(
    'source_of_social_conflict',
  ).contains('Riot');

  fields['bhc_services_aware'] =
      value('awareness_of_health_services') == 'Aware';
  fields['bhc_services_unaware'] =
      value('awareness_of_health_services') == 'Unaware';
  fields['bought_food_everyday'] =
      value('food_preparation_frequency') == 'Everyday';
  fields['bought_food_once_week'] =
      value('food_preparation_frequency') == 'Once a week';
  fields['bought_food_others_checked'] =
      value('food_preparation_frequency') == 'Others';
  fields['bought_food_twice_week'] =
      value('food_preparation_frequency') == 'Twice a week';
  fields['bought_from_carinderia'] = value(
    'bought_food_source',
  ).contains('Carinderia');
  fields['bought_from_food_cart'] = value(
    'bought_food_source',
  ).contains('Food cart');
  fields['bought_from_restaurant_fastfood'] = value(
    'bought_food_source',
  ).contains('Restaurant/Fast food');
  fields['communication_cellphone'] = value(
    'mode_of_communication',
  ).contains('Cell phone');
  fields['communication_postal'] = value(
    'mode_of_communication',
  ).contains('Postal system');
  fields['community_involvement_active'] =
      value('community_involvement') ==
      'Actively joins fiesta, religious procession, local cultural practices';
  fields['community_involvement_not_active'] =
      value('community_involvement') == 'Does not actively join';
  fields['community_services_garbage_collection'] = value(
    'services_in_community',
  ).contains('Garbage collection');
  fields['community_services_livelihood_duplicate'] = value(
    'services_in_community',
  ).contains('Livelihood Services');
  fields['community_services_peace_order'] = value(
    'services_in_community',
  ).contains('Peace and Order');
  fields['construction_light'] =
      value('home_construction_materials') == 'Light';
  fields['construction_mixed'] =
      value('home_construction_materials') == 'Mixed';
  fields['construction_strong_concrete'] =
      value('home_construction_materials') == 'Strong/Concrete';
  fields['consult_albularyo'] = value(
    'personnel_consulted_during_illness',
  ).contains('Albularyo');
  fields['consult_doctor'] = value(
    'personnel_consulted_during_illness',
  ).contains('Doctor');
  fields['consult_elderly'] = value(
    'personnel_consulted_during_illness',
  ).contains('Elderly');
  fields['consult_faith_healer'] = value(
    'personnel_consulted_during_illness',
  ).contains('Faith Healer');
  fields['consult_hilot'] = value(
    'personnel_consulted_during_illness',
  ).contains('Hilot');
  fields['consult_midwife'] = value(
    'personnel_consulted_during_illness',
  ).contains('Midwife');
  fields['consult_nurse'] = value(
    'personnel_consulted_during_illness',
  ).contains('Nurse');
  fields['cooking_sanitary_dirty'] =
      value('cooking_area_sanitary_condition') == 'Dirty';
  fields['cooking_sanitary_generally_clean'] =
      value('cooking_area_sanitary_condition') == 'Generally clean';
  fields['cultural_practices_always'] =
      value('cultural_perception_health_practices') ==
      'Always practices local cultural practices about health matters';
  fields['cultural_practices_does_not_practice'] =
      value('cultural_perception_health_practices') ==
      'Does not practice any local cultural practices about health matters';
  fields['cultural_practices_sometimes'] =
      value('cultural_perception_health_practices') ==
      'Sometimes practices local cultural practices about health matters';
  fields['disposal_not_practiced_burial_pit'] =
      value('waste_disposal_method_if_not_practiced') == 'Burial in pit';
  fields['disposal_not_practiced_collected'] =
      value('waste_disposal_method_if_not_practiced') == 'Collected';
  fields['disposal_not_practiced_composting'] =
      value('waste_disposal_method_if_not_practiced') == 'Composting';
  fields['disposal_not_practiced_hog_feeding'] =
      value('waste_disposal_method_if_not_practiced') == 'Hog-feeding';
  fields['disposal_not_practiced_open_burning'] =
      value('waste_disposal_method_if_not_practiced') == 'Open burning';
  fields['disposal_not_practiced_open_dumping'] =
      value('waste_disposal_method_if_not_practiced') == 'Open dumping';
  fields['disposal_practiced_burial_pit'] =
      value('waste_disposal_method_if_practiced') == 'Burial in pit';
  fields['disposal_practiced_collected'] =
      value('waste_disposal_method_if_practiced') == 'Collected';
  fields['disposal_practiced_composting'] =
      value('waste_disposal_method_if_practiced') == 'Composting';
  fields['disposal_practiced_hog_feeding'] =
      value('waste_disposal_method_if_practiced') == 'Hog-feeding';
  fields['disposal_practiced_open_burning'] =
      value('waste_disposal_method_if_practiced') == 'Open burning';
  fields['disposal_practiced_open_dumping'] =
      value('waste_disposal_method_if_practiced') == 'Open dumping';
  fields['drainage_flowing'] = value('drainage_condition') == 'Flowing';
  fields['drainage_stagnant'] = value('drainage_condition') == 'Stagnant';
  fields['drug_types_checked'] = value('family_member_uses_drugs') == 'Yes';
  fields['drug_use_no'] = value('family_member_uses_drugs') == 'No';
  fields['drug_use_yes'] = value('family_member_uses_drugs') == 'Yes';
  fields['family_composition_blended'] =
      value('type_of_family_composition') == 'Blended Family';
  fields['family_composition_cohabiting_communal'] =
      value('type_of_family_composition') == 'Cohabiting/Communal';
  fields['family_composition_dyad'] =
      value('type_of_family_composition') == 'Dyad';
  fields['family_composition_extended'] =
      value('type_of_family_composition') == 'Extended';
  fields['family_composition_living_with_grandparents'] =
      value('type_of_family_composition') == 'Living with Grandparent(s)';
  fields['family_composition_nuclear'] =
      value('type_of_family_composition') == 'Nuclear';
  fields['family_composition_same_sex'] =
      value('type_of_family_composition') == 'Homosexual/Same Sex';
  fields['family_composition_single_parent'] =
      value('type_of_family_composition') == 'Single- parent';
  fields['family_descent_bilateral'] =
      value('type_of_family_descent') == 'Bilateral';
  fields['family_descent_matrilineal'] =
      value('type_of_family_descent') == 'Matrilineal';
  fields['family_descent_patrilineal'] =
      value('type_of_family_descent') == 'Patrilineal';
  fields['family_power_egalitarian'] =
      value('type_of_family_locus_of_power') == 'Egalitarian';
  fields['family_power_matricentric'] =
      value('type_of_family_locus_of_power') == 'Matricentric';
  fields['family_power_matrifocal_matriarchal'] =
      value('type_of_family_locus_of_power') == 'Matrifocal/Matriarchal';
  fields['family_power_patrifocal_patriarchal'] =
      value('type_of_family_locus_of_power') == 'Patrifocal/Patriarchal';
  fields['family_residence_bilocal_ambilocal'] =
      value('type_of_family_place_of_residence') == 'Bilocal (Ambilocal)';
  fields['family_residence_matrilocal'] =
      value('type_of_family_place_of_residence') == 'Matrilocal';
  fields['family_residence_neolocal'] =
      value('type_of_family_place_of_residence') == 'Neolocal';
  fields['family_residence_patrilocal'] =
      value('type_of_family_place_of_residence') == 'Patrilocal';
  fields['financial_source_help_relative_friends'] = value(
    'financial_sources',
  ).contains('Help from relative/friends');
  fields['food_first_fish'] = value('first_food_choice') == 'Fish';
  fields['food_first_meat_only'] = value('first_food_choice') == 'Meat only';
  fields['food_first_mixed'] = value('first_food_choice') == 'Mixed';
  fields['food_first_others_checked'] = value('first_food_choice') == 'Others';
  fields['food_first_serving_1'] = value('first_food_choice_servings') == '1';
  fields['food_first_serving_2_3'] =
      value('first_food_choice_servings') == '2-3';
  fields['food_first_serving_4_5_above'] =
      value('first_food_choice_servings') == '4-5 and above';
  fields['food_first_vegetable'] = value('first_food_choice') == 'Vegetable';
  fields['food_intake_everyday'] = value('food_intake_frequency') == 'Everyday';
  fields['food_intake_once_week'] =
      value('food_intake_frequency') == 'Once a week';
  fields['food_intake_others_checked'] =
      value('food_intake_frequency') == 'Others';
  fields['food_intake_twice_week'] =
      value('food_intake_frequency') == 'Twice a week';
  fields['food_second_fish'] = value('second_food_choice') == 'Fish';
  fields['food_second_meat'] = value('second_food_choice') == 'Meat';
  fields['food_second_mixed'] = value('second_food_choice') == 'Mixed';
  fields['food_second_others_checked'] =
      value('second_food_choice') == 'Others';
  fields['food_second_serving_1'] = value('second_food_choice_servings') == '1';
  fields['food_second_serving_2_3'] =
      value('second_food_choice_servings') == '2-3';
  fields['food_second_serving_4_5_above'] =
      value('second_food_choice_servings') == '4-5 and above';
  fields['food_second_vegetable'] = value('second_food_choice') == 'Vegetable';
  fields['fp_acceptor_good_for_health'] = value(
    'reason_for_using_family_planning_method',
  ).contains('Good for health');
  fields['fp_acceptor_others_checked'] = value(
    'reason_for_using_family_planning_method',
  ).contains('Others');
  fields['fp_basal_body_temperature'] =
      value('family_planning_fertility_awareness_method') ==
      'Basal Body Temperature (BBT)';
  fields['fp_cervical_mucus'] =
      value('family_planning_fertility_awareness_method') ==
      'Cervical Mucus Method / Billings Ovu. Method';
  fields['fp_condoms'] = value('family_planning_supply_method') == 'Condoms';
  fields['fp_female_sterilization'] =
      value('family_planning_permanent_method') ==
      'Female sterilization / Bilateral Tubal Ligation';
  fields['fp_fertility_awareness_method'] =
      value('family_planning_temporary_method') ==
      'Fertility Awareness-Based Method';
  fields['fp_implant'] = value('family_planning_supply_method') == 'Implant';
  fields['fp_injectable'] =
      value('family_planning_supply_method') == 'Injectable';
  fields['fp_iud'] = value('family_planning_supply_method') == 'IUD';
  fields['fp_lactational_amenorrhea'] =
      value('family_planning_fertility_awareness_method') ==
      'Lactational Amenorrhea Method (LAM)';
  fields['fp_male_sterilization'] =
      value('family_planning_permanent_method') ==
      'Male sterilization / Vasectomy';
  fields['fp_nonacceptor_bad_for_health'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Bad for health');
  fields['fp_nonacceptor_influenced_by_others'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Influenced by others');
  fields['fp_nonacceptor_others_checked'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Others');
  fields['fp_nonacceptor_personal_belief'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Personal belief');
  fields['fp_nonacceptor_religious_belief'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Religious belief');
  fields['fp_permanent_method'] =
      value('modern_family_planning_method_used') == 'Permanent method';
  fields['fp_pills'] = value('family_planning_supply_method') == 'Pills';
  fields['fp_standard_days'] =
      value('family_planning_fertility_awareness_method') ==
      'Standard Days Method (SDM)';
  fields['fp_supply_methods'] =
      value('family_planning_temporary_method') == 'Supply Methods';
  fields['fp_sympto_thermal'] =
      value('family_planning_fertility_awareness_method') ==
      'Sympto-Thermal Method';
  fields['fp_temporary_method'] =
      value('modern_family_planning_method_used') == 'Temporary method';
  fields['priority_clothing'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Clothing');
  fields['priority_education'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Education');
  fields['priority_food'] =
      value('priorities_and_expenditure_ranking').contains('1. Food') ||
      value('priorities_and_expenditure_ranking').contains('Food');
  fields['priority_health'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Health');
  fields['priority_recreation'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Recreation');
  fields['priority_savings'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Savings');
  fields['priority_utilities'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Utilities');
  fields['settlement_barangay_hearing'] = value(
    'effective_practices_setting_issues',
  ).contains('Brgy. hearing');
  fields['settlement_local_police'] = value(
    'effective_practices_setting_issues',
  ).contains('Endorsed to local police');
  fields['settlement_others_checked'] = value(
    'effective_practices_setting_issues',
  ).contains('Others');
  fields['settlement_parties'] = value(
    'effective_practices_setting_issues',
  ).contains('Settlement among involved parties');
  fields['smoker_frequency_checked'] =
      value('family_member_is_cigarette_smoker') == 'Yes';
  fields['smoker_no'] = value('family_member_is_cigarette_smoker') == 'No';
  fields['smoker_yes'] = value('family_member_is_cigarette_smoker') == 'Yes';
  fields['social_conflict_alcohol'] = value(
    'source_of_social_conflict',
  ).contains('Alcohol');
  fields['social_conflict_drugs'] = value(
    'source_of_social_conflict',
  ).contains('Drugs');
  fields['social_conflict_family'] = value(
    'source_of_social_conflict',
  ).contains('Family dispute');
  fields['social_conflict_gossip'] = value(
    'source_of_social_conflict',
  ).contains('Gossip');
  fields['social_conflict_others_checked'] = value(
    'source_of_social_conflict',
  ).contains('Others');
  fields['social_conflict_riot'] = value(
    'source_of_social_conflict',
  ).contains('Riot');

  fields['bhc_services_aware'] =
      value('awareness_of_health_services') == 'Aware';
  fields['bhc_services_unaware'] =
      value('awareness_of_health_services') == 'Unaware';
  fields['bought_food_everyday'] =
      value('food_preparation_frequency') == 'Everyday';
  fields['bought_food_once_week'] =
      value('food_preparation_frequency') == 'Once a week';
  fields['bought_food_others_checked'] =
      value('food_preparation_frequency') == 'Others';
  fields['bought_food_twice_week'] =
      value('food_preparation_frequency') == 'Twice a week';
  fields['bought_from_carinderia'] = value(
    'bought_food_source',
  ).contains('Carinderia');
  fields['bought_from_food_cart'] = value(
    'bought_food_source',
  ).contains('Food cart');
  fields['bought_from_restaurant_fastfood'] = value(
    'bought_food_source',
  ).contains('Restaurant/Fast food');
  fields['communication_cellphone'] = value(
    'mode_of_communication',
  ).contains('Cell phone');
  fields['communication_postal'] = value(
    'mode_of_communication',
  ).contains('Postal system');
  fields['community_involvement_active'] =
      value('community_involvement') ==
      'Actively joins fiesta, religious procession, local cultural practices';
  fields['community_involvement_not_active'] =
      value('community_involvement') == 'Does not actively join';
  fields['community_services_garbage_collection'] = value(
    'services_in_community',
  ).contains('Garbage collection');
  fields['community_services_livelihood_duplicate'] = value(
    'services_in_community',
  ).contains('Livelihood Services');
  fields['community_services_peace_order'] = value(
    'services_in_community',
  ).contains('Peace and Order');
  fields['construction_light'] =
      value('home_construction_materials') == 'Light';
  fields['construction_mixed'] =
      value('home_construction_materials') == 'Mixed';
  fields['construction_strong_concrete'] =
      value('home_construction_materials') == 'Strong/Concrete';
  fields['consult_albularyo'] = value(
    'personnel_consulted_during_illness',
  ).contains('Albularyo');
  fields['consult_doctor'] = value(
    'personnel_consulted_during_illness',
  ).contains('Doctor');
  fields['consult_elderly'] = value(
    'personnel_consulted_during_illness',
  ).contains('Elderly');
  fields['consult_faith_healer'] = value(
    'personnel_consulted_during_illness',
  ).contains('Faith Healer');
  fields['consult_hilot'] = value(
    'personnel_consulted_during_illness',
  ).contains('Hilot');
  fields['consult_midwife'] = value(
    'personnel_consulted_during_illness',
  ).contains('Midwife');
  fields['consult_nurse'] = value(
    'personnel_consulted_during_illness',
  ).contains('Nurse');
  fields['cooking_sanitary_dirty'] =
      value('cooking_area_sanitary_condition') == 'Dirty';
  fields['cooking_sanitary_generally_clean'] =
      value('cooking_area_sanitary_condition') == 'Generally clean';
  fields['cultural_practices_always'] =
      value('cultural_perception_health_practices') ==
      'Always practices local cultural practices about health matters';
  fields['cultural_practices_does_not_practice'] =
      value('cultural_perception_health_practices') ==
      'Does not practice any local cultural practices about health matters';
  fields['cultural_practices_sometimes'] =
      value('cultural_perception_health_practices') ==
      'Sometimes practices local cultural practices about health matters';
  fields['disposal_not_practiced_burial_pit'] =
      value('waste_disposal_method_if_not_practiced') == 'Burial in pit';
  fields['disposal_not_practiced_collected'] =
      value('waste_disposal_method_if_not_practiced') == 'Collected';
  fields['disposal_not_practiced_composting'] =
      value('waste_disposal_method_if_not_practiced') == 'Composting';
  fields['disposal_not_practiced_hog_feeding'] =
      value('waste_disposal_method_if_not_practiced') == 'Hog-feeding';
  fields['disposal_not_practiced_open_burning'] =
      value('waste_disposal_method_if_not_practiced') == 'Open burning';
  fields['disposal_not_practiced_open_dumping'] =
      value('waste_disposal_method_if_not_practiced') == 'Open dumping';
  fields['disposal_practiced_burial_pit'] =
      value('waste_disposal_method_if_practiced') == 'Burial in pit';
  fields['disposal_practiced_collected'] =
      value('waste_disposal_method_if_practiced') == 'Collected';
  fields['disposal_practiced_composting'] =
      value('waste_disposal_method_if_practiced') == 'Composting';
  fields['disposal_practiced_hog_feeding'] =
      value('waste_disposal_method_if_practiced') == 'Hog-feeding';
  fields['disposal_practiced_open_burning'] =
      value('waste_disposal_method_if_practiced') == 'Open burning';
  fields['disposal_practiced_open_dumping'] =
      value('waste_disposal_method_if_practiced') == 'Open dumping';
  fields['drainage_flowing'] = value('drainage_condition') == 'Flowing';
  fields['drainage_stagnant'] = value('drainage_condition') == 'Stagnant';
  fields['drug_types_checked'] = value('family_member_uses_drugs') == 'Yes';
  fields['drug_use_no'] = value('family_member_uses_drugs') == 'No';
  fields['drug_use_yes'] = value('family_member_uses_drugs') == 'Yes';
  fields['family_composition_blended'] =
      value('type_of_family_composition') == 'Blended Family';
  fields['family_composition_cohabiting_communal'] =
      value('type_of_family_composition') == 'Cohabiting/Communal';
  fields['family_composition_dyad'] =
      value('type_of_family_composition') == 'Dyad';
  fields['family_composition_extended'] =
      value('type_of_family_composition') == 'Extended';
  fields['family_composition_living_with_grandparents'] =
      value('type_of_family_composition') == 'Living with Grandparent(s)';
  fields['family_composition_nuclear'] =
      value('type_of_family_composition') == 'Nuclear';
  fields['family_composition_same_sex'] =
      value('type_of_family_composition') == 'Homosexual/Same Sex';
  fields['family_composition_single_parent'] =
      value('type_of_family_composition') == 'Single- parent';
  fields['family_descent_bilateral'] =
      value('type_of_family_descent') == 'Bilateral';
  fields['family_descent_matrilineal'] =
      value('type_of_family_descent') == 'Matrilineal';
  fields['family_descent_patrilineal'] =
      value('type_of_family_descent') == 'Patrilineal';
  fields['family_power_egalitarian'] =
      value('type_of_family_locus_of_power') == 'Egalitarian';
  fields['family_power_matricentric'] =
      value('type_of_family_locus_of_power') == 'Matricentric';
  fields['family_power_matrifocal_matriarchal'] =
      value('type_of_family_locus_of_power') == 'Matrifocal/Matriarchal';
  fields['family_power_patrifocal_patriarchal'] =
      value('type_of_family_locus_of_power') == 'Patrifocal/Patriarchal';
  fields['family_residence_bilocal_ambilocal'] =
      value('type_of_family_place_of_residence') == 'Bilocal (Ambilocal)';
  fields['family_residence_matrilocal'] =
      value('type_of_family_place_of_residence') == 'Matrilocal';
  fields['family_residence_neolocal'] =
      value('type_of_family_place_of_residence') == 'Neolocal';
  fields['family_residence_patrilocal'] =
      value('type_of_family_place_of_residence') == 'Patrilocal';
  fields['financial_source_help_relative_friends'] = value(
    'financial_sources',
  ).contains('Help from relative/friends');
  fields['food_first_fish'] = value('first_food_choice') == 'Fish';
  fields['food_first_meat_only'] = value('first_food_choice') == 'Meat only';
  fields['food_first_mixed'] = value('first_food_choice') == 'Mixed';
  fields['food_first_others_checked'] = value('first_food_choice') == 'Others';
  fields['food_first_serving_1'] = value('first_food_choice_servings') == '1';
  fields['food_first_serving_2_3'] =
      value('first_food_choice_servings') == '2-3';
  fields['food_first_serving_4_5_above'] =
      value('first_food_choice_servings') == '4-5 and above';
  fields['food_first_vegetable'] = value('first_food_choice') == 'Vegetable';
  fields['food_intake_everyday'] = value('food_intake_frequency') == 'Everyday';
  fields['food_intake_once_week'] =
      value('food_intake_frequency') == 'Once a week';
  fields['food_intake_others_checked'] =
      value('food_intake_frequency') == 'Others';
  fields['food_intake_twice_week'] =
      value('food_intake_frequency') == 'Twice a week';
  fields['food_second_fish'] = value('second_food_choice') == 'Fish';
  fields['food_second_meat'] = value('second_food_choice') == 'Meat';
  fields['food_second_mixed'] = value('second_food_choice') == 'Mixed';
  fields['food_second_others_checked'] =
      value('second_food_choice') == 'Others';
  fields['food_second_serving_1'] = value('second_food_choice_servings') == '1';
  fields['food_second_serving_2_3'] =
      value('second_food_choice_servings') == '2-3';
  fields['food_second_serving_4_5_above'] =
      value('second_food_choice_servings') == '4-5 and above';
  fields['food_second_vegetable'] = value('second_food_choice') == 'Vegetable';
  fields['fp_acceptor_good_for_health'] = value(
    'reason_for_using_family_planning_method',
  ).contains('Good for health');
  fields['fp_acceptor_others_checked'] = value(
    'reason_for_using_family_planning_method',
  ).contains('Others');
  fields['fp_basal_body_temperature'] =
      value('family_planning_fertility_awareness_method') ==
      'Basal Body Temperature (BBT)';
  fields['fp_cervical_mucus'] =
      value('family_planning_fertility_awareness_method') ==
      'Cervical Mucus Method / Billings Ovu. Method';
  fields['fp_condoms'] = value('family_planning_supply_method') == 'Condoms';
  fields['fp_female_sterilization'] =
      value('family_planning_permanent_method') ==
      'Female sterilization / Bilateral Tubal Ligation';
  fields['fp_fertility_awareness_method'] =
      value('family_planning_temporary_method') ==
      'Fertility Awareness-Based Method';
  fields['fp_implant'] = value('family_planning_supply_method') == 'Implant';
  fields['fp_injectable'] =
      value('family_planning_supply_method') == 'Injectable';
  fields['fp_iud'] = value('family_planning_supply_method') == 'IUD';
  fields['fp_lactational_amenorrhea'] =
      value('family_planning_fertility_awareness_method') ==
      'Lactational Amenorrhea Method (LAM)';
  fields['fp_male_sterilization'] =
      value('family_planning_permanent_method') ==
      'Male sterilization / Vasectomy';
  fields['fp_nonacceptor_bad_for_health'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Bad for health');
  fields['fp_nonacceptor_influenced_by_others'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Influenced by others');
  fields['fp_nonacceptor_others_checked'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Others');
  fields['fp_nonacceptor_personal_belief'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Personal belief');
  fields['fp_nonacceptor_religious_belief'] = value(
    'reason_for_not_using_family_planning_method',
  ).contains('Religious belief');
  fields['fp_permanent_method'] =
      value('modern_family_planning_method_used') == 'Permanent method';
  fields['fp_pills'] = value('family_planning_supply_method') == 'Pills';
  fields['fp_standard_days'] =
      value('family_planning_fertility_awareness_method') ==
      'Standard Days Method (SDM)';
  fields['fp_supply_methods'] =
      value('family_planning_temporary_method') == 'Supply Methods';
  fields['fp_sympto_thermal'] =
      value('family_planning_fertility_awareness_method') ==
      'Sympto-Thermal Method';
  fields['fp_temporary_method'] =
      value('modern_family_planning_method_used') == 'Temporary method';
  fields['priority_clothing'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Clothing');
  fields['priority_education'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Education');
  fields['priority_food'] =
      value('priorities_and_expenditure_ranking').contains('1. Food') ||
      value('priorities_and_expenditure_ranking').contains('Food');
  fields['priority_health'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Health');
  fields['priority_recreation'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Recreation');
  fields['priority_savings'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Savings');
  fields['priority_utilities'] = value(
    'priorities_and_expenditure_ranking',
  ).contains('Utilities');
  fields['settlement_barangay_hearing'] = value(
    'effective_practices_setting_issues',
  ).contains('Brgy. hearing');
  fields['settlement_local_police'] = value(
    'effective_practices_setting_issues',
  ).contains('Endorsed to local police');
  fields['settlement_others_checked'] = value(
    'effective_practices_setting_issues',
  ).contains('Others');
  fields['settlement_parties'] = value(
    'effective_practices_setting_issues',
  ).contains('Settlement among involved parties');
  fields['smoker_frequency_checked'] =
      value('family_member_is_cigarette_smoker') == 'Yes';
  fields['smoker_no'] = value('family_member_is_cigarette_smoker') == 'No';
  fields['smoker_yes'] = value('family_member_is_cigarette_smoker') == 'Yes';
  fields['social_conflict_alcohol'] = value(
    'source_of_social_conflict',
  ).contains('Alcohol');
  fields['social_conflict_drugs'] = value(
    'source_of_social_conflict',
  ).contains('Drugs');
  fields['social_conflict_family'] = value(
    'source_of_social_conflict',
  ).contains('Family dispute');
  fields['social_conflict_gossip'] = value(
    'source_of_social_conflict',
  ).contains('Gossip');
  fields['social_conflict_others_checked'] = value(
    'source_of_social_conflict',
  ).contains('Others');
  fields['social_conflict_riot'] = value(
    'source_of_social_conflict',
  ).contains('Riot');

  fields['smoker_yes'] = hasYesFromAny([
    'has_cigarette_smoker_in_family',
    'family_member_is_cigarette_smoker',
  ]);
  fields['smoker_no'] = hasNoFromAny([
    'has_cigarette_smoker_in_family',
    'family_member_is_cigarette_smoker',
  ]);
  fields['smoker_frequency_checked'] = fields['smoker_yes'];

  fields['drug_use_yes'] = hasYesFromAny([
    'uses_prohibited_or_dangerous_drugs',
    'family_member_uses_drugs',
  ]);
  fields['drug_use_no'] = hasNoFromAny([
    'uses_prohibited_or_dangerous_drugs',
    'family_member_uses_drugs',
  ]);
  fields['drug_types_checked'] = fields['drug_use_yes'];

  fields['bhc_services_aware'] = hasExactValueFromAny([
    'awareness_of_bhc_rhu_health_services',
    'awareness_of_health_services',
  ], 'Aware');
  fields['bhc_services_unaware'] = hasExactValueFromAny([
    'awareness_of_bhc_rhu_health_services',
    'awareness_of_health_services',
  ], 'Unaware');

  fields['rhu_physicians'] = value('rhu_physicians_schedule');
  fields['rhu_nurse'] = value('rhu_nurse_schedule');
  fields['bhc_midwife'] = value('bhc_midwife_schedule');

  fields['family_power_patrifocal_patriarchal'] = hasChoiceFromAny([
    'family_locus_of_power',
    'locus_of_power',
  ], 'Patrifocal/Patriarchal');
  fields['family_power_matrifocal_matriarchal'] = hasChoiceFromAny([
    'family_locus_of_power',
    'locus_of_power',
  ], 'Matrifocal/Matriarchal');
  fields['family_power_egalitarian'] = hasChoiceFromAny([
    'family_locus_of_power',
    'locus_of_power',
  ], 'Egalitarian');
  fields['family_power_matricentric'] = hasChoiceFromAny([
    'family_locus_of_power',
    'locus_of_power',
  ], 'Matricentric');

  fields['family_residence_patrilocal'] = hasChoiceFromAny([
    'family_place_of_residence',
    'place_of_residence',
  ], 'Patrilocal');
  fields['family_residence_matrilocal'] = hasChoiceFromAny([
    'family_place_of_residence',
    'place_of_residence',
  ], 'Matrilocal');
  fields['family_residence_bilocal_ambilocal'] = hasChoiceFromAny([
    'family_place_of_residence',
    'place_of_residence',
  ], 'Bilocal/Ambilocal');
  fields['family_residence_neolocal'] = hasChoiceFromAny([
    'family_place_of_residence',
    'place_of_residence',
  ], 'Neolocal');

  fields['fp_acceptor'] = hasExactValueFromAny([
    'family_planning_status',
  ], 'Acceptor');
  fields['fp_nonacceptor'] = hasExactValueFromAny([
    'family_planning_status',
  ], 'Non-Acceptor');
  fields['fp_acceptor_good_for_health'] = hasChoiceFromAny([
    'family_planning_acceptor_reasons',
    'reason_for_using_family_planning_method',
  ], 'Good for health of family');
  fields['fp_acceptor_others_checked'] = hasChoiceFromAny([
    'family_planning_acceptor_reasons',
    'reason_for_using_family_planning_method',
  ], 'Others');
  fields['fp_nonacceptor_bad_for_health'] = hasChoiceFromAny([
    'family_planning_non_acceptor_reasons',
    'reason_for_not_using_family_planning_method',
  ], 'Bad for health of family');
  fields['fp_nonacceptor_religious_belief'] = hasChoiceFromAny([
    'family_planning_non_acceptor_reasons',
    'reason_for_not_using_family_planning_method',
  ], 'Religious belief');
  fields['fp_nonacceptor_personal_belief'] = hasChoiceFromAny([
    'family_planning_non_acceptor_reasons',
    'reason_for_not_using_family_planning_method',
  ], 'Personal belief');
  fields['fp_nonacceptor_influenced_by_others'] =
      hasChoiceFromAny([
        'family_planning_non_acceptor_reasons',
        'reason_for_not_using_family_planning_method',
      ], 'Influence by others') ||
      hasChoiceFromAny([
        'family_planning_non_acceptor_reasons',
        'reason_for_not_using_family_planning_method',
      ], 'Influenced by others');
  fields['fp_nonacceptor_others_checked'] = hasChoiceFromAny([
    'family_planning_non_acceptor_reasons',
    'reason_for_not_using_family_planning_method',
  ], 'Others');

  fields['fp_female_sterilization'] =
      isChecked('permanent_method_female_sterilization_btl') ||
      hasExactValueFromAny([
        'family_planning_permanent_method',
      ], 'Female sterilization / Bilateral Tubal Ligation');
  fields['fp_male_sterilization'] =
      isChecked('permanent_method_male_sterilization_vasectomy') ||
      hasExactValueFromAny([
        'family_planning_permanent_method',
      ], 'Male sterilization / Vasectomy');
  fields['fp_pills'] =
      isChecked('supply_method_pills') ||
      hasExactValueFromAny(['family_planning_supply_method'], 'Pills');
  fields['fp_iud'] =
      isChecked('supply_method_iud') ||
      hasExactValueFromAny(['family_planning_supply_method'], 'IUD');
  fields['fp_injectable'] =
      isChecked('supply_method_injectable') ||
      hasExactValueFromAny(['family_planning_supply_method'], 'Injectable');
  fields['fp_condoms'] =
      isChecked('supply_method_condoms') ||
      hasExactValueFromAny(['family_planning_supply_method'], 'Condoms');
  fields['fp_implant'] =
      isChecked('supply_method_implant') ||
      hasExactValueFromAny(['family_planning_supply_method'], 'Implant');
  fields['fp_cervical_mucus'] =
      isChecked('fertility_method_cervical_mucus_billings') ||
      hasExactValueFromAny([
        'family_planning_fertility_awareness_method',
      ], 'Cervical Mucus Method / Billings Ovu. Method');
  fields['fp_basal_body_temperature'] =
      isChecked('fertility_method_basal_body_temperature') ||
      hasExactValueFromAny([
        'family_planning_fertility_awareness_method',
      ], 'Basal Body Temperature (BBT)');
  fields['fp_sympto_thermal'] =
      isChecked('fertility_method_sympto_thermal') ||
      hasExactValueFromAny([
        'family_planning_fertility_awareness_method',
      ], 'Sympto-Thermal Method');
  fields['fp_standard_days'] =
      isChecked('fertility_method_standard_days') ||
      hasExactValueFromAny([
        'family_planning_fertility_awareness_method',
      ], 'Standard Days Method (SDM)');
  fields['fp_lactational_amenorrhea'] =
      isChecked('fertility_method_lactational_amenorrhea') ||
      hasExactValueFromAny([
        'family_planning_fertility_awareness_method',
      ], 'Lactational Amenorrhea Method (LAM)');
  fields['fp_permanent_method'] =
      fields['fp_female_sterilization'] == true ||
      fields['fp_male_sterilization'] == true ||
      hasExactValueFromAny([
        'modern_family_planning_method_used',
      ], 'Permanent method');
  fields['fp_supply_methods'] =
      fields['fp_pills'] == true ||
      fields['fp_iud'] == true ||
      fields['fp_injectable'] == true ||
      fields['fp_condoms'] == true ||
      fields['fp_implant'] == true ||
      hasExactValueFromAny([
        'family_planning_temporary_method',
      ], 'Supply Methods');
  fields['fp_fertility_awareness_method'] =
      fields['fp_cervical_mucus'] == true ||
      fields['fp_basal_body_temperature'] == true ||
      fields['fp_sympto_thermal'] == true ||
      fields['fp_standard_days'] == true ||
      fields['fp_lactational_amenorrhea'] == true ||
      hasExactValueFromAny([
        'family_planning_temporary_method',
      ], 'Fertility Awareness-Based Method');
  fields['fp_temporary_method'] =
      fields['fp_supply_methods'] == true ||
      fields['fp_fertility_awareness_method'] == true ||
      hasExactValueFromAny([
        'modern_family_planning_method_used',
      ], 'Temporary method');

  fields['social_conflict_gossip'] = hasChoiceFromAny([
    'social_conflict_causes',
    'source_of_social_conflict',
  ], 'Gossip');
  fields['social_conflict_family'] =
      hasChoiceFromAny([
        'social_conflict_causes',
        'source_of_social_conflict',
      ], 'Family conflict') ||
      hasChoiceFromAny([
        'social_conflict_causes',
        'source_of_social_conflict',
      ], 'Family dispute');
  fields['social_conflict_drugs'] = hasChoiceFromAny([
    'social_conflict_causes',
    'source_of_social_conflict',
  ], 'Drugs');
  fields['social_conflict_riot'] = hasChoiceFromAny([
    'social_conflict_causes',
    'source_of_social_conflict',
  ], 'Riot');
  fields['social_conflict_alcohol'] =
      hasChoiceFromAny([
        'social_conflict_causes',
        'source_of_social_conflict',
      ], 'Alcohol drinking') ||
      hasChoiceFromAny([
        'social_conflict_causes',
        'source_of_social_conflict',
      ], 'Alcohol');
  fields['social_conflict_others_checked'] = hasChoiceFromAny([
    'social_conflict_causes',
    'source_of_social_conflict',
  ], 'Others');

  fields['settlement_parties'] = hasChoiceFromAny([
    'conflict_resolution_approaches',
    'effective_practices_setting_issues',
  ], 'Settlement among involved parties');
  fields['settlement_barangay_hearing'] = hasChoiceFromAny([
    'conflict_resolution_approaches',
    'effective_practices_setting_issues',
  ], 'Brgy. hearing');
  fields['settlement_local_police'] = hasChoiceFromAny([
    'conflict_resolution_approaches',
    'effective_practices_setting_issues',
  ], 'Endorsed to local police');
  fields['settlement_others_checked'] = hasChoiceFromAny([
    'conflict_resolution_approaches',
    'effective_practices_setting_issues',
  ], 'Others');
  fields['community_settlement_others'] =
      value('conflict_resolution_approaches_other').isNotEmpty
      ? value('conflict_resolution_approaches_other')
      : value('community_settlement_other');

  final familyCompositionKeys = [
    'family_composition_type',
    'type_of_family_composition',
  ];
  fields['family_composition_nuclear'] = hasChoiceFromAny(
    familyCompositionKeys,
    'Nuclear',
  );
  fields['family_composition_extended'] = hasChoiceFromAny(
    familyCompositionKeys,
    'Extended',
  );
  fields['family_composition_dyad'] = hasChoiceFromAny(
    familyCompositionKeys,
    'Dyad',
  );
  fields['family_composition_same_sex'] = hasChoiceFromAny(
    familyCompositionKeys,
    'Homosexual/Same Sex',
  );
  fields['family_composition_cohabiting_communal'] = hasChoiceFromAny(
    familyCompositionKeys,
    'Cohabiting/Communal',
  );
  fields['family_composition_blended'] = hasChoiceFromAny(
    familyCompositionKeys,
    'Blended Family',
  );
  fields['family_composition_living_with_grandparents'] = hasChoiceFromAny(
    familyCompositionKeys,
    'Living with Grandparent(s)',
  );
  fields['family_composition_single_parent'] =
      hasChoiceFromAny(familyCompositionKeys, 'Single-parent') ||
      hasChoiceFromAny(familyCompositionKeys, 'Single- parent');

  String priorityRank(String choice, String rankKey) {
    final explicitRank = _surveyValueLabel(data[rankKey]);
    if (explicitRank.isNotEmpty) {
      return explicitRank;
    }

    for (final source in [
      value('priorities_ranking'),
      value('priorities_and_expenditure_ranking'),
    ]) {
      final choiceThenRank = RegExp(
        '${RegExp.escape(choice)}\\s*[:=-]\\s*(\\d)',
        caseSensitive: false,
      ).firstMatch(source);
      if (choiceThenRank != null) {
        return choiceThenRank.group(1) ?? '';
      }

      final rankThenChoice = RegExp(
        r'(\d)\s*[.)-]?\s*' + RegExp.escape(choice),
        caseSensitive: false,
      ).firstMatch(source);
      if (rankThenChoice != null) {
        return rankThenChoice.group(1) ?? '';
      }
    }

    return '';
  }

  fields['priority_food'] = priorityRank('Food', 'priority_food_rank');
  fields['priority_clothing'] = priorityRank(
    'Clothing',
    'priority_clothing_rank',
  );
  fields['priority_education'] = priorityRank(
    'Education',
    'priority_education_rank',
  );
  fields['priority_utilities'] = priorityRank(
    'Utilities',
    'priority_utilities_rank',
  );
  fields['priority_health'] = priorityRank('Health', 'priority_health_rank');
  fields['priority_recreation'] = priorityRank(
    'Recreation',
    'priority_recreation_rank',
  );
  fields['priority_savings'] = priorityRank('Savings', 'priority_savings_rank');

  fields['immunizations'] = _surveyMapRows(data['immunization_records'])
      .map(
        (row) => {
          'name': _surveyRowValue(row, 'name'),
          'age_in_mos': _surveyRowValue(row, 'age_in_mos', [
            'age_in_months',
            'age',
          ]),
          'age_in_months': _surveyRowValue(row, 'age_in_mos', [
            'age_in_months',
            'age',
          ]),
          'gender': _surveyRowValue(row, 'gender'),
          'bcg': _surveyRowValue(row, 'bcg'),
          'dpt_1': _surveyRowValue(row, 'dpt_1'),
          'dpt_2': _surveyRowValue(row, 'dpt_2'),
          'dpt_3': _surveyRowValue(row, 'dpt_3'),
          'hepa_b_1': _surveyRowValue(row, 'hepa_b_1'),
          'hepa_b_2': _surveyRowValue(row, 'hepa_b_2'),
          'hepa_b_3': _surveyRowValue(row, 'hepa_b_3'),
          'opv_1': _surveyRowValue(row, 'opv_1'),
          'opv_2': _surveyRowValue(row, 'opv_2'),
          'opv_3': _surveyRowValue(row, 'opv_3'),
          'measles': _surveyRowValue(row, 'measles'),
          'complete_according_to_age': _surveyRowValue(
            row,
            'complete_according_to_age',
          ),
          'incomplete_according_to_age': _surveyRowValue(
            row,
            'incomplete_according_to_age',
          ),
          'fully_immunized_child': _surveyRowValue(
            row,
            'fully_immunized_child',
          ),
          'immun_name': _surveyRowValue(row, 'name'),
          'immun_age_mos': _surveyRowValue(row, 'age_in_mos', [
            'age_in_months',
            'age',
          ]),
          'immun_gender': _surveyRowValue(row, 'gender'),
          'immun_bcg': _surveyRowValue(row, 'bcg'),
          'immun_dpt1': _surveyRowValue(row, 'dpt_1'),
          'immun_dpt2': _surveyRowValue(row, 'dpt_2'),
          'immun_dpt3': _surveyRowValue(row, 'dpt_3'),
          'immun_hepa_b1': _surveyRowValue(row, 'hepa_b_1'),
          'immun_hepa_b2': _surveyRowValue(row, 'hepa_b_2'),
          'immun_hepa_b3': _surveyRowValue(row, 'hepa_b_3'),
          'immun_opv1': _surveyRowValue(row, 'opv_1'),
          'immun_opv2': _surveyRowValue(row, 'opv_2'),
          'immun_opv3': _surveyRowValue(row, 'opv_3'),
          'immun_measles': _surveyRowValue(row, 'measles'),
          'immun_complete_age': _surveyRowValue(
            row,
            'complete_according_to_age',
          ),
          'immun_incomplete_age': _surveyRowValue(
            row,
            'incomplete_according_to_age',
          ),
          'immun_fully_immunized': _surveyRowValue(
            row,
            'fully_immunized_child',
          ),
        },
      )
      .toList();

  fields['anthropometric'] = _surveyMapRows(data['anthropometric_data_under_5'])
      .map(
        (row) => {
          'name': _surveyRowValue(row, 'name'),
          'age_in_months': _surveyRowValue(row, 'age_in_months', [
            'age_in_mos',
            'age',
          ]),
          'age_in_mos': _surveyRowValue(row, 'age_in_months', [
            'age_in_mos',
            'age',
          ]),
          'weight_kg': _surveyRowValue(row, 'weight_kg'),
          'height_m': _surveyRowValue(row, 'height_m'),
          'bmi': _surveyRowValue(row, 'bmi'),
          'bmi_remarks': _surveyRowValue(row, 'bmi_remarks'),
          'waist_circumference_cm': _surveyRowValue(
            row,
            'waist_circumference_cm',
          ),
          'hip_circumference_cm': _surveyRowValue(row, 'hip_circumference_cm'),
          'waist_hip_ratio': _surveyRowValue(row, 'waist_hip_ratio'),
          'waist_hip_ratio_remarks': _surveyRowValue(
            row,
            'waist_hip_ratio_remarks',
          ),
          'mid_upper_arm_circumference': _surveyRowValue(
            row,
            'mid_upper_arm_circumference',
          ),
          'mid_upper_arm_remarks': _surveyRowValue(
            row,
            'mid_upper_arm_remarks',
          ),
          'anthro_name': _surveyRowValue(row, 'name'),
          'anthro_age_mos': _surveyRowValue(row, 'age_in_months', [
            'age_in_mos',
            'age',
          ]),
          'anthro_weight_kg': _surveyRowValue(row, 'weight_kg'),
          'anthro_height_m': _surveyRowValue(row, 'height_m'),
          'anthro_bmi': _surveyRowValue(row, 'bmi'),
          'anthro_bmi_remarks': _surveyRowValue(row, 'bmi_remarks'),
          'anthro_waist_cm': _surveyRowValue(row, 'waist_circumference_cm'),
          'anthro_hips_cm': _surveyRowValue(row, 'hip_circumference_cm'),
          'anthro_whr': _surveyRowValue(row, 'waist_hip_ratio'),
          'anthro_whr_remarks': _surveyRowValue(row, 'waist_hip_ratio_remarks'),
          'anthro_muac': _surveyRowValue(row, 'mid_upper_arm_circumference'),
          'anthro_muac_remarks': _surveyRowValue(row, 'mid_upper_arm_remarks'),
        },
      )
      .toList();

  fields['mortality'] = _surveyMapRows(data['mortality_records'])
      .map(
        (row) => {
          'name': _surveyRowValue(row, 'name'),
          'age': _surveyRowValue(row, 'age'),
          'gender': _surveyRowValue(row, 'gender'),
          'cause_of_death': _surveyRowValue(row, 'cause_of_death', [
            'cause',
            'reason',
          ]),
          'cause': _surveyRowValue(row, 'cause_of_death', ['cause', 'reason']),
          'mortality_name': _surveyRowValue(row, 'name'),
          'mortality_age': _surveyRowValue(row, 'age'),
          'mortality_gender': _surveyRowValue(row, 'gender'),
          'mortality_cause_death': _surveyRowValue(row, 'cause_of_death', [
            'cause',
            'reason',
          ]),
        },
      )
      .toList();

  fields['ncd_history'] =
      _surveyMapRows(data['non_communicable_disease_records'])
          .map(
            (row) => {
              'name': _surveyRowValue(row, 'name'),
              'age': _surveyRowValue(row, 'age'),
              'gender': _surveyRowValue(row, 'gender'),
              'ncd': _surveyRowValue(row, 'ncd', ['cause', 'reason']),
              'cause': _surveyRowValue(row, 'ncd', ['cause', 'reason']),
              'ncd_name': _surveyRowValue(row, 'name'),
              'ncd_age': _surveyRowValue(row, 'age'),
              'ncd_gender': _surveyRowValue(row, 'gender'),
              'ncd_type': _surveyRowValue(row, 'ncd', ['cause', 'reason']),
            },
          )
          .toList();

  fields['cd_history'] = _surveyMapRows(data['communicable_disease_records'])
      .map(
        (row) => {
          'name': _surveyRowValue(row, 'name'),
          'age': _surveyRowValue(row, 'age'),
          'gender': _surveyRowValue(row, 'gender'),
          'cd': _surveyRowValue(row, 'cd', ['cause', 'reason']),
          'cause': _surveyRowValue(row, 'cd', ['cause', 'reason']),
          'cd_name': _surveyRowValue(row, 'name'),
          'cd_age': _surveyRowValue(row, 'age'),
          'cd_gender': _surveyRowValue(row, 'gender'),
          'cd_type': _surveyRowValue(row, 'cd', ['cause', 'reason']),
        },
      )
      .toList();

  fields['rabies_animals'] = _surveyMapRows(data['rabies_carrier_animals'])
      .map(
        (row) => {
          'animal_kind': _surveyRowValue(row, 'animal_kind', ['kind', 'name']),
          'kind': _surveyRowValue(row, 'animal_kind', ['kind', 'name']),
          'name': _surveyRowValue(row, 'animal_kind', ['kind', 'name']),
          'animal_number': _surveyRowValue(row, 'animal_number', ['number']),
          'number': _surveyRowValue(row, 'animal_number', ['number']),
          'kept_inside_yard': _surveyRowValue(row, 'kept_inside_yard'),
          'kept_free_outside': _surveyRowValue(row, 'kept_free_outside'),
          'with_regular_vaccination': _surveyRowValue(
            row,
            'with_regular_vaccination',
          ),
          'without_vaccination': _surveyRowValue(row, 'without_vaccination'),
          'animal_inside_yard': _surveyRowValue(row, 'kept_inside_yard'),
          'animal_free_outside': _surveyRowValue(row, 'kept_free_outside'),
          'animal_with_vaccine': _surveyRowValue(
            row,
            'with_regular_vaccination',
          ),
          'animal_without_vaccine': _surveyRowValue(row, 'without_vaccination'),
        },
      )
      .toList();
  // --- END OF CUSTOM TAG MAPPING ---

  return fields;
}

String _documentXml(List<HealthSubmission> submissions) {
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..writeln(
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">',
    )
    ..writeln('<w:body>');

  for (var index = 0; index < submissions.length; index++) {
    if (index > 0) {
      buffer.writeln(_pageBreakParagraph());
    }
    buffer.write(_surveyDocumentSection(submissions[index], index));
  }

  buffer
    ..writeln(
      '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="720" w:right="540" w:bottom="720" w:left="540" w:header="360" w:footer="360" w:gutter="0"/></w:sectPr>',
    )
    ..writeln('</w:body>')
    ..writeln('</w:document>');

  return buffer.toString();
}

String _surveyDocumentSection(HealthSubmission submission, int sectionIndex) {
  final surveyData = submission.surveyData;
  final buffer = StringBuffer()
    ..writeln(_documentHeaderTable(sectionIndex))
    ..writeln(_paragraph('COMMUNITY SURVEY TOOL', center: true, bold: true))
    ..writeln(_paragraph('(NEED ASSESSMENT)', center: true, bold: true))
    ..writeln(
      _table([
        [
          'Control No.',
          _surveyString(surveyData, 'control_no'),
          'Number of Family',
          _surveyString(surveyData, 'number_of_family').isEmpty
              ? '${submission.familyMembersCount}'
              : _surveyString(surveyData, 'number_of_family'),
        ],
        [
          'Address',
          _surveyString(surveyData, 'address').isEmpty
              ? submission.address
              : _surveyString(surveyData, 'address'),
          'Date: 1st visit',
          _surveyString(surveyData, 'first_visit_date').isEmpty
              ? _dateOnly(submission.createdAt)
              : _surveyString(surveyData, 'first_visit_date'),
        ],
        [
          'Informant',
          _surveyString(surveyData, 'informant').isEmpty
              ? submission.respondentName
              : _surveyString(surveyData, 'informant'),
          '2nd visit',
          _surveyString(surveyData, 'second_visit_date'),
        ],
        [
          'Surveyed by',
          _surveyString(surveyData, 'surveyed_by'),
          '3rd visit',
          _surveyString(surveyData, 'third_visit_date'),
        ],
        [
          'Time Started',
          _surveyString(surveyData, 'time_started'),
          'Time Finished',
          _surveyString(surveyData, 'time_finished'),
          'Status of last visit',
          _surveyString(surveyData, 'status_of_last_visit').isEmpty
              ? submission.syncStatus.name
              : _surveyString(surveyData, 'status_of_last_visit'),
        ],
      ]),
    )
    ..writeln(_sectionHeading('I. Demographic Variable'))
    ..writeln(
      _table(_demographicTableRows(submission), headerRows: 1, fontSize: 11),
    )
    ..writeln(_sectionHeading('Type of Family'))
    ..writeln(
      _paragraph(
        'Based on composition: '
        '${_docxCheckbox(submission, 'family_composition_type', 'Nuclear')}   '
        '${_docxCheckbox(submission, 'family_composition_type', 'Extended')}   '
        '${_docxCheckbox(submission, 'family_composition_type', 'Dyad')}   '
        '${_docxCheckbox(submission, 'family_composition_type', 'Homosexual/Same Sex')}   '
        '${_docxCheckbox(submission, 'family_composition_type', 'Cohabiting/Communal')}   '
        '${_docxCheckbox(submission, 'family_composition_type', 'Blended Family')}   '
        '${_docxCheckbox(submission, 'family_composition_type', 'Living with Grandparent(s)')}   '
        '${_docxCheckbox(submission, 'family_composition_type', 'Single-parent')}',
      ),
    )
    ..writeln(
      _paragraph(
        'Based on locus of power: '
        '${_docxCheckbox(submission, 'family_locus_of_power', 'Patrifocal/Patriarchal')}   '
        '${_docxCheckbox(submission, 'family_locus_of_power', 'Matrifocal/Matriarchal')}   '
        '${_docxCheckbox(submission, 'family_locus_of_power', 'Egalitarian')}   '
        '${_docxCheckbox(submission, 'family_locus_of_power', 'Matricentric')}',
      ),
    )
    ..writeln(
      _paragraph(
        'Based on place of residence: '
        '${_docxCheckbox(submission, 'family_place_of_residence', 'Patrilocal')}   '
        '${_docxCheckbox(submission, 'family_place_of_residence', 'Matrilocal')}   '
        '${_docxCheckbox(submission, 'family_place_of_residence', 'Bilocal/Ambilocal')}   '
        '${_docxCheckbox(submission, 'family_place_of_residence', 'Neolocal')}',
      ),
    )
    ..writeln(
      _paragraph(
        'Based on descent: '
        '${_docxCheckbox(submission, 'family_descent', 'Patrilineal')}   '
        '${_docxCheckbox(submission, 'family_descent', 'Matrilineal')}   '
        '${_docxCheckbox(submission, 'family_descent', 'Bilateral')}',
      ),
    )
    ..writeln(
      _paragraph(
        'Dialect Frequently used: ${_surveyString(submission.surveyData, 'dialect_frequently_used')}',
      ),
    )
    ..writeln(_sectionHeading('II. Socio-economic, cultural and environmental'))
    ..writeln(
      _table([
        ['Social Indicators', ''],
        ['Services in the Community', ''],
        ['Institutional Facilities', ''],
        ['Organizations', ''],
        ['Tradition/Customs', ''],
        ['Recreational Facilities', ''],
        ['Mode of Transportation', ''],
        ['Mode of Communication', ''],
        ['Economic Indicator', ''],
        ['Income earners / Monthly Family Income / Expenditures', ''],
        ['Financial Source for Family expenditures', ''],
        ['Adequacy of Family Income', ''],
        ['Cultural Orientation regarding Illness', ''],
        ['Cultural Belief', ''],
        ['Cultural Perception', ''],
        ['Community Involvement', ''],
      ]),
    )
    ..writeln(_sectionHeading('Environmental Indicator'))
    ..writeln(
      _table([
        ['Home ownership / construction / rooms', ''],
        ['Lighting / ventilation / sanitary condition', ''],
        ['Water and sanitation status', submission.waterSanitation],
        ['Water source / storage / distance', ''],
        ['Food storage / cooking facilities', ''],
        ['Waste disposal', ''],
        ['Toilet facilities', ''],
        ['Drainage system', ''],
        ['Animals / vectors / breeding sites / housing congestion', ''],
      ]),
    )
    ..writeln(_sectionHeading('III. Health and Illness Pattern'))
    ..writeln(
      _table([
        ['Lifestyle Practices', ''],
        ['Use of Safety Precaution', ''],
        ['Smoker / drugs / alcohol', ''],
      ]),
    )
    ..writeln(_subHeading('Nutritional Status'))
    ..writeln(
      _table([
        ['Name', 'Age', 'Nutritional Status', 'Remarks'],
        ..._nutritionRows(submission),
      ], headerRows: 1),
    )
    ..writeln(
      _table([
        ['Dietary History / 24-Hour Food Recall', ''],
        ['Beliefs and Practices', ''],
        ['Person mostly consulted in times of sickness', ''],
        ['Measures taken in times of sickness', ''],
        ['Medication / treatment', ''],
        [
          'Medical / Dental Check-up',
          'Medical: ${_surveyString(submission.surveyData, 'medical_checkup_frequency')}\nDental: ${_surveyString(submission.surveyData, 'dental_checkup_frequency')}',
        ],
      ]),
    )
    ..writeln(_sectionHeading('Community Health programs'))
    ..writeln(
      _table([
        ['Health Services available in the barangay health center', ''],
      ]),
    )
    ..writeln(_subHeading('Immunization record'))
    ..writeln(
      _table([
        [
          'Name',
          'Age',
          'Gender',
          'Complete according to Age',
          'Incomplete according to Age',
          'Fully Immunized Child',
          'Remarks',
        ],
        ..._immunizationRows(submission),
      ], headerRows: 1),
    )
    ..writeln(
      _table([
        ['Ante-natal Registration', ''],
        ['Family Planning', ''],
      ]),
    )
    ..writeln(_sectionHeading('Health Indicators'))
    ..writeln(_subHeading('Morbidity'))
    ..writeln(
      _table([
        [
          'Name',
          'Age',
          'Gender',
          'Cause',
          'Intervention',
          'Admitted',
          'Not Admitted',
          'With',
          'Without',
        ],
        ..._morbidityRows(submission),
      ], headerRows: 1),
    )
    ..writeln(
      _table([
        ['Mortality within the past 12 months', ''],
        ['History / Presence of Non Communicable Disease in the Family', ''],
        ['History / Presence of Communicable Disease in the Family', ''],
        ['Blood Pressure Record for Ages 35 and above', ''],
        ['Awareness of health services offered by the BHC/RHU', ''],
      ]),
    )
    ..writeln(_sectionHeading('IV. Health Resource'))
    ..writeln(
      _table([
        ['Manpower Resources', ''],
        ['Material Resources', ''],
      ]),
    )
    ..writeln(_sectionHeading('V. Political / Leadership Patterns'))
    ..writeln(
      _table([
        ['Political / Leadership Patterns', ''],
        ['Conditions / events / issues that cause social conflicts', ''],
        ['Practices / approaches effective in setting issues', ''],
      ]),
    )
    ..writeln(
      _sectionHeading(
        'VI. Concerns / suggestions regarding the life style in the area in general.',
      ),
    )
    ..writeln(
      _table([
        ['Community concerns', _listOrBlank(submission.communityConcerns)],
        ['Notes', submission.notes],
      ]),
    );

  final surveySections = _surveyResponseSections(submission);
  if (surveySections.isNotEmpty) {
    buffer.writeln(_sectionHeading('Captured PDF Field Responses'));
    for (final section in surveySections) {
      buffer
        ..writeln(_subHeading(section.title))
        ..writeln(
          _table(
            [
              ['Field', 'Response'],
              for (final row in section.rows) [row.field, row.response],
            ],
            headerRows: 1,
            fontSize: 10,
          ),
        );
    }
  }

  return buffer.toString();
}

List<List<String>> _demographicTableRows(HealthSubmission submission) {
  return [
    [
      '#',
      'Name of Family Member',
      'Relation-ship to the Head of the Family',
      'Gender',
      'Age',
      'Birth M',
      'Birth D',
      'Birth Y',
      'Marital Status',
      'Religion',
      'Highest Educational COMPLETED',
      'Occupation Status',
      'If Employed',
      'Location',
      'Category',
      'Place of Origin',
      'Length of Residence',
    ],
    ..._demographicRows(submission),
  ];
}

List<List<String>> _demographicRows(HealthSubmission submission) {
  final surveyMemberRows = _surveyMapRows(
    submission.surveyData['family_members'],
  );
  if (surveyMemberRows.isNotEmpty) {
    return [
      for (var index = 0; index < surveyMemberRows.length; index++)
        _demographicSurveyRow(surveyMemberRows[index], index),
    ];
  }

  final rows = <List<String>>[
    [
      '1',
      submission.respondentName,
      'Head',
      '',
      submission.respondentAge?.toString() ?? '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
    ],
  ];

  for (var index = 0; index < submission.familyMembers.length; index++) {
    final member = submission.familyMembers[index];
    rows.add([
      '${index + 2}',
      member.name,
      member.relationship,
      '',
      member.age?.toString() ?? '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
    ]);
  }

  return rows;
}

List<List<String>> _demographicTemplateRows(HealthSubmission submission) {
  final surveyMemberRows = _surveyMapRows(
    submission.surveyData['family_members'],
  );
  if (surveyMemberRows.isNotEmpty) {
    return [
      for (var index = 0; index < surveyMemberRows.length; index++)
        _demographicTemplateSurveyRow(surveyMemberRows[index], index),
    ];
  }

  final rows = <List<String>>[];
  for (int i = 0; i < submission.familyMembers.length; i++) {
    final member = submission.familyMembers[i].toSurveyJson();
    rows.add(_demographicTemplateSurveyRow(member, i));
  }
  return rows;
}

List<String> _demographicSurveyRow(Map<String, dynamic> row, int index) {
  String value(String key, [List<String> aliases = const []]) {
    for (final candidateKey in [key, ...aliases]) {
      final candidateValue = _surveyValueLabel(row[candidateKey]);
      if (candidateValue.isNotEmpty) {
        return candidateValue;
      }
    }
    return '';
  }

  return [
    value('member_no').isEmpty ? '${index + 1}' : value('member_no'),
    value('name_of_family_member', ['name']),
    value('relationship_to_head', ['relationship']),
    value('gender'),
    value('age'),
    value('birthdate_month'),
    value('birthdate_day'),
    value('birthdate_year'),
    value('marital_status'),
    value('religion') == 'Others' ? value('religion_other') : value('religion'),
    value('highest_educational_completed'),
    value('occupation_status'),
    value('employment_type_if_employed'),
    value('place_of_work_location'),
    value('place_of_work_category'),
    value('place_of_origin'),
    value('length_of_residence'),
  ];
}

List<String> _demographicTemplateSurveyRow(
  Map<String, dynamic> row,
  int index,
) {
  String value(String key, [List<String> aliases = const []]) =>
      _surveyRowValue(row, key, aliases);

  return [
    value('member_no').isEmpty ? '${index + 1}' : value('member_no'),
    value('name_of_family_member', ['name']),
    value('relationship_to_head', ['relationship']),
    _choiceCode(value('gender'), const {'male': '1', 'female': '2'}),
    value('age'),
    value('birthdate_month'),
    value('birthdate_day'),
    value('birthdate_year'),
    _choiceCode(value('marital_status'), const {
      'child': '1',
      'single': '2',
      'married': '3',
      'married but separated': '4',
      'widow': '5',
      'widower': '6',
    }),
    _choiceCode(value('religion'), const {
      'roman catholic': '1',
      'muslim': '2',
      'iglesia ni cristo': '3',
      'born again christian': '4',
      'jehovahs witness': '5',
      'jehovah witness': '5',
      'protestant methodist evangelical baptist adventist': '6',
      'others': '7',
    }),
    _choiceCode(value('highest_educational_completed'), const {
      'pre elementary': '1',
      'pre elem': '1',
      'elementary level': '2',
      'elem level': '2',
      'elementary graduate': '3',
      'elem grad': '3',
      'high school level': '4',
      'high school graduate': '5',
      'vocational': '6',
      'short course': '7',
      'college level': '8',
      'college graduate': '9',
      'post graduate': '10',
      'over 7 years old without formal schooling': '11',
      'less than 5 years old': '12',
      'sped': '13',
    }),
    _choiceCode(value('occupation_status'), const {
      'employed': '1',
      'unemployed': '2',
      'minor below 18 years old': '3',
    }),
    _choiceCode(value('employment_type_if_employed'), const {
      'regular full time': '1',
      'regular part time': '2',
      'contractual 6 months': '3',
      'contractual every week': '4',
      'contractual everyday': '5',
      'self employed': '6',
      'seasonal': '7',
      'ofw': '8',
      'contractual by job offer': '9',
    }),
    _choiceCode(value('place_of_work_location'), const {
      'within the community': '1',
      'within the municipality city': '2',
      'outside the municipality city': '3',
      'ofw outside the country': '4',
    }),
    _choiceCode(value('place_of_work_category'), const {
      'in house': '1',
      'field': '2',
      'office': '3',
    }),
    _choiceCode(value('place_of_origin'), const {
      'metro manila': '1',
      'central luzon': '2',
      'northern luzon': '3',
      'southern luzon': '4',
      'visayas region': '5',
      'mindanao region': '6',
    }),
    _compactResidenceLength(value('length_of_residence')),
    value('religion') == 'Others' ? value('religion_other') : value('religion'),
  ];
}

String _compactResidenceLength(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final numeric = RegExp(r'\d+(?:\.\d+)?').firstMatch(trimmed);
  return numeric?.group(0) ?? trimmed;
}

String _surveyRowValue(
  Map<String, dynamic> row,
  String key, [
  List<String> aliases = const [],
]) {
  for (final candidateKey in [key, ...aliases]) {
    final candidateValue = _surveyValueLabel(row[candidateKey]);
    if (candidateValue.isNotEmpty) {
      return candidateValue;
    }
  }
  return '';
}

const _mealRecallTimes = [
  'Breakfast',
  'AM Snack',
  'Lunch',
  'PM Snack',
  'Dinner',
  'Midnight Snack',
];

List<Map<String, dynamic>> _mealRecallRows(Object? value) {
  final rows = _surveyMapRows(value);
  if (rows.isEmpty) {
    return const [];
  }

  final normalizedRows = <Map<String, dynamic>>[];
  for (final row in rows) {
    final explicitMeal = _canonicalMealTime(
      _surveyRowValue(row, 'time_of_day', [
        'meal_time',
        'mealTime',
        'meal',
        'time',
      ]),
    );
    final explicitFood = _surveyRowValue(row, 'food_taken', [
      'food',
      'foods',
      'food_items',
      'items',
    ]);
    if (explicitMeal.isNotEmpty || explicitFood.isNotEmpty) {
      normalizedRows.add({
        ...row,
        'time_of_day': explicitMeal,
        'food_taken': explicitFood,
      });
      continue;
    }

    for (final mealTime in _mealRecallTimes) {
      final food = _surveyRowValue(row, mealTime, _mealRecallAliases(mealTime));
      if (food.isEmpty) {
        continue;
      }
      normalizedRows.add({...row, 'time_of_day': mealTime, 'food_taken': food});
    }
  }

  return normalizedRows;
}

Map<String, String> _mealRecallMap(List<Map<String, dynamic>> rows) {
  final meals = <String, String>{};
  for (final row in rows) {
    final mealTime = _canonicalMealTime(_surveyRowValue(row, 'time_of_day'));
    final food = _surveyRowValue(row, 'food_taken');
    if (mealTime.isEmpty || food.isEmpty) {
      continue;
    }
    meals[mealTime] = food;
  }
  return meals;
}

List<String> _mealRecallAliases(String mealTime) {
  return switch (mealTime) {
    'Breakfast' => const ['breakfast', 'breakfast_food'],
    'AM Snack' => const [
      'am_snack',
      'am_snack_food',
      'snack1',
      'snack1_food',
      'morning_snack',
    ],
    'Lunch' => const ['lunch', 'lunch_food'],
    'PM Snack' => const [
      'pm_snack',
      'pm_snack_food',
      'snack2',
      'snack2_food',
      'afternoon_snack',
    ],
    'Dinner' => const ['dinner', 'dinner_food', 'supper'],
    'Midnight Snack' => const [
      'midnight_snack',
      'midnight_snack_food',
      'late_night_snack',
    ],
    _ => const [],
  };
}

String _canonicalMealTime(String value) {
  final normalized = _normalizeSurveyChoice(value);
  return switch (normalized) {
    'breakfast' || 'breakfast food' => 'Breakfast',
    'am snack' || 'morning snack' || 'snack 1' || 'snack1' => 'AM Snack',
    'lunch' || 'lunch food' => 'Lunch',
    'pm snack' || 'afternoon snack' || 'snack 2' || 'snack2' => 'PM Snack',
    'dinner' || 'dinner food' || 'supper' => 'Dinner',
    'midnight snack' || 'late night snack' => 'Midnight Snack',
    _ => value.trim(),
  };
}

String _incomeEarnerName(
  HealthSubmission submission,
  Map<String, dynamic> row,
) {
  final explicitName = _surveyRowValue(row, 'family_member_name', [
    'name_of_family_member',
    'name',
  ]);
  if (explicitName.isNotEmpty) {
    return explicitName;
  }

  final memberNo = _surveyRowValue(row, 'family_member_no', ['member_no']);
  final lookupNo = memberNo.isEmpty
      ? _surveyRowValue(row, 'earner_no')
      : memberNo;
  if (lookupNo.isEmpty) {
    return '';
  }

  final surveyMemberRows = _surveyMapRows(
    submission.surveyData['family_members'],
  );
  for (var index = 0; index < surveyMemberRows.length; index++) {
    final memberRow = surveyMemberRows[index];
    final candidateNo = _surveyRowValue(memberRow, 'member_no');
    final fallbackNo = '${index + 1}';
    if (_sameMemberNumber(
      candidateNo.isEmpty ? fallbackNo : candidateNo,
      lookupNo,
    )) {
      return _surveyRowValue(memberRow, 'name_of_family_member', ['name']);
    }
  }

  for (final member in submission.familyMembers) {
    final memberNo = _surveyValueLabel(member.details['member_no']);
    if (_sameMemberNumber(memberNo, lookupNo)) {
      return member.name;
    }
  }
  if (_sameMemberNumber(lookupNo, '1')) {
    return submission.respondentName;
  }
  final familyMembersIncludeRespondent =
      submission.familyMembers.isNotEmpty &&
      _normalizeSurveyChoice(submission.familyMembers.first.name) ==
          _normalizeSurveyChoice(submission.respondentName);
  for (var index = 0; index < submission.familyMembers.length; index++) {
    final impliedNo = familyMembersIncludeRespondent ? index + 1 : index + 2;
    if (_sameMemberNumber(lookupNo, '$impliedNo')) {
      return submission.familyMembers[index].name;
    }
  }

  return '';
}

bool _sameMemberNumber(String left, String right) {
  final normalizedLeft = left.trim();
  final normalizedRight = right.trim();
  if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
    return false;
  }

  final leftNumber = num.tryParse(normalizedLeft);
  final rightNumber = num.tryParse(normalizedRight);
  if (leftNumber != null && rightNumber != null) {
    return leftNumber == rightNumber;
  }

  return normalizedLeft == normalizedRight;
}

String _choiceCode(String value, Map<String, String> codes) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  if (RegExp(r'^\d+$').hasMatch(trimmed)) {
    return trimmed;
  }
  final normalized = trimmed
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  return codes[normalized] ?? trimmed;
}

List<List<String>> _nutritionRows(HealthSubmission submission) {
  return [
    [
      submission.respondentName,
      submission.respondentAge?.toString() ?? '',
      submission.nutritionalStatus,
      '',
    ],
    for (final member in submission.familyMembers)
      [member.name, member.age?.toString() ?? '', member.nutritionalStatus, ''],
  ];
}

List<List<String>> _immunizationRows(HealthSubmission submission) {
  return [
    _immunizationRow(
      name: submission.respondentName,
      age: submission.respondentAge?.toString() ?? '',
      vaccinationStatus: submission.vaccinationStatus,
    ),
    for (final member in submission.familyMembers)
      _immunizationRow(
        name: member.name,
        age: member.age?.toString() ?? '',
        vaccinationStatus: member.vaccinationStatus,
      ),
  ];
}

List<String> _immunizationRow({
  required String name,
  required String age,
  required String vaccinationStatus,
}) {
  final status = vaccinationStatus.toLowerCase();
  final incomplete = status.contains('incomplete');
  final complete = !incomplete && status.contains('complete');

  return [
    name,
    age,
    '',
    complete ? 'X' : '',
    incomplete ? 'X' : '',
    complete ? 'X' : '',
    vaccinationStatus,
  ];
}

List<List<String>> _morbidityRows(HealthSubmission submission) {
  final rows = <List<String>>[];

  if (submission.healthProblems.isNotEmpty) {
    rows.add([
      submission.respondentName,
      submission.respondentAge?.toString() ?? '',
      '',
      _listOrBlank(submission.healthProblems),
      '',
      '',
      '',
      'X',
      '',
    ]);
  }

  for (final member in submission.familyMembers) {
    if (member.healthProblems.isEmpty) {
      continue;
    }

    rows.add([
      member.name,
      member.age?.toString() ?? '',
      '',
      _listOrBlank(member.healthProblems),
      '',
      '',
      '',
      'X',
      '',
    ]);
  }

  if (rows.isEmpty) {
    rows.add(List.filled(9, ''));
  }

  return rows;
}

String _documentHeaderTable(int sectionIndex) {
  final centerContent = [
    _paragraph(
      'BULACAN STATE UNIVERSITY',
      center: true,
      bold: true,
      fontSize: 18,
    ),
    _paragraph('Alliance Expertise Team', center: true, fontSize: 18),
    _paragraph('COLLEGE OF NURSING', center: true, bold: true, fontSize: 18),
    _paragraph('City of Malolos', center: true, fontSize: 18),
  ].join();

  return '''
<w:tbl>
  <w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders></w:tblPr>
  <w:tr>
    ${_rawTableCell(_documentImageParagraph('rId3', 'Bulacan State University Logo', 681990, 681990, sectionIndex * 2 + 1), width: 1500)}
    ${_rawTableCell(centerContent, width: 8160)}
    ${_rawTableCell(_documentImageParagraph('rId2', 'College of Nursing Logo', 667385, 667385, sectionIndex * 2 + 2), width: 1500)}
  </w:tr>
</w:tbl>
''';
}

String _rawTableCell(String content, {required int width}) {
  return '<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>$content</w:tc>';
}

String _documentImageParagraph(
  String relationshipId,
  String name,
  int width,
  int height,
  int docPrId,
) {
  final escapedName = _xmlEscape(name);
  return '''
<w:p>
  <w:pPr><w:jc w:val="center"/></w:pPr>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0">
        <wp:extent cx="$width" cy="$height"/>
        <wp:docPr id="$docPrId" name="$escapedName"/>
        <wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>
        <a:graphic>
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic>
              <pic:nvPicPr><pic:cNvPr id="0" name="$escapedName"/><pic:cNvPicPr/></pic:nvPicPr>
              <pic:blipFill><a:blip r:embed="$relationshipId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
              <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$width" cy="$height"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
''';
}

String _table(
  List<List<String>> rows, {
  int headerRows = 0,
  int fontSize = 18,
}) {
  final buffer = StringBuffer()
    ..writeln('<w:tbl>')
    ..writeln(
      '<w:tblPr><w:tblW w:w="5000" w:type="pct"/><w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="000000"/><w:left w:val="single" w:sz="4" w:space="0" w:color="000000"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/><w:right w:val="single" w:sz="4" w:space="0" w:color="000000"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="000000"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="000000"/></w:tblBorders></w:tblPr>',
    );

  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    buffer.writeln('<w:tr>');
    for (final cell in rows[rowIndex]) {
      final shaded = rowIndex < headerRows;
      buffer
        ..writeln('<w:tc>')
        ..writeln('<w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr>')
        ..writeln(_paragraph(cell, fontSize: fontSize, bold: shaded))
        ..writeln('</w:tc>');
    }
    buffer.writeln('</w:tr>');
  }

  buffer.writeln('</w:tbl>');
  return buffer.toString();
}

String _sectionHeading(String text) {
  return _paragraph(text, bold: true, fontSize: 22, spacingBefore: 160);
}

String _subHeading(String text) {
  return _paragraph(text, bold: true, fontSize: 20, spacingBefore: 120);
}

String _paragraph(
  String text, {
  bool bold = false,
  bool center = false,
  int fontSize = 20,
  int spacingBefore = 0,
}) {
  final escapedText = _xmlEscape(_valueOrBlank(text));
  final jc = center ? '<w:jc w:val="center"/>' : '';
  final spacing = spacingBefore > 0
      ? '<w:spacing w:before="$spacingBefore" w:after="40"/>'
      : '<w:spacing w:after="40"/>';
  final boldTag = bold ? '<w:b/>' : '';

  return '<w:p><w:pPr>$jc$spacing</w:pPr><w:r><w:rPr>$boldTag<w:sz w:val="$fontSize"/></w:rPr><w:t xml:space="preserve">$escapedText</w:t></w:r></w:p>';
}

String _pageBreakParagraph() {
  return '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';
}

String _dateOnly(DateTime value) => DateFormat('MMM d, yyyy').format(value);

Future<Uint8List> _loadAssetBytes(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

String _xmlEscape(String value) => const HtmlEscape().convert(value);

String _valueOrBlank(String value) => value.trim();

String _listOrBlank(List<String> values) => values.join(', ');

String _docxCheckbox(
  HealthSubmission submission,
  String key,
  String choice, [
  String? label,
]) {
  final text = label ?? choice;
  return _surveyHasChoice(submission.surveyData, key, choice)
      ? '(X) $text'
      : '( ) $text';
}

bool _surveyHasChoice(Map<String, dynamic> data, String key, String choice) {
  bool matches(Object? value) {
    if (value == null) {
      return false;
    }
    if (value is List) {
      return value.any(matches);
    }
    if (value is Map) {
      return value.entries.any((entry) {
        final keyMatches =
            _normalizeSurveyChoice(entry.key) == _normalizeSurveyChoice(choice);
        return keyMatches && entry.value != false && entry.value != null;
      });
    }

    final normalizedValue = _normalizeSurveyChoice(_surveyValueLabel(value));
    final normalizedChoice = _normalizeSurveyChoice(choice);
    return normalizedValue == normalizedChoice ||
        normalizedValue
            .split(',')
            .map(_normalizeSurveyChoice)
            .contains(normalizedChoice);
  }

  return matches(data[key]);
}

String _normalizeSurveyChoice(Object? value) {
  return _surveyValueLabel(value)
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

class _SurveyExportSection {
  const _SurveyExportSection({required this.title, required this.rows});

  final String title;
  final List<_SurveyExportRow> rows;
}

class _SurveyExportRow {
  const _SurveyExportRow({required this.field, required this.response});

  final String field;
  final String response;
}

List<_SurveyExportSection> _surveyResponseSections(
  HealthSubmission submission,
) {
  final surveyData = submission.surveyData;
  if (surveyData.isEmpty) {
    return const [];
  }

  final sections = <_SurveyExportSection>[];
  final exportedKeys = <String>{};
  for (final section in surveySections) {
    final rows = <_SurveyExportRow>[];
    for (final field in section.fields) {
      if (field.type == SurveyFieldType.note ||
          field.type == SurveyFieldType.heading) {
        continue;
      }

      exportedKeys.add(field.key);
      final value = surveyData[field.key];
      if (!_surveyValueHasContent(value)) {
        continue;
      }
      rows.addAll(_surveyFieldRows(field, value));
    }
    if (rows.isNotEmpty) {
      sections.add(_SurveyExportSection(title: section.title, rows: rows));
    }
  }

  final extraRows = <_SurveyExportRow>[];
  for (final entry in surveyData.entries) {
    if (exportedKeys.contains(entry.key) ||
        !_surveyValueHasContent(entry.value)) {
      continue;
    }
    extraRows.add(
      _SurveyExportRow(
        field: _surveyLabelFromKey(entry.key),
        response: _surveyValueLabel(entry.value),
      ),
    );
  }
  if (extraRows.isNotEmpty) {
    sections.add(
      _SurveyExportSection(
        title: 'Additional Captured Fields',
        rows: extraRows,
      ),
    );
  }

  return sections;
}

List<_SurveyExportRow> _surveyFieldRows(SurveyField field, Object? value) {
  if (field.type != SurveyFieldType.repeatableTable) {
    return [
      _SurveyExportRow(field: field.label, response: _surveyValueLabel(value)),
    ];
  }

  final rows = <_SurveyExportRow>[];
  final tableRows = _surveyMapRows(value);
  for (var index = 0; index < tableRows.length; index++) {
    final row = tableRows[index];
    final rowLabel = '${field.label} row ${index + 1}';
    final exportedChildKeys = <String>{};

    for (final childField in field.fields) {
      if (childField.type == SurveyFieldType.note ||
          childField.type == SurveyFieldType.heading) {
        continue;
      }

      exportedChildKeys.add(childField.key);
      final childValue = row[childField.key];
      if (!_surveyValueHasContent(childValue)) {
        continue;
      }
      rows.add(
        _SurveyExportRow(
          field: '$rowLabel - ${childField.label}',
          response: _surveyValueLabel(childValue),
        ),
      );
    }

    for (final entry in row.entries) {
      if (exportedChildKeys.contains(entry.key) ||
          !_surveyValueHasContent(entry.value)) {
        continue;
      }
      rows.add(
        _SurveyExportRow(
          field: '$rowLabel - ${_surveyLabelFromKey(entry.key)}',
          response: _surveyValueLabel(entry.value),
        ),
      );
    }
  }

  return rows;
}

String _surveyRowLabel(List<SurveyField> fields, Map<String, dynamic> row) {
  final parts = <String>[];
  for (final field in fields) {
    final value = row[field.key];
    if (!_surveyValueHasContent(value)) {
      continue;
    }
    parts.add('${field.label}: ${_surveyValueLabel(value)}');
  }
  return parts.join('; ');
}

String _surveyLabelFromKey(String key) {
  return key
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

List<Map<String, dynamic>> _surveyMapRows(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
  return const [];
}

String _surveyString(Map<String, dynamic> data, String key) {
  return _surveyValueLabel(data[key]);
}

String _surveyValueLabel(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is List) {
    return value
        .map(_surveyValueLabel)
        .where((item) => item.isNotEmpty)
        .join(', ');
  }
  if (value is Map) {
    return value.entries
        .where((entry) => _surveyValueHasContent(entry.value))
        .map((entry) => '${entry.key}: ${_surveyValueLabel(entry.value)}')
        .join('; ');
  }
  if (value is bool) {
    return value ? 'Yes' : 'No';
  }
  return '$value'.trim();
}

bool _surveyValueHasContent(Object? value) {
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

Map<String, dynamic> _jsonSafeMap(Map<String, dynamic> value) {
  return value.map((key, value) => MapEntry(key, _jsonSafeValue(value)));
}

Object? _jsonSafeValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', _jsonSafeValue(value)));
  }
  if (value is Iterable) {
    return value.map(_jsonSafeValue).toList();
  }
  return '$value';
}

String _corePropsXml() {
  final timestamp = DateTime.now().toUtc().toIso8601String();
  return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>KASUDLO Community Survey Tool</dc:title>
  <dc:creator>KASUDLO</dc:creator>
  <cp:lastModifiedBy>KASUDLO</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">$timestamp</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$timestamp</dcterms:modified>
</cp:coreProperties>
''';
}

const _contentTypesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
''';

const _packageRelsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
''';

const _documentRelsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/college-of-nursing.png"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/bulacan-state-university.png"/>
</Relationships>
''';

const _appPropsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>KASUDLO</Application>
</Properties>
''';

const _stylesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:sz w:val="20"/></w:rPr>
  </w:style>
</w:styles>
''';
