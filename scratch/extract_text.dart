import 'dart:io';
import 'package:xml/xml.dart';

void main() {
  final file = File('e:/flutter-project/Kasudlo/temp_docx_backup/word/document.xml');
  final doc = XmlDocument.parse(file.readAsStringSync());
  
  // Extract all visible text, paragraph by paragraph
  final paragraphs = doc.descendants.whereType<XmlElement>().where((e) => e.name.local == 'p');
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
  print('\nTotal non-empty paragraphs: $count');
}
