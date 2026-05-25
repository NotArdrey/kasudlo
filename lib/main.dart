import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/services/local_store.dart';
import 'src/services/supabase_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.initialize();
  await SupabaseGateway.initialize();

  runApp(const ProviderScope(child: KasudloApp()));
}
