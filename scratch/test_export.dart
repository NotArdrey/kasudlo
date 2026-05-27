import 'dart:io';
import 'package:kasudlo/src/services/report_exporter.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'dart:convert';

void main() async {
  try {
    final templateBytes = File('e:/flutter-project/Kasudlo/assets/template/cdx_template.docx').readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(templateBytes);

    final documentFile = archive.findFile('word/document.xml');
    if (documentFile == null) throw Exception('Invalid docx template');

    var originalXml = utf8.decode(documentFile.content as List<int>);
    print('Decoded originalXml length: ${originalXml.length}');

    try {
      final document = XmlDocument.parse(originalXml);
      for (final p in document.descendants.whereType<XmlElement>().where((e) => e.name.local == 'p')) {
        final texts = p.descendants.whereType<XmlElement>().where((e) => e.name.local == 't').toList();
        if (texts.length > 1) {
          final fullText = texts.map((e) => e.innerText).join('');
          texts.first.innerText = fullText;
          for (var i = 1; i < texts.length; i++) {
            texts[i].innerText = '';
          }
        }
      }
      originalXml = document.toXmlString();
    } catch (e) {
      print('XML parse error: $e');
    }

    final bodyStartIdx = originalXml.indexOf('<w:body>') + '<w:body>'.length;
    final sectPrIdx = originalXml.lastIndexOf('<w:sectPr');
    print('bodyStartIdx: $bodyStartIdx, sectPrIdx: $sectPrIdx');
    
    if (bodyStartIdx == -1 || sectPrIdx == -1 || bodyStartIdx >= sectPrIdx) {
      throw Exception('Could not parse template XML structure');
    }
    
    print('Success testing XML reading logic.');
  } catch(e) {
    print('Error: $e');
  }
}
