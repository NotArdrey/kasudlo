import 'dart:io';

void main() {
  final files = [
    r'e:\flutter-project\Kasudlo\lib\src\state\app_controller.dart',
    r'e:\flutter-project\Kasudlo\lib\src\screens\admin_screen.dart',
    r'e:\flutter-project\Kasudlo\lib\src\screens\settings_screen.dart',
    r'e:\flutter-project\Kasudlo\lib\src\screens\contact_information_screen.dart',
    r'e:\flutter-project\Kasudlo\lib\src\services\groq_gateway.dart',
    r'e:\flutter-project\Kasudlo\test\button_flow_test.dart',
    r'e:\flutter-project\Kasudlo\test\report_summary_test.dart',
    r'e:\flutter-project\Kasudlo\test\report_exporter_test.dart',
  ];

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) continue;

    var content = file.readAsStringSync();

    // Perform regex replacements
    content = content.replaceAll(RegExp(r'\bworker\b'), 'nurse');
    content = content.replaceAll(RegExp(r'\bWorker\b'), 'Nurse');
    content = content.replaceAll(RegExp(r'\bworkers\b'), 'nurses');
    content = content.replaceAll(RegExp(r'\bWorkers\b'), 'Nurses');

    file.writeAsStringSync(content);
  }
  print('Done replacing worker with nurse in Dart files.');
}
