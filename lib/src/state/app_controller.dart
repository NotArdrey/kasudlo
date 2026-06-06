import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../services/groq_gateway.dart';
import '../services/local_store.dart';
import '../services/supabase_gateway.dart';

final appControllerProvider = ChangeNotifierProvider<AppController>((ref) {
  final controller = AppController();
  controller.bootstrap();
  return controller;
});

class AppController extends ChangeNotifier {
  final _uuid = const Uuid();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<String?>? _passwordRecoverySubscription;
  bool _isSyncInProgress = false;

  String _hashCredential(String email, String password) {
    final bytes = utf8.encode('${email.trim().toLowerCase()}|$password');
    return sha256.convert(bytes).toString();
  }

  bool isReady = false;
  bool isBusy = false;
  bool isSignedIn = false;
  bool isPasswordRecoverySession = false;
  bool isAdminLoading = false;
  bool isAdminActionBusy = false;
  bool isAuditLoading = false;
  bool isAiLoading = false;
  bool isHealthTipsLoading = false;
  bool isHealthTipActionBusy = false;
  String? activeEmail;
  String? activeFullName;
  AccountRole activeRole = AccountRole.nurse;
  String? errorMessage;
  String? adminErrorMessage;
  String? auditErrorMessage;
  String? aiErrorMessage;
  String? healthTipsErrorMessage;
  AppPreferences preferences = const AppPreferences();
  List<HealthSubmission> submissions = const [];
  List<HealthTip> healthTips = const [];
  List<AdminUser> adminUsers = const [];
  List<AuditLogEntry> auditLogs = const [];
  List<HealthSubmission> patientFindings = const [];
  bool isPatientFindingsLoading = false;
  String? passwordResetMessage;

  bool get isSupabaseConfigured => SupabaseGateway.isConfigured;
  bool get isAdmin => activeRole == AccountRole.admin;
  bool get isPatient => activeRole == AccountRole.patient;
  bool get canManageHealthTips => activeRole != AccountRole.patient;
  int get conflictCount => submissions
      .where((submission) => submission.syncStatus == SyncStatus.conflict)
      .length;
  int get retryableSyncCount => submissions
      .where((submission) => _isRetryableSyncStatus(submission.syncStatus))
      .length;
  int get pendingCount => submissions
      .where(
        (submission) =>
            submission.syncStatus == SyncStatus.pending ||
            submission.syncStatus == SyncStatus.failed ||
            submission.syncStatus == SyncStatus.syncing ||
            submission.syncStatus == SyncStatus.conflict ||
            submission.syncStatus == SyncStatus.pendingDelete,
      )
      .length;

  List<HealthSubmission> get activeSubmissions =>
      submissions.where((s) => !s.isDeleted).toList();
  List<HealthSubmission> get draftSubmissions =>
      submissions
          .where(
            (submission) =>
                !submission.isDeleted &&
                submission.syncStatus == SyncStatus.draft,
          )
          .toList()
        ..sort((a, b) => b.effectiveUpdatedAt.compareTo(a.effectiveUpdatedAt));
  List<HealthSubmission> get archivedSubmissions =>
      submissions.where((submission) => submission.isDeleted).toList()..sort(
        (a, b) => (b.deletedAt ?? b.effectiveUpdatedAt).compareTo(
          a.deletedAt ?? a.effectiveUpdatedAt,
        ),
      );

  ReportSummary get summary => ReportSummary.fromSubmissions(activeSubmissions);

