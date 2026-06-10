import 'package:flutter/material.dart';
import '../models.dart';

class AiGuidanceEditorDialog extends StatefulWidget {
  const AiGuidanceEditorDialog({super.key, required this.guidance});

  final AiHealthGuidance guidance;

  @override
  State<AiGuidanceEditorDialog> createState() => AiGuidanceEditorDialogState();
}

class AiGuidanceEditorDialogState extends State<AiGuidanceEditorDialog> {
  late final TextEditingController _summaryController;
  late final TextEditingController _concerningController;
  late final TextEditingController _actionsController;
  String _riskLevel = 'low';

  @override
  void initState() {
    super.initState();
    _summaryController = TextEditingController(text: widget.guidance.summary);
    _concerningController = TextEditingController(
      text: widget.guidance.concerningFindings.join('\n'),
    );
    _actionsController = TextEditingController(
      text: widget.guidance.recommendedActions.join('\n'),
    );
    _riskLevel = widget.guidance.riskLevel.toLowerCase();
    if (!['urgent', 'high', 'moderate', 'low'].contains(_riskLevel)) {
      _riskLevel = 'unknown';
    }
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _concerningController.dispose();
    _actionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Edit AI Findings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Risk Level',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _riskLevel,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('Urgent'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(
                          value: 'moderate',
                          child: Text('Moderate'),
                        ),
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'unknown',
                          child: Text('Unknown'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _riskLevel = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Summary',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _summaryController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Concerning Findings (One per line)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _concerningController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Suggested Actions (One per line)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _actionsController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: () {
                  final updated = widget.guidance.copyWith(
                    riskLevel: _riskLevel,
                    summary: _summaryController.text.trim(),
                    concerningFindings: _concerningController.text
                        .split('\n')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                    recommendedActions: _actionsController.text
                        .split('\n')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                  );
                  Navigator.of(context).pop(updated);
                },
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
