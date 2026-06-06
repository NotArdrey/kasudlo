import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'ai_guidance_card_editor.dart';
import 'app_chrome.dart';

class AiGuidanceCard extends StatelessWidget {
  const AiGuidanceCard({
    super.key,
    required this.guidance,
    required this.isLoading,
    this.onGenerate,
    this.onEdit,
    this.errorMessage,
  });

  final AiHealthGuidance? guidance;
  final bool isLoading;
  final VoidCallback? onGenerate;
  final ValueChanged<AiHealthGuidance>? onEdit;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final currentGuidance = guidance;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI health guidance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (currentGuidance != null)
                StatusBadge(
                  label: _riskLabel(currentGuidance.riskLevel),
                  color: _riskColor(currentGuidance.riskLevel),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (onGenerate != null)
            OutlinedButton.icon(
              onPressed: isLoading ? null : onGenerate,
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology_alt_outlined),
              label: Text(
                currentGuidance == null ? 'Generate AI' : 'Refresh AI',
              ),
            ),
          if (onEdit != null && currentGuidance != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final updated = await showDialog<AiHealthGuidance>(
                  context: context,
                  builder: (ctx) =>
                      AiGuidanceEditorDialog(guidance: currentGuidance),
                );
                if (updated != null) {
                  onEdit!(updated);
                }
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Findings'),
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: const TextStyle(color: KasudloColors.critical),
            ),
          ],
          if (onGenerate != null || errorMessage != null)
            const SizedBox(height: 12),
          if (currentGuidance == null)
            Text(
              'No AI guidance yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: KasudloColors.muted),
            )
          else
            _GuidanceBody(guidance: currentGuidance),
        ],
      ),
    );
  }
}

class _GuidanceBody extends StatelessWidget {
  const _GuidanceBody({required this.guidance});

  final AiHealthGuidance guidance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (guidance.summary.trim().isNotEmpty)
          Text(guidance.summary, style: Theme.of(context).textTheme.bodyLarge),
        _BulletSection(
          title: 'Concerning findings',
          items: guidance.concerningFindings,
          icon: Icons.warning_amber_outlined,
          color: _riskColor(guidance.riskLevel),
        ),
        _BulletSection(
          title: 'Suggested actions',
          items: guidance.recommendedActions,
          icon: Icons.check_circle_outline,
          color: KasudloColors.primary,
        ),
        _CareSuggestions(suggestions: guidance.careSuggestions),
        _BulletSection(
          title: 'Follow-up questions',
          items: guidance.followUpQuestions,
          icon: Icons.help_outline,
          color: KasudloColors.secondary,
        ),
        if (guidance.emergencyWarning.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: KasudloColors.critical.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: KasudloColors.critical.withValues(alpha: 0.36),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                guidance.emergencyWarning,
                style: const TextStyle(
                  color: KasudloColors.critical,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        if (guidance.disclaimer.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            guidance.disclaimer,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: KasudloColors.muted),
          ),
        ],
      ],
    );
  }
}

class _BulletSection extends StatelessWidget {
  const _BulletSection({
    required this.title,
    required this.items,
    required this.icon,
    required this.color,
  });

  final String title;
  final List<String> items;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('- ', style: TextStyle(color: color)),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CareSuggestions extends StatelessWidget {
  const _CareSuggestions({required this.suggestions});

  final List<AiCareSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_hospital_outlined,
                size: 18,
                color: KasudloColors.critical,
              ),
              const SizedBox(width: 8),
              Text(
                'Nearby care',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final suggestion in suggestions) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: KasudloColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.name.trim().isEmpty
                          ? suggestion.type
                          : suggestion.name,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    if (suggestion.type.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        suggestion.type,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: KasudloColors.muted),
                      ),
                    ],
                    if (suggestion.reason.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(suggestion.reason),
                    ],
                    if (suggestion.locationHint.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        suggestion.locationHint,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: KasudloColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (suggestion != suggestions.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

String _riskLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return 'Unknown';
  }
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

Color _riskColor(String value) => switch (value.trim().toLowerCase()) {
  'urgent' => KasudloColors.critical,
  'high' => KasudloColors.critical,
  'moderate' => KasudloColors.warning,
  'low' => KasudloColors.primary,
  _ => KasudloColors.muted,
};