  Future<void> bootstrap() async {
    _startPasswordRecoveryWatcher();
    preferences = LocalStore.loadPreferences();
    submissions = LocalStore.loadSubmissions();
    healthTips = LocalStore.loadHealthTips();
    if (!isSupabaseConfigured) {
      if (submissions.isEmpty && !LocalStore.hasSeededDemoData()) {
        await LocalStore.upsertSubmissions(_demoSubmissions());
        await LocalStore.markDemoDataSeeded();
        submissions = LocalStore.loadSubmissions();
      } else {
        await _refreshDemoDetailsIfNeeded();
      }
      await _seedLocalHealthTipsIfNeeded();
    }

    final user = SupabaseGateway.currentUser;
    isPasswordRecoverySession =
        isSupabaseConfigured && SupabaseGateway.isPasswordRecoverySession;
    isSignedIn = user != null && !isPasswordRecoverySession;
    activeEmail = user?.email;
    activeRole = AccountRole.nurse;
    if (user != null && isSupabaseConfigured && !isPasswordRecoverySession) {
      await _loadActiveProfile(fallbackEmail: user.email);
      await _refreshRemoteHealthTips();
      if (activeRole == AccountRole.patient) {
        await loadPatientFindings();
      } else {
        await _refreshRemoteSubmissions();
        await syncPending();
      }
    }
    isReady = true;
    _startConnectivitySyncWatcher();
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    await _runBusy(() async {
      bool useLocal = !isSupabaseConfigured;

      if (isSupabaseConfigured) {
        try {
          await SupabaseGateway.signIn(email: email, password: password);
          isPasswordRecoverySession = false;
          await _loadActiveProfile(
            fallbackEmail: SupabaseGateway.currentUser?.email ?? email,
          );

          if (activeEmail != null) {
            await LocalStore.cacheOfflineUser(
              OfflineUserCache(
                id: SupabaseGateway.currentUser?.id ?? _uuid.v4(),
                email: activeEmail!,
                role: activeRole,
                credentialHash: _hashCredential(activeEmail!, password),
                lastLoginAt: DateTime.now().toUtc(),
              ),
            );
          }

          isSignedIn = true;
          await _logAuditEvent(
            action: 'auth.sign_in',
            entityType: 'session',
            summary: 'Signed in to KASUDLO.',
          );
          await _refreshRemoteHealthTips();
          if (activeRole == AccountRole.patient) {
            await loadPatientFindings();
          } else {
            await _refreshRemoteSubmissions();
            await syncPending();
          }
          return;
        } catch (e) {
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('socket') ||
              errorStr.contains('clientexception') ||
              errorStr.contains('failed host lookup') ||
              errorStr.contains('network') ||
              errorStr.contains('offline')) {
            useLocal = true;
          } else {
            rethrow;
          }
        }
      }

      if (useLocal) {
        final normalizedEmail = email.trim();
        final offlineUser = LocalStore.getOfflineUser(normalizedEmail);

        if (offlineUser == null) {
          if (normalizedEmail.isEmpty ||
              normalizedEmail == 'local-demo@kasudlo.app') {
            throw StateError('Invalid email or password.');
          }
          throw StateError(
            'Offline login is only allowed for users who have previously logged in online on this device.',
          );
        }

        final expectedHash = _hashCredential(normalizedEmail, password);
        if (offlineUser.credentialHash != expectedHash) {
          throw StateError('Invalid email or password.');
        }

        final thirtyDaysAgo = DateTime.now().toUtc().subtract(
          const Duration(days: 30),
        );
        if (offlineUser.lastLoginAt.isBefore(thirtyDaysAgo)) {
          throw StateError(
            'Offline session expired. Please connect to the internet to log in again.',
          );
        }

        activeEmail = offlineUser.email;
        activeRole = offlineUser.role;
        isSignedIn = true;
        await _seedLocalHealthTipsIfNeeded();
        if (activeRole == AccountRole.patient) {
          patientFindings = const [];
        }
        await _logAuditEvent(
          action: 'auth.sign_in',
          entityType: 'session',
          summary: 'Signed in to KASUDLO in local mode.',
        );
      }
    });
  }

  Future<void> signOut() async {
    await _runBusy(() async {
      await _logAuditEvent(
        action: 'auth.sign_out',
        entityType: 'session',
        summary: 'Signed out of KASUDLO.',
      );
      await SupabaseGateway.signOut();
      SupabaseGateway.clearPasswordRecoverySession();
      isSignedIn = false;
      isPasswordRecoverySession = false;
      activeEmail = null;
      activeFullName = null;
      activeRole = AccountRole.nurse;
      healthTipsErrorMessage = null;
      adminUsers = const [];
      auditLogs = const [];
      patientFindings = const [];
      isPatientFindingsLoading = false;
    });
  }

  Future<void> requestPasswordReset(String email) async {
    final normalizedEmail = email.trim();
    await _runBusy(() async {
      if (!isSupabaseConfigured) {
        passwordResetMessage =
            'Password reset is available after Supabase is configured.';
        return;
      }

      await SupabaseGateway.requestPasswordResetEmail(email: normalizedEmail);
      passwordResetMessage =
          'If an account exists for $normalizedEmail, a reset link has been sent. Open it on this device to choose a new password.';
    });
  }

  Future<void> completePasswordReset(String password) async {
    await _runBusy(() async {
      if (!isSupabaseConfigured) {
        throw StateError('Password reset needs live Supabase configuration.');
      }
      if (!isPasswordRecoverySession && SupabaseGateway.currentUser == null) {
        throw StateError(
          'Open the reset link from your email before choosing a new password.',
        );
      }

      await SupabaseGateway.updatePassword(password: password);
      await _logAuditEvent(
        action: 'auth.password_reset',
        entityType: 'session',
        summary: 'Updated password from reset flow.',
      );
      await SupabaseGateway.signOut();
      SupabaseGateway.clearPasswordRecoverySession();
      isPasswordRecoverySession = false;
      isSignedIn = false;
      activeRole = AccountRole.nurse;
      passwordResetMessage =
          'Password updated. Sign in with your new password.';
    });
  }

  void clearAuthMessages() {
    errorMessage = null;
    passwordResetMessage = null;
    notifyListeners();
  }

  Future<void> updatePreferences(AppPreferences nextPreferences) async {
    preferences = nextPreferences;
    notifyListeners();

    try {
      await LocalStore.savePreferences(nextPreferences);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Unable to save preferences: $error');
      }
    }
  }

  Future<void> setFieldRemindersEnabled(bool value) {
    return updatePreferences(
      preferences.copyWith(fieldRemindersEnabled: value),
    );
  }

  Future<void> setSyncNotificationsEnabled(bool value) {
    return updatePreferences(
      preferences.copyWith(syncNotificationsEnabled: value),
    );
  }

  Future<void> setSoundsEnabled(bool value) {
    return updatePreferences(preferences.copyWith(soundsEnabled: value));
  }

  Future<void> setOfflineModeEnabled(bool value) {
    return updatePreferences(preferences.copyWith(offlineModeEnabled: value));
  }

  Future<void> setDataSaverEnabled(bool value) {
    return updatePreferences(preferences.copyWith(dataSaverEnabled: value));
  }

  Future<void> loadAdminUsers({String search = ''}) async {
    if (!isAdmin) {
      adminUsers = const [];
      notifyListeners();
      return;
    }

    isAdminLoading = true;
    adminErrorMessage = null;
    notifyListeners();
    try {
      if (isSupabaseConfigured) {
        adminUsers = await SupabaseGateway.listAdminUsers(search: search);
      } else {
        adminUsers = _localAdminUsers();
      }
      await _logAuditEvent(
        action: 'admin.accounts.list',
        entityType: 'account',
        summary: search.trim().isEmpty
            ? 'Viewed account directory.'
            : 'Searched account directory.',
        metadata: {'search': search.trim(), 'count': adminUsers.length},
      );
    } catch (error) {
      adminErrorMessage = _friendlyErrorMessage(error);
    } finally {
      isAdminLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAuditLogs({String search = ''}) async {
    if (!isAdmin) {
      auditLogs = const [];
      notifyListeners();
      return;
    }

    isAuditLoading = true;
    auditErrorMessage = null;
    notifyListeners();
    try {
      await _logAuditEvent(
        action: 'admin.audit.view',
        entityType: 'audit_log',
        summary: search.trim().isEmpty
            ? 'Viewed audit log.'
            : 'Searched audit log.',
        metadata: {'search': search.trim()},
      );

      if (isSupabaseConfigured) {
        auditLogs = await SupabaseGateway.listAuditLogs(search: search);
      } else {
        auditLogs = _filteredLocalAuditLogs(search);
      }
    } catch (error) {
      auditErrorMessage = _friendlyErrorMessage(error);
    } finally {
      isAuditLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPatientFindings() async {
    if (!isPatient) {
      patientFindings = const [];
      notifyListeners();
      return;
    }

    isPatientFindingsLoading = true;
    notifyListeners();
    try {
      if (isSupabaseConfigured && isSignedIn) {
        patientFindings = await SupabaseGateway.fetchPatientFindings();
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Unable to fetch patient findings: $error');
    } finally {
      isPatientFindingsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createAdminAccount({
    required String fullName,
    required String email,
    required String password,
    required AccountRole role,
  }) async {
    if (!isAdmin) {
      adminErrorMessage = 'Only admins can create accounts.';
      notifyListeners();
      return false;
    }

    isAdminActionBusy = true;
    adminErrorMessage = null;
    notifyListeners();
    try {
      final createdUser = isSupabaseConfigured
          ? await SupabaseGateway.createAdminUser(
              fullName: fullName,
              email: email,
              password: password,
              role: role,
            )
          : AdminUser(
              id: _uuid.v4(),
              email: email.trim(),
              fullName: fullName.trim(),
              role: role,
              createdAt: DateTime.now(),
            );

      adminUsers = [createdUser, ...adminUsers];
      if (!isSupabaseConfigured) {
        await _logAuditEvent(
          action: 'admin.account.create',
          entityType: 'account',
          entityId: createdUser.id,
          summary: 'Created ${role.label.toLowerCase()} account for $email.',
          metadata: {'email': email.trim(), 'role': role.name},
        );
      }
      return true;
    } catch (error) {
      adminErrorMessage = _friendlyErrorMessage(error);
      return false;
    } finally {
      isAdminActionBusy = false;
      notifyListeners();
    }
  }

  Future<bool> createPatientAccountForSubmission({
    required HealthSubmission submission,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      return true;
    }
    if (password.length < 6) {
      errorMessage = 'Use at least 6 password characters.';
      notifyListeners();
      return false;
    }

    errorMessage = null;
    notifyListeners();
    try {
      if (isSupabaseConfigured) {
        if (!isSignedIn || SupabaseGateway.currentUser == null) {
          throw StateError('Sign in before creating a patient account.');
        }
        await SupabaseGateway.createPatientUser(
          fullName: submission.respondentName,
          email: normalizedEmail,
          password: password,
        );
      } else {
        await LocalStore.cacheOfflineUser(
          OfflineUserCache(
            id: _uuid.v4(),
            email: normalizedEmail,
            role: AccountRole.patient,
            credentialHash: _hashCredential(normalizedEmail, password),
            lastLoginAt: DateTime.now().toUtc(),
          ),
        );
      }

      await _logAuditEvent(
        action: 'collection.patient_account.create',
        entityType: 'account',
        entityId: submission.clientSubmissionId,
        summary: 'Created patient account for ${submission.respondentName}.',
        metadata: {
          'email': normalizedEmail,
          'client_submission_id': submission.clientSubmissionId,
        },
      );
      return true;
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> loadHealthTips() async {
    isHealthTipsLoading = true;
    healthTipsErrorMessage = null;
    notifyListeners();
    try {
      if (isSupabaseConfigured && isSignedIn) {
        await _refreshRemoteHealthTips(logView: true);
      } else {
        healthTips = LocalStore.loadHealthTips();
        await _seedLocalHealthTipsIfNeeded();
      }
    } catch (error) {
      healthTipsErrorMessage = _friendlyErrorMessage(error);
    } finally {
      isHealthTipsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveHealthTip({
    String? id,
    required String title,
    required String description,
    required List<HealthTipAttachment> attachments,
  }) async {
    if (!canManageHealthTips) {
      healthTipsErrorMessage =
          'Patient accounts can view health teaching only.';
      notifyListeners();
      return false;
    }

    isHealthTipActionBusy = true;
    healthTipsErrorMessage = null;
    notifyListeners();
    try {
      final now = DateTime.now().toUtc();
      final previous = id == null ? null : _healthTipById(id);
      final healthTip = HealthTip(
        id: previous?.id ?? id ?? _uuid.v4(),
        title: title.trim(),
        description: description.trim(),
        attachments: attachments,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
        createdByEmail: previous?.createdByEmail ?? activeEmail ?? '',
      );

      final savedHealthTip = isSupabaseConfigured && isSignedIn
          ? await SupabaseGateway.upsertHealthTip(healthTip)
          : healthTip;
      await LocalStore.upsertHealthTip(savedHealthTip);
      healthTips = LocalStore.loadHealthTips();
      await _logAuditEvent(
        action: previous == null ? 'health_tip.create' : 'health_tip.update',
        entityType: 'health_tip',
        entityId: savedHealthTip.id,
        summary: previous == null
            ? 'Created health teaching "${savedHealthTip.title}".'
            : 'Updated health teaching "${savedHealthTip.title}".',
      );
      return true;
    } catch (error) {
      healthTipsErrorMessage = _friendlyErrorMessage(error);
      return false;
    } finally {
      isHealthTipActionBusy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteHealthTip(String id) async {
    if (!canManageHealthTips) {
      healthTipsErrorMessage =
          'Patient accounts can view health teaching only.';
      notifyListeners();
      return false;
    }

    isHealthTipActionBusy = true;
    healthTipsErrorMessage = null;
    notifyListeners();
    try {
      final deleted = _healthTipById(id);
      if (isSupabaseConfigured && isSignedIn) {
        await SupabaseGateway.deleteHealthTip(id);
      }
      await LocalStore.deleteHealthTip(id);
      healthTips = LocalStore.loadHealthTips();
      await _logAuditEvent(
        action: 'health_tip.delete',
        entityType: 'health_tip',
        entityId: id,
        summary: deleted == null
            ? 'Deleted health teaching.'
            : 'Deleted health teaching "${deleted.title}".',
      );
      return true;
    } catch (error) {
      healthTipsErrorMessage = _friendlyErrorMessage(error);
      return false;
    } finally {
      isHealthTipActionBusy = false;
      notifyListeners();
    }
  }

  Future<void> saveDraft(HealthSubmission submission) async {
    final draft = submission.copyWith(
      syncStatus: SyncStatus.draft,
      updatedAt: DateTime.now().toUtc(),
      lastError: null,
    );
    await LocalStore.upsertSubmission(draft);
    _reloadSubmissions();
    await _logAuditEvent(
      action: 'collection.draft.save',
      entityType: 'household_assessment',
      entityId: draft.clientSubmissionId,
      summary: 'Saved draft for ${draft.respondentName}.',
    );
  }

  Future<void> submit(HealthSubmission submission) async {
    final pending = submission.copyWith(
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime.now().toUtc(),
      lastError: null,
    );
    await LocalStore.upsertSubmission(pending);
    _reloadSubmissions();
    await _logAuditEvent(
      action: 'collection.submit.queue',
      entityType: 'household_assessment',
      entityId: pending.clientSubmissionId,
      summary: 'Queued assessment for ${pending.respondentName}.',
    );
    await syncPending();
  }

  Future<void> updateReportSubmission(HealthSubmission submission) async {
    final editedAt = DateTime.now().toUtc();
    final previous = _submissionById(submission.clientSubmissionId);
    final comparisonBase = previous ?? submission;
    final contentChanges = reportEditChanges(
      previous: comparisonBase,
      next: submission,
    );
    final historyChanged = !reportEditHistoryEquals(
      comparisonBase.editHistory,
      submission.editHistory,
    );
    final shouldRecordHistory = contentChanges.isNotEmpty || !historyChanged;
    final withHistory = shouldRecordHistory
        ? submission.withEditHistory(
            previous: comparisonBase,
            editedAt: editedAt,
            editedBy: activeEmail,
          )
        : submission;
    final updated = withHistory.copyWith(
      syncStatus: submission.syncStatus == SyncStatus.draft
          ? SyncStatus.draft
          : SyncStatus.pending,
      updatedAt: editedAt,
      lastError: null,
    );
    await LocalStore.upsertSubmission(updated);
    _reloadSubmissions();
    await _logAuditEvent(
      action: 'report.record.update',
      entityType: 'household_assessment',
      entityId: updated.clientSubmissionId,
      summary: 'Updated report record for ${updated.respondentName}.',
    );
    await syncPending();
  }

  Future<AiHealthGuidance?> analyzeSubmission(
    HealthSubmission submission,
  ) async {
    if ((!isSupabaseConfigured || !isSignedIn) && !GroqGateway.isConfigured) {
      aiErrorMessage = 'AI guidance needs live Supabase sign-in or Groq setup.';
      notifyListeners();
      return null;
    }

    isAiLoading = true;
    aiErrorMessage = null;
    notifyListeners();

    try {
      final guidance = isSupabaseConfigured && isSignedIn
          ? await SupabaseGateway.analyzeAssessment(submission)
          : await GroqGateway.analyzeAssessment(submission);
      if (isSupabaseConfigured && isSignedIn) {
        await _logAuditEvent(
          action: 'ai.guidance.generate',
          entityType: 'household_assessment',
          entityId: submission.clientSubmissionId,
          summary: 'Generated AI guidance for ${submission.respondentName}.',
          metadata: {
            'risk_level': guidance.riskLevel,
            'care_suggestions': guidance.careSuggestions.length,
          },
        );
      }
      return guidance;
    } catch (error) {
      aiErrorMessage = _friendlyErrorMessage(error);
      return null;
    } finally {
      isAiLoading = false;
      notifyListeners();
    }
  }

  Future<AiHealthGuidance?> analyzeAndSaveSubmissionGuidance(
    HealthSubmission submission,
  ) async {
    final guidance = await analyzeSubmission(submission);
    if (guidance == null) {
      return null;
    }

    final current =
        _submissionById(submission.clientSubmissionId) ?? submission;
    final shouldSync = current.syncStatus != SyncStatus.draft;
    final updated = current.copyWith(
      aiGuidance: guidance,
      syncStatus: shouldSync ? SyncStatus.pending : SyncStatus.draft,
      updatedAt: DateTime.now().toUtc(),
      lastError: null,
    );

    await LocalStore.upsertSubmission(updated);
    _reloadSubmissions();
    if (shouldSync) {
      await syncPending();
    }
    return guidance;
  }

  Future<void> syncPending() async {
    if (_isSyncInProgress) {
      return;
    }

    _isSyncInProgress = true;
    try {
      if (!isSupabaseConfigured || !isSignedIn) {
        await _logAuditEvent(
          action: 'sync.skip',
          entityType: 'sync',
          summary: 'Skipped sync because live Supabase is unavailable.',
        );
        return;
      }

      if (isPatient) {
        await _logAuditEvent(
          action: 'sync.skip',
          entityType: 'sync',
          summary: 'Skipped sync because patient accounts are view-only.',
        );
        return;
      }

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        await _logAuditEvent(
          action: 'sync.skip',
          entityType: 'sync',
          summary: 'Skipped sync because the device is offline.',
        );
        return;
      }

      var syncedCount = 0;
      var failedCount = 0;
      await _logAuditEvent(
        action: 'sync.start',
        entityType: 'sync',
        summary: 'Started pending record sync.',
        metadata: {'pending_count': pendingCount},
      );

      for (final submission in List<HealthSubmission>.from(submissions)) {
        if (!_isRetryableSyncStatus(submission.syncStatus)) {
          continue;
        }

        final queuedSubmission = submission.syncStatus == SyncStatus.syncing
            ? submission.copyWith(syncStatus: SyncStatus.pending)
            : submission;

        await LocalStore.upsertSubmission(
          queuedSubmission.copyWith(syncStatus: SyncStatus.syncing),
        );
        _reloadSubmissions();

        try {
          final remoteBeforeUpload = await SupabaseGateway.fetchAssessment(
            queuedSubmission.clientSubmissionId,
          );
          if (_shouldHoldForConflict(queuedSubmission, remoteBeforeUpload)) {
            await LocalStore.upsertSubmission(
              _conflictedSubmission(
                localSubmission: queuedSubmission,
                remoteSubmission: remoteBeforeUpload!,
              ),
            );
            failedCount++;
            await _logAuditEvent(
              action: 'sync.record.conflict',
              entityType: 'household_assessment',
              entityId: queuedSubmission.clientSubmissionId,
              summary:
                  'Held sync for ${queuedSubmission.respondentName} because Supabase has newer data.',
            );
            _reloadSubmissions();
            continue;
          }

          final remoteSubmission = await SupabaseGateway.submitAssessment(
            queuedSubmission,
          );
          await LocalStore.upsertSubmission(
            _syncedSubmissionFrom(
              localSubmission: queuedSubmission,
              remoteSubmission: remoteSubmission,
            ),
          );
          syncedCount++;
          await _logAuditEvent(
            action: 'sync.record.success',
            entityType: 'household_assessment',
            entityId: queuedSubmission.clientSubmissionId,
            summary:
                'Synced assessment for ${queuedSubmission.respondentName}.',
          );
        } catch (error) {
          failedCount++;
          await LocalStore.upsertSubmission(
            queuedSubmission.copyWith(
              syncStatus: SyncStatus.failed,
              lastError: error.toString(),
            ),
          );
          await _logAuditEvent(
            action: 'sync.record.failure',
            entityType: 'household_assessment',
            entityId: queuedSubmission.clientSubmissionId,
            summary:
                'Failed to sync assessment for ${queuedSubmission.respondentName}.',
            metadata: {'error': error.toString()},
          );
        }
        _reloadSubmissions();
      }

      await _refreshRemoteSubmissions();
      await _logAuditEvent(
        action: 'sync.complete',
        entityType: 'sync',
        summary: 'Completed pending record sync.',
        metadata: {'synced_count': syncedCount, 'failed_count': failedCount},
      );
    } finally {
      _isSyncInProgress = false;
    }
  }

  HealthSubmission createSubmission({
    String? clientSubmissionId,
    DateTime? createdAt,
    required String respondentName,
    required int? respondentAge,
    required String address,
    required int familyMembersCount,
    required List<FamilyMember> familyMembers,
    required List<String> healthProblems,
    required String vaccinationStatus,
    required String waterSanitation,
    required String nutritionalStatus,
    required List<String> communityConcerns,
    Map<String, dynamic> surveyData = const {},
    required bool consentGiven,
    required String notes,
  }) {
    final now = DateTime.now().toUtc();
    return HealthSubmission(
      clientSubmissionId: clientSubmissionId ?? _uuid.v4(),
      respondentName: respondentName.trim(),
      respondentAge: respondentAge,
      address: address.trim(),
      familyMembersCount: familyMembersCount,
      familyMembers: familyMembers,
      healthProblems: healthProblems,
      vaccinationStatus: vaccinationStatus,
      waterSanitation: waterSanitation,
      nutritionalStatus: nutritionalStatus,
      communityConcerns: communityConcerns,
      surveyData: surveyData,
      consentGiven: consentGiven,
      notes: notes.trim(),
      createdAt: createdAt ?? now,
      syncStatus: SyncStatus.draft,
      updatedAt: now,
    );
  }

  Future<void> archiveSubmission(String clientSubmissionId) async {
    HealthSubmission? archived;
    for (final submission in submissions) {
      if (submission.clientSubmissionId == clientSubmissionId) {
        archived = submission;
        break;
      }
    }

    if (archived == null || archived.isDeleted) return;

    final archivedAt = DateTime.now().toUtc();
    final shouldSyncArchive = archived.syncStatus != SyncStatus.draft;
    final softDeleted = archived.copyWith(
      isDeleted: true,
      deletedAt: archivedAt,
      deletedBy: activeEmail,
      syncStatus: shouldSyncArchive
          ? SyncStatus.pendingDelete
          : SyncStatus.draft,
      updatedAt: archivedAt,
      lastError: null,
    );
    await LocalStore.upsertSubmission(softDeleted);

    _reloadSubmissions();
    if (shouldSyncArchive) {
      unawaited(syncPending());
    }

    await _logAuditEvent(
      action: 'report.record.archive',
      entityType: 'household_assessment',
      entityId: clientSubmissionId,
      summary: 'Archived report record for ${archived.respondentName}.',
    );
  }

  Future<void> deleteLocalSubmission(String clientSubmissionId) {
    return archiveSubmission(clientSubmissionId);
  }

  Future<void> restoreArchivedSubmission(String clientSubmissionId) async {
    if (!isAdmin) {
      adminErrorMessage = 'Only admins can restore archived records.';
      notifyListeners();
      return;
    }

    final archived = _submissionById(clientSubmissionId);
    if (archived == null || !archived.isDeleted) {
      return;
    }

    isAdminActionBusy = true;
    adminErrorMessage = null;
    notifyListeners();
    try {
      if (isSupabaseConfigured && isSignedIn) {
        await SupabaseGateway.restoreAssessment(clientSubmissionId);
      }

      final restoredAt = DateTime.now().toUtc();
      final restored = archived.copyWith(
        isDeleted: false,
        deletedAt: null,
        deletedBy: null,
        syncStatus: archived.remoteUpdatedAt == null
            ? archived.syncStatus
            : SyncStatus.synced,
        updatedAt: restoredAt,
        lastError: null,
      );
      await LocalStore.upsertSubmission(restored);
      _reloadSubmissions();

      await _logAuditEvent(
        action: 'report.record.restore',
        entityType: 'household_assessment',
        entityId: clientSubmissionId,
        summary:
            'Restored archived report record for ${archived.respondentName}.',
      );
    } catch (error) {
      adminErrorMessage = _friendlyErrorMessage(error);
    } finally {
      isAdminActionBusy = false;
      notifyListeners();
    }
  }

  Future<void> hardDeleteSubmission(String clientSubmissionId) async {
    if (!isAdmin) {
      adminErrorMessage = 'Only admins can permanently delete records.';
      notifyListeners();
      return;
    }

    final deleted = _submissionById(clientSubmissionId);
    if (deleted == null) {
      return;
    }
    if (!deleted.isDeleted) {
      adminErrorMessage = 'Archive the record before permanently deleting it.';
      notifyListeners();
      return;
    }

    isAdminActionBusy = true;
    adminErrorMessage = null;
    notifyListeners();
    try {
      if (isSupabaseConfigured && isSignedIn) {
        await SupabaseGateway.hardDeleteAssessment(clientSubmissionId);
      }
      await LocalStore.deleteSubmission(clientSubmissionId);
      await _logAuditEvent(
        action: 'report.record.hard_delete',
        entityType: 'household_assessment',
        entityId: clientSubmissionId,
        summary:
            'Permanently deleted report record for ${deleted.respondentName}.',
      );
    } catch (error) {
      adminErrorMessage = _friendlyErrorMessage(error);
    } finally {
      isAdminActionBusy = false;
      _reloadSubmissions();
    }
  }

  @visibleForTesting
  String debugFriendlyErrorMessage(Object error) =>
      _friendlyErrorMessage(error);

  @visibleForTesting
  Iterable<HealthSubmission> debugMergeRemoteSubmissions(
    List<HealthSubmission> remoteSubmissions,
  ) {
    return _mergeRemoteSubmissions(remoteSubmissions);
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    isBusy = true;
    errorMessage = null;
    passwordResetMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      errorMessage = _friendlyErrorMessage(error);
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void _startPasswordRecoveryWatcher() {
    if (!isSupabaseConfigured) {
      return;
    }

    _passwordRecoverySubscription ??= SupabaseGateway.passwordRecoveryStream
        .listen(_handlePasswordRecovery);
  }

  void _handlePasswordRecovery(String? email) {
    isPasswordRecoverySession = true;
    isSignedIn = false;
    activeEmail = email ?? SupabaseGateway.currentUser?.email;
    activeFullName = null;
    activeRole = AccountRole.nurse;
    errorMessage = null;
    passwordResetMessage = 'Choose a new password for this account.';
    notifyListeners();
  }

  void _reloadSubmissions() {
    submissions = LocalStore.loadSubmissions();
    notifyListeners();
  }

  void _startConnectivitySyncWatcher() {
    _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen((
      connectivity,
    ) {
      if (!isSupabaseConfigured ||
          !isSignedIn ||
          isPatient ||
          connectivity.contains(ConnectivityResult.none)) {
        return;
      }
      unawaited(syncPending());
    });
  }

  Future<void> _refreshRemoteSubmissions() async {
    if (!isSupabaseConfigured || SupabaseGateway.currentUser == null) {
      return;
    }

    try {
      final remoteSubmissions = await SupabaseGateway.listAssessments();
      if (remoteSubmissions.isEmpty) {
        return;
      }

      final mergedSubmissions = _mergeRemoteSubmissions(remoteSubmissions);

      await LocalStore.upsertSubmissions(mergedSubmissions);
      submissions = LocalStore.loadSubmissions();
      await _logAuditEvent(
        action: 'data.remote.refresh',
        entityType: 'household_assessment',
        summary: 'Refreshed records from Supabase.',
        metadata: {'count': remoteSubmissions.length},
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Unable to refresh remote submissions: $error');
      }
    }
  }

  Future<void> _refreshRemoteHealthTips({bool logView = false}) async {
    if (!isSupabaseConfigured || SupabaseGateway.currentUser == null) {
      return;
    }

    try {
      var remoteHealthTips = await SupabaseGateway.listHealthTips();

      // If remote is empty but we have local tips (e.g. created in local mode), upload them
      if (remoteHealthTips.isEmpty && healthTips.isNotEmpty) {
        for (final tip in healthTips) {
          await SupabaseGateway.upsertHealthTip(tip);
        }
        remoteHealthTips = await SupabaseGateway.listHealthTips();
      }

      await LocalStore.saveHealthTips(remoteHealthTips);
      healthTips = LocalStore.loadHealthTips();
      if (logView) {
        await _logAuditEvent(
          action: 'health_tip.list',
          entityType: 'health_tip',
          summary: 'Viewed health teaching.',
          metadata: {'count': remoteHealthTips.length},
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Unable to refresh remote health teaching: $error');
      }
      rethrow;
    }
  }

  HealthSubmission? _submissionById(String clientSubmissionId) {
    for (final submission in submissions) {
      if (submission.clientSubmissionId == clientSubmissionId) {
        return submission;
      }
    }
    return null;
  }

  HealthTip? _healthTipById(String id) {
    for (final healthTip in healthTips) {
      if (healthTip.id == id) {
        return healthTip;
      }
    }
    return null;
  }

  Iterable<HealthSubmission> _mergeRemoteSubmissions(
    List<HealthSubmission> remoteSubmissions,
  ) {
    final localSubmissions = {
      for (final submission in submissions)
        submission.clientSubmissionId: submission,
    };
    final remoteIds = <String>{};
    final merged = <HealthSubmission>[];

    for (final remoteSubmission in remoteSubmissions) {
      remoteIds.add(remoteSubmission.clientSubmissionId);
      final localSubmission =
          localSubmissions[remoteSubmission.clientSubmissionId];
      if (localSubmission == null) {
        merged.add(remoteSubmission);
        continue;
      }

      merged.add(
        _mergeRemoteSubmission(
          localSubmission: localSubmission,
          remoteSubmission: remoteSubmission,
        ),
      );
    }

    for (final localSubmission in submissions) {
      if (remoteIds.contains(localSubmission.clientSubmissionId)) {
        continue;
      }
      merged.add(
        localSubmission.syncStatus == SyncStatus.syncing
            ? localSubmission.copyWith(syncStatus: SyncStatus.pending)
            : localSubmission,
      );
    }

    return merged;
  }

  HealthSubmission _mergeRemoteSubmission({
    required HealthSubmission localSubmission,
    required HealthSubmission remoteSubmission,
  }) {
    if (localSubmission.syncStatus == SyncStatus.conflict) {
      if (localSubmission.hasSameAssessmentContent(remoteSubmission)) {
        return _syncedSubmissionFrom(
          localSubmission: localSubmission,
          remoteSubmission: remoteSubmission,
        );
      }

      return localSubmission.copyWith(
        remoteUpdatedAt:
            _remoteClock(remoteSubmission) ?? localSubmission.remoteUpdatedAt,
      );
    }

    if (_hasUnsentLocalWork(localSubmission)) {
      if (_shouldHoldForConflict(localSubmission, remoteSubmission)) {
        return _conflictedSubmission(
          localSubmission: localSubmission,
          remoteSubmission: remoteSubmission,
        );
      }

      return localSubmission.syncStatus == SyncStatus.syncing
          ? localSubmission.copyWith(syncStatus: SyncStatus.pending)
          : localSubmission;
    }

    if (localSubmission.hasSameAssessmentContent(remoteSubmission)) {
      return _syncedSubmissionFrom(
        localSubmission: localSubmission,
        remoteSubmission: remoteSubmission,
      );
    }

    return remoteSubmission;
  }

  bool _isRetryableSyncStatus(SyncStatus status) {
    return status == SyncStatus.pending ||
        status == SyncStatus.failed ||
        status == SyncStatus.syncing ||
        status == SyncStatus.pendingDelete;
  }

  bool _hasUnsentLocalWork(HealthSubmission submission) {
    return submission.syncStatus == SyncStatus.draft ||
        _isRetryableSyncStatus(submission.syncStatus);
  }

  bool _shouldHoldForConflict(
    HealthSubmission localSubmission,
    HealthSubmission? remoteSubmission,
  ) {
    if (remoteSubmission == null ||
        localSubmission.hasSameAssessmentContent(remoteSubmission)) {
      return false;
    }

    final remoteUpdatedAt = _remoteClock(remoteSubmission);
    if (remoteUpdatedAt == null) {
      return false;
    }

    final lastSeenRemoteAt = localSubmission.remoteUpdatedAt;
    final localEditedAt = localSubmission.effectiveUpdatedAt;
    const clockTolerance = Duration(seconds: 1);

    if (lastSeenRemoteAt == null) {
      return remoteUpdatedAt.isAfter(localEditedAt.add(clockTolerance));
    }

    return remoteUpdatedAt.isAfter(lastSeenRemoteAt.add(clockTolerance)) &&
        remoteUpdatedAt.isAfter(localEditedAt.add(clockTolerance));
  }

  HealthSubmission _conflictedSubmission({
    required HealthSubmission localSubmission,
    required HealthSubmission remoteSubmission,
  }) {
    return localSubmission.copyWith(
      syncStatus: SyncStatus.conflict,
      remoteUpdatedAt:
          _remoteClock(remoteSubmission) ?? localSubmission.remoteUpdatedAt,
      lastError:
          'Supabase has a newer version of this record. Review the local changes, edit if needed, then save again to sync.',
    );
  }

  HealthSubmission _syncedSubmissionFrom({
    required HealthSubmission localSubmission,
    HealthSubmission? remoteSubmission,
  }) {
    final remoteUpdatedAt =
        _remoteClock(remoteSubmission) ?? DateTime.now().toUtc();
    final syncedSubmission = remoteSubmission ?? localSubmission;

    return syncedSubmission.copyWith(
      syncStatus: SyncStatus.synced,
      updatedAt: localSubmission.effectiveUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt,
      lastError: null,
    );
  }

  DateTime? _remoteClock(HealthSubmission? submission) {
    return submission?.remoteUpdatedAt ?? submission?.updatedAt;
  }

  Future<void> _logAuditEvent({
    required String action,
    String entityType = 'system',
    String? entityId,
    required String summary,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (!isSignedIn && SupabaseGateway.currentUser == null) {
      return;
    }

    if (isSupabaseConfigured && SupabaseGateway.currentUser != null) {
      try {
        await SupabaseGateway.logAuditEvent(
          action: action,
          entityType: entityType,
          entityId: entityId,
          summary: summary,
          metadata: metadata,
        );
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Unable to write audit event: $error');
        }
      }
      return;
    }

    final entry = AuditLogEntry(
      id: _uuid.v4(),
      actorEmail: activeEmail ?? 'local-demo@kasudlo.app',
      actorRole: activeRole.name,
      action: action,
      entityType: entityType,
      entityId: entityId,
      summary: summary,
      createdAt: DateTime.now(),
    );
    auditLogs = [entry, ...auditLogs].take(100).toList();
  }

  List<AuditLogEntry> _filteredLocalAuditLogs(String search) {
    final query = search.trim().toLowerCase();
    if (query.isEmpty) {
      return auditLogs;
    }

    return auditLogs.where((entry) {
      return [
        entry.actorEmail,
        entry.actorRole,
        entry.action,
        entry.entityType,
        entry.entityId ?? '',
        entry.summary,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _loadActiveProfile({String? fallbackEmail}) async {
    try {
      final profile = await SupabaseGateway.currentProfile();
      activeEmail = profile?.email.trim().isNotEmpty == true
          ? profile!.email
          : fallbackEmail?.trim();
      activeFullName = profile?.fullName.trim().isNotEmpty == true
          ? profile!.fullName
          : null;
      activeRole = profile?.role ?? AccountRole.nurse;
    } catch (_) {
      activeEmail = fallbackEmail?.trim();
      activeFullName = null;
      activeRole = AccountRole.nurse;
    }
  }

  List<AdminUser> _localAdminUsers() => [
    AdminUser(
      id: 'local-admin',
      email: activeEmail ?? 'admin@kasudlo.app',
      fullName: 'Local Admin',
      role: AccountRole.admin,
      createdAt: DateTime.now(),
    ),
    ...adminUsers.where((user) => user.id != 'local-admin'),
  ];

  String _friendlyErrorMessage(Object error) {
    final message = error.toString();
    final normalized = message.toLowerCase();

    if (normalized.contains('invalid login credentials') ||
        normalized.contains('invalid_credentials')) {
      return 'Email or password is incorrect. Check the account created by your admin.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Confirm this email address before signing in.';
    }
    if (normalized.contains('code verifier') ||
        normalized.contains('expired')) {
      return 'This reset link is expired. Request a new password reset email.';
    }
    if (normalized.contains('session missing') ||
        normalized.contains('authsessionmissing')) {
      return 'Open the reset link from your email before choosing a new password.';
    }
    if (normalized.contains('network') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('xmlhttprequest')) {
      return 'Connection problem. Check your internet connection and try again.';
    }

    return message
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^Bad state:\s*'), '');
  }

  Future<void> _seedLocalHealthTipsIfNeeded() async {
    if (healthTips.isNotEmpty || LocalStore.hasSeededHealthTips()) {
      return;
    }
    await LocalStore.saveHealthTips(_demoHealthTips());
    await LocalStore.markHealthTipsSeeded();
    healthTips = LocalStore.loadHealthTips();
  }

  List<HealthTip> _demoHealthTips() {
    final now = DateTime.now().toUtc();
    return [
      HealthTip(
        id: 'demo-health-tip-hydration',
        title: 'Hydration during field days',
        description:
            'Drink safe water regularly, especially during hot barangay visits. Watch for dizziness, dry mouth, and dark urine.',
        attachments: const [],
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
        createdByEmail: activeEmail ?? 'local-demo@kasudlo.app',
      ),
      HealthTip(
        id: 'demo-health-tip-dengue',
        title: 'Dengue prevention checklist',
        description:
            'Remove standing water, cover containers, and seek care quickly for persistent fever, severe headache, or bleeding symptoms.',
        attachments: const [],
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
        createdByEmail: activeEmail ?? 'local-demo@kasudlo.app',
      ),
    ];
  }

  List<HealthSubmission> _demoSubmissions() {
    final now = DateTime.now();
    return [
      _mariaSantosDemoSubmission(
        createdAt: now.subtract(const Duration(days: 2, hours: 3)),
      ),
      _junReyesDemoSubmission(
        createdAt: now.subtract(const Duration(days: 1, hours: 6)),
      ),
      _lornaCruzDemoSubmission(
        createdAt: now.subtract(const Duration(hours: 8)),
      ),
    ];
  }

  Future<void> _refreshDemoDetailsIfNeeded() async {
    bool didUpdate = false;

    final lorna = _submissionById('demo-household-003');
    if (lorna != null && _needsDemoDetailsRefresh(lorna)) {
      await LocalStore.upsertSubmission(
        _lornaCruzDemoSubmission(
          createdAt: lorna.createdAt,
          syncStatus: lorna.syncStatus,
        ).copyWith(editHistory: lorna.editHistory, lastError: lorna.lastError),
      );
      didUpdate = true;
    }

    final maria = _submissionById('demo-household-001');
    if (maria != null && _needsDemoDetailsRefresh(maria)) {
      await LocalStore.upsertSubmission(
        _mariaSantosDemoSubmission(
          createdAt: maria.createdAt,
          syncStatus: maria.syncStatus,
        ).copyWith(editHistory: maria.editHistory, lastError: maria.lastError),
      );
      didUpdate = true;
    }

    final jun = _submissionById('demo-household-002');
    if (jun != null && _needsDemoDetailsRefresh(jun)) {
      await LocalStore.upsertSubmission(
        _junReyesDemoSubmission(
          createdAt: jun.createdAt,
          syncStatus: jun.syncStatus,
        ).copyWith(editHistory: jun.editHistory, lastError: jun.lastError),
      );
      didUpdate = true;
    }

    if (didUpdate) {
      submissions = LocalStore.loadSubmissions();
    }
  }

  bool _needsDemoDetailsRefresh(HealthSubmission submission) {
    return true;
  }

  HealthSubmission _mariaSantosDemoSubmission({
    required DateTime createdAt,
    SyncStatus syncStatus = SyncStatus.synced,
  }) {
    final familyRows = [
      {
        'member_no': 1,
        'name_of_family_member': 'Carlos Santos',
        'relationship_to_head': 'Spouse',
        'gender': 'Male',
        'age': 45,
        'birthdate_month': 10,
        'birthdate_day': 12,
        'birthdate_year': 1980,
        'marital_status': 'Married',
        'religion': 'Roman Catholic',
        'highest_educational_completed': 'College Graduate',
        'occupation_status': 'Employed',
        'place_of_work_location': 'Outside the community',
        'place_of_work_category': 'Office',
        'place_of_origin': 'Metro Manila',
        'length_of_residence': '10 years',
      },
      {
        'member_no': 2,
        'name_of_family_member': 'Ana Santos',
        'relationship_to_head': 'Child',
        'gender': 'Female',
        'age': 12,
        'birthdate_month': 5,
        'birthdate_day': 20,
        'birthdate_year': 2014,
        'marital_status': 'Single',
        'religion': 'Roman Catholic',
        'highest_educational_completed': 'Elementary Level',
        'occupation_status': 'Student',
        'place_of_work_location': 'Within the community',
        'place_of_work_category': 'School',
        'place_of_origin': 'Metro Manila',
        'length_of_residence': '10 years',
      },
    ];

    final surveyData = _lornaCruzSurveyData(familyRows)
      ..addAll({
        'control_no': 'CTRL-001',
        'number_of_family': 5,
        'address': 'Barangay San Isidro',
        'first_visit_date': '2026-05-20',
        'informant': 'Maria Santos',
        'surveyed_by': 'Nurse John',
        'time_started': '10:00',
        'time_finished': '11:00',
        'status_of_last_visit': 'Completed',
      });

    return HealthSubmission(
      clientSubmissionId: 'demo-household-001',
      respondentName: 'Maria Santos',
      respondentAge: 42,
      address: 'Barangay San Isidro',
      familyMembersCount: 5,
      familyMembers: familyRows.map(FamilyMember.fromSurveyData).toList(),
      healthProblems: const ['Hypertension', 'Diabetes'],
      vaccinationStatus: 'Complete',
      waterSanitation: 'Safe water and sanitary toilet',
      nutritionalStatus: 'Normal',
      communityConcerns: const ['Dengue risk', 'Limited clinic access'],
      surveyData: surveyData,
      consentGiven: true,
      notes: 'Needs BP follow-up during next barangay visit.',
      createdAt: createdAt,
      syncStatus: syncStatus,
    );
  }

  HealthSubmission _junReyesDemoSubmission({
    required DateTime createdAt,
    SyncStatus syncStatus = SyncStatus.pending,
  }) {
    final familyRows = [
      {
        'member_no': 1,
        'name_of_family_member': 'Mila Reyes',
        'relationship_to_head': 'Spouse',
        'gender': 'Female',
        'age': 28,
        'birthdate_month': 3,
        'birthdate_day': 15,
        'birthdate_year': 1998,
        'marital_status': 'Married',
        'religion': 'Iglesia ni Cristo',
        'highest_educational_completed': 'High School Graduate',
        'occupation_status': 'Unemployed',
        'place_of_work_location': 'Within the community',
        'place_of_work_category': 'In-House',
        'place_of_origin': 'Visayas',
        'length_of_residence': '5 years',
      },
      {
        'member_no': 2,
        'name_of_family_member': 'Jun Reyes',
        'relationship_to_head': 'Head',
        'gender': 'Male',
        'age': 31,
        'birthdate_month': 7,
        'birthdate_day': 22,
        'birthdate_year': 1994,
        'marital_status': 'Married',
        'religion': 'Iglesia ni Cristo',
        'highest_educational_completed': 'College Undergraduate',
        'occupation_status': 'Employed',
        'place_of_work_location': 'Within the community',
        'place_of_work_category': 'Construction',
        'place_of_origin': 'Visayas',
        'length_of_residence': '5 years',
      },
    ];

    final surveyData = _lornaCruzSurveyData(familyRows)
      ..addAll({
        'control_no': 'CTRL-002',
        'number_of_family': 4,
        'address': 'Purok 3, Barangay Mabini',
        'first_visit_date': '2026-05-21',
        'informant': 'Jun Reyes',
        'surveyed_by': 'Nurse Sarah',
        'time_started': '14:00',
        'time_finished': '15:30',
        'status_of_last_visit': 'Completed',
      });

    return HealthSubmission(
      clientSubmissionId: 'demo-household-002',
      respondentName: 'Jun Reyes',
      respondentAge: 31,
      address: 'Purok 3, Barangay Mabini',
      familyMembersCount: 4,
      familyMembers: familyRows.map(FamilyMember.fromSurveyData).toList(),
      healthProblems: const ['Asthma', 'Cough or fever'],
      vaccinationStatus: 'Incomplete',
      waterSanitation: 'Unsafe water source',
      nutritionalStatus: 'At risk',
      communityConcerns: const ['Low vaccination', 'Unsafe water'],
      surveyData: surveyData,
      consentGiven: true,
      notes: 'Water source needs sanitation referral.',
      createdAt: createdAt,
      syncStatus: syncStatus,
    );
  }

  HealthSubmission _lornaCruzDemoSubmission({
    required DateTime createdAt,
    SyncStatus syncStatus = SyncStatus.draft,
  }) {
    final familyRows = _lornaCruzFamilyRows();
    final surveyData = _lornaCruzSurveyData(familyRows);
    return HealthSubmission(
      clientSubmissionId: 'demo-household-003',
      respondentName: 'Lorna Cruz',
      respondentAge: 65,
      address: 'Sitio Maligaya, Barangay Mabini',
      familyMembersCount: 2,
      familyMembers: familyRows.map(FamilyMember.fromSurveyData).toList(),
      healthProblems: const ['Hypertension', 'Arthritis'],
      vaccinationStatus: 'Complete',
      waterSanitation: 'No sanitary toilet',
      nutritionalStatus: 'Underweight',
      communityConcerns: const [
        'Malnutrition',
        'Poor sanitation',
        'Limited clinic access',
      ],
      surveyData: surveyData,
      consentGiven: true,
      notes:
          'Prioritize nutrition screening, home sanitation follow-up, and BP monitoring.',
      createdAt: createdAt,
      syncStatus: syncStatus,
    );
  }

  List<Map<String, dynamic>> _lornaCruzFamilyRows() {
    return [
      {
        'member_no': 1,
        'name_of_family_member': 'Lorna Cruz',
        'relationship_to_head': 'Head',
        'gender': 'Female',
        'age': 65,
        'birthdate_month': 8,
        'birthdate_day': 14,
        'birthdate_year': 1960,
        'marital_status': 'Widow',
        'religion': 'Roman Catholic',
        'highest_educational_completed': 'High School Graduate',
        'occupation_status': 'Unemployed',
        'place_of_work_location': 'Within the community',
        'place_of_work_category': 'In-House',
        'place_of_origin': 'Central Luzon',
        'length_of_residence': '32 years',
      },
      {
        'member_no': 2,
        'name_of_family_member': 'Rica Cruz',
        'relationship_to_head': 'Grandchild',
        'gender': 'Female',
        'age': 9,
        'birthdate_month': 2,
        'birthdate_day': 3,
        'birthdate_year': 2017,
        'marital_status': 'Child',
        'religion': 'Roman Catholic',
        'highest_educational_completed': 'Elementary Level',
        'occupation_status': 'Minor, below 18 years old',
        'place_of_work_location': 'Within the community',
        'place_of_work_category': 'In-House',
        'place_of_origin': 'Central Luzon',
        'length_of_residence': '9 years',
      },
    ];
  }

  Map<String, dynamic> _lornaCruzSurveyData(
    List<Map<String, dynamic>> familyRows,
  ) {
    return {
      'control_no': 'CTRL-003',
      'number_of_family': 2,
      'address': 'Sitio Maligaya, Barangay Mabini',
      'first_visit_date': '2026-05-22',
      'second_visit_date': '2026-05-23',
      'third_visit_date': '2026-05-24',
      'informant': 'Lorna Cruz',
      'surveyed_by': 'Nurse Li',
      'time_started': '09:15',
      'time_finished': '10:45',
      'status_of_last_visit': 'Completed',
      'family_members': familyRows,
      'family_composition_type': ['Extended', 'Living with Grandparent(s)'],
      'family_locus_of_power': 'Matricentric',
      'family_place_of_residence': 'Neolocal',
      'family_descent': 'Bilateral',
      'dialect_frequently_used': 'Tagalog',
      'services_in_community': ['Health Services', 'Garbage collection'],
      'institutional_facilities': ['Brgy. Hall', 'Health Station', 'Church'],
      'organizations': ['Senior Citizen'],
      'traditions_customs': ['Bayanihan', 'Fiestas', 'Respect for elderly'],
      'recreational_facilities': ['Plaza'],
      'mode_of_transportation': ['Tricycle'],
      'mode_of_communication': ['Cell phone'],
      'income_earner_count': 1,
      'income_earners': [
        {
          'earner_no': 1,
          'family_position': 'Grandchild support',
          'income_php': 6000,
        },
      ],
      'monthly_family_income_combined': '5,001-10,000',
      'financial_sources': ['Pension', 'Help from relative/friends'],
      'monthly_family_expenditures': '5,001-10,000',
      'priority_food_rank': 1,
      'priority_clothing_rank': 5,
      'priority_education_rank': 3,
      'priority_utilities_rank': 4,
      'priority_health_rank': 2,
      'priority_recreation_rank': 7,
      'priority_savings_rank': 6,
      'family_income_adequacy': 'Not Adequate',
      'cultural_orientation_illness': [
        'Illness is caused by physiologic factor, e.g. infection',
        'Illness is caused by change in weather',
      ],
      'cultural_belief_health_restoration': [
        'Health can be restored by God/other spiritual faith',
        'Health can be restored by health personnel, e.g. doctors, nurses',
      ],
      'cultural_perception_health_practices':
          'Sometimes practices local cultural practices about health matters',
      'community_involvement':
          'Actively joins fiesta, religious procession, local cultural practices',
      'home_ownership': 'Owned',
      'home_construction_materials': 'Light',
      'sleeping_rooms_count': '1',
      'home_space_adequacy': 'Inadequate',
      'lighting_facility': 'Electricity',
      'lighting_adequacy': 'Adequate',
      'ventilation_adequacy': 'Inadequate',
      'general_sanitary_condition': 'Dirty',
      'water_supply_ownership': 'Public',
      'water_source_cooking': 'Deep well',
      'water_source_drinking': 'Commercial',
      'water_source_bathing_cr_flushing': 'Deep well',
      'water_potability_key_informant': 'No',
      'water_storage': 'Large covered container without faucet',
      'water_source_distance_from_house': '30 meters',
      'food_storage_cover_status': 'Covered',
      'food_storage_type': ['Cabinet', 'Basket'],
      'cooking_facility': ['Gas stove', 'Firewood/charcoal'],
      'cooking_area_sanitary_condition': 'Generally clean',
      'garbage_storage': 'Container',
      'waste_segregation': 'Not Practiced',
      'waste_disposal_method_if_not_practiced': ['Open burning', 'Collected'],
      'reason_for_not_practicing_waste_segregation': [
        'Not aware of effects',
        'Long-time practice of family',
      ],
      'toilet_ownership': 'None',
      'toilet_type': 'None',
      'toilet_location_from_water_source': 'Not applicable',
      'toilet_sanitary_condition': 'Dirty',
      'drainage_system': 'Open drainage',
      'drainage_condition': 'Stagnant',
      'has_rabies_carrier_animals': 'Yes',
      'rabies_carrier_animals': [
        {
          'animal_kind': 'Dog',
          'animal_number': 1,
          'kept_inside_yard': false,
          'kept_free_outside': true,
          'with_regular_vaccination': false,
          'without_vaccination': true,
        },
      ],
      'vector_control_measures': ['Cleaning the yard'],
      'has_breeding_sites_observed': 'Yes',
      'housing_congestion_observed': 'No',
      'has_industrial_establishment_or_factory_observed': 'No',
      'uses_safety_devices_when_necessary': 'Practice',
      'has_cigarette_smoker_in_family': 'No',
      'uses_prohibited_or_dangerous_drugs': 'No',
      'alcohol_drinkers': [
        {
          'name': 'Lorna Cruz',
          'age': 65,
          'age_started_drinking_alcohol': 0,
          'frequency': 'Never',
          'reason': 'Does not drink',
        },
      ],
      'bought_food_source': ['Carinderia'],
      'reason_for_bought_food_option': ['Convenient', 'Cheaper'],
      'antenatal_registrations': [
        {
          'name': 'Lorna Cruz',
          'aog': '20 weeks',
          'prenatal_checkup_with_regular': true,
          'prenatal_checkup_with_not_regular': false,
          'prenatal_checkup_without': false,
          'tetanus_vaccination_with': true,
          'tetanus_vaccination_without': false,
        },
      ],
      'communicable_disease_records': [
        {'name': 'Rica Cruz', 'age': 9, 'gender': 'Female', 'cd': 'Chickenpox'},
      ],
      'anthropometric_data_under_5': [
        {
          'name': 'Rica Cruz',
          'age_in_months': 108,
          'weight_kg': 25.5,
          'height_m': 1.2,
          'bmi': 17.7,
          'bmi_remarks': 'Normal',
          'waist_circumference_cm': 55.0,
          'hip_circumference_cm': 65.0,
          'waist_hip_ratio': 0.84,
          'waist_hip_ratio_remarks': 'Normal',
          'mid_upper_arm_circumference': 16.5,
          'mid_upper_arm_remarks': 'Normal',
        },
      ],
      'food_recall_24_hour': [
        {
          'date': '2026-05-23',
          'time_of_day': 'Breakfast',
          'food_taken': 'Rice porridge and coffee',
        },
        {
          'date': '2026-05-23',
          'time_of_day': 'Lunch',
          'food_taken': 'Rice, dried fish, and boiled vegetables',
        },
        {
          'date': '2026-05-23',
          'time_of_day': 'Dinner',
          'food_taken': 'Rice and vegetable soup',
        },
      ],
      'first_food_choice': 'Vegetable',
      'first_food_choice_servings': '1',
      'second_food_choice': 'Fish',
      'second_food_choice_servings': '1',
      'reason_for_food_choices': ['Affordable', 'Health condition'],
      'reason_for_not_choosing_other_food_options': ['Not affordable'],
      'food_intake_frequency': 'Everyday',
      'food_prepared_for_mealtime': 'Prepared at home',
      'food_preparation_frequency': 'Everyday',
      'canned_preserved_food_frequency': 'Sometimes',
      'grilled_food_frequency': 'Never',
      'carbonated_beverage_frequency': 'Never',
      'personnel_consulted_during_illness': ['Doctor', 'Midwife', 'Elderly'],
      'measures_taken_during_illness': [
        'Consult a Rural Health Team',
        'Self-Medication',
      ],
      'medication_treatment_during_illness': [
        'Prescribed by Doctor',
        'Self-Medication/OTC drugs',
      ],
      'medical_checkup_frequency': 'Twice a year',
      'dental_checkup_frequency': 'More than a year',
      'barangay_health_center_services_available':
          'BP monitoring, senior citizen consultation, immunization, and nutrition counseling',
      'immunization_records': [
        {
          'name': 'Rica Cruz',
          'age_in_months': 108,
          'gender': 'Female',
          'bcg': '2017-03-03',
          'dpt_1': '2017-04-03',
          'dpt_2': '2017-05-03',
          'dpt_3': '2017-06-03',
          'hepa_b_1': '2017-03-05',
          'hepa_b_2': '2017-04-05',
          'hepa_b_3': '2017-05-05',
          'opv_1': '2017-04-07',
          'opv_2': '2017-05-07',
          'opv_3': '2017-06-07',
          'measles': '2018-02-03',
          'complete_according_to_age': true,
          'incomplete_according_to_age': false,
          'fully_immunized_child': true,
        },
      ],
      'family_planning_eligible': false,
      'family_planning_status': 'Non-Acceptor',
      'family_planning_non_acceptor_reasons': ['Bad for health of family'],
      'permanent_method_female_sterilization_btl': true,
      'permanent_method_male_sterilization_vasectomy': false,
      'supply_method_pills': true,
      'supply_method_iud': false,
      'supply_method_injectable': false,
      'supply_method_condoms': false,
      'supply_method_implant': false,
      'fertility_method_cervical_mucus_billings': false,
      'fertility_method_basal_body_temperature': false,
      'fertility_method_sympto_thermal': false,
      'fertility_method_standard_days': false,
      'fertility_method_lactational_amenorrhea': false,
      'morbidity_records': [
        {
          'name': 'Lorna Cruz',
          'age': 65,
          'gender': 'Female',
          'cause': 'Hypertension',
          'intervention_with': true,
          'intervention_without': false,
          'admitted': false,
          'not_admitted': true,
        },
      ],
      'mortality_records': [
        {
          'name': 'Pedro Cruz',
          'age': 65,
          'gender': 'Male',
          'cause_of_death': 'Heart Attack',
        },
      ],
      'non_communicable_disease_records': [
        {
          'name': 'Lorna Cruz',
          'age': 65,
          'gender': 'Female',
          'ncd': 'Hypertension',
        },
        {
          'name': 'Lorna Cruz',
          'age': 65,
          'gender': 'Female',
          'ncd': 'Arthritis',
        },
      ],
      'blood_pressure_records': [
        {'name': 'Lorna Cruz', 'age': 65, 'gender': 'Female', 'bp': '150/90'},
      ],
      'awareness_of_bhc_rhu_health_services': 'Aware',
      'health_manpower_categories_available': 'BHW, midwife, nurse',
      'health_manpower_geographical_distribution':
          'Barangay health station is one tricycle ride away',
      'rhu_team_per_population_summary': '1 RHU team serves nearby sitios',
      'physician_count_per_population': '1:5000',
      'nurse_count_per_population': '1:2500',
      'midwife_count_per_population': '1:1000',
      'other_rhu_team_count_per_population': '2 BHWs per purok',
      'existing_manpower_development_policies':
          'Quarterly BHW training and senior citizen monitoring',
      'rhu_physicians_schedule': 'Monday 9 AM',
      'rhu_nurse_schedule': 'Tuesday 9 AM',
      'bhc_midwife_schedule': 'Wednesday 9 AM',
      'health_budget_expenditures_availability': 'Available',
      'health_budget_amount_per_year_php': 80000,
      'supplies_equipment_availability': 'Limited Supplies',
      'recognized_formal_elected_leaders': ['Captain', 'Kagawad'],
      'recognized_non_formal_leaders': ['BHW', 'Elderly'],
      'social_conflict_causes': ['Gossip', 'Alcohol drinking'],
      'conflict_resolution_approaches': [
        'Brgy. hearing',
        'Settlement among involved parties',
      ],
      'general_lifestyle_area_concerns_suggestions':
          'Needs sanitary toilet assistance, nutrition support, drainage '
          'clearing, and regular senior BP checks.',
      'health_problems': ['Hypertension', 'Arthritis'],
      'vaccination_status': 'Complete',
      'water_sanitation': 'No sanitary toilet',
      'nutritional_status': 'Underweight',
      'community_concerns': [
        'Malnutrition',
        'Poor sanitation',
        'Limited clinic access',
      ],
      'notes':
          'Prioritize nutrition screening, home sanitation follow-up, and BP monitoring.',
      'account_create_requested': false,
      'account_email': '',
    };
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _passwordRecoverySubscription?.cancel();
    super.dispose();
  }
}
