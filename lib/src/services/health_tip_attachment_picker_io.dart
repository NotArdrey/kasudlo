import 'dart:io';

import 'package:path/path.dart' as path;

import 'health_tip_attachment.dart';

const supportsDirectAttachmentPicker = false;
const supportsAttachmentPathImport = true;

Future<PickedHealthTipAttachment?> pickHealthTipAttachment() async {
  return null;
}

Future<PickedHealthTipAttachment?> readHealthTipAttachmentFromPath(
  String filePath,
) async {
  final normalizedPath = filePath.trim();
  if (normalizedPath.isEmpty) {
    return null;
  }

  final file = File(normalizedPath);
  if (!await file.exists()) {
    throw StateError('File was not found.');
  }

  final bytes = await file.readAsBytes();
  final fileName = path.basename(normalizedPath);
  return PickedHealthTipAttachment(
    fileName: fileName,
    mimeType: guessAttachmentMimeType(fileName),
    bytes: bytes,
  );
}
