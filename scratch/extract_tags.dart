import 'dart:io';

void main() async {
  final file = File('e:/Codes/kasudlo/scratch/miniword_extracted/word/document.xml');
  final content = await file.readAsString();
  
  final regex = RegExp(r'\{\{(.*?)\}\}');
  final matches = regex.allMatches(content);
  
  final tags = matches.map((m) => m.group(1)).toSet().toList()..sort();
  print(tags.join('\n'));
}
