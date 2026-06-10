import 'dart:convert';
import 'package:xml/xml.dart';

void main() {
  final content = '''
  <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    <w:body>
      <w:tbl>
        <w:tr>
          <w:tc><w:p><w:r><w:t>{{name}}</w:t></w:r></w:p></w:tc>
          <w:tc><w:p><w:r><w:t>{{age}}</w:t></w:r></w:p></w:tc>
        </w:tr>
        <w:tr>
          <w:tc><w:p><w:r><w:t>{{smoker_name}}</w:t></w:r></w:p></w:tc>
          <w:tc><w:p><w:r><w:t>{{smoker_age}}</w:t></w:r></w:p></w:tc>
        </w:tr>
      </w:tbl>
    </w:body>
  </w:document>
  ''';

  final doc = XmlDocument.parse(content);
  final fields = {
    'name': 'Global Name',
    'smokers': [
      {'smoker_name': 'John', 'smoker_age': '20'},
      {'smoker_name': 'Jane', 'smoker_age': '22'},
    ]
  };

  final listFields = <String, List<dynamic>>{};
  fields.forEach((key, value) {
    if (value is List) listFields[key] = value;
  });

  // Find table rows
  final trElements = doc.findAllElements('w:tr').toList();
  for (final tr in trElements) {
    final text = tr.innerText;
    // Check if this row is a template for any list
    String? matchedListKey;
    for (final listEntry in listFields.entries) {
      final listName = listEntry.key;
      final list = listEntry.value;
      if (list.isNotEmpty && list.first is Map) {
        final firstItem = list.first as Map;
        bool hasMatch = false;
        for (final itemKey in firstItem.keys) {
          if (text.contains('{{$itemKey}}')) {
            hasMatch = true;
            break;
          }
        }
        if (hasMatch) {
          matchedListKey = listName;
          break;
        }
      }
    }

    if (matchedListKey != null) {
      final list = listFields[matchedListKey]!;
      for (final item in list) {
        final clone = tr.copy();
        // Replace tags in clone
        for (final t in clone.findAllElements('w:t')) {
          String tText = t.innerText;
          (item as Map).forEach((k, v) {
            tText = tText.replaceAll('{{$k}}', v.toString());
          });
          t.innerText = tText;
        }
        tr.parent!.children.insert(tr.parent!.children.indexOf(tr), clone);
      }
      tr.parent!.children.remove(tr);
    }
  }

  // Now replace global tags
  for (final t in doc.findAllElements('w:t')) {
    String tText = t.innerText;
    fields.forEach((k, v) {
      if (v is! List) {
        tText = tText.replaceAll('{{$k}}', v.toString());
      }
    });
    t.innerText = tText;
  }

  print(doc.toXmlString(pretty: true));
}
