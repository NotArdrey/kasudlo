import 'dart:io';

Future<String> saveExportFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) async {
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName',
  );
  file.writeAsBytesSync(bytes, flush: true);
  return file.path;
}
