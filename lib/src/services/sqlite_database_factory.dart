import 'package:sqflite_common/sqlite_api.dart';

import 'sqlite_database_factory_stub.dart'
    if (dart.library.io) 'sqlite_database_factory_io.dart'
    if (dart.library.js_interop) 'sqlite_database_factory_web.dart';

Future<DatabaseFactory> createSqliteDatabaseFactory() {
  return createDatabaseFactory();
}
