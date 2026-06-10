import 'package:postgres/postgres.dart';
import 'dart:convert';

void main() async {
  final host = 'ombfilswymuhsaovefuc.supabase.co'; // try direct API domain
  final ports = [5432, 6543];

  for (final port in ports) {
    try {
      print('Trying port \$port...');
      final connection = await Connection.open(
        Endpoint(
          host: host,
          port: port,
          database: 'postgres',
          username: 'postgres',
          password: 'Ardrey_012005',
        ),
        settings: ConnectionSettings(sslMode: SslMode.require, connectTimeout: Duration(seconds: 5)),
      );

      print('Connected on port \$port!');
      
      final query = '''
        INSERT INTO household_assessments (
          client_submission_id, 
          respondent_name, 
          respondent_age, 
          address, 
          family_members_count, 
          family_members, 
          health_problems, 
          vaccination_status, 
          water_sanitation, 
          nutritional_status, 
          community_concerns, 
          consent_given, 
          notes, 
          edit_history, 
          payload
        ) VALUES (
          gen_random_uuid(), 
          'Ardrey Dummy Respondent', 
          35, 
          '123 Dummy St', 
          3, 
          '[]'::jsonb, 
          '[]'::jsonb, 
          'Complete', 
          'Level 3', 
          'Normal', 
          '[]'::jsonb, 
          true, 
          'This is a dummy record', 
          '[]'::jsonb, 
          '{}'::jsonb
        ) RETURNING respondent_name;
      ''';

      final result = await connection.execute(query);
      for (final row in result) {
        print('Inserted Name: \${row[0]}');
      }

      await connection.close();
      return;
    } catch (e) {
      print('Failed on port \$port: \$e');
    }
  }
}
