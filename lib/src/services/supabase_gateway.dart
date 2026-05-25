import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models.dart';

class SupabaseGateway {
  static bool _initialized = false;

  static bool get isConfigured => AppConfig.hasSupabase;

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
    );
    _initialized = true;
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
  }

  static Future<void> submitAssessment(HealthSubmission submission) async {
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

  static Future<List<HealthSubmission>> listAssessments() async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase is not configured.');
    }

    final data = await supabase
        .from('household_assessments')
        .select(
          'client_submission_id, respondent_name, respondent_age, address, '
          'family_members_count, family_members, health_problems, '
          'vaccination_status, water_sanitation, nutritional_status, '
          'community_concerns, consent_given, notes, edit_history, payload, '
          'created_at, submitted_at',
        )
        .order('created_at', ascending: false);

    return data
        .whereType<Map>()
        .map(
          (item) =>
              HealthSubmission.fromRemoteJson(Map<String, dynamic>.from(item)),
        )
        .toList();
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
}
