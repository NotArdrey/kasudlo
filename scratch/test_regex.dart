import 'dart:io';

void main() {
  final file = File('e:/flutter-project/Kasudlo/temp_docx/word/document.xml');
  var content = file.readAsStringSync();

  // Let's search for "Respect for elderly" with any XML tags in between.
  // We want to match: ( ) [xml tags or spaces] Respect [xml tags or spaces] for [xml tags or spaces] elderly

  String makeRegex(String text) {
    // Escape special regex characters in the text
    final escaped = RegExp.escape(text);
    // Replace spaces with optional XML tags and whitespace
    final spaced = escaped.split(RegExp(r'\s+')).join(r'(?:<[^>]+>|\s)*');
    return r'\(\s*\)(?:<[^>]+>|\s)*' + spaced;
  }

  final regexStr = makeRegex('Respect for elderly');
  final regex = RegExp(regexStr);

  final matches = regex.allMatches(content);
  print('Regex: $regexStr');
  print('Found ${matches.length} matches for "Respect for elderly"');
  for (final match in matches) {
    print('Match: ${match.group(0)}');
  }

  final nuclearRegexStr = makeRegex('Nuclear');
  final nuclearRegex = RegExp(nuclearRegexStr);
  print(
    'Found ${nuclearRegex.allMatches(content).length} matches for "Nuclear"',
  );
}
