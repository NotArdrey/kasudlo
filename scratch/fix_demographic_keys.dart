import 'dart:io';

void main() {
  final content = File('lib/src/services/report_exporter.dart').readAsStringSync();
  final newContent = content.replaceAll("'birthdate_month': row[5],", "'birth_month': row[5],")
                            .replaceAll("'birthdate_day': row[6],", "'birth_day': row[6],")
                            .replaceAll("'birthdate_year': row[7],", "'birth_year': row[7],");
  File('lib/src/services/report_exporter.dart').writeAsStringSync(newContent);
}
