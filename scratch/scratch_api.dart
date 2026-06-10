import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = Uri.parse('https://api.supabase.com/v1/projects/ombfilswymuhsaovefuc/database/query');
  final pat = 'REDACTED_SUPABASE_PAT';

  final getUserIdQuery = '''
    SELECT user_id FROM household_assessments 
    WHERE respondent_name = 'Ellyna Marie Nicole T. Vasallo' 
    LIMIT 1;
  ''';

  final getUserIdResponse = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer ' + pat,
      'Content-Type': 'application/json'
    },
    body: jsonEncode({'query': getUserIdQuery}),
  );

  print('Get User ID Status: ' + getUserIdResponse.statusCode.toString());
  print('Get User ID Body: ' + getUserIdResponse.body);

  if (getUserIdResponse.statusCode == 201 || getUserIdResponse.statusCode == 200) {
    final List<dynamic> data = jsonDecode(getUserIdResponse.body);
    if (data.isNotEmpty) {
      final userId = data[0]['user_id'];
      print('Found User ID: ' + userId);

      final updateQuery = '''
        UPDATE household_assessments 
        SET user_id = ''' + "'" + userId + "'" + '''
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
    } else {
      print('Could not find the target user ID.');
    }
  }
}
