import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String> saveExportFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final extension = fileName.contains('.') ? fileName.split('.').last : null;
    final savedPath = await FilePicker.platform.saveFile(
      fileName: fileName,
      type: extension == null ? FileType.any : FileType.custom,
      allowedExtensions: extension == null ? null : [extension],
      bytes: Uint8List.fromList(bytes),
    );
    if (savedPath == null) {
      throw const FileSystemException('Export was canceled.');
    }
    return savedPath;
  }

  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName',
  );
  file.writeAsBytesSync(bytes, flush: true);
  return file.path;
}
