import 'dart:io';
import 'package:archive/archive.dart';

void main() {
  final dir = Directory('.');
  for (final entry in dir.listSync()) {
    if (entry is File && entry.path.endsWith('.docx')) {
      final name = entry.path.split(Platform.pathSeparator).last;
      try {
        final bytes = entry.readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);
        final docXmlFile = archive.findFile('word/document.xml');
        if (docXmlFile == null) continue;
        final content = String.fromCharCodes(docXmlFile.content as List<int>);

        // Match both <<tag>> and {{tag}} style tags
        final pattern1 = RegExp(r'<<[^>]+>>');
        final pattern2 = RegExp(r'\{\{[^\}]+\}\}');
        final matches1 = pattern1.allMatches(content).toList();
        final matches2 = pattern2.allMatches(content).toList();

        print(
          '$name: found ${matches1.length} <<...>> tags, ${matches2.length} {{...}} tags.',
        );
        if (matches1.isNotEmpty) {
          print(
            '  First 3 <<...>>: ${matches1.take(3).map((m) => m.group(0)).join(", ")}',
          );
        }
        if (matches2.isNotEmpty) {
          print(
            '  First 3 {{...}}: ${matches2.take(3).map((m) => m.group(0)).join(", ")}',
          );
        }
      } catch (e) {
        print('$name: Error: $e');
      }
    }
  }
}
