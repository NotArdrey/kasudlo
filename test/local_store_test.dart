import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasudlo/src/models.dart';
import 'package:kasudlo/src/services/local_store.dart';
import 'package:path/path.dart' as path;
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
    await LocalStore.upsertHealthTip(
      HealthTip(
        id: 'tip-one',
        title: 'Dengue prevention',
        description: 'Remove standing water.',
        fileName: 'dengue.pdf',
        mimeType: 'application/pdf',
        fileSize: 12,
        attachmentBase64: 'aGVhbHRo',
        createdAt: DateTime(2026, 5, 24, 14),
        updatedAt: DateTime(2026, 5, 24, 15),
        createdByEmail: 'nurse@example.com',
      ),
    );
    await LocalStore.savePreferences(
      const AppPreferences(dataSaverEnabled: true, language: 'Filipino'),
    );
    await LocalStore.markDemoDataSeeded();
    await LocalStore.markHealthTipsSeeded();

    final records = LocalStore.loadSubmissions();
    expect(records, hasLength(1));
    expect(records.single.clientSubmissionId, 'local-one');
    expect(records.single.syncStatus, SyncStatus.draft);
    expect(records.single.surveyData['account_email'], 'lorna@example.com');
    expect(LocalStore.loadPreferences().dataSaverEnabled, isTrue);
    expect(LocalStore.loadPreferences().language, 'Filipino');
    expect(LocalStore.hasSeededDemoData(), isTrue);
    expect(LocalStore.hasSeededHealthTips(), isTrue);
    expect(LocalStore.loadHealthTips(), hasLength(1));
    expect(LocalStore.loadHealthTips().single.title, 'Dengue prevention');

    await LocalStore.deleteSubmission('local-one');
    await LocalStore.deleteHealthTip('tip-one');
    expect(LocalStore.loadSubmissions(), isEmpty);
    expect(LocalStore.loadHealthTips(), isEmpty);
  });

  test('restores abandoned syncing records as pending on restart', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'kasudlo_local_store_test_',
    );
    final databasePath = path.join(tempDir.path, 'restart.sqlite');

    try {
      await LocalStore.initializeForTesting(
        databaseFactoryFfi,
        databasePath: databasePath,
      );

      final updatedAt = DateTime.utc(2026, 5, 24, 18, 30);
      await LocalStore.upsertSubmission(
        HealthSubmission(
          clientSubmissionId: 'syncing-one',
          respondentName: 'Ana Cruz',
          respondentAge: 30,
          address: 'Barangay 1',
          familyMembersCount: 2,
          familyMembers: const [],
          healthProblems: const ['Cough or fever'],
          vaccinationStatus: 'Complete',
          waterSanitation: 'Safe water and sanitary toilet',
          nutritionalStatus: 'Normal',
          communityConcerns: const ['Dengue risk'],
          consentGiven: true,
          notes: '',
          createdAt: DateTime.utc(2026, 5, 23),
          syncStatus: SyncStatus.syncing,
          updatedAt: updatedAt,
        ),
      );

      await LocalStore.closeForTesting();
      await LocalStore.initializeForTesting(
        databaseFactoryFfi,
        databasePath: databasePath,
      );

      final records = LocalStore.loadSubmissions();
      expect(records.single.syncStatus, SyncStatus.pending);
      expect(records.single.updatedAt, updatedAt);
    } finally {
      await LocalStore.closeForTesting();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });
}
