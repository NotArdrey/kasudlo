import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

void main() {
  final dir = Directory('e:/flutter-project/Kasudlo/temp_docx');
  final archive = Archive();
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) {
      final relativePath = p.relative(entity.path, from: dir.path).replaceAll('\\', '/');
      final bytes = entity.readAsBytesSync();
      archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
    }
  }
  
  final zipBytes = ZipEncoder().encode(archive);
  File('e:/flutter-project/Kasudlo/assets/template/cdx_template.docx').writeAsBytesSync(zipBytes!);
  print('Successfully created valid docx zip with forward slashes.');
}
