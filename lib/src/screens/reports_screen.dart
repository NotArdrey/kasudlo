import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../assessment_options.dart';
import '../models.dart';
import '../services/report_exporter.dart';
import '../state/app_controller.dart';
import '../survey_schema.dart';
import '../theme.dart';
import '../widgets/account_request_fields.dart';
import '../widgets/ai_guidance_card.dart';
import '../widgets/app_chrome.dart';
import '../widgets/survey_form.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final summary = controller.summary;

    return AppPage(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: KasudloColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/collect'),
        icon: const Icon(Icons.add),
        label: const Text('Collect'),
      ),
      title: 'Reports',
      subtitle: 'Summarized community health data',
      children: [
        if (!summary.hasData)
          const EmptyState(
            icon: Icons.bar_chart_outlined,
            title: 'No report data',
            message:
                'Submitted or saved forms will appear in the monitoring report.',
          )
        else ...[
          _ReportRecordsCard(
            submissions: controller.activeSubmissions,
            onView: (submission) => _showViewSheet(context, submission),
            onEdit: (submission) => _showEditSheet(context, ref, submission),
            onDelete: (submission) => _confirmDelete(context, ref, submission),
          ),
        ],
      ],
    );
  }

  Future<void> _showViewSheet(
    BuildContext context,
    HealthSubmission submission,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ViewReportSheet(submission: submission),
    );
  }

  Future<void> _showEditSheet(
    BuildContext context,
    WidgetRef ref,
    HealthSubmission submission,
  ) async {
    final updated = await showModalBottomSheet<HealthSubmission>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _EditReportSheet(submission: submission),
    );

    if (updated == null || !context.mounted) {
      return;
    }

    await ref.read(appControllerProvider).updateReportSubmission(updated);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Report record updated.')));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    HealthSubmission submission,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete report record?'),
        content: Text('Remove ${submission.respondentName} from reports?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Confirm Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await ref
        .read(appControllerProvider)
        .deleteLocalSubmission(submission.clientSubmissionId);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Report record deleted.')));
  }
}

