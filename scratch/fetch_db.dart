import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://ombfilswymuhsaovefuc.supabase.co/rest/v1/household_assessments?select=respondent_name');
  final response = await http.get(
    url,
    headers: {
      'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9tYmZpbHN3eW11aHNhb3ZlZnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1MzU4NDEsImV4cCI6MjA5NTExMTg0MX0.1LaDW6GkH-QYYSLIRQO0Pu8vIy3JG7reDNnVPHxucHk',
      'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9tYmZpbHN3eW11aHNhb3ZlZnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1MzU4NDEsImV4cCI6MjA5NTExMTg0MX0.1LaDW6GkH-QYYSLIRQO0Pu8vIy3JG7reDNnVPHxucHk',
    },
  );
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data is List && data.isNotEmpty) {
      final submission = data.first;
      final surveyData = submission['payload']; // wait, payload or survey_data?
      // Let's print the entire JSON keys
      print('Submission Keys: ${submission.keys.join(", ")}');
      
      final dynamic sData = submission['survey_data'] ?? submission['payload'];
      if (sData != null) {
        print('Family Members:');
        print(jsonEncode(sData['family_members']));
        print('\nCheckboxes:');
        print('Community Involvement: ${sData['community_involvement']}');
        print('Cigarette Smokers: ${jsonEncode(sData['cigarette_smokers'])}');
        print('Animals: ${jsonEncode(sData['rabies_carrier_animals'])}');
        print('Income Earners: ${jsonEncode(sData['income_earners'])}');
      } else {
        print('No survey data inside submission');
      }
    } else {
      print('No data found for Ardrey Dummy Respondent.');
    }
  } else {
    print('Failed: ${response.statusCode} - ${response.body}');
  }
}
