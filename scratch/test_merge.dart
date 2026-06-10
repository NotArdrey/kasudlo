import 'dart:io';
import 'package:xml/xml.dart';

void main() {
  final file = File('e:/flutter-project/Kasudlo/temp_docx/word/document.xml');
  final document = XmlDocument.parse(file.readAsStringSync());

  // Merge adjacent <w:t> tags within the same <w:p>
  var mergedCount = 0;
  for (final p in document.descendants.whereType<XmlElement>().where(
    (e) => e.name.local == 'p',
  )) {
    final runs = p.findElements('w:r').toList();
    if (runs.length > 1) {
      // Find consecutive runs that only have <w:t> and maybe identical <w:rPr>
      // To simplify, let's just find all <w:t> in the paragraph and merge their text into the first <w:t>,
      // and remove the other <w:t> tags! (This destroys local character styling, but usually it's fine for simple text)
      final texts = p.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 't')
          .toList();
      if (texts.length > 1) {
        final fullText = texts.map((e) => e.innerText).join('');
        texts.first.innerText = fullText;
        for (var i = 1; i < texts.length; i++) {
          texts[i].innerText =
              ''; // Clear other texts instead of removing to avoid breaking XML tree
        }
        mergedCount++;
      }
    }
  }

  print('Merged texts in $mergedCount paragraphs.');

  final fullXml = document.toXmlString();
  print(
    'Contains "Respect for elderly": ${fullXml.contains('Respect for elderly')}',
  );
  print('Contains "Nuclear": ${fullXml.contains('Nuclear')}');
}
