import 'dart:io';

void main() {
  final file = File('e:/flutter-project/Kasudlo/temp_docx/word/document.xml');
  var content = file.readAsStringSync();

  // Replacements
  // Address is tricky: <w:t>Address:</w:t> is followed by empty cells.
  // Actually, we can use the script from before to replace specific <w:t> tags.
  // Wait, let's just do simple text replacements for the fields if they exist,
  // or just replace the next _________ after a keyword.

  String replaceNextBlank(String source, String keyword, String tag) {
    final idx = source.indexOf(keyword);
    if (idx == -1) return source;

    // Find the next sequence of 5 or more underscores
    final regex = RegExp(r'_{5,}');
    final match = regex.firstMatch(source.substring(idx));
    if (match != null) {
      final start = idx + match.start;
      final end = idx + match.end;
      return source.substring(0, start) + '{{$tag}}' + source.substring(end);
    }
    return source;
  }

  content = replaceNextBlank(content, '>Control No.', 'control_no');
  content = replaceNextBlank(content, '>Number of Family', 'number_of_family');
  content = replaceNextBlank(content, '>Address', 'address');
  content = replaceNextBlank(content, '>Date:', 'first_visit_date');
  content = replaceNextBlank(content, '>1', 'first_visit_date'); // "1st visit"
  content = replaceNextBlank(content, '>Informant', 'informant');
  content = replaceNextBlank(content, '>2', 'second_visit_date');
  content = replaceNextBlank(content, '>Surveyed by', 'surveyed_by');
  content = replaceNextBlank(content, '>3', 'third_visit_date');
  content = replaceNextBlank(content, '>Time Started:', 'time_started');
  content = replaceNextBlank(content, '>Time Finished:', 'time_finished');
  content = replaceNextBlank(
    content,
    '>Status of last visit',
    'status_of_last_visit',
  );

  file.writeAsStringSync(content);
  print('Tags injected successfully.');
}
