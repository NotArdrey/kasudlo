import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = Uri.parse('https://api.supabase.com/v1/projects/ombfilswymuhsaovefuc/database/query');
  final pat = 'REDACTED_SUPABASE_PAT';

  final query = '''
    SELECT * FROM household_assessments 
    WHERE respondent_name = 'Ardrey Dummy Respondent' 
    LIMIT 1;
  ''';

  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer ' + pat,
      'Content-Type': 'application/json'
    },
    body: jsonEncode({'query': query}),
  );

  print(response.body);
}
