import 'package:http/http.dart' as http;
import 'dart:convert';
import '../lib/src/survey_schema.dart';

void main() async {
  final url = Uri.parse('https://api.supabase.com/v1/projects/ombfilswymuhsaovefuc/database/query');
  final pat = 'REDACTED_SUPABASE_PAT';

  final Map<String, dynamic> fullPayload = {};

  for (final section in surveySections) {
    for (final field in section.fields) {
      if (field.type == SurveyFieldType.repeatableTable) {
        if (field.key == 'family_members') continue; // Handled separately
        if (field.key == 'smokers') {
          fullPayload[field.key] = [
            {'name_of_smoker': 'Dummy Smoker', 'age': 45}
          ];
        } else if (field.key == 'pregnant_women') {
          fullPayload[field.key] = [
            {'name_of_pregnant': 'Dummy Pregnant', 'age': 25, 'months_pregnant': 6}
          ];
        } else {
          fullPayload[field.key] = [];
        }
      } else if (field.type == SurveyFieldType.select || field.type == SurveyFieldType.singleSelectCheckbox) {
        if (field.options.isNotEmpty) {
          fullPayload[field.key] = field.options.first;
        } else {
          fullPayload[field.key] = 'Option 1';
        }
      } else if (field.type == SurveyFieldType.multiSelect || field.type == SurveyFieldType.multiSelectCheckbox) {
        if (field.options.isNotEmpty) {
          fullPayload[field.key] = [field.options.first];
        } else {
          fullPayload[field.key] = ['Option 1'];
        }
      } else if (field.type == SurveyFieldType.number) {
        fullPayload[field.key] = 1;
      } else if (field.type == SurveyFieldType.text || field.type.name == 'longText') {
        fullPayload[field.key] = 'Dummy ' + field.label;
      } else if (field.type == SurveyFieldType.date) {
        fullPayload[field.key] = '2026-06-08';
      }
    }
  }

  // Ensure these are explicitly set in the payload as they are used directly by the template
  fullPayload['religion'] = 'Catholic';
  fullPayload['civil_status'] = 'Married';
  fullPayload['highest_educational_attainment'] = 'College Graduate';
  fullPayload['occupation'] = 'Software Developer';
  fullPayload['monthly_income'] = '₱20,000 - ₱30,000';
  fullPayload['four_ps_beneficiary_count'] = 1;
  fullPayload['voters_count'] = 2;
  fullPayload['pets'] = ['Dog', 'Cat'];
  fullPayload['has_toilet'] = 'Yes';
  fullPayload['electricity'] = 'Yes';
  fullPayload['housing_ownership'] = 'Owned';

  // Populate family_members
  fullPayload['family_members'] = [
    {
      'member_no': '1',
      'name_of_family_member': 'Ardrey Dummy Respondent',
      'relationship_to_head': 'Head',
      'gender': 'Male',
      'age': 35,
      'birthdate_month': 'January',
      'birthdate_day': '15',
      'birthdate_year': '1991',
      'marital_status': 'Married',
      'religion': 'Roman Catholic',
      'highest_educational_completed': 'College Graduate',
      'occupation_status': 'Employed',
      'employment_type_if_employed': 'Regular Full Time',
      'place_of_work_location': 'Within the community',
      'place_of_work_category': 'Office',
      'place_of_origin': 'Metro Manila',
      'length_of_residence': '10 years'
    },
    {
      'member_no': '2',
      'name_of_family_member': 'Jane Dummy Respondent',
      'relationship_to_head': 'Wife',
      'gender': 'Female',
      'age': 32,
      'birthdate_month': 'March',
      'birthdate_day': '20',
      'birthdate_year': '1994',
      'marital_status': 'Married',
      'religion': 'Roman Catholic',
      'highest_educational_completed': 'College Graduate',
      'occupation_status': 'Employed',
      'employment_type_if_employed': 'Regular Full Time',
      'place_of_work_location': 'Outside the municipality city',
      'place_of_work_category': 'Office',
      'place_of_origin': 'Metro Manila',
      'length_of_residence': '10 years'
    }
  ];

  final payloadJsonStr = jsonEncode(fullPayload).replaceAll("'", "''");

  final updateQuery = '''
    UPDATE household_assessments 
    SET payload = ''' + "'" + payloadJsonStr + "'" + '''::jsonb
    WHERE respondent_name = 'Ardrey Dummy Respondent';
  ''';

  final updateResponse = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer ' + pat,
      'Content-Type': 'application/json'
    },
    body: jsonEncode({'query': updateQuery}),
  );

  print('Update Status: ' + updateResponse.statusCode.toString());
  print('Update Body: ' + updateResponse.body);
}
