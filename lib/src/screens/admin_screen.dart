import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/app_chrome.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _searchController = TextEditingController();
  final _auditSearchController = TextEditingController();
  AccountRole _selectedRole = AccountRole.worker;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _auditSearchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(appControllerProvider).loadAdminUsers();
      ref.read(appControllerProvider).loadAuditLogs();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    _auditSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final visibleUsers = _filteredUsers(controller.adminUsers);
    final visibleAuditLogs = _filteredAuditLogs(controller.auditLogs);
    final adminCount = controller.adminUsers
        .where((user) => user.role == AccountRole.admin)
        .length;
    final workerCount = controller.adminUsers
        .where((user) => user.role == AccountRole.worker)
        .length;
    final patientCount = controller.adminUsers
        .where((user) => user.role == AccountRole.patient)
        .length;

    return AppPage(
      title: 'Admin',
      subtitle: 'Account management',
      actions: [
        IconButton(
          tooltip: 'Refresh accounts',
          onPressed: controller.isAdminLoading
              ? null
              : () => controller.loadAdminUsers(
                  search: _searchController.text.trim(),
                ),
          icon: const Icon(Icons.refresh),
        ),
      ],
      children: [
        _AdminHeader(
          email: controller.activeEmail ?? 'admin',
          supabaseConfigured: controller.isSupabaseConfigured,
        ),
        _AdminMetrics(
          total: controller.adminUsers.length,
          admins: adminCount,
          workers: workerCount,
          patients: patientCount,
        ),
        _CreateAccountCard(
          formKey: _formKey,
          nameController: _nameController,
          emailController: _emailController,
          passwordController: _passwordController,
          selectedRole: _selectedRole,
          obscurePassword: _obscurePassword,
          busy: controller.isAdminActionBusy,
          errorMessage: controller.adminErrorMessage,
          onRoleChanged: (role) => setState(() => _selectedRole = role),
          onPasswordVisibilityChanged: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          onSubmit: _submit,
        ),
        _AccountDirectoryCard(
          searchController: _searchController,
          users: visibleUsers,
          loading: controller.isAdminLoading,
        ),
        _AuditLogCard(
          searchController: _auditSearchController,
          logs: visibleAuditLogs,
          loading: controller.isAuditLoading,
          errorMessage: controller.auditErrorMessage,
          onRefresh: controller.isAuditLoading
              ? null
              : () => controller.loadAuditLogs(
                  search: _auditSearchController.text.trim(),
                ),
        ),
      ],
    );
  }

  List<AdminUser> _filteredUsers(List<AdminUser> users) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return users;
    }

    return users.where((user) {
      return [
        user.fullName,
        user.email,
        user.role.label,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  List<AuditLogEntry> _filteredAuditLogs(List<AuditLogEntry> logs) {
    final query = _auditSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return logs;
    }

    return logs.where((entry) {
      return [
        entry.actorEmail,
        entry.actorRole,
        entry.action,
        entry.entityType,
        entry.entityId ?? '',
        entry.summary,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = ref.read(appControllerProvider);
    final success = await controller.createAdminAccount(
      fullName: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      role: _selectedRole,
    );

    if (!mounted || !success) {
      return;
    }

    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    setState(() => _selectedRole = AccountRole.worker);
    await controller.loadAdminUsers(search: _searchController.text.trim());

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account created.')));
  }
}

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({
    required this.searchController,
    required this.logs,
    required this.loading,
    required this.onRefresh,
    this.errorMessage,
  });

  final TextEditingController searchController;
  final List<AuditLogEntry> logs;
  final bool loading;
  final VoidCallback? onRefresh;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final listMaxHeight = (MediaQuery.sizeOf(context).height * 0.5)
        .clamp(320.0, 560.0)
        .toDouble();
    final shouldConstrainList = logs.length > 4;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Audit log',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Refresh audit log',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Search audit log',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: KasudloColors.critical),
            ),
          ],
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(),
              ),
            )
          else if (logs.isEmpty)
            const _AuditEmptyState()
          else
            SizedBox(
              height: shouldConstrainList ? listMaxHeight : null,
              child: ListView.separated(
                shrinkWrap: !shouldConstrainList,
                physics: shouldConstrainList
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _AuditLogTile(entry: logs[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, h:mm a');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: KasudloColors.primary.withValues(alpha: 0.12),
        foregroundColor: KasudloColors.primary,
        child: const Icon(Icons.manage_history_outlined),
      ),
      title: Text(
        _auditActionLabel(entry.action),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.summary.isEmpty ? entry.entityType : entry.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${entry.actorEmail} - ${formatter.format(entry.createdAt.toLocal())}',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: KasudloColors.muted),
          ),
        ],
      ),
      trailing: StatusBadge(
        label: entry.actorRole.isEmpty ? 'user' : entry.actorRole,
        color: _auditRoleColor(entry.actorRole),
      ),
    );
  }
}

Color _auditRoleColor(String role) => switch (role) {
  'admin' => KasudloColors.secondary,
  'patient' => KasudloColors.warning,
  _ => KasudloColors.primary,
};

class _AuditEmptyState extends StatelessWidget {
  const _AuditEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          const Icon(
            Icons.manage_history_outlined,
            color: KasudloColors.primary,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            'No audit events found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'System actions will appear here after users work in the app.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: KasudloColors.muted),
          ),
        ],
      ),
    );
  }
}

