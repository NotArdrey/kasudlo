import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models.dart';

class SupabaseGateway {
  static bool _initialized = false;
  static const _assessmentSelect =
      'client_submission_id, respondent_name, respondent_age, address, '
      'family_members_count, family_members, health_problems, '
      'vaccination_status, water_sanitation, nutritional_status, '
      'community_concerns, consent_given, notes, edit_history, payload, '
      'created_at, submitted_at, updated_at';
  static const _healthTipSelect =
      'id, title, description, file_name, mime_type, file_size, '
      'attachment_base64, created_by_email, created_at, updated_at';
  static bool _isPasswordRecoverySession = false;
  static bool _initialAuthLinkHandled = false;
  static final _appLinks = AppLinks();
  static final _handledAuthCallbackUrls = <String>{};
  static final _passwordRecoveryController =
      StreamController<String?>.broadcast();
  static StreamSubscription<AuthState>? _authStateSubscription;
  static StreamSubscription<Uri>? _authLinkSubscription;

  static bool get isConfigured => AppConfig.hasSupabase;
  static bool get isPasswordRecoverySession => _isPasswordRecoverySession;
  static Stream<String?> get passwordRecoveryStream =>
      _passwordRecoveryController.stream;

  static SupabaseClient? get client {
    if (!isConfigured || !_initialized) {
      return null;
    }
    return Supabase.instance.client;
  }

  static User? get currentUser => client?.auth.currentUser;

