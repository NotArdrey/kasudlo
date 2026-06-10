import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

void main() {
  final bytes = File('lib/src/services/report_exporter_legacy.dart').readAsBytesSync();
  // Decode utf-16le
  final buffer = StringBuffer();
  for (int i = 0; i < bytes.length; i += 2) {
    if (i + 1 < bytes.length) {
      int codeUnit = bytes[i] | (bytes[i + 1] << 8);
      buffer.writeCharCode(codeUnit);
    }
  }
  File('lib/src/services/report_exporter_legacy_utf8.dart').writeAsStringSync(buffer.toString());
  print('Done');
}
