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
    print(response.body);
  } else {
    print('Failed: ${response.statusCode}');
  }
}
