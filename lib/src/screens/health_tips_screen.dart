import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/health_tip_attachment_picker.dart';
import '../services/report_file_saver_stub.dart'
    if (dart.library.html) '../services/report_file_saver_web.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/app_chrome.dart';

const _maxAttachmentBytes = 5 * 1024 * 1024;

class HealthTipsScreen extends ConsumerWidget {
  const HealthTipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final canManage = controller.canManageHealthTips;
    final healthTips = controller.healthTips;

    return AppPage(
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              backgroundColor: KasudloColors.primary,
              foregroundColor: Colors.white,
              onPressed: controller.isHealthTipActionBusy
                  ? null
                  : () => _openEditor(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Add Teaching'),
            )
          : null,
      title: 'Health Teaching',
      subtitle: canManage ? 'Upload guidance and files' : 'Care guidance',
      children: [
        if (controller.healthTipsErrorMessage != null)
          AppCard(
            child: Text(
              controller.healthTipsErrorMessage!,
              style: const TextStyle(color: KasudloColors.critical),
            ),
          ),
        if (controller.isHealthTipsLoading)
          const AppCard(child: LinearProgressIndicator()),

        if (healthTips.isEmpty)
          const EmptyState(
            icon: Icons.tips_and_updates_outlined,
            title: 'No health teaching yet',
            message: 'Health teaching from the care team will appear here.',
          )
        else
          for (final healthTip in healthTips)
            _HealthTipCard(
              healthTip: healthTip,
              canManage: canManage,
              onEdit: () => _openEditor(context, healthTip),
              onDelete: () => _confirmDelete(context, ref, healthTip),
              onDownload: (attachment) =>
                  _downloadAttachment(context, attachment),
            ),
      ],
    );
  }

  Future<void> _openEditor(BuildContext context, HealthTip? healthTip) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _HealthTipEditorDialog(initialHealthTip: healthTip),
    );

    if (context.mounted && saved == true) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              healthTip == null
                  ? 'Health teaching uploaded.'
                  : 'Health teaching saved.',
            ),
          ),
        );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    HealthTip healthTip,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete health teaching?'),
        content: Text(healthTip.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final deleted = await ref
        .read(appControllerProvider)
        .deleteHealthTip(healthTip.id);
    if (!context.mounted || !deleted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Health teaching deleted.')));
  }

  Future<void> _downloadAttachment(
    BuildContext context,
    HealthTipAttachment attachment,
  ) async {
    final bytes = _attachmentBytes(attachment);
    if (bytes == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Attachment is missing.')));
      return;
    }

    final savedPath = await saveExportFile(
      bytes: bytes,
      fileName: attachment.fileName,
      mimeType: attachment.mimeType.isEmpty
          ? 'application/octet-stream'
          : attachment.mimeType,
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Saved $savedPath')));
  }
}

class _HealthTipEditorDialog extends ConsumerStatefulWidget {
  const _HealthTipEditorDialog({this.initialHealthTip});

  final HealthTip? initialHealthTip;

  @override
  ConsumerState<_HealthTipEditorDialog> createState() =>
      _HealthTipEditorDialogState();
}

class _HealthTipEditorDialogState
    extends ConsumerState<_HealthTipEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late List<HealthTipAttachment> _attachments;
  late Set<String> _targetPatientIds;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialHealthTip;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _attachments = initial?.attachments.toList() ?? [];
    _targetPatientIds = initial?.effectiveTargetPatientIds.toSet() ?? {};

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(appControllerProvider).loadHealthTipPatients();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final editing = widget.initialHealthTip != null;
    final patients = controller.adminUsers
        .where((user) => user.role == AccountRole.patient)
        .toList();

    return AlertDialog(
      title: Text(editing ? 'Edit health teaching' : 'Upload health teaching'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Details',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                _VisibilitySelector(
                  patients: patients,
                  selectedPatientIds: _targetPatientIds,
                  isLoading: controller.isAdminLoading,
                  errorMessage: controller.adminErrorMessage,
                  onAllPatientsSelected: () {
                    setState(() => _targetPatientIds.clear());
                  },
                  onPatientToggled: _toggleTargetPatient,
                ),
                const SizedBox(height: 12),
                if (_attachments.isNotEmpty) ...[
                  for (final attachment in _attachments) ...[
                    _AttachmentEditorSummary(
                      attachment: attachment,
                      onRemove: () => _removeAttachment(attachment),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                OutlinedButton.icon(
                  onPressed: _attachFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Add Attachment'),
                ),
                if (controller.healthTipsErrorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    controller.healthTipsErrorMessage!,
                    style: const TextStyle(color: KasudloColors.critical),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: controller.isHealthTipActionBusy
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: controller.isHealthTipActionBusy ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _attachFile() async {
    try {
      var picked = await pickHealthTipAttachment();
      if (picked == null && supportsAttachmentPathImport && mounted) {
        final filePath = await _askForFilePath();
        if (filePath != null) {
          picked = await readHealthTipAttachmentFromPath(filePath);
        }
      }
      if (!mounted || picked == null) {
        return;
      }
      if (picked.bytes.length > _maxAttachmentBytes) {
        _showMessage('Attachment must be 5 MB or smaller.');
        return;
      }
      setState(() {
        _attachments.add(
          HealthTipAttachment(
            fileName: picked!.fileName,
            mimeType: picked.mimeType,
            fileSize: picked.bytes.length,
            base64: base64Encode(picked.bytes),
          ),
        );
      });
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  Future<String?> _askForFilePath() {
    final pathController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import file'),
        content: TextField(
          controller: pathController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Local file path'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(pathController.text.trim()),
            child: const Text('Import'),
          ),
        ],
      ),
    ).whenComplete(pathController.dispose);
  }

  void _removeAttachment(HealthTipAttachment attachment) {
    setState(() {
      _attachments.remove(attachment);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final saved = await ref
        .read(appControllerProvider)
        .saveHealthTip(
          id: widget.initialHealthTip?.id,
          title: _titleController.text,
          description: _descriptionController.text,
          attachments: _attachments,
          targetPatientIds: _targetPatientIds.toList(),
        );
    if (mounted && saved) {
      Navigator.of(context).pop(true);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleTargetPatient(String patientId, bool selected) {
    setState(() {
      if (selected) {
        _targetPatientIds.add(patientId);
      } else {
        _targetPatientIds.remove(patientId);
      }
    });
  }
}

class _VisibilitySelector extends StatelessWidget {
  const _VisibilitySelector({
    required this.patients,
    required this.selectedPatientIds,
    required this.isLoading,
    required this.errorMessage,
    required this.onAllPatientsSelected,
    required this.onPatientToggled,
  });

  final List<AdminUser> patients;
  final Set<String> selectedPatientIds;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onAllPatientsSelected;
  final void Function(String patientId, bool selected) onPatientToggled;

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedPatientIds.length;

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Visibility',
        alignLabelWithHint: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: selectedPatientIds.isEmpty,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Seen by all patients'),
            onChanged: (_) => onAllPatientsSelected(),
          ),
          if (isLoading) const LinearProgressIndicator(),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: const TextStyle(color: KasudloColors.critical),
            ),
          ],
          if (!isLoading && patients.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No patient accounts available.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: KasudloColors.muted),
            ),
          ],
          if (patients.isNotEmpty) ...[
            const Divider(height: 16),
            Text(
              selectedCount == 0
                  ? 'All patients selected'
                  : '$selectedCount patient${selectedCount == 1 ? '' : 's'} selected',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: KasudloColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            for (final patient in patients)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: selectedPatientIds.contains(patient.id),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(_patientLabel(patient)),
                subtitle: patient.fullName.trim().isEmpty
                    ? null
                    : Text(patient.email),
                onChanged: (value) =>
                    onPatientToggled(patient.id, value ?? false),
              ),
          ],
        ],
      ),
    );
  }

  String _patientLabel(AdminUser patient) {
    final fullName = patient.fullName.trim();
    return fullName.isEmpty ? patient.email : fullName;
  }
}

