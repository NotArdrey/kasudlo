import 'dart:convert';
import 'dart:io';

import 'package:kasudlo/src/models.dart';
import 'package:kasudlo/src/services/report_exporter.dart';

// Copying _sampleSurveyData from test/report_exporter_test.dart
Map<String, dynamic> _sampleSurveyData() {
  return {
    'control_no': 'CTRL-001',
    'number_of_family': 4,
    'address': 'Barangay 1',
    'first_visit_date': '2026-05-20',
    'status_of_last_visit': 'Completed',
    'family_members': [
      {
        'member_no': 1,
        'name_of_family_member': 'Ana Cruz',
        'relationship_to_head': 'Head',
        'gender': 'Female',
        'age': 30,
      },
      {
        'member_no': 2,
        'name_of_family_member': 'Nico Cruz',
        'relationship_to_head': 'Child',
        'gender': 'Male',
        'age': 8,
      }
    ],
  };
}

void main() async {
  final submission = HealthSubmission(
    clientSubmissionId: 'one',
    respondentName: 'Ana Cruz',
    respondentAge: 30,
    address: 'Barangay 1',
    familyMembersCount: 4,
    familyMembers: [],
    healthProblems: [],
    vaccinationStatus: 'Complete',
    waterSanitation: 'Safe',
    nutritionalStatus: 'Normal',
    communityConcerns: [],
    consentGiven: true,
    notes: 'Test note',
    createdAt: DateTime.now(),
    syncStatus: SyncStatus.synced,
    surveyData: _sampleSurveyData(),
  );

  final result = await exportReportRecords(
    submissions: [submission],
    format: ReportExportFormat.templateDocs,
  );

  print('Exported to: \${result.savedLocation}');
}
