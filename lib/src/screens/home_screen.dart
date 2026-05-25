import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/app_chrome.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final summary = controller.summary;

    return AppPage(
      title: 'Home',
      subtitle: 'Community monitoring dashboard',
      actions: [
        IconButton(
          tooltip: 'Sync pending records',
          onPressed: controller.pendingCount == 0
              ? null
              : controller.syncPending,
          icon: const Icon(Icons.sync),
        ),
      ],
      children: [
        _GreetingCard(
          email: controller.activeEmail ?? 'health worker',
          supabaseConfigured: controller.isSupabaseConfigured,
        ),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.08,
          children: [
            MetricCard(
              label: 'Households',
              value: '${summary.totalHouseholds}',
              icon: Icons.home_work_outlined,
            ),
            MetricCard(
              label: 'Family members',
              value: '${summary.totalFamilyMembers}',
              icon: Icons.groups_outlined,
              color: KasudloColors.secondary,
            ),
            MetricCard(
              label: 'Pending sync',
              value: '${controller.pendingCount}',
              icon: Icons.cloud_upload_outlined,
              color: KasudloColors.warning,
            ),
            MetricCard(
              label: 'Synced records',
              value: '${summary.syncedRecords}',
              icon: Icons.verified_outlined,
            ),
          ],
        ),
        _QuickActions(
          onCollect: () => context.go('/collect'),
          onReports: () => context.go('/reports'),
          onSync: controller.syncPending,
        ),
        if (controller.submissions.isEmpty)
          const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'No surveys yet',
            message:
                'Start a household assessment to build the community profile.',
          )
        else
          _RecentSubmissions(
            submissions: controller.submissions.take(4).toList(),
          ),
      ],
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.email, required this.supabaseConfigured});

  final String email;
  final bool supabaseConfigured;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: KasudloColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.health_and_safety_outlined,
              color: KasudloColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KASUDLO field duty',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: KasudloColors.muted),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: supabaseConfigured ? 'Live' : 'Local',
            color: supabaseConfigured
                ? KasudloColors.primary
                : KasudloColors.warning,
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onCollect,
    required this.onReports,
    required this.onSync,
  });

  final VoidCallback onCollect;
  final VoidCallback onReports;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onCollect,
            icon: const Icon(Icons.add_task),
            label: const Text('Collect Data'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onReports,
            icon: const Icon(Icons.monitor_heart_outlined),
            label: const Text('View Reports'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onSync,
            icon: const Icon(Icons.sync),
            label: const Text('Retry Sync'),
          ),
        ],
      ),
    );
  }
}

class _RecentSubmissions extends StatelessWidget {
  const _RecentSubmissions({required this.submissions});

  final List<HealthSubmission> submissions;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, h:mm a');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent records',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final submission in submissions) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_pin_circle_outlined),
              title: Text(submission.respondentName),
              subtitle: Text(formatter.format(submission.createdAt)),
              trailing: StatusBadge(
                label: submission.syncStatus.name,
                color: _statusColor(submission.syncStatus),
              ),
            ),
            if (submission != submissions.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Color _statusColor(SyncStatus status) {
    return switch (status) {
      SyncStatus.synced => KasudloColors.primary,
      SyncStatus.failed => KasudloColors.critical,
      SyncStatus.syncing => KasudloColors.secondary,
      _ => KasudloColors.warning,
    };
  }
}
