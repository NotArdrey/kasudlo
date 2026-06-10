import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_controller.dart';
import '../theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final summary = controller.summary;
    final email = controller.activeEmail ?? 'Health Worker';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, controller),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                controller.isPatient
                    ? _buildPatientHomeView(context, controller)
                    : _buildStaffHomeView(context, controller, summary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, AppController controller) {
    final email = controller.activeEmail ?? 'Health Worker';
    final fullName = controller.activeFullName;
    final role = controller.activeRole.name;
    final roleDisplay = role.isNotEmpty
        ? role.replaceFirst(role[0], role[0].toUpperCase())
        : 'User';

    String greetingName = email;
    if (fullName != null && fullName.trim().isNotEmpty) {
      final firstName = fullName.trim().split(' ').first;
      if (firstName.toLowerCase() == roleDisplay.toLowerCase()) {
        greetingName = firstName;
      } else {
        greetingName = '$roleDisplay $firstName';
      }
    }

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: KasudloColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(color: KasudloColors.primary),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'Welcome back,',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    greetingName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
    );
  }

  List<Widget> _buildStaffHomeView(
    BuildContext context,
    AppController controller,
    dynamic summary,
  ) {
    return [
      _buildSectionTitle(context, 'Community Overview'),
      const SizedBox(height: 16),
      _buildMetricsGrid(context, summary),
      const SizedBox(height: 32),
      _buildSectionTitle(context, 'Quick Actions'),
      const SizedBox(height: 16),
      _buildQuickActions(context, controller),
    ];
  }

  List<Widget> _buildPatientHomeView(
    BuildContext context,
    AppController controller,
  ) {
    return [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KasudloColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                color: KasudloColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Health Matters',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Welcome to Kasudlo. Stay updated with the latest health guidelines and reach out if you need assistance.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),
      _buildSectionTitle(context, 'Quick Links'),
      const SizedBox(height: 16),
      _ActionTile(
        title: 'Health Teaching',
        subtitle: 'View wellness advice from your care team',
        icon: Icons.tips_and_updates_rounded,
        color: KasudloColors.secondary,
        onTap: () => context.go('/health-tips'),
      ),
      const SizedBox(height: 12),
      _ActionTile(
        title: 'Contact Us',
        subtitle: 'Reach out to your local health worker',
        icon: Icons.contact_phone_rounded,
        color: KasudloColors.primary,
        onTap: () => context.go('/contact'),
      ),
    ];
  }

  Widget _buildMetricsGrid(BuildContext context, dynamic summary) {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            _ModernMetricCard(
              label: 'Households',
              value: '${summary.totalHouseholds}',
              icon: Icons.home_work_rounded,
              color: const Color(0xFF4A90E2),
            ),
            _ModernMetricCard(
              label: 'Family Members',
              value: '${summary.totalFamilyMembers}',
              icon: Icons.groups_rounded,
              color: const Color(0xFF50E3C2),
            ),
          ],
        ),
        if ((summary.healthProblems as Map<String, int>).isNotEmpty) ...[
          const SizedBox(height: 16),
          _HealthProblemsBreakdown(
            healthProblems: summary.healthProblems as Map<String, int>,
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, AppController controller) {
    return Column(
      children: [
        _ActionTile(
          title: 'Collect New Data',
          subtitle: 'Start a new household assessment',
          icon: Icons.add_task_rounded,
          color: KasudloColors.primary,
          onTap: () => context.go('/collect'),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          title: 'View Reports',
          subtitle: 'Analyze collected community data',
          icon: Icons.analytics_rounded,
          color: KasudloColors.secondary,
          onTap: () => context.go('/reports'),
        ),
        if (controller.retryableSyncCount > 0) ...[
          const SizedBox(height: 12),
          _ActionTile(
            title: 'Retry Sync',
            subtitle:
                '${controller.retryableSyncCount} records waiting to sync',
            icon: Icons.sync_rounded,
            color: KasudloColors.warning,
            onTap: controller.syncPending,
          ),
        ],
      ],
    );
  }
}

class _ModernMetricCard extends StatelessWidget {
  const _ModernMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 32,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _HealthProblemsBreakdown extends StatelessWidget {
  const _HealthProblemsBreakdown({required this.healthProblems});

  final Map<String, int> healthProblems;

  @override
  Widget build(BuildContext context) {
    final entries = healthProblems.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topEntries = entries.take(4).toList();
    final otherEntries = entries.skip(4).toList();
    if (otherEntries.isNotEmpty) {
      final otherSum = otherEntries.map((e) => e.value).reduce((a, b) => a + b);
      topEntries.add(MapEntry('Other', otherSum));
    }

    final colors = [
      KasudloColors.primary,
      KasudloColors.secondary,
      KasudloColors.warning,
      KasudloColors.critical,
      Colors.grey,
    ];
    final totalCount = topEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.value,
    );
    final maxCount = topEntries.fold<int>(0, (max, entry) {
      return entry.value > max ? entry.value : max;
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Health Problems',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Column(
            children: List.generate(topEntries.length, (i) {
              final entry = topEntries[i];
              final color = colors[i % colors.length];
              final percentage = totalCount == 0
                  ? 0.0
                  : entry.value / totalCount;
              final barWidth = maxCount == 0 ? 0.0 : entry.value / maxCount;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == topEntries.length - 1 ? 0 : 16,
                ),
                child: _HealthProblemBarRow(
                  label: entry.key,
                  count: entry.value,
                  percentage: percentage,
                  barWidth: barWidth,
                  color: color,
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total reported concerns',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '$totalCount',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthProblemBarRow extends StatelessWidget {
  const _HealthProblemBarRow({
    required this.label,
    required this.count,
    required this.percentage,
    required this.barWidth,
    required this.color,
  });

  final String label;
  final int count;
  final double percentage;
  final double barWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percentLabel = '${(percentage * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$count',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: Text(
                percentLabel,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: color.withValues(alpha: 0.12)),
                FractionallySizedBox(
                  widthFactor: barWidth.clamp(0.0, 1.0).toDouble(),
                  alignment: Alignment.centerLeft,
                  child: ColoredBox(color: color),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
