import 'dart:io';
import '../lib/src/survey_schema.dart';

void main() {
  final buffer = StringBuffer();
  buffer.writeln('# Docmosis Tagging Guide');
  buffer.writeln('');
  buffer.writeln(
    'This document provides the exact Docmosis tags you need to copy and paste into your MS Word document.',
  );
  buffer.writeln('');

  for (final section in surveySections) {
    buffer.writeln('## ${section.title}');
    for (final field in section.fields) {
      if (field.type == SurveyFieldType.repeatableTable) {
        buffer.writeln('### ${field.label} (Table)');
        buffer.writeln('Start row (first cell): `<<rs_${field.key}>>`');
        for (final subField in field.fields) {
          buffer.writeln('- **${subField.label}**: `<<${subField.key}>>`');
        }
        buffer.writeln('End row (last cell): `<<es_${field.key}>>`');
        buffer.writeln('');
      } else if (field.type == SurveyFieldType.select ||
          field.type == SurveyFieldType.multiSelect ||
          field.type == SurveyFieldType.singleSelectCheckbox ||
          field.type == SurveyFieldType.multiSelectCheckbox) {
        buffer.writeln('### ${field.label} (Checkboxes)');
        for (final option in field.options) {
          final cleanOption = option.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
          buffer.writeln(
            '- **$option**: `<<cs_${field.key}_$cleanOption>>(X)<<else>>( )<<es_>>`',
          );
        }
        buffer.writeln('');
      } else if (field.type == SurveyFieldType.heading ||
          field.type == SurveyFieldType.note ||
          field.type == SurveyFieldType.priorityRankingGroup ||
          field.type == SurveyFieldType.mealTimeGroup) {
        // Skip
      } else {
        buffer.writeln('- **${field.label}**: `<<${field.key}>>`');
      }
    }
    buffer.writeln('');
  }

  File(
    'e:/Codes/kasudlo/docmosis_tags_guide.md',
  ).writeAsStringSync(buffer.toString());
  print('Done');
}
