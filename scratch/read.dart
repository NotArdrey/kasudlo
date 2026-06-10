import 'dart:io';

void main() {
  final content = File('lib/src/services/report_exporter_legacy.dart').readAsStringSync();
  print(content.substring(0, 1500));
}
