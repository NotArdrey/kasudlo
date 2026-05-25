import 'package:flutter_test/flutter_test.dart';
import 'package:kasudlo/src/models.dart';
import 'package:kasudlo/src/state/app_controller.dart';

void main() {
  test('AppController shows friendly auth errors', () {
    final controller = AppController();

    expect(
      controller.debugFriendlyErrorMessage(
        'AuthApiException(message: Invalid login credentials, statusCode: 400, code: invalid_credentials)',
      ),
      'Email or password is incorrect. Check the account created by your admin.',
    );
  });

  test('HealthSubmission maps remote database rows as synced records', () {
    final submission = HealthSubmission.fromRemoteJson({
      'client_submission_id': 'remote-one',
      'respondent_name': 'Remote Household',
      'respondent_age': 41,
      'address': 'Barangay Remote',
      'family_members_count': 3,
      'family_members': const [],
      'health_problems': const ['Asthma'],
      'vaccination_status': 'Complete',
      'water_sanitation': 'Safe water and sanitary toilet',
      'nutritional_status': 'Normal',
      'community_concerns': const ['Dengue risk'],
      'consent_given': true,
      'notes': 'Imported from Supabase.',
      'edit_history': const [
        {
          'edited_at': '2026-05-24T05:15:00Z',
          'edited_by': 'worker@test.com',
          'summary': '1 field updated.',
          'changes': ['Name changed from Old to Remote Household.'],
        },
      ],
      'submitted_at': '2026-05-24T04:00:00Z',
    });

    expect(submission.clientSubmissionId, 'remote-one');
    expect(submission.respondentName, 'Remote Household');
    expect(submission.syncStatus, SyncStatus.synced);
    expect(submission.createdAt, DateTime.parse('2026-05-24T04:00:00Z'));
    expect(submission.editHistory, hasLength(1));
    expect(submission.editHistory.first.summary, '1 field updated.');
    expect(
      submission.editHistory.first.editedAt,
      DateTime.parse('2026-05-24T05:15:00Z'),
    );
  });

  test('HealthSubmission RPC payload uses survey family member keys', () {
    final submission = HealthSubmission(
      clientSubmissionId: 'family-key-check',
      respondentName: 'Ana',
      respondentAge: 34,
      address: 'Barangay 1',
      familyMembersCount: 1,
      familyMembers: const [
        FamilyMember(
          name: 'Ben Cruz',
          age: 12,
          relationship: 'Son',
          healthProblems: [],
          vaccinationStatus: '',
          nutritionalStatus: '',
        ),
      ],
      healthProblems: const [],
      vaccinationStatus: 'Unknown',
      waterSanitation: 'Safe water and sanitary toilet',
      nutritionalStatus: 'Normal',
      communityConcerns: const [],
      consentGiven: true,
      notes: '',
      createdAt: DateTime(2026, 5, 24),
      syncStatus: SyncStatus.pending,
    );

    final familyMembers = submission.toRpcPayload()['family_members'] as List;
    final member = familyMembers.single as Map<String, dynamic>;

    expect(member, containsPair('name_of_family_member', 'Ben Cruz'));
    expect(member, containsPair('relationship_to_head', 'Son'));
    expect(member, isNot(contains('name')));
    expect(member, isNot(contains('relationship')));
  });

  test('AppPreferences round trips saved settings', () {
    final preferences = const AppPreferences().copyWith(
      fieldRemindersEnabled: false,
      soundsEnabled: true,
      dataSaverEnabled: true,
      language: 'Cebuano',
    );

    final restored = AppPreferences.fromJson(preferences.toJson());

    expect(restored.fieldRemindersEnabled, isFalse);
    expect(restored.syncNotificationsEnabled, isTrue);
    expect(restored.soundsEnabled, isTrue);
    expect(restored.offlineModeEnabled, isTrue);
    expect(restored.dataSaverEnabled, isTrue);
    expect(restored.language, 'Cebuano');
  });

  test('AccountRole parses patient accounts', () {
    expect(accountRoleFromString('patient'), AccountRole.patient);
    expect(AccountRole.patient.label, 'Patient');
  });

  test('AI health guidance parses structured Groq results', () {
    final guidance = AiHealthGuidance.fromJson({
      'risk_level': 'high',
      'summary': 'Hypertension and sanitation concerns need follow-up.',
      'concerning_findings': ['High blood pressure risk'],
      'recommended_actions': ['Refer for BP check within 24 hours'],
      'follow_up_questions': ['Any chest pain or severe headache?'],
      'care_suggestions': [
        {
          'name': 'Nearest municipal hospital',
          'type': 'Hospital or emergency department',
          'reason': 'Can assess urgent blood pressure symptoms.',
          'location_hint': 'Verify the closest open facility locally.',
        },
      ],
      'emergency_warning': 'Seek emergency care for chest pain.',
      'disclaimer': 'AI guidance does not replace clinical judgment.',
    });

    expect(guidance.riskLevel, 'high');
    expect(guidance.recommendedActions.single, contains('BP check'));
    expect(guidance.careSuggestions.single.type, contains('Hospital'));
  });

  test('HealthSubmission records and restores edit history entries', () {
    final original = HealthSubmission(
      clientSubmissionId: 'one',
      respondentName: 'Ana',
      respondentAge: 34,
      address: 'Barangay 1',
      familyMembersCount: 4,
      familyMembers: const [],
      healthProblems: const ['Hypertension'],
      vaccinationStatus: 'Complete',
      waterSanitation: 'Safe water and sanitary toilet',
      nutritionalStatus: 'Normal',
      communityConcerns: const ['Dengue risk'],
      consentGiven: true,
      notes: '',
      createdAt: DateTime(2026, 5, 23),
      syncStatus: SyncStatus.synced,
    );
    final edited = original
        .copyWith(respondentName: 'Ana Edited', familyMembersCount: 6)
        .withEditHistory(
          previous: original,
          editedAt: DateTime(2026, 5, 24, 13, 5),
          editedBy: 'worker@test.com',
        );

    expect(edited.editHistory, hasLength(1));
    expect(edited.editHistory.first.summary, '2 fields updated.');
    expect(
      edited.editHistory.first.changes,
      contains('Informant changed from Ana to Ana Edited.'),
    );

    final restored = HealthSubmission.fromJson(edited.toJson());

    expect(restored.editHistory, hasLength(1));
    expect(restored.editHistory.first.editedBy, 'worker@test.com');
    expect(restored.editHistory.first.editedAt, DateTime(2026, 5, 24, 13, 5));
  });

  test('ReportSummary aggregates household health fields', () {
    final submissions = [
      HealthSubmission(
        clientSubmissionId: 'one',
        respondentName: 'Ana',
        respondentAge: 34,
        address: 'Barangay 1',
        familyMembersCount: 4,
        familyMembers: const [],
        healthProblems: const ['Hypertension', 'Cough or fever'],
        vaccinationStatus: 'Complete',
        waterSanitation: 'Safe water and sanitary toilet',
        nutritionalStatus: 'Normal',
        communityConcerns: const ['Dengue risk'],
        consentGiven: true,
        notes: '',
        createdAt: DateTime(2026, 5, 23),
        syncStatus: SyncStatus.synced,
      ),
      HealthSubmission(
        clientSubmissionId: 'two',
        respondentName: 'Ben',
        respondentAge: 41,
        address: 'Barangay 2',
        familyMembersCount: 3,
        familyMembers: const [],
        healthProblems: const ['Hypertension'],
        vaccinationStatus: 'Incomplete',
        waterSanitation: 'Unsafe water source',
        nutritionalStatus: 'At risk',
        communityConcerns: const ['Dengue risk', 'Unsafe water'],
        consentGiven: true,
        notes: '',
        createdAt: DateTime(2026, 5, 23),
        syncStatus: SyncStatus.pending,
      ),
    ];

    final summary = ReportSummary.fromSubmissions(submissions);

    expect(summary.totalHouseholds, 2);
    expect(summary.totalFamilyMembers, 7);
    expect(summary.syncedRecords, 1);
    expect(summary.pendingDrafts, 1);
    expect(summary.healthProblems['Hypertension'], 2);
    expect(summary.communityConcerns['Dengue risk'], 2);
    expect(summary.vaccinationStatuses['Complete'], 1);
    expect(summary.waterSanitationStatuses['Unsafe water source'], 1);
  });

  test('offline pending submissions survive remote refresh until synced', () {
    final controller = AppController();
    final local = _submission(
      id: 'same-record',
      respondentName: 'Offline Edit',
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime.utc(2026, 5, 24, 10),
      remoteUpdatedAt: DateTime.utc(2026, 5, 24, 8),
    );
    final remote = _submission(
      id: 'same-record',
      respondentName: 'Remote Old',
      syncStatus: SyncStatus.synced,
      updatedAt: DateTime.utc(2026, 5, 24, 8),
      remoteUpdatedAt: DateTime.utc(2026, 5, 24, 8),
    );
    controller.submissions = [local];

    final merged = controller.debugMergeRemoteSubmissions([remote]).toList();

    expect(merged, hasLength(1));
    expect(merged.single.respondentName, 'Offline Edit');
    expect(merged.single.syncStatus, SyncStatus.pending);
  });

  test('newer remote changes hold offline edits as conflicts', () {
    final controller = AppController();
    final local = _submission(
      id: 'same-record',
      respondentName: 'Offline Edit',
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime.utc(2026, 5, 24, 9),
      remoteUpdatedAt: DateTime.utc(2026, 5, 24, 8),
    );
    final remote = _submission(
      id: 'same-record',
      respondentName: 'Remote New',
      syncStatus: SyncStatus.synced,
      updatedAt: DateTime.utc(2026, 5, 24, 10),
      remoteUpdatedAt: DateTime.utc(2026, 5, 24, 10),
    );
    controller.submissions = [local];

    final merged = controller.debugMergeRemoteSubmissions([remote]).toList();

    expect(merged.single.respondentName, 'Offline Edit');
    expect(merged.single.syncStatus, SyncStatus.conflict);
    expect(merged.single.lastError, contains('Supabase has a newer version'));
  });
}

HealthSubmission _submission({
  required String id,
  required String respondentName,
  required SyncStatus syncStatus,
  required DateTime updatedAt,
  DateTime? remoteUpdatedAt,
}) {
  return HealthSubmission(
    clientSubmissionId: id,
    respondentName: respondentName,
    respondentAge: 34,
    address: 'Barangay 1',
    familyMembersCount: 4,
    familyMembers: const [],
    healthProblems: const ['Hypertension'],
    vaccinationStatus: 'Complete',
    waterSanitation: 'Safe water and sanitary toilet',
    nutritionalStatus: 'Normal',
    communityConcerns: const ['Dengue risk'],
    consentGiven: true,
    notes: '',
    createdAt: DateTime.utc(2026, 5, 23),
    syncStatus: syncStatus,
    updatedAt: updatedAt,
    remoteUpdatedAt: remoteUpdatedAt,
  );
}
