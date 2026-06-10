import 'dart:io';
import 'package:archive/archive.dart';

void main() {
  final bytes = File('e:/Codes/kasudlo/FINAL-CDX-TOOL-2024-1_TAGGED.docx').readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  final docXml = archive.findFile('word/document.xml')!;
  final content = String.fromCharCodes(docXml.content as List<int>);
  print('control_no: ' + content.contains('&lt;&lt;control_no&gt;&gt;').toString());
  print('rs_family: ' + content.contains('&lt;&lt;rs_family_members&gt;&gt;').toString());
}
