import 'package:postgres/postgres.dart';

void main() async {
  print('Connecting to database...');
  final connection = await Connection.open(
    Endpoint(
      host: 'db.ombfilswymuhsaovefuc.supabase.co',
      port: 5432,
      database: 'postgres',
      username: 'postgres',
      password: 'Ardrey_012005',
    ),
    settings: ConnectionSettings(sslMode: SslMode.require),
  );

  final sql = '''
alter table public.health_tips
  add column if not exists target_patient_id uuid null references auth.users (id) on delete set null;

create index if not exists health_tips_target_patient_idx
  on public.health_tips (target_patient_id);

drop policy if exists health_tips_select_authenticated on public.health_tips;
create policy health_tips_select_authenticated
on public.health_tips
for select
to authenticated
using (
  target_patient_id is null 
  or target_patient_id = (select auth.uid()) 
  or (select public.is_kasudlo_health_tip_manager(auth.uid()))
);
''';

  try {
    print('Executing migration...');
    await connection.execute(sql);
    print('Migration executed successfully!');
  } catch (e) {
    print('Error: \$e');
  } finally {
    await connection.close();
    print('Connection closed.');
  }
}
