import 'package:sqflite_common/sqlite_api.dart';

Future<DatabaseFactory> createDatabaseFactory() async {
  throw UnsupportedError('SQLite is not supported on this platform.');
}
