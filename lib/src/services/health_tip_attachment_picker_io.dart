import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import 'health_tip_attachment.dart';

const supportsDirectAttachmentPicker = true;
const supportsAttachmentPathImport = false;

Future<PickedHealthTipAttachment?> pickHealthTipAttachment() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.any,
    withData: false,
    withReadStream: false,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }
  final pickedFile = result.files.first;
  final filePath = pickedFile.path;
  if (filePath == null) return null;
  
  final file = File(filePath);
  final bytes = await file.readAsBytes();
  return PickedHealthTipAttachment(
    fileName: pickedFile.name,
    mimeType: guessAttachmentMimeType(pickedFile.name),
    bytes: bytes,
  );
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