class _ReportRecordsCard extends ConsumerStatefulWidget {
  const _ReportRecordsCard({
    required this.submissions,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final List<HealthSubmission> submissions;
  final ValueChanged<HealthSubmission> onView;
  final ValueChanged<HealthSubmission> onEdit;
  final ValueChanged<HealthSubmission> onDelete;

  @override
  ConsumerState<_ReportRecordsCard> createState() => _ReportRecordsCardState();
}

class _ReportRecordsCardState extends ConsumerState<_ReportRecordsCard> {
  final _searchController = TextEditingController();
  final _selectedSubmissionIds = <String>{};
  String _query = '';
  ReportExportFormat? _exportingFormat;
  bool _isAnalyzingWithAi = false;

  @override
  void didUpdateWidget(covariant _ReportRecordsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.submissions
        .map((submission) => submission.clientSubmissionId)
        .toSet();
    _selectedSubmissionIds.removeWhere((id) => !currentIds.contains(id));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, yyyy');
    final filteredSubmissions = widget.submissions
        .where(
          (submission) => _matchesReportSearch(
            submission: submission,
            query: _query,
            formatter: formatter,
          ),
        )
        .toList();
    final countLabel = _query.trim().isEmpty
        ? '${widget.submissions.length} records'
        : '${filteredSubmissions.length} of ${widget.submissions.length}';
    final selectedSubmissions = widget.submissions
        .where(
          (submission) =>
              _selectedSubmissionIds.contains(submission.clientSubmissionId),
        )
        .toList();
    final selectedCount = selectedSubmissions.length;
    final isExporting = _exportingFormat != null;
    final listMaxHeight = (MediaQuery.sizeOf(context).height * 0.48)
        .clamp(320.0, 560.0)
        .toDouble();
    final shouldConstrainList = filteredSubmissions.length > 4;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Report records',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                countLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: KasudloColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (false) ...[
                OutlinedButton.icon(
                  onPressed: selectedCount == 0 || isExporting
                      ? null
                      : () => _exportSelected(ReportExportFormat.pdf),
                  icon: _ExportButtonIcon(
                    format: ReportExportFormat.pdf,
                    exportingFormat: _exportingFormat,
                    idleIcon: Icons.picture_as_pdf_outlined,
                  ),
                  label: const Text('Export PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: selectedCount == 0 || isExporting
                      ? null
                      : () => _exportSelected(ReportExportFormat.docs),
                  icon: _ExportButtonIcon(
                    format: ReportExportFormat.docs,
                    exportingFormat: _exportingFormat,
                    idleIcon: Icons.description_outlined,
                  ),
                  label: const Text('Export Docs'),
                ),
              ],
              TextButton.icon(
                onPressed: filteredSubmissions.isEmpty
                    ? null
                    : () => _selectFiltered(filteredSubmissions),
                icon: const Icon(Icons.select_all_outlined),
                label: const Text('Select shown'),
              ),
              TextButton.icon(
                onPressed: selectedCount == 0 || _isAnalyzingWithAi ? null : _clearSelection,
                icon: const Icon(Icons.clear_outlined),
                label: const Text('Clear'),
              ),
              OutlinedButton.icon(
                onPressed: selectedCount == 0 || isExporting || _isAnalyzingWithAi
                    ? null
                    : () => _analyzeSelectedWithAi(),
                icon: _isAnalyzingWithAi 
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.2)) 
                    : const Icon(Icons.psychology_outlined),
                label: const Text('Analyze with AI'),
              ),
              Text(
                selectedCount == 1 ? '1 selected' : '$selectedCount selected',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: KasudloColors.muted),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _exportingFormat == null && !_isAnalyzingWithAi
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey(_exportingFormat ?? _isAnalyzingWithAi),
                    padding: const EdgeInsets.only(top: 12),
                    child: _exportingFormat != null 
                        ? _ExportProgressStatus(format: _exportingFormat!)
                        : const _AiProgressStatus(),
                  ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              labelText: 'Search report records',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear report search',
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          if (filteredSubmissions.isEmpty)
            const _NoMatchingRecords()
          else
            SizedBox(
              height: shouldConstrainList ? listMaxHeight : null,
              child: ListView.separated(
                shrinkWrap: !shouldConstrainList,
                physics: shouldConstrainList
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: filteredSubmissions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final submission = filteredSubmissions[index];
                  return _ReportRecordTile(
                    submission: submission,
                    formatter: formatter,
                    selected: _selectedSubmissionIds.contains(
                      submission.clientSubmissionId,
                    ),
                    onSelectedChanged: (selected) =>
                        _toggleSelection(submission, selected),
                    onView: () => widget.onView(submission),
                    onEdit: () => widget.onEdit(submission),
                    onDelete: () => widget.onDelete(submission),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _toggleSelection(HealthSubmission submission, bool selected) {
    setState(() {
      if (selected) {
        _selectedSubmissionIds.add(submission.clientSubmissionId);
      } else {
        _selectedSubmissionIds.remove(submission.clientSubmissionId);
      }
    });
  }

  void _selectFiltered(List<HealthSubmission> submissions) {
    setState(() {
      for (final submission in submissions) {
        _selectedSubmissionIds.add(submission.clientSubmissionId);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedSubmissionIds.clear());
  }

  Future<void> _exportSelected(ReportExportFormat format) async {
    final selectedSubmissions = widget.submissions
        .where(
          (submission) =>
              _selectedSubmissionIds.contains(submission.clientSubmissionId),
        )
        .toList();

    if (selectedSubmissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one report record.')),
      );
      return;
    }

    setState(() => _exportingFormat = format);

    try {
      final result = await exportReportRecords(
        submissions: selectedSubmissions,
        format: format,
      );
      if (!mounted) {
        return;
      }

      final recordLabel = result.recordCount == 1 ? 'record' : 'records';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${result.recordCount} $recordLabel to ${result.format.label}: ${result.savedLocation}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export ${format.label}.')),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingFormat = null);
      }
    }
  }

  Future<void> _analyzeSelectedWithAi() async {
    final selectedSubmissions = widget.submissions
        .where(
          (submission) =>
              _selectedSubmissionIds.contains(submission.clientSubmissionId),
        )
        .toList();

    if (selectedSubmissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one report record to analyze.')),
      );
      return;
    }

    setState(() => _isAnalyzingWithAi = true);

    var successCount = 0;
    var failureCount = 0;
    
    try {
      final controller = ref.read(appControllerProvider);
      
      for (final submission in selectedSubmissions) {
        if (!mounted) break;
        final guidance = await controller.analyzeAndSaveSubmissionGuidance(submission);
        if (guidance != null) {
          successCount++;
        } else {
          failureCount++;
        }
      }

      if (!mounted) return;
      
      final label = successCount == 1 ? 'record' : 'records';
      final failureText = failureCount > 0 ? '\n$failureCount failed.' : '';
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Analysis Complete'),
          content: Text('Successfully analyzed $successCount $label with AI.$failureText'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to analyze records with AI.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isAnalyzingWithAi = false);
      }
    }
  }
}

class _ExportButtonIcon extends StatelessWidget {
  const _ExportButtonIcon({
    required this.format,
    required this.exportingFormat,
    required this.idleIcon,
  });

  final ReportExportFormat format;
  final ReportExportFormat? exportingFormat;
  final IconData idleIcon;

  @override
  Widget build(BuildContext context) {
    if (exportingFormat != format) {
      return Icon(idleIcon);
    }

    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2.2),
    );
  }
}

class _ExportProgressStatus extends StatelessWidget {
  const _ExportProgressStatus({required this.format});

