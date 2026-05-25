import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<DatabaseFactory> createDatabaseFactory() async {
  sqfliteFfiInit();
  return databaseFactoryFfi;
}
