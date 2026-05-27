import 'dart:io';

import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<sqflite.DatabaseFactory> createDatabaseFactory() async {
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    return sqflite.databaseFactory;
  }
  sqfliteFfiInit();
  return databaseFactoryFfi;
}