  final ReportExportFormat format;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Preparing ${format.label} download...',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiProgressStatus extends StatelessWidget {
  const _AiProgressStatus();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Analyzing selected records with AI...',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRecordTile extends StatelessWidget {
  const _ReportRecordTile({
    required this.submission,
    required this.formatter,
    required this.selected,
    required this.onSelectedChanged,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final HealthSubmission submission;
  final DateFormat formatter;
  final bool selected;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: selected,
        onChanged: (value) => onSelectedChanged(value ?? false),
      ),
      title: Text(submission.respondentName, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${formatter.format(submission.createdAt)} - ${submission.familyMembersCount} members',
        overflow: TextOverflow.ellipsis,
      ),
      trailing: SizedBox(
        width: 144,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'View report record',
              onPressed: onView,
              icon: const Icon(Icons.info_outline),
            ),
            IconButton(
              tooltip: 'Edit report record',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete report record',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

final _profileReportFields = surveyHeaderFields
    .where(
      (field) =>
          !{'informant', 'address', 'number_of_family'}.contains(field.key),
    )
    .toList();

final _familyMembersReportField = tableField(
  'family_members',
  'Family members',
  familyMemberFields,
  addButtonLabel: 'Add Member',
);

final _socioEconomicReportFields = [
  ...socialIndicatorFields,
  ...economicIndicatorFields,
  ...culturalIndicatorFields,
  ...environmentalIndicatorFields,
];

final _healthPatternReportFields = [
  ...lifestylePracticeFields,
  ...nutritionalStatusFields,
  ...beliefsPracticeFields,
  ...communityHealthProgramFields,
  ...healthIndicatorFields,
];

class _ViewReportSheet extends ConsumerStatefulWidget {
  const _ViewReportSheet({required this.submission});

  final HealthSubmission submission;

  @override
  ConsumerState<_ViewReportSheet> createState() => _ViewReportSheetState();
}

class _ViewReportSheetState extends ConsumerState<_ViewReportSheet> {
  bool _isAnalyzing = false;

  Future<void> _analyzeWithAi() async {
    setState(() => _isAnalyzing = true);
    try {
      final controller = ref.read(appControllerProvider);
      final currentSubmission = controller.activeSubmissions.firstWhere(
        (s) => s.clientSubmissionId == widget.submission.clientSubmissionId,
        orElse: () => widget.submission,
      );
      final guidance = await controller.analyzeAndSaveSubmissionGuidance(currentSubmission);
      if (!mounted) return;
      if (guidance != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully generated AI guidance.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate AI guidance.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error generating AI guidance.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final currentSubmission = controller.activeSubmissions.firstWhere(
      (s) => s.clientSubmissionId == widget.submission.clientSubmissionId,
      orElse: () => widget.submission,
    );

    final detailGroups = _reportDetailGroups(
      currentSubmission,
      isAnalyzingAi: _isAnalyzing,
      onAnalyzeAi: _analyzeWithAi,
      onEditAiFindings: (updated) {
        ref.read(appControllerProvider).updateReportSubmission(
          currentSubmission.copyWith(aiGuidance: updated),
        );
      },
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'View report record',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final group in detailGroups) ...[
                group,
                const SizedBox(height: 16),
              ],
              _ReportEditHistory(entries: currentSubmission.editHistory),
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _reportDetailGroups(
  HealthSubmission submission, {
  bool isAnalyzingAi = false,
  VoidCallback? onAnalyzeAi,
  ValueChanged<AiHealthGuidance>? onEditAiFindings,
}) {
  final surveyData = _surveyDataWithSubmissionFields(submission);
  final groups = <Widget>[];

  void addGroup(String title, List<Widget> children) {
    if (children.isEmpty) {
      return;
    }
    groups.add(_ReportDetailGroup(title: title, children: children));
  }

  void addSurveyGroup(String title, List<SurveyField> fields) {
    addGroup(title, _surveyResponseWidgets(fields, surveyData));
  }

  final aiGuidance = submission.aiGuidance;
  if (aiGuidance != null) {
    groups.add(AiGuidanceCard(
      guidance: aiGuidance,
      isLoading: false,
      onEdit: onEditAiFindings,
    ));
  } else if (onAnalyzeAi != null) {
    groups.add(
      _ReportDetailGroup(
        title: 'AI Analysis',
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: isAnalyzingAi ? null : onAnalyzeAi,
              icon: isAnalyzingAi 
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.psychology_outlined),
              label: Text(isAnalyzingAi ? 'Analyzing...' : 'Generate AI Guidance'),
            ),
          ),
        ],
      ),
    );
  }

  addGroup('I. Demographic Variable', [
    _ReportDetailRow(
      label: 'Informant',
      value: _displayValue(submission.respondentName),
    ),
    _ReportDetailRow(
      label: 'Age',
      value: submission.respondentAge?.toString() ?? 'None',
    ),
    _ReportDetailRow(
      label: 'Address',
      value: _displayValue(submission.address),
    ),
    _ReportDetailRow(
      label: 'Family members',
      value: '${submission.familyMembersCount}',
    ),
    ..._surveyResponseWidgets(_profileReportFields, surveyData),
    ..._accountDetailRows(surveyData),
    _SurveyTableResponse(
      field: _familyMembersReportField,
      rows: _reportFamilyRows(submission),
    ),
    ..._surveyResponseWidgets(familyProfileFields, surveyData),
  ]);

  addSurveyGroup(
    'II. Socio-economic, Cultural and Environmental',
    _socioEconomicReportFields,
  );
  addSurveyGroup('III. Health and Illness Pattern', _healthPatternReportFields);
  addSurveyGroup('IV. Health Resource', healthResourceFields);
  addSurveyGroup(
    'V. Political/Leadership Patterns',
    politicalLeadershipPatternFields,
  );
  addGroup(
    'VI. Any concerns/suggestions regarding the life style in the area in general',
    [
      ..._surveyResponseWidgets(lifestyleConcernSuggestionFields, surveyData),
      _ReportDetailRow(
        label: 'Community concerns',
        value: _displayList(submission.communityConcerns),
      ),
      _ReportDetailRow(label: 'Notes', value: _displayValue(submission.notes)),
    ],
  );
  addGroup('Record details', [
    _ReportDetailRow(
      label: 'Date recorded',
      value: _formatReportDateTime(submission.createdAt),
    ),
    _ReportDetailRow(label: 'Sync status', value: submission.syncStatus.name),
    if ((submission.lastError ?? '').trim().isNotEmpty)
      _ReportDetailRow(
        label: 'Sync note',
        value: _displayValue(submission.lastError ?? ''),
      ),
  ]);

  return groups;
}

List<Widget> _accountDetailRows(Map<String, dynamic> surveyData) {
  final createRequested = accountCreateRequestedFromData(surveyData);
  return [
    _ReportDetailRow(
      label: 'Create account',
      value: createRequested ? 'Yes' : 'No',
    ),
    _ReportDetailRow(
      label: 'Account email',
      value: _displayValue(accountEmailFromData(surveyData)),
    ),
    _ReportDetailRow(
      label: 'Password',
      value: createRequested ? 'Not stored' : 'None',
    ),
  ];
}

class _ReportDetailGroup extends StatelessWidget {
  const _ReportDetailGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _ReportDetailRow extends StatelessWidget {
  const _ReportDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: KasudloColors.muted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ReportEditHistory extends StatelessWidget {
  const _ReportEditHistory({required this.entries, this.onEdit, this.onDelete});

  final List<ReportEditHistoryEntry> entries;
  final ValueChanged<int>? onEdit;
  final ValueChanged<int>? onDelete;

  @override
  Widget build(BuildContext context) {
    final sortedEntries = List.generate(
      entries.length,
      (index) => _IndexedReportEditHistoryEntry(index, entries[index]),
    )..sort((a, b) => b.entry.editedAt.compareTo(a.entry.editedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Edit history', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (sortedEntries.isEmpty)
          Text(
            'No edits recorded yet.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: KasudloColors.muted),
          )
        else
          for (var index = 0; index < sortedEntries.length; index++) ...[
            _ReportEditHistoryTile(
              entry: sortedEntries[index].entry,
              onEdit: onEdit == null
                  ? null
                  : () => onEdit!(sortedEntries[index].index),
              onDelete: onDelete == null
                  ? null
                  : () => onDelete!(sortedEntries[index].index),
            ),
            if (index != sortedEntries.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _IndexedReportEditHistoryEntry {
  const _IndexedReportEditHistoryEntry(this.index, this.entry);

  final int index;
  final ReportEditHistoryEntry entry;
}

class _ReportEditHistoryTile extends StatelessWidget {
  const _ReportEditHistoryTile({
    required this.entry,
    this.onEdit,
    this.onDelete,
  });

  final ReportEditHistoryEntry entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final editedBy = entry.editedBy?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: KasudloColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _formatReportDateTime(entry.editedAt),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    tooltip: 'Edit history entry',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete history entry',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            if (editedBy != null && editedBy.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Edited by $editedBy',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: KasudloColors.muted),
              ),
            ],
            const SizedBox(height: 6),
            Text(entry.summary),
            if (entry.changes.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final change in entry.changes)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '- $change',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoMatchingRecords extends StatelessWidget {
  const _NoMatchingRecords();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: KasudloColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.search_off_outlined, color: KasudloColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No report records match this search.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: KasudloColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _matchesReportSearch({
  required HealthSubmission submission,
  required String query,
  required DateFormat formatter,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return true;
  }

  final searchableText = [
    submission.respondentName,
    submission.address,
    formatter.format(submission.createdAt),
    '${submission.familyMembersCount} members',
    submission.vaccinationStatus,
    submission.waterSanitation,
    submission.nutritionalStatus,
    ...submission.healthProblems,
    ...submission.communityConcerns,
    ...submission.surveyData.values.map(_reportValueLabel),
  ].join(' ').toLowerCase();

  return normalizedQuery
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .every(searchableText.contains);
}

String _formatReportDateTime(DateTime value) {
  return DateFormat('MMM d, yyyy h:mm a').format(value.toLocal());
}

String _displayValue(String value) {
  final normalizedValue = value.trim();
  return normalizedValue.isEmpty ? 'None' : normalizedValue;
}

String _displayList(List<String> values) {
  return values.isEmpty ? 'None' : values.join(', ');
}

Map<String, dynamic> _surveyDataWithSubmissionFields(
  HealthSubmission submission,
) {
  final surveyData = Map<String, dynamic>.from(submission.surveyData);
  final familyRows = _reportFamilyRows(submission);

  surveyData['informant'] = submission.respondentName;
  surveyData['address'] = submission.address;
  surveyData['number_of_family'] = submission.familyMembersCount;
  surveyData['health_problems'] = submission.healthProblems;
  surveyData['vaccination_status'] = submission.vaccinationStatus;
  surveyData['water_sanitation'] = submission.waterSanitation;
  surveyData['nutritional_status'] = submission.nutritionalStatus;
  surveyData['community_concerns'] = submission.communityConcerns;
  surveyData['notes'] = submission.notes;
  surveyData[accountCreateRequestedKey] = accountCreateRequestedFromData(
    surveyData,
  );
  surveyData[accountEmailKey] = accountEmailFromData(surveyData);
  if (familyRows.isNotEmpty) {
    surveyData['family_members'] = familyRows;
  }

  return surveyData;
}

List<Map<String, dynamic>> _reportFamilyRows(HealthSubmission submission) {
  final surveyRows = _reportRows(submission.surveyData['family_members']);
  if (surveyRows.isNotEmpty) {
    return surveyRows;
  }

  return [
    for (var index = 0; index < submission.familyMembers.length; index++)
      _familyMemberSurveyRow(submission.familyMembers[index], index),
  ];
}

Map<String, dynamic> _familyMemberSurveyRow(FamilyMember member, int index) {
  final row = Map<String, dynamic>.from(member.details);
  if (!_reportValueHasContent(row['member_no'])) {
    row['member_no'] = index + 1;
  }
  if (!_reportValueHasContent(row['name_of_family_member'])) {
    row['name_of_family_member'] = member.name;
  }
  if (!_reportValueHasContent(row['relationship_to_head'])) {
    row['relationship_to_head'] = member.relationship;
  }
  if (!_reportValueHasContent(row['age']) && member.age != null) {
    row['age'] = member.age;
  }
  return row;
}

List<FamilyMember> _familyMembersFromSurveyData(
  Map<String, dynamic> surveyData,
) {
  return _reportRows(
    surveyData['family_members'],
  ).map(FamilyMember.fromSurveyData).toList();
}

List<Widget> _surveyResponseWidgets(
  List<SurveyField> fields,
  Map<String, dynamic> data,
) {
  final widgets = <Widget>[];

  for (final field in fields) {
    if (field.type == SurveyFieldType.note ||
        field.type == SurveyFieldType.heading) {
      continue;
    }

    if (!_fieldVisibleInReport(field, data)) {
      continue;
    }

    final value = data[field.key];

    if (field.type == SurveyFieldType.repeatableTable) {
      final rows = _reportRows(value);
      widgets.add(_SurveyTableResponse(field: field, rows: rows));
      continue;
    }

    widgets.add(
      _ReportDetailRow(
        label: field.label,
        value: _reportValueHasContent(value)
            ? _reportValueLabel(value)
            : 'None',
      ),
    );
  }

  return widgets;
}

bool _fieldVisibleInReport(SurveyField field, Map<String, dynamic> data) {
  final visibility = field.visibleWhen;
  if (visibility == null || visibility.matches(data)) {
    return true;
  }
  return _reportValueHasContent(data[field.key]);
}

class _SurveyTableResponse extends StatelessWidget {
  const _SurveyTableResponse({required this.field, required this.rows});

  final SurveyField field;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: KasudloColors.muted),
          ),
          const SizedBox(height: 4),
          if (rows.isEmpty)
            Text(
              'No rows added yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: KasudloColors.muted),
            )
          else
            for (var index = 0; index < rows.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SurveyTableRowCard(
                  index: index,
                  fields: field.fields,
                  row: rows[index],
                ),
              ),
        ],
      ),
    );
  }
}

class _SurveyTableRowCard extends StatelessWidget {
  const _SurveyTableRowCard({
    required this.index,
    required this.fields,
    required this.row,
  });

  final int index;
  final List<SurveyField> fields;
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Member ${index + 1}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final field in fields)
            if (_reportValueHasContent(row[field.key]))
              _ReportDetailRow(
                label: field.label,
                value: _reportValueLabel(row[field.key]),
              ),
        ],
      ),
    );
  }
}

