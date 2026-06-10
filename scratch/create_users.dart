import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://ombfilswymuhsaovefuc.supabase.co';
  final serviceRoleKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9tYmZpbHN3eW11aHNhb3ZlZnVjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTUzNTg0MSwiZXhwIjoyMDk1MTExODQxfQ.Y0bOuQwDqDdtjoT6ZftrfGGLo4yKrfFXYj4Y18qeVfk';

  final client = SupabaseClient(supabaseUrl, serviceRoleKey);

  final email = 'admin@gmail.com';

  try {
    final userResponse = await client.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: 'pass123',
        emailConfirm: true,
        userMetadata: {'full_name': 'Admin User', 'role': 'admin'},
        appMetadata: {'kasudlo_role': 'admin'},
      ),
    );
    print('Created admin user with email $email');
  } catch (e) {
    if (e.toString().contains('User already registered')) {
      print('User already exists. Updating password instead...');
      try {
        final existing = await client
            .from('auth.users')
            .select('id')
            .eq('email', email)
            .single();
        final id = existing['id'] as String;
        await client.auth.admin.updateUserById(
          id,
          attributes: AdminUserAttributes(password: 'pass123'),
        );
        print('Updated password for existing $email');
      } catch (innerE) {
        print('Failed to update: $innerE');
      }
    } else {
      print('Failed to create user $email: $e');
    }
  }
}
