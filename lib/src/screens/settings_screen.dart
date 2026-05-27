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
    final email = controller.activeEmail ?? 'Signed in nurse';
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
