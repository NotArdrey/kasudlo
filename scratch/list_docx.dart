import 'dart:io';
import 'package:archive/archive.dart';

void main() {
  final bytes = File('e:/flutter-project/Kasudlo/assets/template/cdx_template.docx').readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  for(final f in archive) {
    print(f.name);
  }
}