  static Future<void> initialize() async {
    if (!isConfigured || _initialized) {
      return;
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    _initialized = true;
    _startPasswordRecoveryWatcher();
    await _startAuthLinkHandling();
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final supabase = client;
    if (supabase == null) {
      return;
    }
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> requestPasswordResetEmail({required String email}) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase is not configured.');
    }

    await supabase.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: kIsWeb ? null : AppConfig.passwordResetRedirectUrl,
    );
  }

  static Future<void> updatePassword({required String password}) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase is not configured.');
    }

    await supabase.auth.updateUser(UserAttributes(password: password));
  }

  static void clearPasswordRecoverySession() {
    _isPasswordRecoverySession = false;
  }

  static Future<UserProfile?> currentProfile() async {
    final supabase = client;
    if (supabase == null) {
      return null;
    }
    final user = currentUser;
    if (user == null) {
      return null;
    }

    final data = await supabase
        .from('profiles')
        .select('id, email, full_name, role')
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        fullName: '${user.userMetadata?['full_name'] ?? ''}',
        role: accountRoleFromString(user.userMetadata?['role']),
      );
    }

    return UserProfile.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<List<AdminUser>> listAdminUsers({String search = ''}) async {
    final response = await _invokeAdminUsers({
      'action': 'list',
      if (search.trim().isNotEmpty) 'search': search.trim(),
    });

    final users = response['users'];
    if (users is! List) {
      return const [];
    }

    return users
        .whereType<Map>()
        .map((item) => AdminUser.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<List<AuditLogEntry>> listAuditLogs({
    String search = '',
    int limit = 100,
  }) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase is not configured.');
    }

    final data = await supabase.rpc(
      'kasudlo_admin_list_audit_logs',
      params: {'p_limit': limit, 'p_search': search.trim()},
    );

    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map>()
        .map((item) => AuditLogEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<AdminUser> createAdminUser({
    required String fullName,
    required String email,
    required String password,
    required AccountRole role,
  }) async {
    final response = await _invokeAdminUsers({
      'action': 'create',
      'full_name': fullName.trim(),
      'email': email.trim(),
      'password': password,
      'role': role.name,
    });

    final user = response['user'];
    if (user is! Map) {
      throw StateError('Admin account creation returned no user.');
    }

    return AdminUser.fromJson(Map<String, dynamic>.from(user));
  }

  static Future<void> signOut() async {
    await client?.auth.signOut();
    clearPasswordRecoverySession();
  }

  static Future<HealthSubmission?> submitAssessment(
    HealthSubmission submission,
  ) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase is not configured.');
    }

    await supabase.rpc(
      'kasudlo_submit_household_assessment',
      params: {
        'payload': submission.toRpcPayload(),
        'p_client_submission_id': submission.clientSubmissionId,
      },
    );

    return fetchAssessment(submission.clientSubmissionId);
  }

  static Future<AiHealthGuidance> analyzeAssessment(
    HealthSubmission submission,
  ) async {
    final response = await _invokeFunction('kasudlo-ai-guidance', {
      'submission': submission.toJson(),
    });

    final guidance = response['guidance'];
    if (guidance is! Map) {
      throw StateError('AI guidance returned no result.');
    }

    return AiHealthGuidance.fromJson(Map<String, dynamic>.from(guidance));
  }

  static Future<void> logAuditEvent({
    required String action,
    required String entityType,
    String? entityId,
    required String summary,
    Map<String, dynamic> metadata = const {},
  }) async {
    final supabase = client;
    if (supabase == null || currentUser == null) {
      return;
    }

    await supabase.rpc(
      'kasudlo_log_audit_event',
      params: {
        'p_action': action,
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_summary': summary,
        'p_metadata': metadata,
      },
    );
  }

  static Future<List<HealthTip>> listHealthTips() async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase is not configured.');
    }

    final data = await supabase
        .from('health_tips')
        .select(_healthTipSelect)
        .order('updated_at', ascending: false);

    return data
        .whereType<Map>()
        .map((item) => HealthTip.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<HealthTip> upsertHealthTip(HealthTip healthTip) async {
    final supabase = client;
    final user = currentUser;
    if (supabase == null || user == null) {
      throw StateError('Supabase is not configured.');
    }

    final data = await supabase
        .from('health_tips')
        .upsert({
          ...healthTip.toJson(),
          'created_by': user.id,
          'created_by_email': user.email ?? healthTip.createdByEmail,
        }, onConflict: 'id')
        .select(_healthTipSelect)
        .single();

    return HealthTip.fromJson(Map<String, dynamic>.from(data));
  }

  static Future<void> deleteHealthTip(String id) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase is not configured.');
    }

    await supabase.from('health_tips').delete().eq('id', id);
  }

  static Future<List<HealthSubmission>> listAssessments() async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase is not configured.');
    }

    final data = await supabase
        .from('household_assessments')
        .select(_assessmentSelect)
        .order('created_at', ascending: false);

    return data
        .whereType<Map>()
        .map(
          (item) =>
              HealthSubmission.fromRemoteJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  static Future<HealthSubmission?> fetchAssessment(
    String clientSubmissionId,
  ) async {
    final supabase = client;
    final user = currentUser;
    if (supabase == null || user == null) {
      throw StateError('Supabase is not configured.');
    }

    final data = await supabase
        .from('household_assessments')
        .select(_assessmentSelect)
        .eq('user_id', user.id)
        .eq('client_submission_id', clientSubmissionId)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return HealthSubmission.fromRemoteJson(Map<String, dynamic>.from(data));
  }

  static Future<Map<String, dynamic>> _invokeAdminUsers(
    Map<String, dynamic> body,
  ) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase is not configured.');
    }

    return _invokeFunction('kasudlo-admin-users', body);
  }

  static Future<Map<String, dynamic>> _invokeFunction(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase is not configured.');
    }

    final response = await supabase.functions.invoke(functionName, body: body);

    if (response.status >= 400) {
      throw StateError(_functionErrorMessage(response.data));
    }

    final data = response.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return const {};
  }

  static String _functionErrorMessage(Object? data) {
    if (data is Map && data['error'] != null) {
      return '${data['error']}';
    }
    if (data is Map && data['message'] != null) {
      return '${data['message']}';
    }
    if (data is String && data.trim().isNotEmpty) {
      return data;
    }
    return 'Admin action failed.';
  }

  static void _startPasswordRecoveryWatcher() {
    final supabase = client;
    if (supabase == null || _authStateSubscription != null) {
      return;
    }

    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _markPasswordRecovery(data.session?.user.email);
      } else if (data.event == AuthChangeEvent.signedOut) {
        clearPasswordRecoverySession();
      }
    });
  }

  static Future<void> _startAuthLinkHandling() async {
    await _handleInitialAuthLink();

    _authLinkSubscription ??= _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleAuthCallback(uri)),
      onError: (Object error, StackTrace stackTrace) {
        if (kDebugMode) {
          debugPrint('Unable to receive auth link: $error');
        }
      },
    );
  }

  static Future<void> _handleInitialAuthLink() async {
    if (_initialAuthLinkHandled) {
      return;
    }
    _initialAuthLinkHandled = true;

    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        await _handleAuthCallback(uri);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Unable to handle initial auth link: $error');
      }
    }
  }

  static Future<void> _handleAuthCallback(Uri uri) async {
    final supabase = client;
    if (supabase == null || !_isAuthCallbackUri(uri)) {
      return;
    }

    final cacheKey = uri.toString();
    if (!_handledAuthCallbackUrls.add(cacheKey)) {
      return;
    }

    try {
      final response = await supabase.auth.getSessionFromUrl(uri);
      if (response.redirectType == AuthChangeEvent.passwordRecovery.name ||
          response.redirectType == 'recovery') {
        _markPasswordRecovery(response.session.user.email);
      }
    } catch (error) {
      _handledAuthCallbackUrls.remove(cacheKey);
      if (kDebugMode) {
        debugPrint('Unable to handle auth callback: $error');
      }
    }
  }

  static bool _isAuthCallbackUri(Uri uri) {
    return uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('access_token') ||
        uri.queryParameters.containsKey('error_description') ||
        uri.fragment.contains('access_token') ||
        uri.fragment.contains('error_description');
  }

  static void _markPasswordRecovery(String? email) {
    _isPasswordRecoverySession = true;
    _passwordRecoveryController.add(email ?? currentUser?.email);
  }
}
