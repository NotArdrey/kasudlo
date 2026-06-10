import 'dart:io';
import 'package:archive/archive.dart';

void main() {
  final bytes = File('e:/Codes/kasudlo/FINAL-CDX-TOOL-2024-1_TAGGED.docx').readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  
  final docXml = archive.findFile('word/document.xml');
  if (docXml == null) {
    print('document.xml not found');
    return;
  }
  
  final content = String.fromCharCodes(docXml.content as List<int>);
  
  // Strip XML tags
  String text = content.replaceAll(RegExp(r'<[^>]+>'), '');
  
  // Unescape XML entities
  text = text.replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&amp;', '&');
  
  // Find Docmosis tags
  final tags = RegExp(r'<<.*?>>').allMatches(text).map((m) => m.group(0)!).toSet().toList()..sort();
  
  for (final tag in tags) {
    print(tag);
  }
}
