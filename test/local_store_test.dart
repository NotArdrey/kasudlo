import 'package:flutter_test/flutter_test.dart';
import 'package:kasudlo/src/models.dart';
import 'package:kasudlo/src/services/local_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(sqfliteFfiInit);

  tearDown(() async {
    await LocalStore.closeForTesting();
  });

  test('persists submissions, preferences, and seed flags in SQLite', () async {
    await LocalStore.initializeForTesting(databaseFactoryFfi);

    final submission = HealthSubmission(
      clientSubmissionId: 'local-one',
      respondentName: 'Lorna Cruz',
      respondentAge: 65,
      address: 'Sitio Maligaya',
      familyMembersCount: 2,
      familyMembers: const [],
      healthProblems: const ['Hypertension'],
      vaccinationStatus: 'Unknown',
      waterSanitation: 'No sanitary toilet',
      nutritionalStatus: 'Underweight',
      communityConcerns: const ['Poor sanitation'],
      consentGiven: true,
      notes: 'Follow up.',
      createdAt: DateTime(2026, 5, 24, 15, 26),
      syncStatus: SyncStatus.draft,
      surveyData: const {
        'account_create_requested': true,
        'account_email': 'lorna@example.com',
      },
    );

    await LocalStore.upsertSubmission(submission);
    await LocalStore.savePreferences(
      const AppPreferences(dataSaverEnabled: true, language: 'Filipino'),
    );
    await LocalStore.markDemoDataSeeded();

    final records = LocalStore.loadSubmissions();
    expect(records, hasLength(1));
    expect(records.single.clientSubmissionId, 'local-one');
    expect(records.single.syncStatus, SyncStatus.draft);
    expect(records.single.surveyData['account_email'], 'lorna@example.com');
    expect(LocalStore.loadPreferences().dataSaverEnabled, isTrue);
    expect(LocalStore.loadPreferences().language, 'Filipino');
    expect(LocalStore.hasSeededDemoData(), isTrue);

    await LocalStore.deleteSubmission('local-one');
    expect(LocalStore.loadSubmissions(), isEmpty);
  });
}
