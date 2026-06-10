import 'dart:convert';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://ombfilswymuhsaovefuc.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9tYmZpbHN3eW11aHNhb3ZlZnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1MzU4NDEsImV4cCI6MjA5NTExMTg0MX0.1LaDW6GkH-QYYSLIRQO0Pu8vIy3JG7reDNnVPHxucHk', // from config.dart
  );

  final response = await supabase
      .from('household_assessments')
      .select('respondent_name, payload')
      .ilike('respondent_name', '%Ardrey%');

  print(jsonEncode(response));
}
