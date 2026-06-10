import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';

const _docmosisRenderUrl = String.fromEnvironment(
  'DOCMOSIS_RENDER_URL',
  defaultValue: 'http://127.0.0.1:8787/render',
);

Future<List<int>> renderDocmosisTemplate({
  required HealthSubmission submission,
  required Map<String, dynamic> fields,
  required String fileName,
}) async {
  final response = await http.post(
    Uri.parse(_docmosisRenderUrl),
    headers: const {'content-type': 'application/json'},
    body: jsonEncode({
      'fileName': fileName,
      'submissionId': submission.clientSubmissionId,
      'fields': fields,
    }),
  );

  if (response.statusCode != 200) {
    final message = response.body.trim();
    throw StateError(
      message.isEmpty
          ? 'Docmosis render failed with HTTP ${response.statusCode}.'
          : message,
    );
  }

  return response.bodyBytes;
}
