import 'dart:convert';
import 'package:kasudlo/src/models.dart';
import 'package:kasudlo/src/services/report_exporter.dart';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://api.supabase.com/v1/projects/ombfilswymuhsaovefuc/database/query');
  final pat = 'REDACTED_SUPABASE_PAT';

  final getQuery = '''
    SELECT * FROM household_assessments 
    WHERE respondent_name = 'Ardrey Dummy Respondent' 
    LIMIT 1;
  ''';

  final getResponse = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer ' + pat,
      'Content-Type': 'application/json'
    },
    body: jsonEncode({'query': getQuery}),
  );

  final List<dynamic> data = jsonDecode(getResponse.body);
  final HealthSubmission submission = HealthSubmission.fromRemoteJson(data.first);
  
  final fields = docmosisTemplateFields(submission);
  
  print('family_composition_nuclear: \${fields['family_composition_nuclear']}');
  print('income_10001_15000: \${fields['income_10001_15000']}');
  print('religion: \${fields['religion']}');
}
