import 'dart:io';

void main() {
  final content = File('lib/src/services/report_exporter.dart').readAsStringSync();
  final insert = File('scratch/missing_fields_mapped.dart').readAsStringSync();
  final newContent = content.replaceFirst('  // --- END OF CUSTOM TAG MAPPING ---', insert + '\n  // --- END OF CUSTOM TAG MAPPING ---');
  File('lib/src/services/report_exporter.dart').writeAsStringSync(newContent);
}