String _reportValueLabel(Object? value) {
  if (value is List) {
    return value.map(_reportValueLabel).join(', ');
  }
  if (value is Map) {
    return value.entries
        .where((entry) => _reportValueHasContent(entry.value))
        .map((entry) => '${entry.key}: ${_reportValueLabel(entry.value)}')
        .join('; ');
  }
  if (value is bool) {
    return value ? 'Yes' : 'No';
  }
  return '$value'.trim();
}

List<Map<String, dynamic>> _reportRows(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
  return const [];
}

Map<String, dynamic> _compactReportSurveyData(Map<String, dynamic> data) {
  final compacted = <String, dynamic>{};
  for (final entry in data.entries) {
    final value = _compactReportValue(entry.value);
    if (_reportValueHasContent(value)) {
      compacted[entry.key] = value;
    }
  }
  return compacted;
}

Object? _compactReportValue(Object? value) {
  if (value is String) {
    return value.trim();
  }
  if (value is List) {
    final items = <Object?>[];
    for (final item in value) {
      final compactedItem = _compactReportValue(item);
      if (_reportValueHasContent(compactedItem)) {
        items.add(compactedItem);
      }
    }
    return items;
  }
  if (value is Map) {
    return _compactReportSurveyData(Map<String, dynamic>.from(value));
  }
  return value;
}