String _auditActionLabel(String action) {
  final normalized = action.trim();
  if (normalized.isEmpty) {
    return 'System action';
  }

  return normalized
      .split('.')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.email, required this.supabaseConfigured});

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
              color: KasudloColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: KasudloColors.secondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin console',
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

class _AdminMetrics extends StatelessWidget {
  const _AdminMetrics({
    required this.total,
    required this.admins,
    required this.workers,
    required this.patients,
  });

  final int total;
  final int admins;
  final int workers;
  final int patients;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        label: 'Accounts',
        value: '$total',
        icon: Icons.groups_outlined,
        color: KasudloColors.primary,
      ),
      _MetricData(
        label: 'Admins',
        value: '$admins',
        icon: Icons.verified_user_outlined,
        color: KasudloColors.secondary,
      ),
      _MetricData(
        label: 'Workers',
        value: '$workers',
        icon: Icons.health_and_safety_outlined,
        color: KasudloColors.primary,
      ),
      _MetricData(
        label: 'Patients',
        value: '$patients',
        icon: Icons.person_outline,
        color: KasudloColors.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 560;
        final width = useTwoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _AdminMetricTile(metric: metric),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _AdminMetricTile extends StatelessWidget {
  const _AdminMetricTile({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(metric.icon, color: metric.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.value,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  metric.label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: KasudloColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateAccountCard extends StatelessWidget {
  const _CreateAccountCard({
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.selectedRole,
    required this.obscurePassword,
    required this.busy,
    required this.onRoleChanged,
    required this.onPasswordVisibilityChanged,
    required this.onSubmit,
    this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final AccountRole selectedRole;
  final bool obscurePassword;
  final bool busy;
  final String? errorMessage;
  final ValueChanged<AccountRole> onRoleChanged;
  final VoidCallback onPasswordVisibilityChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create account',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 340) {
                  return DropdownButtonFormField<AccountRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.manage_accounts_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: AccountRole.worker,
                        child: Text('Worker'),
                      ),
                      DropdownMenuItem(
                        value: AccountRole.patient,
                        child: Text('Patient'),
                      ),
                      DropdownMenuItem(
                        value: AccountRole.admin,
                        child: Text('Admin'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (role) {
                            if (role != null) {
                              onRoleChanged(role);
                            }
                          },
                  );
                }

                return SegmentedButton<AccountRole>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: AccountRole.worker,
                      label: Text('Worker'),
                      icon: Icon(Icons.health_and_safety_outlined),
                    ),
                    ButtonSegment(
                      value: AccountRole.patient,
                      label: Text('Patient'),
                      icon: Icon(Icons.person_outline),
                    ),
                    ButtonSegment(
                      value: AccountRole.admin,
                      label: Text('Admin'),
                      icon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                  ],
                  selected: {selectedRole},
                  onSelectionChanged: busy
                      ? null
                      : (selection) => onRoleChanged(selection.first),
                );
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a full name'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) =>
                  value == null || !value.contains('@') || !value.contains('.')
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: 'Temporary password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: onPasswordVisibilityChanged,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => value == null || value.length < 6
                  ? 'Use at least 6 characters'
                  : null,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: KasudloColors.critical),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: busy ? null : onSubmit,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt),
              label: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDirectoryCard extends StatelessWidget {
  const _AccountDirectoryCard({
    required this.searchController,
    required this.users,
    required this.loading,
  });

  final TextEditingController searchController;
  final List<AdminUser> users;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Account directory',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Search accounts',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(),
              ),
            )
          else if (users.isEmpty)
            const _DirectoryEmptyState()
          else
            _UserList(users: users),
        ],
      ),
    );
  }
}

class _DirectoryEmptyState extends StatelessWidget {
  const _DirectoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          const Icon(
            Icons.manage_accounts_outlined,
            color: KasudloColors.primary,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            'No accounts found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Created accounts will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: KasudloColors.muted),
          ),
        ],
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({required this.users});

  final List<AdminUser> users;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, yyyy');

    return Column(
      children: [
        for (final user in users) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: _roleColor(user.role).withValues(alpha: 0.12),
              foregroundColor: _roleColor(user.role),
              child: Icon(_roleIcon(user.role)),
            ),
            title: Text(
              user.fullName.isEmpty ? user.email : user.fullName,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${user.email} - ${formatter.format(user.createdAt)}',
              overflow: TextOverflow.ellipsis,
            ),
            trailing: StatusBadge(
              label: user.role.label,
              color: _roleColor(user.role),
            ),
          ),
          if (user != users.last) const Divider(height: 1),
        ],
      ],
    );
  }

  Color _roleColor(AccountRole role) => switch (role) {
    AccountRole.admin => KasudloColors.secondary,
    AccountRole.patient => KasudloColors.warning,
    AccountRole.worker => KasudloColors.primary,
  };

  IconData _roleIcon(AccountRole role) => switch (role) {
    AccountRole.admin => Icons.admin_panel_settings_outlined,
    AccountRole.patient => Icons.person_outline,
    AccountRole.worker => Icons.health_and_safety_outlined,
  };
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}
