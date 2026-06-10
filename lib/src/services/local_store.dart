import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite_common/sqlite_api.dart';

import '../models.dart';
import 'sqlite_database_factory.dart';

class LocalStore {
  static const _databaseName = 'kasudlo.sqlite';
  static const _submissionsTable = 'submissions';
  static const _keyValueTable = 'app_kv';
  static const _demoSeededKey = '__kasudlo_demo_seeded';
  static const _healthTipsSeededKey = '__kasudlo_health_tips_seeded';
  static const _healthTipsKey = '__kasudlo_health_tips';
  static const _preferencesKey = '__kasudlo_preferences';
  static const _offlineUsersKey = '__kasudlo_offline_users';

  static Database? _database;
  static final Map<String, HealthSubmission> _submissionCache = {};
  static final Map<String, HealthTip> _healthTipCache = {};
  static final Map<String, OfflineUserCache> _offlineUserCache = {};
  static AppPreferences _preferencesCache = const AppPreferences();
  static bool _demoSeededCache = false;
  static bool _healthTipsSeededCache = false;

  static Future<void> initialize() async {
    final databaseFactory = await createSqliteDatabaseFactory();
    final databasesPath = await databaseFactory.getDatabasesPath();
    final databasePath = path.join(databasesPath, _databaseName);

    await _openDatabase(databaseFactory, databasePath);
  }

  static Future<void> initializeForTesting(
    DatabaseFactory databaseFactory, {
    String databasePath = inMemoryDatabasePath,
  }) {
    return _openDatabase(databaseFactory, databasePath);
  }

  static Future<void> closeForTesting() async {
    await _database?.close();
    _database = null;
    _submissionCache.clear();
    _healthTipCache.clear();
    _offlineUserCache.clear();
    _preferencesCache = const AppPreferences();
    _demoSeededCache = false;
    _healthTipsSeededCache = false;
  }

