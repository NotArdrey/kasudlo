import 'dart:io';

void main() {
  var tags = File('scratch/tags_utf8.txt').readAsLinesSync().map((t) => t.replaceAll('{{', '').replaceAll('}}', '')).toSet();
  var exporter = File('lib/src/services/report_exporter.dart').readAsStringSync();
  
  var missing = tags.where((t) => !exporter.contains(t)).toList();
  missing.sort();
  for (var m in missing) {
    print(m);
  }
}
