import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../assessment_options.dart';
import '../models.dart';
import '../services/report_exporter.dart';
import '../state/app_controller.dart';
import '../survey_schema.dart';
import '../theme.dart';
import '../widgets/account_request_fields.dart';
import '../widgets/app_chrome.dart';
import '../widgets/survey_form.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final summary = controller.summary;

    return AppPage(
      title: 'Reports',
      subtitle: 'Summarized community health data',
      children: [
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
              icon: Icons.home_outlined,
            ),
            MetricCard(
              label: 'Family members',
              value: '${summary.totalFamilyMembers}',
              icon: Icons.people_alt_outlined,
              color: KasudloColors.secondary,
            ),
          ],
        ),
        if (!summary.hasData)
          const EmptyState(
            icon: Icons.bar_chart_outlined,
            title: 'No report data',
            message:
                'Submitted or saved forms will appear in the monitoring report.',
          )
        else ...[
          _ReportRecordsCard(
            submissions: controller.submissions,
            onView: (submission) => _showViewSheet(context, submission),
            onEdit: (submission) => _showEditSheet(context, ref, submission),
            onDelete: (submission) => _confirmDelete(context, ref, submission),
          ),
          _BreakdownCard(
            title: 'Vaccination status',
            values: summary.vaccinationStatuses,
            color: KasudloColors.primary,
          ),
          _BreakdownCard(
            title: 'Nutritional status',
            values: summary.nutritionalStatuses,
            color: KasudloColors.secondary,
          ),
          _BreakdownCard(
            title: 'Water and sanitation',
            values: summary.waterSanitationStatuses,
            color: KasudloColors.warning,
          ),
          _RankedListCard(
            title: 'Common health problems',
            values: summary.healthProblems,
            emptyText: 'No health problems selected.',
          ),
          _RankedListCard(
            title: 'Community concerns',
            values: summary.communityConcerns,
            emptyText: 'No community concerns selected.',
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

class _ReportRecordsCard extends StatefulWidget {
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
  State<_ReportRecordsCard> createState() => _ReportRecordsCardState();
}

class _ReportRecordsCardState extends State<_ReportRecordsCard> {
  final _searchController = TextEditingController();
  final _selectedSubmissionIds = <String>{};
  String _query = '';

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
              OutlinedButton.icon(
                onPressed: selectedCount == 0
                    ? null
                    : () => _exportSelected(ReportExportFormat.pdf),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
              OutlinedButton.icon(
                onPressed: selectedCount == 0
                    ? null
                    : () => _exportSelected(ReportExportFormat.docs),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Export Docs'),
              ),
              TextButton.icon(
                onPressed: filteredSubmissions.isEmpty
                    ? null
                    : () => _selectFiltered(filteredSubmissions),
                icon: const Icon(Icons.select_all_outlined),
                label: const Text('Select shown'),
              ),
              TextButton.icon(
                onPressed: selectedCount == 0 ? null : _clearSelection,
                icon: const Icon(Icons.clear_outlined),
                label: const Text('Clear'),
              ),
              Text(
                selectedCount == 1 ? '1 selected' : '$selectedCount selected',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: KasudloColors.muted),
              ),
            ],
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

class _ViewReportSheet extends StatelessWidget {
  const _ViewReportSheet({required this.submission});

  final HealthSubmission submission;

  @override
  Widget build(BuildContext context) {
    final detailGroups = _reportDetailGroups(submission);

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
              _ReportEditHistory(entries: submission.editHistory),
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _reportDetailGroups(HealthSubmission submission) {
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

  addGroup('I. Demographic Variable', [
    _ReportDetailRow(
      label: 'Name',
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
  addGroup('III. Health and Illness Pattern', [
    _ReportDetailRow(
      label: 'Vaccination status',
      value: _displayValue(submission.vaccinationStatus),
    ),
    _ReportDetailRow(
      label: 'Water and sanitation',
      value: _displayValue(submission.waterSanitation),
    ),
    _ReportDetailRow(
      label: 'Nutritional status',
      value: _displayValue(submission.nutritionalStatus),
    ),
    _ReportDetailRow(
      label: 'Health problems',
      value: _displayList(submission.healthProblems),
    ),
    ..._surveyResponseWidgets(_healthPatternReportFields, surveyData),
  ]);
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
  const _ReportEditHistory({required this.entries});

  final List<ReportEditHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final sortedEntries = entries.toList()
      ..sort((a, b) => b.editedAt.compareTo(a.editedAt));

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
            _ReportEditHistoryTile(entry: sortedEntries[index]),
            if (index != sortedEntries.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ReportEditHistoryTile extends StatelessWidget {
  const _ReportEditHistoryTile({required this.entry});

  final ReportEditHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final editedBy = entry.editedBy?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: KasudloColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatReportDateTime(entry.editedAt),
              style: Theme.of(context).textTheme.labelLarge,
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
  return DateFormat('MMM d, yyyy h:mm a').format(value);
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
    if (field.type == SurveyFieldType.note) {
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
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Row ${index + 1}: ${_surveyRowLabel(field.fields, rows[index])}',
                ),
              ),
        ],
      ),
    );
  }
}

String _surveyRowLabel(List<SurveyField> fields, Map<String, dynamic> row) {
  final parts = <String>[];
  for (final field in fields) {
    final value = row[field.key];
    if (!_reportValueHasContent(value)) {
      continue;
    }
    parts.add('${field.label}: ${_reportValueLabel(value)}');
  }
  return parts.isEmpty ? 'No details' : parts.join('; ');
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
    _accountCreateRequested = accountCreateRequestedFromData(_surveyData);
    _accountEmailController = TextEditingController(
      text: accountEmailFromData(_surveyData),
    );
    _accountPasswordController = TextEditingController();
    _accountConfirmPasswordController = TextEditingController();
    _vaccinationStatus = _optionValue(
      vaccinationStatusOptions,
      submission.vaccinationStatus,
    );
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
                _ReportEditHistory(entries: widget.submission.editHistory),
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
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Enter a name' : null,
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
          _ReportDropdownField(
            label: 'Vaccination status',
            value: _vaccinationStatus,
            options: _optionList(
              vaccinationStatusOptions,
              widget.submission.vaccinationStatus,
            ),
            onChanged: (value) => setState(() => _vaccinationStatus = value),
          ),
          const SizedBox(height: 12),
          _ReportDropdownField(
            label: 'Water and sanitation',
            value: _waterSanitation,
            options: _optionList(
              waterSanitationOptions,
              widget.submission.waterSanitation,
            ),
            onChanged: (value) => setState(() => _waterSanitation = value),
          ),
          const SizedBox(height: 12),
          _ReportDropdownField(
            label: 'Nutritional status',
            value: _nutritionalStatus,
            options: _optionList(
              nutritionalStatusOptions,
              widget.submission.nutritionalStatus,
            ),
            onChanged: (value) => setState(() => _nutritionalStatus = value),
          ),
          const SizedBox(height: 14),
          _ReportChipGroup(
            title: 'Health problems',
            options: healthProblemOptions,
            selected: _healthProblems,
            onChanged: _toggleHealthProblem,
          ),
          const SizedBox(height: 14),
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

  void _toggleHealthProblem(String option, bool checked) {
    setState(() {
      checked ? _healthProblems.add(option) : _healthProblems.remove(option);
    });
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
    final surveyData = _compactReportSurveyData({
      ..._surveyData,
      'informant': respondentName,
      'address': address,
      'number_of_family': familyMembersCount,
      'health_problems': healthProblems,
      'vaccination_status': _vaccinationStatus,
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
      vaccinationStatus: _vaccinationStatus,
      waterSanitation: _waterSanitation,
      nutritionalStatus: _nutritionalStatus,
      communityConcerns: communityConcerns,
      surveyData: surveyData,
      notes: _notesController.text.trim(),
    );

    final changes = reportEditChanges(
      previous: widget.submission,
      next: updated,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save report changes?'),
        content: Text(
          changes.isEmpty
              ? 'No field changes were detected. Save this report record anyway?'
              : 'Apply ${changes.length} change${changes.length == 1 ? '' : 's'} to ${widget.submission.respondentName}?',
        ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: KasudloColors.border),
        borderRadius: BorderRadius.circular(6),
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

class _ReportDropdownField extends StatelessWidget {
  const _ReportDropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options
          .map(
            (option) => DropdownMenuItem(
              value: option,
              child: Text(option, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
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

List<String> _optionList(List<String> options, String currentValue) {
  final normalizedValue = currentValue.trim();
  if (normalizedValue.isEmpty || options.contains(normalizedValue)) {
    return options;
  }
  return [normalizedValue, ...options];
}

String _optionValue(List<String> options, String currentValue) {
  final normalizedValue = currentValue.trim();
  if (normalizedValue.isEmpty) {
    return options.first;
  }
  return normalizedValue;
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.values,
    required this.color,
  });

  final String title;
  final Map<String, int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              'No responses yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: KasudloColors.muted),
            )
          else
            SizedBox(
              height: 190,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 42,
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: entries[i].value.toDouble(),
                        title: '${entries[i].value}',
                        radius: 42,
                        color:
                            Color.lerp(color, KasudloColors.border, i / 5) ??
                            color,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key)),
                  Text('${entry.value}'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RankedListCard extends StatelessWidget {
  const _RankedListCard({
    required this.title,
    required this.values,
    required this.emptyText,
  });

  final String title;
  final Map<String, int> values;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              emptyText,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: KasudloColors.muted),
            )
          else
            for (final entry in entries.take(6))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.trending_up),
                title: Text(entry.key),
                trailing: StatusBadge(label: '${entry.value}'),
              ),
        ],
      ),
    );
  }
}
