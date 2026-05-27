import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/ai_guidance_card.dart';
import '../widgets/app_chrome.dart';

class FindingsScreen extends ConsumerWidget {
  const FindingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final findings = controller.patientFindings;

    return AppPage(
      title: 'My Health Findings',
      subtitle: 'Review assessments from your community health worker',
      actions: [
        IconButton(
          onPressed: () {
            ref.read(appControllerProvider).loadPatientFindings();
          },
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
      ],
      children: [
        if (controller.isPatientFindingsLoading)
          const Padding(
            padding: EdgeInsets.all(40.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (findings.isEmpty)
          const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'No findings yet',
            message: 'Your health assessments will appear here once submitted by a nurse.',
          )
        else
          for (final submission in findings)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_outlined, color: KasudloColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Assessment on ${DateFormat.yMMMd().format(submission.createdAt.toLocal())}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AiGuidanceCard(
                      guidance: submission.aiGuidance,
                      isLoading: false,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
