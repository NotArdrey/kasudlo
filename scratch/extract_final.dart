import 'dart:io';
import 'package:xml/xml.dart';
import 'package:archive/archive_io.dart';

void main() {
  final inputBytes = File('FINAL-CDX-TOOL-2024-1.docx').readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(inputBytes);
  final documentFile = archive.findFile('word/document.xml');
  final content = String.fromCharCodes(documentFile!.content as List<int>);

  final doc = XmlDocument.parse(content);
  final paragraphs = doc.descendants.whereType<XmlElement>().where(
    (e) => e.name.local == 'p',
  );
  var count = 0;
  for (final p in paragraphs) {
    final texts = p.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 't')
        .map((e) => e.innerText)
        .join('');
    if (texts.trim().isNotEmpty) {
      count++;
      print('[$count] $texts');
    }
  }
}