bool _reportValueHasContent(Object? value) {
  if (value == null) {
    return false;
  }
  if (value is String) {
    return value.trim().isNotEmpty;
  }
  if (value is List) {
    return value.isNotEmpty;
  }
  if (value is Map) {
    return value.isNotEmpty;
  }
  return true;
}

class _EditReportSheet extends StatefulWidget {
  const _EditReportSheet({required this.submission});

  final HealthSubmission submission;

  @override
  State<_EditReportSheet> createState() => _EditReportSheetState();
}

class _EditReportSheetState extends State<_EditReportSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _addressController;
  late final TextEditingController _familyCountController;
  late final TextEditingController _notesController;
  late final TextEditingController _accountEmailController;
  late final TextEditingController _accountPasswordController;
  late final TextEditingController _accountConfirmPasswordController;
  late final Set<String> _healthProblems;
  late final Set<String> _communityConcerns;
  late final Map<String, dynamic> _surveyData;
  late final List<ReportEditHistoryEntry> _editHistory;
  late String _vaccinationStatus;
  late String _waterSanitation;
  late String _nutritionalStatus;
  late bool _accountCreateRequested;

  @override
  void initState() {
    super.initState();
    final submission = widget.submission;
    _nameController = TextEditingController(text: submission.respondentName);
    _ageController = TextEditingController(
      text: submission.respondentAge?.toString() ?? '',
    );
    _addressController = TextEditingController(text: submission.address);
    _familyCountController = TextEditingController(
      text: submission.familyMembersCount.toString(),
    );
    _notesController = TextEditingController(text: submission.notes);
    _healthProblems = submission.healthProblems.toSet();
    _communityConcerns = submission.communityConcerns.toSet();
    _surveyData = _surveyDataWithSubmissionFields(submission);
    _editHistory = submission.editHistory.toList();
    _accountCreateRequested = accountCreateRequestedFromData(_surveyData);
    _accountEmailController = TextEditingController(
      text: accountEmailFromData(_surveyData),
    );
    _accountPasswordController = TextEditingController();
    _accountConfirmPasswordController = TextEditingController();
    _vaccinationStatus = submission.vaccinationStatus.trim().isEmpty
        ? 'Unknown'
        : submission.vaccinationStatus;
    _waterSanitation = _optionValue(
      waterSanitationOptions,
      submission.waterSanitation,
    );
    _nutritionalStatus = _optionValue(
      nutritionalStatusOptions,
      submission.nutritionalStatus,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _familyCountController.dispose();
    _notesController.dispose();
    _accountEmailController.dispose();
    _accountPasswordController.dispose();
    _accountConfirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Edit report record',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Save report record',
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._editSections(),
                const SizedBox(height: 18),
                _ReportEditHistory(
                  entries: _editHistory,
                  onEdit: _editHistoryEntry,
                  onDelete: _confirmDeleteEditHistoryEntry,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _editSections() {
    return [
      _ReportFormExpansion(
        title: 'I. Demographic Variable',
        initiallyExpanded: true,
        children: [
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Informant'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter informant'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Age'),
            validator: (value) {
              final rawValue = value?.trim() ?? '';
              if (rawValue.isEmpty) {
                return null;
              }
              return int.tryParse(rawValue) == null ? 'Enter a number' : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Address'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter an address'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _familyCountController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Family members'),
            validator: (value) {
              final count = int.tryParse(value?.trim() ?? '');
              return count == null || count <= 0 ? 'Enter a count' : null;
            },
          ),
          const SizedBox(height: 12),
          SurveyFieldList(
            fields: _profileReportFields,
            data: _surveyData,
            onChanged: _setSurveyDataValue,
            path: 'report_edit_demographic_profile',
          ),
          const SizedBox(height: 12),
          AccountRequestFields(
            createRequested: _accountCreateRequested,
            onCreateRequestedChanged: (value) =>
                setState(() => _accountCreateRequested = value),
            emailController: _accountEmailController,
            passwordController: _accountPasswordController,
            confirmPasswordController: _accountConfirmPasswordController,
          ),
          const SizedBox(height: 12),
          SurveyFieldList(
            fields: [_familyMembersReportField],
            data: _surveyData,
            onChanged: _setSurveyDataValue,
            path: 'report_edit_family_members',
          ),
          const SizedBox(height: 12),
          SurveyFieldList(
            fields: familyProfileFields,
            data: _surveyData,
            onChanged: _setSurveyDataValue,
            path: 'report_edit_family_profile',
          ),
        ],
      ),
      const SizedBox(height: 12),
      _SurveyEditSection(
        title: 'II. Socio-economic, Cultural and Environmental',
        fields: _socioEconomicReportFields,
        surveyData: _surveyData,
        onChanged: _setSurveyDataValue,
      ),
      const SizedBox(height: 12),
      _ReportFormExpansion(
        title: 'III. Health and Illness Pattern',
        children: [
          SurveyFieldList(
            fields: _healthPatternReportFields,
            data: _surveyData,
            onChanged: _setSurveyDataValue,
            path: 'report_edit_health_illness',
          ),
        ],
      ),
      const SizedBox(height: 12),
      _SurveyEditSection(
        title: 'IV. Health Resource',
        fields: healthResourceFields,
        surveyData: _surveyData,
        onChanged: _setSurveyDataValue,
      ),
      const SizedBox(height: 12),
      _SurveyEditSection(
        title: 'V. Political/Leadership Patterns',
        fields: politicalLeadershipPatternFields,
        surveyData: _surveyData,
        onChanged: _setSurveyDataValue,
      ),
      const SizedBox(height: 12),
      _ReportFormExpansion(
        title:
            'VI. Any Concerns/Suggestions Regarding Lifestyle in the Area in General',
        children: [
          SurveyFieldList(
            fields: lifestyleConcernSuggestionFields,
            data: _surveyData,
            onChanged: _setSurveyDataValue,
            path: 'report_edit_concerns_suggestions',
          ),
          const SizedBox(height: 14),
          _ReportChipGroup(
            title: 'Community concerns',
            options: communityConcernOptions,
            selected: _communityConcerns,
            onChanged: _toggleCommunityConcern,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _notesController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Notes',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    ];
  }

  void _toggleCommunityConcern(String option, bool checked) {
    setState(() {
      checked
          ? _communityConcerns.add(option)
          : _communityConcerns.remove(option);
    });
  }

  void _setSurveyDataValue(String key, Object? value) {
    setState(() => _surveyData[key] = value);
  }

  Future<void> _editHistoryEntry(int index) async {
    if (index < 0 || index >= _editHistory.length) {
      return;
    }

    final edited = await showDialog<ReportEditHistoryEntry>(
      context: context,
      builder: (context) => _EditHistoryEntryDialog(entry: _editHistory[index]),
    );
    if (edited == null || !mounted) {
      return;
    }

    setState(() => _editHistory[index] = edited);
  }

  Future<void> _confirmDeleteEditHistoryEntry(int index) async {
    if (index < 0 || index >= _editHistory.length) {
      return;
    }

    final entry = _editHistory[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete history entry?'),
        content: Text(
          'Remove the edit history entry from ${_formatReportDateTime(entry.editedAt)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _editHistory.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final ageText = _ageController.text.trim();
    final respondentName = _nameController.text.trim();
    final address = _addressController.text.trim();
    final familyMembersCount = int.parse(_familyCountController.text.trim());
    final healthProblems = _healthProblems.toList()..sort();
    final communityConcerns = _communityConcerns.toList()..sort();
    final incomeEarners = normalizedIncomeEarnerRows(
      _surveyData['income_earners'],
      keepBlankRows: false,
    );
    final incomeEarnerCount = incomeEarnerCountFromRows(incomeEarners);
    final vaccinationStatus = vaccinationStatusFromSurveyData({
      ..._surveyData,
      'income_earners': incomeEarners,
    }, fallback: _vaccinationStatus);
    final surveyData = _compactReportSurveyData({
      ..._surveyData,
      'informant': respondentName,
      'address': address,
      'number_of_family': familyMembersCount,
      'income_earners': incomeEarners,
      'income_earner_count': incomeEarnerCount > 0 ? incomeEarnerCount : null,
      'health_problems': healthProblems,
      'vaccination_status': vaccinationStatus,
      'water_sanitation': _waterSanitation,
      'nutritional_status': _nutritionalStatus,
      'community_concerns': communityConcerns,
      'notes': _notesController.text.trim(),
      accountCreateRequestedKey: _accountCreateRequested,
      accountEmailKey: _accountCreateRequested
          ? _accountEmailController.text.trim()
          : '',
    });
    final updated = widget.submission.copyWith(
      respondentName: respondentName,
      respondentAge: ageText.isEmpty ? null : int.parse(ageText),
      address: address,
      familyMembersCount: familyMembersCount,
      familyMembers: _familyMembersFromSurveyData(surveyData),
      healthProblems: healthProblems,
      vaccinationStatus: vaccinationStatus,
      waterSanitation: _waterSanitation,
      nutritionalStatus: _nutritionalStatus,
      communityConcerns: communityConcerns,
      surveyData: surveyData,
      notes: _notesController.text.trim(),
      editHistory: _editHistory.toList(),
    );

    final changes = reportEditChanges(
      previous: widget.submission,
      next: updated,
    );
    final historyChanged = !reportEditHistoryEquals(
      widget.submission.editHistory,
      _editHistory,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save report changes?'),
        content: Text(_saveConfirmationMessage(changes, historyChanged)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save changes'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    Navigator.of(context).pop(updated);
  }

  String _saveConfirmationMessage(List<String> changes, bool historyChanged) {
    if (changes.isEmpty && historyChanged) {
      return 'Save edit history changes for ${widget.submission.respondentName}?';
    }
    if (changes.isEmpty) {
      return 'No field changes were detected. Save this report record anyway?';
    }

    final fieldChangeText =
        '${changes.length} change${changes.length == 1 ? '' : 's'}';
    if (historyChanged) {
      return 'Apply $fieldChangeText and edit history changes to ${widget.submission.respondentName}?';
    }
    return 'Apply $fieldChangeText to ${widget.submission.respondentName}?';
  }
}

class _EditHistoryEntryDialog extends StatefulWidget {
  const _EditHistoryEntryDialog({required this.entry});

  final ReportEditHistoryEntry entry;

  @override
  State<_EditHistoryEntryDialog> createState() =>
      _EditHistoryEntryDialogState();
}

class _EditHistoryEntryDialogState extends State<_EditHistoryEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _summaryController;
  late final TextEditingController _editedByController;
  late final TextEditingController _changesController;
  late DateTime _editedAt;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _editedAt = entry.editedAt.toLocal();
    _summaryController = TextEditingController(text: entry.summary);
    _editedByController = TextEditingController(text: entry.editedBy ?? '');
    _changesController = TextEditingController(text: entry.changes.join('\n'));
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _editedByController.dispose();
    _changesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit history entry'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _pickEditedAt,
                icon: const Icon(Icons.schedule_outlined),
                label: Text(_formatReportDateTime(_editedAt)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _summaryController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Summary'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a summary'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _editedByController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Edited by'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _changesController,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Changes',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save entry'),
        ),
      ],
    );
  }

  Future<void> _pickEditedAt() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(_editedAt.year, _editedAt.month, _editedAt.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_editedAt),
    );
    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      _editedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final editedBy = _editedByController.text.trim();
    Navigator.of(context).pop(
      ReportEditHistoryEntry(
        editedAt: _editedAt.toUtc(),
        summary: _summaryController.text.trim(),
        editedBy: editedBy.isEmpty ? null : editedBy,
        changes: _changesController.text
            .split(RegExp(r'\r?\n'))
            .map((change) => change.trim())
            .where((change) => change.isNotEmpty)
            .toList(),
      ),
    );
  }
}

class _SurveyEditSection extends StatelessWidget {
  const _SurveyEditSection({
    required this.title,
    required this.fields,
    required this.surveyData,
    required this.onChanged,
  });

  final String title;
  final List<SurveyField> fields;
  final Map<String, dynamic> surveyData;
  final void Function(String key, Object? value) onChanged;

  @override
  Widget build(BuildContext context) {
    return _ReportFormExpansion(
      title: title,
      children: [
        SurveyFieldList(
          fields: fields,
          data: surveyData,
          onChanged: onChanged,
          path: 'report_edit_${title.toLowerCase()}',
        ),
      ],
    );
  }
}

class _ReportFormExpansion extends StatelessWidget {
  const _ReportFormExpansion({
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: KasudloColors.border),
      ),
      child: ExpansionTile(
        title: Text(title),
        initiallyExpanded: initiallyExpanded,
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: children,
      ),
    );
  }
}

class _ReportChipGroup extends StatelessWidget {
  const _ReportChipGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final void Function(String option, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              FilterChip(
                label: Text(option),
                selected: selected.contains(option),
                onSelected: (checked) => onChanged(option, checked),
              ),
          ],
        ),
      ],
    );
  }
}

String _optionValue(List<String> options, String currentValue) {
  final normalizedValue = currentValue.trim();
  if (normalizedValue.isEmpty) {
    return options.first;
  }
  return normalizedValue;
}
