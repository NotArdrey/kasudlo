import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../theme.dart';
import 'app_chrome.dart';
import 'status_badge.dart';

class ArchivedReportsCard extends StatefulWidget {
  const ArchivedReportsCard({
    super.key,
    required this.submissions,
    required this.loading,
    required this.onRestore,
    required this.onHardDelete,
    this.errorMessage,
  });

  final List<HealthSubmission> submissions;
  final bool loading;
  final ValueChanged<HealthSubmission> onRestore;
  final ValueChanged<HealthSubmission> onHardDelete;
  final String? errorMessage;

  @override
  State<ArchivedReportsCard> createState() => _ArchivedReportsCardState();
}

class _ArchivedReportsCardState extends State<ArchivedReportsCard> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HealthSubmission> get _filteredSubmissions {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.submissions;
    }

    return widget.submissions.where((submission) {
      return [
        _submissionTitle(submission),
        submission.address,
        submission.deletedBy ?? '',
        submission.notes,
        ...submission.healthProblems,
        ...submission.communityConcerns,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSubmissions;
    final listMaxHeight = (MediaQuery.sizeOf(context).height * 0.45)
        .clamp(280.0, 520.0)
        .toDouble();
    final shouldConstrainList = filtered.length > 4;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Archived reports',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusBadge(
                label: '${filtered.length}',
                color: KasudloColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Search archive',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          if (widget.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: KasudloColors.critical),
            ),
          ],
          const SizedBox(height: 12),
          if (widget.loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(),
              ),
            )
          else if (filtered.isEmpty)
            const _ArchivedReportsEmptyState()
          else
            SizedBox(
              height: shouldConstrainList ? listMaxHeight : null,
              child: ListView.separated(
                shrinkWrap: !shouldConstrainList,
                physics: shouldConstrainList
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) => _ArchivedReportTile(
                  submission: filtered[index],
                  onRestore: () => widget.onRestore(filtered[index]),
                  onHardDelete: () => widget.onHardDelete(filtered[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArchivedReportTile extends StatelessWidget {
  const _ArchivedReportTile({
    required this.submission,
    required this.onRestore,
    required this.onHardDelete,
  });

  final HealthSubmission submission;
  final VoidCallback onRestore;
  final VoidCallback onHardDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: KasudloColors.warning.withValues(alpha: 0.12),
        foregroundColor: KasudloColors.warning,
        child: const Icon(Icons.archive_outlined),
      ),
      title: Text(
        _submissionTitle(submission),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _archiveSubtitle(submission),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: SizedBox(
        width: 96,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Restore archived record',
              onPressed: onRestore,
              icon: const Icon(Icons.restore_outlined),
            ),
            IconButton(
              tooltip: 'Permanently delete record',
              onPressed: onHardDelete,
              icon: const Icon(Icons.delete_forever_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedReportsEmptyState extends StatelessWidget {
  const _ArchivedReportsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          const Icon(
            Icons.archive_outlined,
            color: KasudloColors.primary,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            'No archived reports',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Soft-deleted report records will stay here until an admin or nurse permanently deletes them.',
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

String _submissionTitle(HealthSubmission submission) {
  final name = submission.respondentName.trim();
  if (name.isNotEmpty) {
    return name;
  }
  final address = submission.address.trim();
  if (address.isNotEmpty) {
    return address;
  }
  return 'Unnamed record';
}

String _archiveSubtitle(HealthSubmission submission) {
  final archivedAt = submission.deletedAt;
  final archivedText = archivedAt == null
      ? 'Archived'
      : 'Archived ${DateFormat('MMM d, yyyy h:mm a').format(archivedAt.toLocal())}';
  final actor = (submission.deletedBy ?? '').trim();
  final actorText = actor.isEmpty ? '' : ' by $actor';
  return '$archivedText$actorText - ${submission.address}';
}