class _AttachmentEditorSummary extends StatelessWidget {
  const _AttachmentEditorSummary({
    required this.attachment,
    required this.onRemove,
  });

  final HealthTipAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: KasudloColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_file, color: KasudloColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    attachment.fileName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Text(
                  _formatFileSize(attachment.fileSize),
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: KasudloColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Remove attachment',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthTipCard extends StatelessWidget {
  const _HealthTipCard({
    required this.healthTip,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    required this.onDownload,
  });

  final HealthTip healthTip;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(HealthTipAttachment) onDownload;

  @override
  Widget build(BuildContext context) {
    final updatedAt = DateFormat(
      'MMM d, yyyy h:mm a',
    ).format(healthTip.updatedAt.toLocal());
    final imageAttachments = healthTip.imageAttachments;
    final fileAttachments = healthTip.fileAttachments;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageAttachments.isNotEmpty) ...[
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: imageAttachments.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final attachment = imageAttachments[index];
                  final bytes = _attachmentBytes(attachment);
                  if (bytes == null) return const _BrokenAttachmentPreview();
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      bytes,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _BrokenAttachmentPreview(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KasudloColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.tips_and_updates_outlined,
                  color: KasudloColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      healthTip.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      updatedAt,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: KasudloColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (canManage) ...[
                IconButton(
                  tooltip: 'Edit health teaching',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete health teaching',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
          if (healthTip.description.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(healthTip.description),
          ],
          if (fileAttachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final attachment in fileAttachments) ...[
              _AttachmentTile(
                attachment: attachment,
                onDownload: () => onDownload(attachment),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment, required this.onDownload});

  final HealthTipAttachment attachment;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: KasudloColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          attachment.isImage
              ? Icons.image_outlined
              : Icons.description_outlined,
          color: KasudloColors.primary,
        ),
        title: Text(attachment.fileName, overflow: TextOverflow.ellipsis),
        subtitle: Text(_formatFileSize(attachment.fileSize)),
        trailing: IconButton(
          tooltip: 'Save attachment',
          onPressed: onDownload,
          icon: const Icon(Icons.download_outlined),
        ),
      ),
    );
  }
}

class _BrokenAttachmentPreview extends StatelessWidget {
  const _BrokenAttachmentPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      color: KasudloColors.surface,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: KasudloColors.muted,
      ),
    );
  }
}

Uint8List? _attachmentBytes(HealthTipAttachment attachment) {
  try {
    return base64Decode(attachment.base64);
  } catch (_) {
    return null;
  }
}

String _formatFileSize(int size) {
  if (size <= 0) {
    return '0 KB';
  }
  if (size < 1024 * 1024) {
    return '${(size / 1024).ceil()} KB';
  }
  return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
}
