import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/admin_screen.dart';
import 'screens/collection_screen.dart';
import 'screens/health_tips_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shell_screen.dart';
import 'state/app_controller.dart';
import 'theme.dart';

class KasudloApp extends ConsumerStatefulWidget {
  const KasudloApp({super.key});

  @override
  ConsumerState<KasudloApp> createState() => _KasudloAppState();
}

class _KasudloAppState extends ConsumerState<KasudloApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(appControllerProvider);
    _router = GoRouter(
      initialLocation: '/home',
      refreshListenable: controller,
      redirect: (context, state) {
        final controller = ref.read(appControllerProvider);
        if (!controller.isReady) {
          return null;
        }

        final isLogin = state.matchedLocation == '/login';
        if (controller.isPasswordRecoverySession) {
          return isLogin ? null : '/login';
        }
        if (!controller.isSignedIn) {
          return isLogin ? null : '/login';
        }
        if (isLogin) {
          return '/home';
        }
        if (state.matchedLocation == '/admin' && !controller.isAdmin) {
          return '/home';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              ShellScreen(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin',
                  builder: (context, state) => const AdminScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/collect',
                  builder: (context, state) => const CollectionScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/reports',
                  builder: (context, state) => const ReportsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/health-tips',
                  builder: (context, state) => const HealthTipsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KASUDLO',
      debugShowCheckedModeBanner: false,
      theme: buildKasudloTheme(),
      routerConfig: _router,
    );
  }
}
