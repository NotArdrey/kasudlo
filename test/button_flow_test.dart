import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kasudlo/src/app.dart';
import 'package:kasudlo/src/models.dart';
import 'package:kasudlo/src/state/app_controller.dart';
import 'package:kasudlo/src/widgets/account_request_fields.dart';

final _reportEditedAtUtc = DateTime.utc(2026, 5, 24, 5, 5);

void main() {
  testWidgets('login buttons validate and sign in', (tester) async {
    final controller = FakeAppController(signedIn: false);
    await _pumpKasudlo(tester, controller);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Use at least 6 characters'), findsOneWidget);

    expect(find.text('Create healthcare nurse account'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Create Account'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), 'nurse@test.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(controller.signInCalls, 1);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('nurse@test.com'), findsOneWidget);
  });

  testWidgets('forgot password sends reset email from login', (tester) async {
    final controller = FakeAppController(signedIn: false);
    await _pumpKasudlo(tester, controller);

    await tester.tap(find.widgetWithText(TextButton, 'Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Reset Link'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'nurse@test.com',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send Reset Link'));
    await tester.pumpAndSettle();

    expect(controller.requestPasswordResetCalls, 1);
    expect(controller.requestedResetEmail, 'nurse@test.com');
    expect(find.textContaining('reset link has been sent'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Back to Sign In'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
  });

  testWidgets('password recovery link lets user set a new password', (
    tester,
  ) async {
    final controller = FakeAppController.passwordRecovery();
    await _pumpKasudlo(tester, controller);

    expect(find.text('Choose a new password'), findsOneWidget);
    expect(find.text('recover@test.com'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'secret1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'secret2',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Update Password'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'secret1',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Update Password'));
    await tester.pumpAndSettle();

    expect(controller.completePasswordResetCalls, 1);
    expect(controller.completedPassword, 'secret1');
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    expect(
      find.text('Password updated. Sign in with your new password.'),
      findsOneWidget,
    );
  });

  testWidgets('admin navigation is hidden for nurses and route redirects', (
    tester,
  ) async {
    final controller = FakeAppController();
    await _pumpKasudlo(tester, controller);

    expect(_navText('Admin'), findsNothing);

    final context = tester.element(find.text('Home').first);
    GoRouter.of(context).go('/admin');
    await tester.pumpAndSettle();

    expect(find.text('Community Overview'), findsOneWidget);
    expect(find.text('Admin console'), findsNothing);
  });

  testWidgets('admin page creates accounts and refreshes the list', (
    tester,
  ) async {
    final controller = FakeAppController.admin();
    await _pumpKasudlo(tester, controller);

    expect(_navText('Admin'), findsOneWidget);
    await tester.tap(_navText('Admin'));
    await tester.pumpAndSettle();
    expect(find.text('Admin console'), findsOneWidget);

    await _selectAccountRole(tester, 'Patient');

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Nurse Ana',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ana@test.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Temporary password'),
      'secret1',
    );
    await _scrollUntilVisible(
      tester,
      find.widgetWithText(ElevatedButton, 'Create Account'),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
    await tester.pumpAndSettle();

    expect(controller.createAdminCalls, 1);
    expect(controller.loadAdminCalls, greaterThanOrEqualTo(1));
    expect(controller.adminUsers.first.role, AccountRole.patient);
    expect(find.text('Nurse Ana'), findsOneWidget);
    expect(find.text('Patient'), findsWidgets);
  });

  testWidgets('admin can view and search audit log without overflow', (
    tester,
  ) async {
    final controller = FakeAppController.adminWithManyAuditLogs();
    await _pumpKasudlo(tester, controller, size: const Size(360, 740));

    await tester.tap(_navText('Admin'));
    await tester.pumpAndSettle();

    await _scrollUntilVisible(tester, find.text('Audit log'));
    expect(find.text('Audit log'), findsOneWidget);
    expect(find.text('Created nurse account.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search audit log'),
      'assessment 12',
    );
    await tester.pumpAndSettle();

    expect(find.text('Synced assessment 12.'), findsOneWidget);
    expect(find.text('Created nurse account.'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Refresh audit log'));
    await tester.pumpAndSettle();
    expect(controller.loadAuditCalls, greaterThanOrEqualTo(1));
  });

  for (final size in const [Size(360, 740), Size(390, 844), Size(768, 1024)]) {
    testWidgets('admin page has no overflow at ${size.width}x${size.height}', (
      tester,
    ) async {
      final controller = FakeAppController.admin();
      await _pumpKasudlo(tester, controller, size: size);

      await tester.tap(_navText('Admin'));
      await tester.pumpAndSettle();
      await _scrollUntilVisible(
        tester,
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Create account'), findsOneWidget);
    });
  }

  testWidgets('home actions and bottom navigation open the expected pages', (
    tester,
  ) async {
    final controller = FakeAppController();
    await _pumpKasudlo(tester, controller);

    await _scrollUntilVisible(tester, find.text('Collect New Data'));
    await tester.tap(find.text('Collect New Data'));
    await tester.pumpAndSettle();
    expect(find.text('Household health assessment'), findsOneWidget);

    await tester.tap(find.byTooltip('Back').hitTestable());
    await tester.pumpAndSettle();
    await _scrollUntilVisible(tester, find.text('View Reports'));
    await tester.tap(find.text('View Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Summarized community health data'), findsOneWidget);

    await tester.tap(_navText('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Account, preferences, and support'), findsOneWidget);

    await tester.tap(_navText('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Community Overview'), findsOneWidget);
  });

  testWidgets('home app bar sync icon retries pending records', (tester) async {
    final controller = FakeAppController.withPending();
    await _pumpKasudlo(tester, controller);

    await _scrollUntilVisible(tester, find.text('Retry Sync'));
    await tester.tap(find.text('Retry Sync'));
    await tester.pumpAndSettle();

    expect(controller.syncCalls, 1);
  });

  testWidgets(
    'health teaching is editable for nurses and view-only for patients',
    (tester) async {
      final workerController = FakeAppController.withHealthTips();
      await _pumpKasudlo(tester, workerController);

      expect(_navText('Teaching'), findsOneWidget);
      await tester.tap(_navText('Teaching'));
      await tester.pumpAndSettle();

      expect(find.text('Health Teaching'), findsWidgets);
      expect(find.text('Dengue prevention'), findsOneWidget);
      expect(find.text('Add Teaching'), findsOneWidget);
      expect(find.byTooltip('Edit health teaching'), findsOneWidget);
      expect(find.byTooltip('Delete health teaching'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit health teaching'));
      await tester.pumpAndSettle();
      expect(find.text('Edit health teaching'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Updated dengue prevention',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(workerController.saveHealthTipCalls, 1);
      expect(find.text('Updated dengue prevention'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete health teaching'));
      await tester.pumpAndSettle();
      expect(find.text('Delete health teaching?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm Delete'));
      await tester.pumpAndSettle();

      expect(workerController.deleteHealthTipCalls, 1);
      expect(find.text('Updated dengue prevention'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final patientController = FakeAppController.withHealthTips(
        role: AccountRole.patient,
      );
      await _pumpKasudlo(tester, patientController);
      await tester.tap(_navText('Teaching'));
      await tester.pumpAndSettle();

      expect(find.text('Dengue prevention'), findsOneWidget);
      expect(find.text('Add Teaching'), findsNothing);
      expect(find.byTooltip('Edit health teaching'), findsNothing);
      expect(find.byTooltip('Delete health teaching'), findsNothing);
    },
  );

  testWidgets('pages fetch and render loaded household records', (
    tester,
  ) async {
    final controller = FakeAppController.withReportData();
    await _pumpKasudlo(tester, controller);

    await _scrollUntilVisible(tester, find.text('Community Overview'));
    expect(find.text('Community Overview'), findsOneWidget);
    expect(find.text('2'), findsWidgets);

    await tester.tap(_navText('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Summarized community health data'), findsOneWidget);
    await _scrollUntilVisible(tester, find.text('Report records'));
    expect(find.text('Ana Cruz'), findsOneWidget);
    expect(find.text('Ben Santos'), findsOneWidget);

    await tester.tap(_navText('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Account, preferences, and support'), findsOneWidget);
  });

  testWidgets(
    'collection auto-creates members, preserves drafts, and guards submit consent',
    (tester) async {
      final controller = FakeAppController();
      await _pumpKasudlo(tester, controller);

      await _scrollUntilVisible(tester, find.text('Collect New Data'));
      await tester.tap(find.text('Collect New Data'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Informant'),
        'Ana Cruz',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Address'),
        'Barangay 1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Family members'),
        '3',
      );
      await _scrollUntilVisible(tester, find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Account email'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Account email'),
        'ana.household@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'secret1',
      );

      expect(find.text('I. Demographic'), findsOneWidget);
      await _scrollUntilVisible(tester, find.text('Member 1'));
      for (var index = 0; index < 3; index++) {
        expect(
          find.byKey(
            ValueKey('family_member_$index.name_of_family_member'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
      }
      expect(
        find.widgetWithText(TextFormField, 'Member no.', skipOffstage: false),
        findsNWidgets(3),
      );
      expect(find.text('Member 1'), findsOneWidget);
      expect(find.text('Member 3'), findsOneWidget);
      await _scrollUntilVisible(
        tester,
        find.byKey(const ValueKey('family_member_0.name_of_family_member')),
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(
            const ValueKey('family_member_0.name_of_family_member'),
          ),
          matching: find.byType(TextFormField),
        ),
        'Ben Cruz',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(
            const ValueKey('family_member_0.relationship_to_head'),
          ),
          matching: find.byType(TextFormField),
        ),
        'Son',
      );

      await _scrollUntilVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Save Draft'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Save Draft'));
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.text('Household health assessment')),
      ).go('/reports');
      await tester.pumpAndSettle();
      expect(find.text('Summarized community health data'), findsOneWidget);
      await tester.tap(_navText('Home'));
      await tester.pumpAndSettle();
      await _scrollUntilVisible(tester, find.text('Collect New Data'));
      await tester.tap(find.text('Collect New Data'));
      await tester.pumpAndSettle();
      expect(find.text('Ben Cruz'), findsOneWidget);

      await _scrollUntilVisible(tester, find.text('II. Socio-economic'));
      await tester.tap(find.text('II. Socio-economic'));
      await tester.pumpAndSettle();
      expect(find.text('1. SOCIAL INDICATORS'), findsOneWidget);

      await _scrollUntilVisible(
        tester,
        find.text('2.1 If practiced, method of disposal'),
      );
      expect(
        find.text('A. REFUSE AND GARBAGE', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('1. Storage', skipOffstage: false), findsOneWidget);
      expect(
        find.text('2. Waste Segregation', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('2.1 If practiced, method of disposal', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('2.2 Reason for practicing', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(
          '2.3 If not practiced, method of disposal',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.text('2.4 Reason for not practicing', skipOffstage: false),
        findsOneWidget,
      );

      await _scrollUntilVisible(
        tester,
        find.byKey(
          const ValueKey(
            'multi.ii_socio_economic_cultural_and_environmental.services_in_community',
          ),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey(
            'multi.ii_socio_economic_cultural_and_environmental.services_in_community',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Religious services').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Health Services').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Done').hitTestable(),
      );
      await tester.pumpAndSettle();

      await _scrollUntilVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Add Income Earner'),
      );
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Add Income Earner'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Income earner'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 - Ben Cruz (Son)').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('income_earner_income_0')),
        '24000',
      );
      await tester.pumpAndSettle();

      await _scrollUntilVisible(tester, find.text('III. Health & Illness'));
      await tester.tap(find.text('III. Health & Illness'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Vaccination status',
        ),
        findsNothing,
      );

      await _scrollUntilVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Save Draft'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Save Draft'));
      await tester.pumpAndSettle();
      expect(controller.saveDraftCalls, greaterThanOrEqualTo(2));
      expect(find.text('Draft saved.'), findsOneWidget);
      expect(
        controller.submissions.first.surveyData[accountCreateRequestedKey],
        isTrue,
      );
      expect(
        controller.submissions.first.surveyData[accountEmailKey],
        'ana.household@test.com',
      );
      expect(controller.submissions.first.familyMembersCount, 3);
      expect(controller.submissions.first.familyMembers, hasLength(3));
      final familyRows =
          controller.submissions.first.surveyData['family_members'] as List;
      expect(familyRows, hasLength(3));
      expect((familyRows.first as Map)['name_of_family_member'], 'Ben Cruz');
      expect(
        familyRows.map((row) => (row as Map)['member_no']),
        orderedEquals([1, 2, 3]),
      );
      expect(controller.submissions.first.surveyData['services_in_community'], [
        'Health Services',
        'Religious services',
      ]);
      expect(controller.submissions.first.surveyData['income_earner_count'], 1);
      final incomeRows =
          controller.submissions.first.surveyData['income_earners'] as List;
      expect(incomeRows, hasLength(1));
      expect((incomeRows.first as Map)['family_member_no'], '1');
      expect((incomeRows.first as Map)['family_member_name'], 'Ben Cruz');
      expect((incomeRows.first as Map)['family_position'], 'Son');
      expect((incomeRows.first as Map)['income_php'], '24000');
      expect(controller.submissions.first.vaccinationStatus, 'Unknown');
      expect(
        controller.submissions.first.surveyData.values,
        isNot(contains('secret1')),
      );

      await _scrollUntilVisible(tester, find.text('I. Demographic'));
      await tester.tap(find.text('I. Demographic'));
      await tester.pumpAndSettle();
      await _scrollUntilVisible(
        tester,
        find.widgetWithText(TextFormField, 'Password'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secret1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'secret1',
      );
      await tester.pumpAndSettle();

      await _scrollUntilVisible(tester, find.text('VI. Concerns'));
      await tester.tap(find.text('VI. Concerns'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await _scrollUntilVisible(
        tester,
        find.widgetWithText(ElevatedButton, 'Submit'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
      await tester.pumpAndSettle();
      expect(controller.submitCalls, 0);
      expect(
        find.text('Consent is required before submitting.'),
        findsOneWidget,
      );

      await _scrollUntilVisible(tester, find.text('Consent was given'));
      await tester.tap(find.text('Consent was given'));
      await tester.pumpAndSettle();
      await _scrollUntilVisible(
        tester,
        find.widgetWithText(ElevatedButton, 'Submit'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
      await tester.pumpAndSettle();
      expect(controller.submitCalls, 1);
      expect(controller.createPatientAccountCalls, 1);
      expect(controller.createdPatientAccountName, 'Ana Cruz');
      expect(controller.createdPatientAccountEmail, 'ana.household@test.com');
      expect(controller.createdPatientAccountPassword, 'secret1');
      expect(find.text('Record queued for sync.'), findsOneWidget);
      expect(controller.guidanceCalls, 1);
      expect(find.text('AI health guidance'), findsOneWidget);
      expect(find.text('Schedule a BP follow-up.'), findsOneWidget);
      expect(controller.submissions.first.aiGuidance?.riskLevel, 'moderate');
    },
  );

  testWidgets('reports records can be viewed, edited, and archived', (
    tester,
  ) async {
    final controller = FakeAppController.withReportData();
    final expectedEditHistoryTime = _testReportDateTime(_reportEditedAtUtc);
    await _pumpKasudlo(tester, controller);

    await tester.tap(_navText('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Report records'), findsOneWidget);
    expect(find.text('Ana Cruz'), findsOneWidget);

    await tester.tap(find.byTooltip('View report record').first);
    await tester.pumpAndSettle();
    expect(find.text('View report record'), findsOneWidget);
    expect(find.text('I. Demographic Variable'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Not stored'), findsNothing);
    expect(
      find.text('II. Socio-economic, Cultural and Environmental'),
      findsOneWidget,
    );
    expect(find.text('IV. Health Resource'), findsOneWidget);
    expect(find.text('V. Political/Leadership Patterns'), findsOneWidget);
    expect(find.text('AI health guidance'), findsOneWidget);
    expect(find.text('Schedule a BP follow-up.'), findsOneWidget);
    expect(find.text('No rows added yet.'), findsWidgets);
    expect(find.text('May 23, 2026 12:00 AM'), findsOneWidget);
    expect(find.text('No edits recorded yet.'), findsOneWidget);

    await tester.tap(find.byTooltip('Close').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit report record').first);
    await tester.pumpAndSettle();
    expect(find.text('Edit report record'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Informant'),
      'Ana Edited',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Family members'),
      '6',
    );
    await tester.tap(find.byTooltip('Save report record'));
    await tester.pumpAndSettle();
    expect(find.text('Save report changes?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(controller.updateReportCalls, 1);
    expect(find.text('Ana Edited'), findsOneWidget);
    expect(controller.submissions.first.familyMembersCount, 6);

    await tester.tap(find.byTooltip('View report record').first);
    await tester.pumpAndSettle();
    expect(find.text('Edit history'), findsOneWidget);
    expect(find.text(expectedEditHistoryTime), findsOneWidget);
    expect(find.text('2 fields updated.'), findsOneWidget);
    expect(
      find.textContaining('Informant changed from Ana Cruz'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Close').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit report record').first);
    await tester.pumpAndSettle();
    expect(find.text(expectedEditHistoryTime), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Edit history entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit history entry'));
    await tester.pumpAndSettle();
    expect(find.text('Edit history entry'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Summary'),
      'Corrected history summary.',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Edited by'),
      'auditor@test.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save entry'));
    await tester.pumpAndSettle();
    expect(find.text('Corrected history summary.'), findsOneWidget);
    await _tapReportSheetSave(tester);
    expect(
      find.text('Save edit history changes for Ana Edited?'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();
    expect(controller.updateReportCalls, 2);

    await tester.tap(find.byTooltip('View report record').first);
    await tester.pumpAndSettle();
    expect(find.text('Corrected history summary.'), findsOneWidget);
    expect(find.text('Edited by auditor@test.com'), findsOneWidget);
    expect(find.text('2 fields updated.'), findsNothing);
    await tester.tap(find.byTooltip('Close').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit report record').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Delete history entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete history entry'));
    await tester.pumpAndSettle();
    expect(find.text('Delete history entry?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No edits recorded yet.'), findsOneWidget);
    await _tapReportSheetSave(tester);
    expect(
      find.text('Save edit history changes for Ana Edited?'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();
    expect(controller.updateReportCalls, 3);

    await tester.tap(find.byTooltip('View report record').first);
    await tester.pumpAndSettle();
    expect(find.text('No edits recorded yet.'), findsOneWidget);
    await tester.tap(find.byTooltip('Close').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.ensureVisible(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Archive report record').first);
    await tester.pumpAndSettle();
    expect(find.text('Archive report record?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(controller.deleteCalls, 1);
    expect(find.text('Ana Edited'), findsNothing);
    expect(find.text('Ben Santos'), findsOneWidget);
  });

  testWidgets('reports search filters many records without overflow', (
    tester,
  ) async {
    final controller = FakeAppController.withManyReportData();
    await _pumpKasudlo(tester, controller, size: const Size(360, 740));

    await tester.tap(_navText('Reports'));
    await tester.pumpAndSettle();

    expect(find.text('Report records'), findsOneWidget);
    expect(find.text('40 records'), findsOneWidget);
    expect(find.text('Household 1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search report records'),
      'Household 39',
    );
    await tester.pumpAndSettle();

    expect(find.text('1 of 40'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Household 39'),
      ),
      findsOneWidget,
    );
    expect(find.text('Household 1'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search report records'),
      'not a real household',
    );
    await tester.pumpAndSettle();

    expect(find.text('0 of 40'), findsOneWidget);
    expect(find.text('No report records match this search.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Clear report search'));
    await tester.pumpAndSettle();

    expect(find.text('40 records'), findsOneWidget);
    expect(find.text('Household 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings buttons sign out', (tester) async {
    final controller = FakeAppController.withPending();
    await _pumpKasudlo(tester, controller);

    await tester.tap(_navText('Settings'));
    await tester.pumpAndSettle();

    await _scrollUntilVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'Sign Out'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign Out'));
    await tester.pumpAndSettle();
    expect(controller.signOutCalls, 1);
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
  });
}

Future<void> _pumpKasudlo(
  WidgetTester tester,
  FakeAppController controller, {
  Size size = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_appWith(controller));
  await tester.pumpAndSettle();
}

Widget _appWith(FakeAppController controller) {
  return ProviderScope(
    overrides: [appControllerProvider.overrideWith((ref) => controller)],
    child: const KasudloApp(),
  );
}

Finder _navText(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  if (finder.hitTestable().evaluate().isNotEmpty) {
    return;
  }

  final page = find.byType(CustomScrollView).hitTestable().first;
  for (final offset in const [Offset(0, -420), Offset(0, 420)]) {
    for (var i = 0; i < 12; i++) {
      if (finder.hitTestable().evaluate().isNotEmpty) {
        return;
      }
      await tester.drag(page, offset);
      await tester.pumpAndSettle();
    }
  }

  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapReportSheetSave(WidgetTester tester) async {
  final saveButton = find.byTooltip('Save report record');
  for (var attempt = 0; attempt < 8; attempt++) {
    final visibleSaveButton = saveButton.hitTestable();
    if (visibleSaveButton.evaluate().isNotEmpty) {
      await tester.tap(visibleSaveButton.first);
      await tester.pumpAndSettle();
      return;
    }

    final scrollView = find.byType(SingleChildScrollView).hitTestable();
    if (scrollView.evaluate().isEmpty) {
      break;
    }
    await tester.drag(scrollView.last, const Offset(0, 520));
    await tester.pumpAndSettle();
  }

  await tester.ensureVisible(saveButton);
  await tester.pumpAndSettle();
  await tester.tap(saveButton.hitTestable().first);
  await tester.pumpAndSettle();
}

Future<void> _selectAccountRole(WidgetTester tester, String label) async {
  final segmentedOption = find.descendant(
    of: find.byType(SegmentedButton<AccountRole>),
    matching: find.text(label),
  );
  if (segmentedOption.evaluate().isNotEmpty) {
    await tester.tap(segmentedOption);
    await tester.pumpAndSettle();
    return;
  }

  await tester.tap(find.byType(DropdownButtonFormField<AccountRole>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

class FakeAppController extends AppController {
  FakeAppController({bool signedIn = true}) {
    isReady = true;
    isSignedIn = signedIn;
    activeEmail = signedIn ? 'nurse@test.com' : null;
    activeRole = AccountRole.nurse;
    submissions = const [];
  }

  FakeAppController.passwordRecovery() {
    isReady = true;
    isSignedIn = false;
    isPasswordRecoverySession = true;
    activeEmail = 'recover@test.com';
    activeRole = AccountRole.nurse;
    passwordResetMessage = 'Choose a new password for this account.';
    submissions = const [];
  }

  FakeAppController.admin() {
    isReady = true;
    isSignedIn = true;
    activeEmail = 'admin@test.com';
    activeRole = AccountRole.admin;
    adminUsers = [
      AdminUser(
        id: 'admin-user',
        email: 'admin@test.com',
        fullName: 'Admin User',
        role: AccountRole.admin,
        createdAt: DateTime(2026, 5, 23),
      ),
      AdminUser(
        id: 'nurse-user',
        email: 'nurse@test.com',
        fullName: 'Nurse User',
        role: AccountRole.nurse,
        createdAt: DateTime(2026, 5, 23),
      ),
    ];
    auditLogs = [
      AuditLogEntry(
        id: 'audit-create-account',
        actorEmail: 'admin@test.com',
        actorRole: AccountRole.admin.name,
        action: 'admin.account.create',
        entityType: 'account',
        entityId: 'nurse-user',
        summary: 'Created nurse account.',
        createdAt: DateTime(2026, 5, 24, 9),
      ),
      AuditLogEntry(
        id: 'audit-sync-record',
        actorEmail: 'nurse@test.com',
        actorRole: AccountRole.nurse.name,
        action: 'sync.record.success',
        entityType: 'household_assessment',
        entityId: 'synced',
        summary: 'Synced assessment 1.',
        createdAt: DateTime(2026, 5, 24, 8),
      ),
    ];
    submissions = const [];
  }

  FakeAppController.adminWithManyAuditLogs() {
    isReady = true;
    isSignedIn = true;
    activeEmail = 'admin@test.com';
    activeRole = AccountRole.admin;
    adminUsers = [
      AdminUser(
        id: 'admin-user',
        email: 'admin@test.com',
        fullName: 'Admin User',
        role: AccountRole.admin,
        createdAt: DateTime(2026, 5, 23),
      ),
    ];
    auditLogs = [
      AuditLogEntry(
        id: 'audit-create-account',
        actorEmail: 'admin@test.com',
        actorRole: AccountRole.admin.name,
        action: 'admin.account.create',
        entityType: 'account',
        entityId: 'nurse-user',
        summary: 'Created nurse account.',
        createdAt: DateTime(2026, 5, 24, 9),
      ),
      for (var index = 1; index <= 24; index++)
        AuditLogEntry(
          id: 'audit-sync-$index',
          actorEmail: 'nurse@test.com',
          actorRole: AccountRole.nurse.name,
          action: 'sync.record.success',
          entityType: 'household_assessment',
          entityId: 'record-$index',
          summary: 'Synced assessment $index.',
          createdAt: DateTime(2026, 5, 24, 8, index),
        ),
    ];
    submissions = const [];
  }

  FakeAppController.withPending() {
    isReady = true;
    isSignedIn = true;
    activeEmail = 'nurse@test.com';
    activeRole = AccountRole.nurse;
    submissions = [_submission('pending', SyncStatus.pending)];
  }

  FakeAppController.withHealthTips({AccountRole role = AccountRole.nurse}) {
    isReady = true;
    isSignedIn = true;
    activeEmail = role == AccountRole.patient
        ? 'patient@test.com'
        : 'nurse@test.com';
    activeRole = role;
    submissions = const [];
    healthTips = [
      HealthTip(
        id: 'tip-one',
        title: 'Dengue prevention',
        description: 'Remove standing water and cover water containers.',
        attachments: const [],
        createdAt: DateTime(2026, 5, 24, 9),
        updatedAt: DateTime(2026, 5, 24, 10),
        createdByEmail: 'nurse@test.com',
      ),
    ];
  }

  FakeAppController.withReportData() {
    isReady = true;
    isSignedIn = true;
    activeEmail = 'nurse@test.com';
    activeRole = AccountRole.nurse;
    submissions = [
      _submission(
        'synced',
        SyncStatus.synced,
        respondentName: 'Ana Cruz',
        familyMembersCount: 4,
        healthProblems: const ['Hypertension', 'Cough or fever'],
        vaccinationStatus: 'Complete',
        waterSanitation: 'Safe water and sanitary toilet',
        nutritionalStatus: 'Normal',
        communityConcerns: const ['Dengue risk'],
        aiGuidance: _sampleAiGuidance(),
      ),
      _submission(
        'pending',
        SyncStatus.pending,
        respondentName: 'Ben Santos',
        familyMembersCount: 3,
        healthProblems: const ['Hypertension'],
        vaccinationStatus: 'Incomplete',
        waterSanitation: 'Unsafe water source',
        nutritionalStatus: 'At risk',
        communityConcerns: const ['Dengue risk', 'Unsafe water'],
      ),
    ];
  }

  FakeAppController.withManyReportData() {
    isReady = true;
    isSignedIn = true;
    activeEmail = 'nurse@test.com';
    activeRole = AccountRole.nurse;
    submissions = List.generate(40, (index) {
      final recordNumber = index + 1;
      return _submission(
        'many-$recordNumber',
        index.isEven ? SyncStatus.synced : SyncStatus.pending,
        respondentName: 'Household $recordNumber',
        familyMembersCount: (index % 6) + 1,
        healthProblems: index.isEven
            ? const ['Hypertension']
            : const ['Cough or fever'],
        vaccinationStatus: index.isEven ? 'Complete' : 'Incomplete',
        waterSanitation: index.isEven
            ? 'Safe water and sanitary toilet'
            : 'Unsafe water source',
        nutritionalStatus: index.isEven ? 'Normal' : 'At risk',
        communityConcerns: index.isEven
            ? const ['Dengue risk']
            : const ['Unsafe water'],
      );
    });
  }

  int signInCalls = 0;
  int requestPasswordResetCalls = 0;
  int completePasswordResetCalls = 0;
  int loadAdminCalls = 0;
  int loadAuditCalls = 0;
  int createAdminCalls = 0;
  int signOutCalls = 0;
  int saveDraftCalls = 0;
  int submitCalls = 0;
  int updateReportCalls = 0;
  int deleteCalls = 0;
  int saveHealthTipCalls = 0;
  int deleteHealthTipCalls = 0;
  int syncCalls = 0;
  int guidanceCalls = 0;
  int createPatientAccountCalls = 0;
  int preferenceUpdateCalls = 0;
  String? requestedResetEmail;
  String? completedPassword;
  String? createdPatientAccountName;
  String? createdPatientAccountEmail;
  String? createdPatientAccountPassword;

  @override
  bool get isSupabaseConfigured => false;

  @override
  Future<void> bootstrap() async {}

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    activeEmail = email;
    final roleHint = email.toLowerCase();
    activeRole = roleHint.startsWith('admin')
        ? AccountRole.admin
        : roleHint.startsWith('patient')
        ? AccountRole.patient
        : AccountRole.nurse;
    isSignedIn = true;
    notifyListeners();
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    requestPasswordResetCalls++;
    requestedResetEmail = email;
    passwordResetMessage =
        'If an account exists for $email, a reset link has been sent.';
    notifyListeners();
  }

  @override
  Future<void> completePasswordReset(String password) async {
    completePasswordResetCalls++;
    completedPassword = password;
    isPasswordRecoverySession = false;
    isSignedIn = false;
    passwordResetMessage = 'Password updated. Sign in with your new password.';
    notifyListeners();
  }

  @override
  Future<void> loadAdminUsers({String search = ''}) async {
    loadAdminCalls++;
    notifyListeners();
  }

  @override
  Future<void> loadAuditLogs({String search = ''}) async {
    loadAuditCalls++;
    notifyListeners();
  }

  @override
  Future<bool> createAdminAccount({
    required String fullName,
    required String email,
    required String password,
    required AccountRole role,
  }) async {
    createAdminCalls++;
    adminUsers = [
      AdminUser(
        id: 'created-$createAdminCalls',
        email: email,
        fullName: fullName,
        role: role,
        createdAt: DateTime(2026, 5, 24),
      ),
      ...adminUsers,
    ];
    notifyListeners();
    return true;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    activeEmail = null;
    activeRole = AccountRole.nurse;
    isSignedIn = false;
    isPasswordRecoverySession = false;
    notifyListeners();
  }

  @override
  Future<void> updatePreferences(AppPreferences nextPreferences) async {
    preferenceUpdateCalls++;
    preferences = nextPreferences;
    notifyListeners();
  }

  @override
  Future<void> saveDraft(HealthSubmission submission) async {
    saveDraftCalls++;
    submissions = [
      submission.copyWith(syncStatus: SyncStatus.draft),
      ...submissions,
    ];
    notifyListeners();
  }

  @override
  Future<void> submit(HealthSubmission submission) async {
    submitCalls++;
    submissions = [
      submission.copyWith(syncStatus: SyncStatus.pending),
      ...submissions,
    ];
    notifyListeners();
  }

  @override
  Future<bool> createPatientAccountForSubmission({
    required HealthSubmission submission,
    required String email,
    required String password,
  }) async {
    createPatientAccountCalls++;
    createdPatientAccountName = submission.respondentName;
    createdPatientAccountEmail = email;
    createdPatientAccountPassword = password;
    return true;
  }

  @override
  Future<AiHealthGuidance?> analyzeAndSaveSubmissionGuidance(
    HealthSubmission submission,
  ) async {
    guidanceCalls++;
    final guidance = _sampleAiGuidance();
    submissions = [
      for (final existing in submissions)
        existing.clientSubmissionId == submission.clientSubmissionId
            ? existing.copyWith(aiGuidance: guidance)
            : existing,
    ];
    notifyListeners();
    return guidance;
  }

  @override
  Future<void> updateReportSubmission(HealthSubmission submission) async {
    updateReportCalls++;
    final previous = submissions.firstWhere(
      (existing) =>
          existing.clientSubmissionId == submission.clientSubmissionId,
      orElse: () => submission,
    );
    final contentChanges = reportEditChanges(
      previous: previous,
      next: submission,
    );
    final historyChanged = !reportEditHistoryEquals(
      previous.editHistory,
      submission.editHistory,
    );
    final shouldRecordHistory = contentChanges.isNotEmpty || !historyChanged;
    final withHistory = shouldRecordHistory
        ? submission.withEditHistory(
            previous: previous,
            editedAt: _reportEditedAtUtc,
            editedBy: activeEmail,
          )
        : submission;
    submissions = [
      for (final existing in submissions)
        if (existing.clientSubmissionId == submission.clientSubmissionId)
          withHistory
        else
          existing,
    ];
    notifyListeners();
  }

  @override
  Future<void> deleteLocalSubmission(String clientSubmissionId) async {
    deleteCalls++;
    submissions = submissions
        .where(
          (submission) => submission.clientSubmissionId != clientSubmissionId,
        )
        .toList();
    notifyListeners();
  }

  @override
  Future<void> loadHealthTips() async {
    notifyListeners();
  }

  @override
  Future<bool> saveHealthTip({
    String? id,
    required String title,
    required String description,
    required List<HealthTipAttachment> attachments,
  }) async {
    saveHealthTipCalls++;
    HealthTip? existing;
    for (final tip in healthTips) {
      if (tip.id == id) {
        existing = tip;
        break;
      }
    }
    final saved = HealthTip(
      id: id ?? 'created-health-tip-$saveHealthTipCalls',
      title: title.trim(),
      description: description.trim(),
      attachments: attachments,
      createdAt: existing?.createdAt ?? DateTime(2026, 5, 24, 9),
      updatedAt: DateTime(2026, 5, 24, 11, saveHealthTipCalls),
      createdByEmail: existing?.createdByEmail ?? activeEmail ?? '',
    );
    healthTips = [
      saved,
      for (final tip in healthTips)
        if (tip.id != saved.id) tip,
    ];
    notifyListeners();
    return true;
  }

  @override
  Future<bool> deleteHealthTip(String id) async {
    deleteHealthTipCalls++;
    healthTips = healthTips.where((tip) => tip.id != id).toList();
    notifyListeners();
    return true;
  }

  @override
  Future<void> syncPending() async {
    syncCalls++;
  }
}

HealthSubmission _submission(
  String id,
  SyncStatus status, {
  String respondentName = 'Ana Cruz',
  int familyMembersCount = 2,
  List<String> healthProblems = const ['Cough or fever'],
  String vaccinationStatus = 'Complete',
  String waterSanitation = 'Safe water and sanitary toilet',
  String nutritionalStatus = 'Normal',
  List<String> communityConcerns = const ['Dengue risk'],
  AiHealthGuidance? aiGuidance,
}) {
  return HealthSubmission(
    clientSubmissionId: id,
    respondentName: respondentName,
    respondentAge: 30,
    address: 'Barangay 1',
    familyMembersCount: familyMembersCount,
    familyMembers: const [],
    healthProblems: healthProblems,
    vaccinationStatus: vaccinationStatus,
    waterSanitation: waterSanitation,
    nutritionalStatus: nutritionalStatus,
    communityConcerns: communityConcerns,
    consentGiven: true,
    notes: '',
    createdAt: DateTime(2026, 5, 23),
    syncStatus: status,
    aiGuidance: aiGuidance,
  );
}

AiHealthGuidance _sampleAiGuidance() {
  return const AiHealthGuidance(
    riskLevel: 'moderate',
    summary: 'Schedule a BP follow-up.',
    concerningFindings: ['Hypertension risk'],
    recommendedActions: ['Recheck blood pressure within one week'],
    followUpQuestions: ['Any dizziness or chest pain?'],
    careSuggestions: [],
    emergencyWarning: '',
    disclaimer: 'AI guidance supports field triage.',
  );
}

String _testReportDateTime(DateTime value) {
  return DateFormat('MMM d, yyyy h:mm a').format(value.toLocal());
}
