import 'dart:io';

void main() {
  final file = File('lib/src/services/report_exporter.dart');
  String content = file.readAsStringSync();

  // Create a helper that finds the block of choices and replaces the whole block
  // format: 'marker', 'label', [\n        '( ) Choice 1', ... \n      ]

  String repl(String original, Map<String, String> map, String key) {
    String res = original;
    map.forEach((choice, label) {
      final chkCall = label == null
          ? "chk('$key', '$choice')"
          : "chk('$key', '$choice', '$label')";
      // Replace exactly the string literal for the choice.
      res = res.replaceAll("'( ) $choice'", chkCall);
      if (label != null) {
        res = res.replaceAll("'( ) $label'", chkCall);
      }
    });
    return res;
  }

  // To be safe, we will just globally replace specific strings in the file for these pages.
  // We already defined `chk(key, choice, [label])` in _surveyPdfPageThree. Oh wait, we need to add `chk` function to all pages!

  // Let's print out what we need to inject first.
  print('Ready to write advanced replacement script.');
}
