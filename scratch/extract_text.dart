import 'dart:io';
void main() {
  var content = File('template_unzip/word/document.xml').readAsStringSync();
  content = content.replaceAll(RegExp(r'<[^>]*>'), '');
  File('template_unzip/all_text.txt').writeAsStringSync(content);
}
