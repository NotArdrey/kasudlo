import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_controller.dart';

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final items = [
      const _NavItem(
        branchIndex: 0,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: 'Home',
      ),
      if (controller.isAdmin)
        const _NavItem(
          branchIndex: 1,
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
          label: 'Admin',
        ),
      const _NavItem(
        branchIndex: 2,
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment,
        label: 'Collect',
      ),
      const _NavItem(
        branchIndex: 3,
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart,
        label: 'Reports',
      ),
      const _NavItem(
        branchIndex: 4,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: 'Settings',
      ),
    ];
    final selectedIndex = items.indexWhere(
      (item) => item.branchIndex == navigationShell.currentIndex,
    );

    return Scaffold(
      body: SafeArea(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onDestinationSelected: (index) {
          final branchIndex = items[index].branchIndex;
          navigationShell.goBranch(
            branchIndex,
            initialLocation: branchIndex == navigationShell.currentIndex,
          );
        },
        destinations: items
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.branchIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final int branchIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
