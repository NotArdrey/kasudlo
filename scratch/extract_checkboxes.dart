import 'dart:io';

void main() {
  final file = File('e:/flutter-project/Kasudlo/lib/src/services/report_exporter.dart');
  final lines = file.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains('( )')) {
      // Print context: previous line, the line, and next line to understand the question
      var prefix = i > 0 && !lines[i-1].contains('( )') ? '${i}: ${lines[i-1].trim()}\n' : '';
      print('$prefix${i+1}: ${lines[i].trim()}');
    }
  }
}