  static Future<void> _openDatabase(
    DatabaseFactory databaseFactory,
    String databasePath,
  ) async {
    await _database?.close();
    _database = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(version: 1, onCreate: _createSchema),
    );
    await _loadCaches();
  }

  static List<HealthSubmission> loadSubmissions() {
    _requireDatabase();
    return _submissionCache.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> upsertSubmission(HealthSubmission submission) async {
    final database = _requireDatabase();
    await database.insert(
      _submissionsTable,
      _submissionRow(submission),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _submissionCache[submission.clientSubmissionId] = submission;
  }

  static Future<void> upsertSubmissions(
    Iterable<HealthSubmission> submissions,
  ) async {
    final database = _requireDatabase();
    final submissionList = submissions.toList();
    if (submissionList.isEmpty) {
      return;
    }

    await database.transaction((transaction) async {
      final batch = transaction.batch();
      for (final submission in submissionList) {
        batch.insert(
          _submissionsTable,
          _submissionRow(submission),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });

    for (final submission in submissionList) {
      _submissionCache[submission.clientSubmissionId] = submission;
    }
  }

  static Future<void> deleteSubmission(String clientSubmissionId) async {
    final database = _requireDatabase();
    await database.delete(
      _submissionsTable,
      where: 'client_submission_id = ?',
      whereArgs: [clientSubmissionId],
    );
    _submissionCache.remove(clientSubmissionId);
  }

  static List<HealthTip> loadHealthTips() {
    _requireDatabase();
    return _sortedHealthTips();
  }

  static Future<void> saveHealthTips(Iterable<HealthTip> healthTips) async {
    final database = _requireDatabase();
    _healthTipCache
      ..clear()
      ..addEntries(healthTips.map((tip) => MapEntry(tip.id, tip)));
    await _putKeyValue(
      database,
      _healthTipsKey,
      jsonEncode(_sortedHealthTips().map((tip) => tip.toJson()).toList()),
    );
  }

  static Future<void> upsertHealthTip(HealthTip healthTip) async {
    final database = _requireDatabase();
    _healthTipCache[healthTip.id] = healthTip;
    await _putKeyValue(
      database,
      _healthTipsKey,
      jsonEncode(_sortedHealthTips().map((tip) => tip.toJson()).toList()),
    );
  }

  static Future<void> deleteHealthTip(String id) async {
    final database = _requireDatabase();
    _healthTipCache.remove(id);
    await _putKeyValue(
      database,
      _healthTipsKey,
      jsonEncode(_sortedHealthTips().map((tip) => tip.toJson()).toList()),
    );
  }

  static AppPreferences loadPreferences() {
    _requireDatabase();
    return _preferencesCache;
  }

  static Future<void> savePreferences(AppPreferences preferences) async {
    final database = _requireDatabase();
    await _putKeyValue(database, _preferencesKey, jsonEncode(preferences));
    _preferencesCache = preferences;
  }

  static OfflineUserCache? getOfflineUser(String email) {
    _requireDatabase();
    return _offlineUserCache[email.trim().toLowerCase()];
  }

  static Future<void> cacheOfflineUser(OfflineUserCache user) async {
    final database = _requireDatabase();
    _offlineUserCache[user.email.trim().toLowerCase()] = user;
    await _putKeyValue(
      database,
      _offlineUsersKey,
      jsonEncode(_offlineUserCache.values.map((u) => u.toJson()).toList()),
    );
  }

  static bool hasSeededDemoData() {
    _requireDatabase();
    return _demoSeededCache;
  }

  static Future<void> markDemoDataSeeded() async {
    final database = _requireDatabase();
    await _putKeyValue(database, _demoSeededKey, 'true');
    _demoSeededCache = true;
  }

  static bool hasSeededHealthTips() {
    _requireDatabase();
    return _healthTipsSeededCache;
  }

  static Future<void> markHealthTipsSeeded() async {
    final database = _requireDatabase();
    await _putKeyValue(database, _healthTipsSeededKey, 'true');
    _healthTipsSeededCache = true;
  }

  static Future<void> _createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE $_submissionsTable (
        client_submission_id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE $_keyValueTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await database.execute(
      'CREATE INDEX idx_submissions_sync_status '
      'ON $_submissionsTable(sync_status)',
    );
    await database.execute(
      'CREATE INDEX idx_submissions_created_at '
      'ON $_submissionsTable(created_at)',
    );
  }

  static Future<void> _loadCaches() async {
    final database = _requireDatabase();
    _submissionCache.clear();
    _healthTipCache.clear();
    _offlineUserCache.clear();

    final rows = await database.query(_submissionsTable);
    for (final row in rows) {
      final submission = _submissionFromRow(row);
      if (submission != null) {
        _submissionCache[submission.clientSubmissionId] = submission;
      }
    }

    final keyValues = await database.query(_keyValueTable);
    _preferencesCache = const AppPreferences();
    _demoSeededCache = false;
    _healthTipsSeededCache = false;
    for (final row in keyValues) {
      final key = row['key'];
      final value = row['value'];
      if (key == _preferencesKey && value is String) {
        _preferencesCache = _preferencesFromJson(value);
      }
      if (key == _demoSeededKey) {
        _demoSeededCache = value == 'true';
      }
      if (key == _healthTipsSeededKey) {
        _healthTipsSeededCache = value == 'true';
      }
      if (key == _healthTipsKey && value is String) {
        for (final healthTip in _healthTipsFromJson(value)) {
          _healthTipCache[healthTip.id] = healthTip;
        }
      }
      if (key == _offlineUsersKey && value is String) {
        for (final user in _offlineUsersFromJson(value)) {
          _offlineUserCache[user.email.trim().toLowerCase()] = user;
        }
      }
    }
  }

  static List<HealthTip> _sortedHealthTips() {
    return _healthTipCache.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static Map<String, Object?> _submissionRow(HealthSubmission submission) => {
    'client_submission_id': submission.clientSubmissionId,
    'created_at': submission.createdAt.toIso8601String(),
    'sync_status': submission.syncStatus.name,
    'payload': jsonEncode(submission.toJson()),
    'updated_at': submission.effectiveUpdatedAt.toIso8601String(),
  };

  static HealthSubmission? _submissionFromRow(Map<String, Object?> row) {
    final payload = row['payload'];
    if (payload is! String || payload.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return null;
      }
      final restoredJson = Map<String, dynamic>.from(decoded);
      restoredJson['sync_status'] ??= row['sync_status'];
      restoredJson['updated_at'] ??= row['updated_at'];
      final restored = HealthSubmission.fromJson(restoredJson);
      if (restored.syncStatus == SyncStatus.syncing) {
        return restored.copyWith(syncStatus: SyncStatus.pending);
      }
      return restored;
    } catch (_) {
      return null;
    }
  }

  static AppPreferences _preferencesFromJson(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return AppPreferences.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      return const AppPreferences();
    }
    return const AppPreferences();
  }

  static List<HealthTip> _healthTipsFromJson(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => HealthTip.fromJson(Map<String, dynamic>.from(item)))
            .where((tip) => tip.id.trim().isNotEmpty)
            .toList();
      }
    } catch (_) {
      return const [];
    }
    return const [];
  }

  static List<OfflineUserCache> _offlineUsersFromJson(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (item) =>
                  OfflineUserCache.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((user) => user.email.trim().isNotEmpty)
            .toList();
      }
    } catch (_) {
      return const [];
    }
    return const [];
  }

  static Future<void> _putKeyValue(
    Database database,
    String key,
    String value,
  ) {
    return database.insert(_keyValueTable, {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Database _requireDatabase() {
    final database = _database;
    if (database == null || !database.isOpen) {
      throw StateError('LocalStore.initialize must be called before use.');
    }
    return database;
  }
}
