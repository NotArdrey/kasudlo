import 'package:flutter/material.dart';

import '../theme.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: KasudloColors.muted),
                ),
            ],
          ),
          actions: actions,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverList.separated(
            itemBuilder: (context, index) => children[index],
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemCount: children.length,
          ),
        ),
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = KasudloColors.primary,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: KasudloColors.muted),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.color = KasudloColors.primary,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Icon(icon, color: KasudloColors.primary, size: 36),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
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
