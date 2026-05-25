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
      title: 'Health Tips',
      subtitle: canManage ? 'Upload guidance and files' : 'Care guidance',
      actions: [
        IconButton(
          tooltip: 'Refresh health tips',
          onPressed: controller.isHealthTipsLoading
              ? null
              : () => ref.read(appControllerProvider).loadHealthTips(),
          icon: const Icon(Icons.refresh),
        ),
        if (canManage)
          IconButton(
            tooltip: 'Add health tip',
            onPressed: controller.isHealthTipActionBusy
                ? null
                : () => _openEditor(context, null),
            icon: const Icon(Icons.add),
          ),
      ],
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
        if (canManage)
          AppCard(
            child: ElevatedButton.icon(
              onPressed: controller.isHealthTipActionBusy
                  ? null
                  : () => _openEditor(context, null),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Health Tip'),
            ),
          ),
        if (healthTips.isEmpty)
          const EmptyState(
            icon: Icons.tips_and_updates_outlined,
            title: 'No health tips yet',
            message: 'Health tips from the care team will appear here.',
          )
        else
          for (final healthTip in healthTips)
            _HealthTipCard(
              healthTip: healthTip,
              canManage: canManage,
              onEdit: () => _openEditor(context, healthTip),
              onDelete: () => _confirmDelete(context, ref, healthTip),
              onDownload: () => _downloadAttachment(context, healthTip),
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
              healthTip == null ? 'Health tip uploaded.' : 'Health tip saved.',
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
        title: const Text('Delete health tip?'),
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
      ..showSnackBar(const SnackBar(content: Text('Health tip deleted.')));
  }

  Future<void> _downloadAttachment(
    BuildContext context,
    HealthTip healthTip,
  ) async {
    final bytes = _attachmentBytes(healthTip);
    if (bytes == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Attachment is missing.')));
      return;
    }

    final savedPath = await saveExportFile(
      bytes: bytes,
      fileName: healthTip.fileName,
      mimeType: healthTip.mimeType.isEmpty
          ? 'application/octet-stream'
          : healthTip.mimeType,
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
  late String _fileName;
  late String _mimeType;
  late int _fileSize;
  late String _attachmentBase64;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialHealthTip;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _fileName = initial?.fileName ?? '';
    _mimeType = initial?.mimeType ?? '';
    _fileSize = initial?.fileSize ?? 0;
    _attachmentBase64 = initial?.attachmentBase64 ?? '';
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

    return AlertDialog(
      title: Text(editing ? 'Edit health tip' : 'Upload health tip'),
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
                _AttachmentEditorSummary(
                  fileName: _fileName,
                  fileSize: _fileSize,
                  hasAttachment: _attachmentBase64.isNotEmpty,
                  onAttach: _attachFile,
                  onRemove: _removeAttachment,
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
        _fileName = picked!.fileName;
        _mimeType = picked.mimeType;
        _fileSize = picked.bytes.length;
        _attachmentBase64 = base64Encode(picked.bytes);
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

  void _removeAttachment() {
    setState(() {
      _fileName = '';
      _mimeType = '';
      _fileSize = 0;
      _attachmentBase64 = '';
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
          fileName: _fileName,
          mimeType: _mimeType,
          fileSize: _fileSize,
          attachmentBase64: _attachmentBase64,
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
}

class _AttachmentEditorSummary extends StatelessWidget {
  const _AttachmentEditorSummary({
    required this.fileName,
    required this.fileSize,
    required this.hasAttachment,
    required this.onAttach,
    required this.onRemove,
  });

  final String fileName;
  final int fileSize;
  final bool hasAttachment;
  final VoidCallback onAttach;
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
                    hasAttachment ? fileName : 'No attachment',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                if (hasAttachment)
                  Text(
                    _formatFileSize(fileSize),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: KasudloColors.muted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAttach,
                    icon: const Icon(Icons.upload_file),
                    label: Text(hasAttachment ? 'Replace' : 'Attach File'),
                  ),
                ),
                if (hasAttachment) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Remove attachment',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
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
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final updatedAt = DateFormat(
      'MMM d, yyyy h:mm a',
    ).format(healthTip.updatedAt.toLocal());
    final imageBytes = healthTip.isImage ? _attachmentBytes(healthTip) : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                imageBytes,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _BrokenAttachmentPreview(),
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
                  tooltip: 'Edit health tip',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete health tip',
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
          if (healthTip.hasAttachment) ...[
            const SizedBox(height: 12),
            _AttachmentTile(healthTip: healthTip, onDownload: onDownload),
          ],
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.healthTip, required this.onDownload});

  final HealthTip healthTip;
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
          healthTip.isImage ? Icons.image_outlined : Icons.description_outlined,
          color: KasudloColors.primary,
        ),
        title: Text(healthTip.fileName, overflow: TextOverflow.ellipsis),
        subtitle: Text(_formatFileSize(healthTip.fileSize)),
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

Uint8List? _attachmentBytes(HealthTip healthTip) {
  if (!healthTip.hasAttachment) {
    return null;
  }
  try {
    return base64Decode(healthTip.attachmentBase64);
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
