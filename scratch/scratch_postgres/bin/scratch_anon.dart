import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

void main() async {
  final supabaseUrl = 'https://ombfilswymuhsaovefuc.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9tYmZpbHN3eW11aHNhb3ZlZnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1MzU4NDEsImV4cCI6MjA5NTExMTg0MX0.1LaDW6GkH-QYYSLIRQO0Pu8vIy3JG7reDNnVPHxucHk';

  final client = SupabaseClient(supabaseUrl, supabaseKey);

  final clientSubmissionId = Uuid().v4();

  final payload = {
    'client_submission_id': clientSubmissionId,
    'respondent_name': 'Dummy Respondent',
    'respondent_age': 35,
    'address': '123 Dummy St',
    'family_members_count': 3,
    'family_members': [
      {'name': 'Dummy Spouse', 'age': 33, 'relationship': 'Spouse'},
      {'name': 'Dummy Child', 'age': 10, 'relationship': 'Child'}
    ],
    'health_problems': ['Cough', 'Fever'],
    'vaccination_status': 'Complete',
    'water_sanitation': 'Level 3',
    'nutritional_status': 'Normal',
    'community_concerns': ['No street lights'],
    'consent_given': true,
    'notes': 'This is a dummy record',
    'edit_history': [],
    'payload': {'dummy': 'data'}
  };

  try {
    final response = await client
        .from('household_assessments')
        .insert(payload)
        .select();
    print('Insert successful: \$response');
    print("Inserted name: \${response[0]['respondent_name']}");
  } catch (e) {
    print('Insert failed: \$e');
  }
}
