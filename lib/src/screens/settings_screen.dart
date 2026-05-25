import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/app_chrome.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final preferences = controller.preferences;
    final email = controller.activeEmail ?? 'Signed in worker';
    final accountMode = controller.isSupabaseConfigured
        ? 'Supabase live project'
        : 'Local demo mode';

    return AppPage(
      title: 'Settings',
      subtitle: 'Account, preferences, and support',
      children: [
        _SettingsSection(
          title: 'Profile',
          children: [
            _AccountSummaryTile(
              email: email,
              role: controller.activeRole,
              accountMode: accountMode,
            ),
            _SettingTile(
              icon: Icons.edit_outlined,
              title: 'Edit profile',
              subtitle: 'Name and contact details',
              onTap: () => _showSettingsMessage(
                context,
                'Profile editing will be handled by your account admin.',
              ),
            ),
            _SettingTile(
              icon: Icons.key_outlined,
              title: 'Change password',
              subtitle: 'Use the reset flow for this account',
              onTap: () => _showSettingsMessage(
                context,
                'Password reset is managed through your sign-in provider.',
              ),
            ),
            _SettingTile(
              icon: Icons.alternate_email,
              title: 'Email',
              subtitle: email,
              trailing: const _ValueTrailing(label: 'Primary'),
            ),
            _SettingTile(
              icon: Icons.link_outlined,
              title: 'Connected account',
              subtitle: accountMode,
              trailing: StatusBadge(
                label: controller.isSupabaseConfigured ? 'Live' : 'Local',
                color: controller.isSupabaseConfigured
                    ? KasudloColors.primary
                    : KasudloColors.warning,
              ),
            ),
          ],
        ),
        _SettingsSection(
          title: 'Notifications',
          children: [
            _SwitchSettingTile(
              icon: Icons.notifications_active_outlined,
              title: 'Field reminders',
              subtitle: 'Assessment reminders',
              value: preferences.fieldRemindersEnabled,
              onChanged: (value) {
                controller.setFieldRemindersEnabled(value);
              },
            ),
            _SwitchSettingTile(
              icon: Icons.cloud_done_outlined,
              title: 'Sync updates',
              subtitle: 'Upload success and failure alerts',
              value: preferences.syncNotificationsEnabled,
              onChanged: (value) {
                controller.setSyncNotificationsEnabled(value);
              },
            ),
            _SwitchSettingTile(
              icon: Icons.volume_up_outlined,
              title: 'Sound alerts',
              subtitle: 'Play sounds for important alerts',
              value: preferences.soundsEnabled,
              onChanged: (value) {
                controller.setSoundsEnabled(value);
              },
            ),
          ],
        ),
        _SettingsSection(
          title: 'Preferences',
          children: [
            _SettingTile(
              icon: Icons.palette_outlined,
              title: 'Theme',
              subtitle: 'System default',
              trailing: const _ValueTrailing(label: 'System'),
              onTap: () => _showSettingsMessage(
                context,
                'Theme selection is currently set to system default.',
              ),
            ),
            _SettingTile(
              icon: Icons.language_outlined,
              title: 'Language',
              subtitle: preferences.language,
              trailing: const _ValueTrailing(
                label: 'English',
                showChevron: true,
              ),
              onTap: () => _showSettingsMessage(
                context,
                'English is the available language for this build.',
              ),
            ),
            _SwitchSettingTile(
              icon: Icons.speed_outlined,
              title: 'Data Saver',
              subtitle: 'Use less mobile data during uploads',
              value: preferences.dataSaverEnabled,
              onChanged: (value) {
                controller.setDataSaverEnabled(value);
              },
            ),
          ],
        ),
        _SettingsSection(
          title: 'Privacy & Security',
          children: [
            _SettingTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy settings',
              subtitle: 'Consent is checked before every submission',
              trailing: const _ValueTrailing(label: 'Required'),
            ),
            _SettingTile(
              icon: Icons.devices_outlined,
              title: 'Login sessions',
              subtitle: 'Current device',
              trailing: const _ValueTrailing(label: 'Active'),
              onTap: () => _showSettingsMessage(
                context,
                'Session management will appear here when available.',
              ),
            ),
            _SettingTile(
              icon: Icons.verified_user_outlined,
              title: 'Account security',
              subtitle: '${controller.activeRole.label} access',
              trailing: const Icon(
                Icons.check_circle,
                color: KasudloColors.primary,
              ),
            ),
            _SettingTile(
              icon: Icons.policy_outlined,
              title: 'Consent and terms',
              subtitle: 'Review app consent requirements',
              onTap: () => _showSettingsMessage(
                context,
                'Consent details are shown during household submission.',
              ),
            ),
          ],
        ),
        _SettingsSection(
          title: 'Offline & Sync',
          footer: ElevatedButton.icon(
            onPressed: controller.retryableSyncCount == 0
                ? null
                : () {
                    controller.syncPending();
                  },
            icon: const Icon(Icons.sync),
            label: const Text('Retry Pending Sync'),
          ),
          children: [
            _SettingTile(
              icon: Icons.cloud_queue_outlined,
              title: 'Sync status',
              subtitle: _pendingLabel(
                controller.pendingCount,
                controller.conflictCount,
              ),
              trailing: StatusBadge(
                label: controller.conflictCount > 0
                    ? 'Review'
                    : controller.pendingCount == 0
                    ? 'Clear'
                    : 'Pending',
                color: controller.pendingCount == 0
                    ? KasudloColors.primary
                    : controller.conflictCount > 0
                    ? KasudloColors.critical
                    : KasudloColors.warning,
              ),
            ),
            _SwitchSettingTile(
              icon: Icons.offline_bolt_outlined,
              title: 'Offline mode',
              subtitle: 'Save work when connection is unavailable',
              value: preferences.offlineModeEnabled,
              onChanged: (value) {
                controller.setOfflineModeEnabled(value);
              },
            ),
            _SettingTile(
              icon: Icons.folder_copy_outlined,
              title: 'Downloaded data',
              subtitle: '${controller.submissions.length} local records',
              trailing: const _ValueTrailing(label: 'On device'),
            ),
          ],
        ),
        _SettingsSection(
          title: 'Permissions',
          children: [
            const _SettingTile(
              icon: Icons.location_on_outlined,
              title: 'Location access',
              subtitle: 'Ask when needed',
              trailing: _ValueTrailing(label: 'Optional'),
            ),
            const _SettingTile(
              icon: Icons.photo_camera_outlined,
              title: 'Camera and photos',
              subtitle: 'Not enabled',
              trailing: _ValueTrailing(label: 'Off'),
            ),
            const _SettingTile(
              icon: Icons.health_and_safety_outlined,
              title: 'Health data',
              subtitle: 'Stored for authorized care work',
              trailing: _ValueTrailing(label: 'Protected'),
            ),
          ],
        ),
        _SettingsSection(
          title: 'Help & Support',
          children: [
            _SettingTile(
              icon: Icons.help_outline,
              title: 'Help Center',
              subtitle: 'Guides and common questions',
              onTap: () => _showSettingsMessage(
                context,
                'Help Center content is not bundled in this build.',
              ),
            ),
            _SettingTile(
              icon: Icons.contact_support_outlined,
              title: 'Contact support',
              subtitle: 'Ask for help with account or sync issues',
              onTap: () => _showSettingsMessage(
                context,
                'Contact your KASUDLO administrator for support.',
              ),
            ),
            _SettingTile(
              icon: Icons.bug_report_outlined,
              title: 'Report a problem',
              subtitle: 'Share an issue with the app team',
              onTap: () => _showSettingsMessage(
                context,
                'Problem reports will be available in a future support flow.',
              ),
            ),
            _SettingTile(
              icon: Icons.quiz_outlined,
              title: 'FAQs',
              subtitle: 'Answers for field workers',
              onTap: () => _showSettingsMessage(
                context,
                'FAQs are not bundled in this build.',
              ),
            ),
          ],
        ),
        _SettingsSection(
          title: 'About',
          children: [
            const _SettingTile(
              icon: Icons.info_outline,
              title: 'App version',
              subtitle: '1.0.0+1',
              trailing: _ValueTrailing(label: 'Current'),
            ),
            _SettingTile(
              icon: Icons.description_outlined,
              title: 'Terms & Conditions',
              subtitle: 'App usage terms',
              onTap: () => _showSettingsMessage(
                context,
                'Terms and conditions are not bundled in this build.',
              ),
            ),
            _SettingTile(
              icon: Icons.shield_outlined,
              title: 'Privacy Policy',
              subtitle: 'Data handling information',
              onTap: () => _showSettingsMessage(
                context,
                'Privacy policy content is not bundled in this build.',
              ),
            ),
            _SettingTile(
              icon: Icons.article_outlined,
              title: 'Licenses',
              subtitle: 'Open source notices',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'KASUDLO',
                applicationVersion: '1.0.0+1',
              ),
            ),
          ],
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: controller.isBusy
                    ? null
                    : () {
                        controller.signOut();
                      },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _showSettingsMessage(
                  context,
                  'Ask your administrator before deleting this account.',
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete Account'),
                style: TextButton.styleFrom(
                  foregroundColor: KasudloColors.critical,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _pendingLabel(int count, int conflictCount) {
    if (conflictCount == 1) {
      return '1 record needs review before sync';
    }
    if (conflictCount > 1) {
      return '$conflictCount records need review before sync';
    }
    if (count == 1) {
      return '1 pending record';
    }
    return '$count pending records';
  }

  void _showSettingsMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) const Divider(height: 1),
          ],
          if (footer != null) ...[
            const Divider(height: 1),
            const SizedBox(height: 12),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _AccountSummaryTile extends StatelessWidget {
  const _AccountSummaryTile({
    required this.email,
    required this.role,
    required this.accountMode,
  });

  final String email;
  final AccountRole role;
  final String accountMode;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: KasudloColors.primary.withValues(alpha: 0.12),
        foregroundColor: KasudloColors.primary,
        child: const Icon(Icons.person_outline),
      ),
      title: Text(email, overflow: TextOverflow.ellipsis),
      subtitle: Text(accountMode),
      trailing: StatusBadge(label: role.label),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 40,
      leading: _SettingIcon(icon: icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing:
          trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
      onTap: onTap,
    );
  }
}

class _SwitchSettingTile extends StatelessWidget {
  const _SwitchSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 40,
      leading: _SettingIcon(icon: icon),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: KasudloColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: KasudloColors.primary, size: 22),
    );
  }
}

class _ValueTrailing extends StatelessWidget {
  const _ValueTrailing({required this.label, this.showChevron = false});

  final String label;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 96),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: KasudloColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (showChevron) const Icon(Icons.chevron_right),
      ],
    );
  }
}
