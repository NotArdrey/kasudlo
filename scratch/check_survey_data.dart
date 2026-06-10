import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://nyfwhdwhiydxewqmyyhx.supabase.co/rest/v1/household_assessments?respondent_name=ilike.*Ardrey*&select=respondent_name,payload');
  final pat = 'REDACTED_SUPABASE_PAT';

  final res = await http.get(url, headers: {
    'apikey': pat,
    'Authorization': 'Bearer $pat',
  });

  print(res.body);
}
