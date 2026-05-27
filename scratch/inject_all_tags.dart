import 'dart:io';

void main() {
  final backupFile = File('e:/flutter-project/Kasudlo/temp_docx_backup/word/document.xml');
  final targetFile = File('e:/flutter-project/Kasudlo/temp_docx/word/document.xml');
  
  var content = backupFile.readAsStringSync();
  int replaced = 0;

  /// Replace the first sequence of 3+ underscores that appears *after* [keyword]
  /// Note: The keyword is searched literally.
  String inject(String source, String keyword, String tag, {int skipOccurrences = 0}) {
    int startIdx = 0;
    for (int i = 0; i <= skipOccurrences; i++) {
      startIdx = source.indexOf(keyword, startIdx);
      if (startIdx == -1) break;
      if (i < skipOccurrences) startIdx += keyword.length;
    }

    if (startIdx == -1) {
      print('WARN: Keyword "$keyword" not found (skip: $skipOccurrences) for tag $tag');
      return source;
    }

    final underscorePattern = RegExp(r'_{3,}');
    final match = underscorePattern.firstMatch(source.substring(startIdx));
    if (match != null) {
      final replaceStart = startIdx + match.start;
      final replaceEnd = startIdx + match.end;
      replaced++;
      return source.substring(0, replaceStart) + '{{$tag}}' + source.substring(replaceEnd);
    } else {
      print('WARN: No underscores found after "$keyword" for tag $tag');
    }
    return source;
  }

  // ── Header fields ──
  content = inject(content, '>Control No.', 'control_no');
  content = inject(content, '>Number of Family', 'number_of_family');
  content = inject(content, '>Address', 'address');
  content = inject(content, 'Date:', 'first_visit_date'); // Date: 1st visit
  content = inject(content, '>Informant', 'informant');
  content = inject(content, '2nd visit', 'second_visit_date');
  content = inject(content, '>Surveyed by', 'surveyed_by');
  content = inject(content, '3rd visit', 'third_visit_date');
  content = inject(content, 'Time Started', 'time_started');
  content = inject(content, 'Time Finished', 'time_finished');
  content = inject(content, 'Status of last visit', 'status_of_last_visit');

  // ── Page 2: Dialect ──
  content = inject(content, 'Dialect Frequently', 'dialect_frequently_used');

  // ── Page 2: "Other" specify fields ──
  content = inject(content, 'Organizations:', 'organizations_other');
  content = inject(content, 'Tradition/Customs:', 'traditions_customs_other');
  content = inject(content, 'Recreational Facilities:', 'recreational_facilities_other');
  content = inject(content, 'Mode of Communication', 'mode_of_communication_other');

  // ── Page 2: Income earners ──
  content = inject(content, 'Earner 1', 'earner_1_position');
  content = inject(content, 'Earner 1', 'earner_1_income', skipOccurrences: 1);
  content = inject(content, 'Earner 2', 'earner_2_position');
  content = inject(content, 'Earner 2', 'earner_2_income', skipOccurrences: 1);
  content = inject(content, 'Earner 3', 'earner_3_position');
  content = inject(content, 'Earner 3', 'earner_3_income', skipOccurrences: 1);
  content = inject(content, 'Earner 4', 'earner_4_position');
  content = inject(content, 'Earner 4', 'earner_4_income', skipOccurrences: 1);

  // ── Page 3: Water source distance ──
  content = inject(content, 'Distance of source of water', 'water_source_distance_from_house');

  // ── Page 4: Smoking & Drugs ──
  content = inject(content, 'packs per day', 'smoking_frequency_sticks_or_packs_per_day');
  content = inject(content, 'Type of Drugs', 'types_of_drugs');

  // ── Page 6: Health resource text fields ──
  content = inject(content, 'RHU Physicians', 'rhu_physicians_schedule');
  content = inject(content, 'RHU Nurse', 'rhu_nurse_schedule');
  content = inject(content, 'BHC Midwife', 'bhc_midwife_schedule');
  content = inject(content, 'Amount per year', 'health_budget_amount_per_year_php');

  // ── Page 6: Concerns/suggestions ──
  content = inject(content, 'concerns/suggestions', 'general_lifestyle_area_concerns_suggestions');

  targetFile.writeAsStringSync(content);
  print('Injected $replaced tags successfully.');
}
