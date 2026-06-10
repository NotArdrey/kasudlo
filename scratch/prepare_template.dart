import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';

void main() {
  final inputBytes = File('FINAL-CDX-TOOL-2024-1.docx').readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(inputBytes);

  final documentFile = archive.findFile('word/document.xml');
  if (documentFile == null) throw Exception('Invalid docx template');

  var content = String.fromCharCodes(documentFile.content as List<int>);

  // First, we do the regex text injections (the ones we did before)
  String inject(
    String source,
    String keyword,
    String tag, {
    int skipOccurrences = 0,
  }) {
    final xmlGap = r'(?:<[^>]+>)*';
    final flexKeyword = keyword
        .split('')
        .map((char) {
          if (char.trim().isEmpty) return r'(?:<[^>]+>|\s)+';
          return RegExp.escape(char);
        })
        .join(xmlGap);

    final searchPattern = RegExp(flexKeyword);
    int startIdx = 0;
    for (int i = 0; i <= skipOccurrences; i++) {
      final match = searchPattern.firstMatch(source.substring(startIdx));
      if (match == null) {
        startIdx = -1;
        break;
      }
      startIdx += match.end;
    }

    if (startIdx == -1) return source;

    final underscorePattern = RegExp(r'_{3,}');
    final match = underscorePattern.firstMatch(source.substring(startIdx));
    if (match != null) {
      final replaceStart = startIdx + match.start;
      final replaceEnd = startIdx + match.end;
      return source.substring(0, replaceStart) +
          '{{$tag}}' +
          source.substring(replaceEnd);
    }
    return source;
  }

  content = inject(content, 'Control No.', 'control_no');
  content = inject(content, 'Number of Family', 'number_of_family');
  content = inject(content, 'Address', 'address');
  content = inject(content, 'Date:', 'first_visit_date');
  content = inject(content, 'Informant', 'informant');
  content = inject(content, '2nd visit', 'second_visit_date');
  content = inject(content, 'Surveyed by', 'surveyed_by');
  content = inject(content, '3rd visit', 'third_visit_date');
  content = inject(content, 'Time Started', 'time_started');
  content = inject(content, 'Time Finished', 'time_finished');
  content = inject(content, 'Status of last visit', 'status_of_last_visit');
  content = inject(content, 'Dialect Frequently', 'dialect_frequently_used');
  content = inject(content, 'Organizations', 'organizations_other');
  content = inject(content, 'Tradition/Customs', 'traditions_customs_other');
  content = inject(
    content,
    'Recreational Facilities',
    'recreational_facilities_other',
  );
  content = inject(
    content,
    'Mode of Communication',
    'mode_of_communication_other',
  );
  content = inject(content, 'Earner 1', 'earner_1_position');
  content = inject(content, 'Php', 'earner_1_income', skipOccurrences: 0);
  content = inject(content, 'Earner 2', 'earner_2_position');
  content = inject(content, 'Php', 'earner_2_income', skipOccurrences: 1);
  content = inject(content, 'Earner 3', 'earner_3_position');
  content = inject(content, 'Php', 'earner_3_income', skipOccurrences: 2);
  content = inject(content, 'Earner 4', 'earner_4_position');
  content = inject(content, 'Php', 'earner_4_income', skipOccurrences: 3);
  content = inject(
    content,
    'Distance of source of water',
    'water_source_distance_from_house',
  );
  content = inject(
    content,
    'packs per day',
    'smoking_frequency_sticks_or_packs_per_day',
  );
  content = inject(content, 'Types of Drugs', 'types_of_drugs');
  content = inject(content, 'RHU Physicians', 'rhu_physicians_schedule');
  content = inject(content, 'RHU Nurse', 'rhu_nurse_schedule');
  content = inject(content, 'BHC Midwife', 'bhc_midwife_schedule');
  content = inject(
    content,
    'Amount per year',
    'health_budget_amount_per_year_php',
  );
  content = inject(
    content,
    'concerns/suggestions',
    'general_lifestyle_area_concerns_suggestions',
  );

  // Now, parse the XML and inject into tables
  final doc = XmlDocument.parse(content);
  final tables = doc.descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == 'tbl')
      .toList();

  // Helper to ensure a table cell has a text node
  void injectCell(XmlElement tc, String text) {
    var p = tc.children
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'p')
        .firstOrNull;
    if (p == null) {
      p = XmlElement(XmlName('w:p'));
      tc.children.add(p);
    }
    final r = XmlElement(XmlName('w:r'));
    final t = XmlElement(XmlName('w:t'))..innerText = text;
    r.children.add(t);
    p.children.add(r);
  }

  // 1. Demographic Table (First table in document)
  if (tables.isNotEmpty) {
    final demoTable = tables[0];
    final rows = demoTable.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'tr')
        .toList();
    // Headers are in rows 0,1,2. Data rows start at index 3.
    // There are 13 rows for data.
    int rowIndex = 0;
    for (int i = 3; i < rows.length && rowIndex < 13; i++) {
      final cells = rows[i].descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'tc')
          .toList();
      // 17 columns in demographic table
      for (int c = 0; c < cells.length && c < 17; c++) {
        injectCell(cells[c], '{{demo_r${rowIndex}_c$c}}');
      }
      rowIndex++;
    }
  }

  // 2. Anthropometric Table (Find table near "Anthropometric Data")
  // Let's just find the table that has headers "Age in mos."
  XmlElement? anthroTable;
  for (final t in tables) {
    if (t.innerText.contains('Age in mos')) {
      anthroTable = t;
      break;
    }
  }
  if (anthroTable != null) {
    final rows = anthroTable.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'tr')
        .toList();
    // Header is row 0 and 1. Data rows start at 2.
    int rowIndex = 0;
    for (int i = 2; i < rows.length && rowIndex < 4; i++) {
      final cells = rows[i].descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'tc')
          .toList();
      for (int c = 0; c < cells.length && c < 12; c++) {
        injectCell(cells[c], '{{anthro_r${rowIndex}_c$c}}');
      }
      rowIndex++;
    }
  }

  // 3. 24-Hour Food Recall Table
  XmlElement? recallTable;
  for (final t in tables) {
    if (t.innerText.contains('Food taken') &&
        t.innerText.contains('BREAKFAST')) {
      recallTable = t;
      break;
    }
  }
  if (recallTable != null) {
    final rows = recallTable.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'tr')
        .toList();
    // Rows 1 to 6 are the meal rows
    final mealRows = [
      'breakfast',
      'snack1',
      'lunch',
      'snack2',
      'dinner',
      'midnight_snack',
    ];
    for (int i = 0; i < mealRows.length; i++) {
      final rIdx = i + 1; // start from row 1
      if (rIdx < rows.length) {
        final cells = rows[rIdx].descendants
            .whereType<XmlElement>()
            .where((e) => e.name.local == 'tc')
            .toList();
        if (cells.length >= 3) {
          // cells[0] is Date, cells[1] is Meal (BREAKFAST), cells[2] is Food taken
          injectCell(cells[0], '{{recall_date_${mealRows[i]}}}');
          injectCell(cells[2], '{{recall_food_${mealRows[i]}}}');
        }
      }
    }
  }

  final newArchive = Archive();
  for (final file in archive) {
    if (file.name == 'word/document.xml') {
      newArchive.addFile(
        ArchiveFile.string('word/document.xml', doc.toXmlString(pretty: false)),
      );
    } else {
      newArchive.addFile(file);
    }
  }

  final outBytes = ZipEncoder().encode(newArchive);
  File('assets/template/cdx_template.docx').writeAsBytesSync(outBytes!);
  print('Successfully prepared template with table tags.');
}
