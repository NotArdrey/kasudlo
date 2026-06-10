import 'dart:io';
import 'package:archive/archive.dart';

void main() {
  final source = File('assets/template/cdx_template.docx');
  final target = File('docmosis_tagged_template.docx');

  final bytes = source.readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);

  final outArchive = Archive();
  for (final file in archive) {
    if (file.name == 'word/document.xml') {
      final content = String.fromCharCodes(file.content as List<int>);
      final updated = content
          .replaceAll('{{', '&lt;&lt;')
          .replaceAll('}}', '&gt;&gt;');
      outArchive.addFile(
        ArchiveFile(file.name, updated.length, updated.codeUnits),
      );
    } else {
      outArchive.addFile(file);
    }
  }

  final outBytes = ZipEncoder().encode(outArchive);
  target.writeAsBytesSync(outBytes!);
  print('Done.');
}
