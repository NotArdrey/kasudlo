import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import '../models.dart';
import 'report_exporter.dart';
import 'report_file_saver_stub.dart'
    if (dart.library.html) 'report_file_saver_web.dart';

enum ReportExportFormatLegacy { pdf, docs }

extension ReportExportFormatLegacyLabel on ReportExportFormatLegacy {
  String get label => switch (this) {
    ReportExportFormatLegacy.pdf => 'PDF',
    ReportExportFormatLegacy.docs => 'Docs',
  };
  String get fileExtension => switch (this) {
    ReportExportFormatLegacy.pdf => 'pdf',
    ReportExportFormatLegacy.docs => 'docx',
  };
  String get mimeType => switch (this) {
    ReportExportFormatLegacy.pdf => 'application/pdf',
    ReportExportFormatLegacy.docs =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };
}

class ReportExportResultLegacy {
  const ReportExportResultLegacy({
    required this.fileName,
    required this.savedLocation,
    required this.recordCount,
    required this.format,
  });

  final String fileName;
  final String savedLocation;
  final int recordCount;
  final ReportExportFormatLegacy format;
}

Future<ReportExportResultLegacy> exportReportRecordsMiniword({
  required List<HealthSubmission> submissions,
  required ReportExportFormatLegacy format,
  DateTime? exportedAt,
}) async {
  final exportTime = exportedAt ?? DateTime.now();
  final sortedSubmissions = submissions.toList()
    ..sort((a, b) => a.respondentName.compareTo(b.respondentName));
  if (sortedSubmissions.length != 1) {
    throw ArgumentError('MiniWord export requires exactly one record.');
  }

  final fileSlug = 'kasudlo-community-survey-manual';
  final fileName =
      '$fileSlug-${DateFormat('yyyyMMdd-HHmmss').format(exportTime)}.${format.fileExtension}';

  final bytes = await _buildMiniwordDocxBytes(sortedSubmissions.single);

  final savedLocation = await saveExportFile(
    bytes: bytes,
    fileName: fileName,
    mimeType: format.mimeType,
  );

  return ReportExportResultLegacy(
    fileName: fileName,
    savedLocation: savedLocation,
    recordCount: sortedSubmissions.length,
    format: format,
  );
}

Future<List<int>> _buildMiniwordDocxBytes(HealthSubmission submission) async {
  final templateData = await rootBundle.load(
    'assets/template/miniword_template.docx',
  );
  final bytes = templateData.buffer.asUint8List(
    templateData.offsetInBytes,
    templateData.lengthInBytes,
  );
  final archive = ZipDecoder().decodeBytes(bytes);
  final fields = docmosisTemplateFields(submission);

  final listFields = <String, List<dynamic>>{};
  fields.forEach((key, value) {
    if (value is List) {
      listFields[key] = value;
    }
  });

  final outArchive = Archive();
  for (final file in archive) {
    if (!file.name.endsWith('.xml')) {
      outArchive.addFile(file);
      continue;
    }

    String content = utf8.decode(file.content);
    if (file.name.contains('word/document') ||
        file.name.contains('header') ||
        file.name.contains('footer')) {
      if (file.name.contains('word/document')) {
        content = _ensureInlineManpowerTags(content);
      }
      try {
        final doc = XmlDocument.parse(content);

        final trElements = doc.findAllElements('w:tr').toList();
        for (final tr in trElements) {
          final rowText = tr.innerText;
          final matchedListKey = _matchingListKey(rowText, listFields);
          if (matchedListKey == null) {
            continue;
          }

          final list = listFields[matchedListKey]!;
          final parent = tr.parent;
          if (parent == null) {
            continue;
          }

          final insertionIndex = parent.children.indexOf(tr);
          for (var index = 0; index < list.length; index++) {
            final item = list[index];
            if (item is! Map) {
              continue;
            }
            final clone = tr.copy();
            _replaceTemplateTagsInElement(
              clone,
              Map<String, dynamic>.from(item),
            );
            parent.children.insert(insertionIndex + index, clone);
          }
          parent.children.remove(tr);
        }

        _replaceTemplateTagsInElement(doc.rootElement, fields);
        if (file.name.contains('word/document')) {
          _appendExportedInformationTable(doc, submission);
        }
        content = doc.toXmlString(pretty: false);
      } catch (_) {
        content = _replaceWholeXmlTags(content, fields);
      }
    } else {
      content = _replaceWholeXmlTags(content, fields);
    }

    final encoded = utf8.encode(content);
    outArchive.addFile(ArchiveFile(file.name, encoded.length, encoded));
  }

  return ZipEncoder().encode(outArchive);
}

void _appendExportedInformationTable(
  XmlDocument document,
  HealthSubmission submission,
) {
  final body = document.findAllElements('w:body').firstOrNull;
  if (body == null) {
    return;
  }

  final rows = _exportedInformationRows(submission);
  if (rows.isEmpty) {
    return;
  }

  final fragment = XmlDocument.parse('''
<root xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p><w:r><w:br w:type="page"/></w:r></w:p>
  <w:p>
    <w:r><w:rPr><w:b/></w:rPr><w:t>Exported Information Table</w:t></w:r>
  </w:p>
  <w:tbl>
    <w:tblPr>
      <w:tblW w:w="0" w:type="auto"/>
      <w:tblBorders>
        <w:top w:val="single" w:sz="4" w:space="0" w:color="000000"/>
        <w:left w:val="single" w:sz="4" w:space="0" w:color="000000"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/>
        <w:right w:val="single" w:sz="4" w:space="0" w:color="000000"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="000000"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      </w:tblBorders>
    </w:tblPr>
    ${_exportedInformationHeaderRowXml()}
    ${rows.map(_exportedInformationRowXml).join()}
  </w:tbl>
</root>
''');

  final nodes = fragment.rootElement.children.map((node) => node.copy());
  final sectPrIndex = body.children.indexWhere(
    (node) => node is XmlElement && node.name.local == 'sectPr',
  );
  if (sectPrIndex == -1) {
    body.children.addAll(nodes);
  } else {
    body.children.insertAll(sectPrIndex, nodes);
  }
}

String _exportedInformationHeaderRowXml() {
  return '''
<w:tr>
  <w:tc><w:tcPr><w:tcW w:w="3200" w:type="dxa"/></w:tcPr><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Field</w:t></w:r></w:p></w:tc>
  <w:tc><w:tcPr><w:tcW w:w="6000" w:type="dxa"/></w:tcPr><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Response</w:t></w:r></w:p></w:tc>
</w:tr>
''';
}

String _exportedInformationRowXml(_ExportedInformationRow row) {
  return '''
<w:tr>
  <w:tc><w:tcPr><w:tcW w:w="3200" w:type="dxa"/></w:tcPr><w:p><w:r><w:t>${_escapeXmlText(row.field)}</w:t></w:r></w:p></w:tc>
  <w:tc><w:tcPr><w:tcW w:w="6000" w:type="dxa"/></w:tcPr><w:p><w:r><w:t>${_escapeXmlText(row.response)}</w:t></w:r></w:p></w:tc>
</w:tr>
''';
}

List<_ExportedInformationRow> _exportedInformationRows(
  HealthSubmission submission,
) {
  final rows = <_ExportedInformationRow>[];

  void add(String field, Object? value) {
    final response = _exportedInformationValue(value);
    if (response.isEmpty) {
      return;
    }
    rows.add(_ExportedInformationRow(field, response));
  }

  add('Respondent Name', submission.respondentName);
  add('Respondent Age', submission.respondentAge);
  add('Address', submission.address);
  add('Family Members Count', submission.familyMembersCount);
  add('Health Problems', submission.healthProblems);
  add('Vaccination Status', submission.vaccinationStatus);
  add('Water Sanitation', submission.waterSanitation);
  add('Nutritional Status', submission.nutritionalStatus);
  add('Community Concerns', submission.communityConcerns);
  add('Notes', submission.notes);
  add(
    'Created At',
    DateFormat('yyyy-MM-dd HH:mm').format(submission.createdAt),
  );
  add('Sync Status', submission.syncStatus.name);

  _flattenExportedInformation(
    rows: rows,
    label: 'Survey Data',
    value: submission.surveyData,
  );

  return rows;
}

void _flattenExportedInformation({
  required List<_ExportedInformationRow> rows,
  required String label,
  required Object? value,
}) {
  if (!_exportedInformationHasContent(value)) {
    return;
  }

  if (value is Map) {
    value.forEach((key, childValue) {
      _flattenExportedInformation(
        rows: rows,
        label: '$label > ${_exportedInformationLabel('$key')}',
        value: childValue,
      );
    });
    return;
  }

  if (value is List && value.any((item) => item is Map || item is List)) {
    for (var index = 0; index < value.length; index++) {
      _flattenExportedInformation(
        rows: rows,
        label: '$label #${index + 1}',
        value: value[index],
      );
    }
    return;
  }

  rows.add(_ExportedInformationRow(label, _exportedInformationValue(value)));
}

bool _exportedInformationHasContent(Object? value) {
  if (value == null) {
    return false;
  }
  if (value is String) {
    return value.trim().isNotEmpty;
  }
  if (value is Iterable) {
    return value.any(_exportedInformationHasContent);
  }
  if (value is Map) {
    return value.values.any(_exportedInformationHasContent);
  }
  return true;
}

String _exportedInformationValue(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is bool) {
    return value ? 'Yes' : 'No';
  }
  if (value is DateTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(value);
  }
  if (value is List) {
    return value
        .map(_exportedInformationValue)
        .where((item) => item.isNotEmpty)
        .join(', ');
  }
  if (value is Map) {
    return value.entries
        .map(
          (entry) =>
              '${_exportedInformationLabel('${entry.key}')}: ${_exportedInformationValue(entry.value)}',
        )
        .where((item) => item.trim().isNotEmpty)
        .join('; ');
  }
  return '$value'.trim();
}

String _exportedInformationLabel(String key) {
  return key
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _ensureInlineManpowerTags(String content) {
  const replacements = {
    'Categories of health manpower available':
        'Categories of health manpower available: {{health_manpower_categories}}',
    'Geographical distribution':
        'Geographical distribution: {{health_manpower_distribution}}',
    'Number of Physician, Nurse, midwife and other members of RHU team per population':
        'Number of Physician, Nurse, midwife and other members of RHU team per population: {{rhu_team_population}}',
    'Existing manpower development/ policies':
        'Existing manpower development/ policies: {{manpower_policies}}',
  };

  var output = content;
  for (final entry in replacements.entries) {
    if (output.contains(entry.value)) {
      continue;
    }
    output = output.replaceAll(entry.key, entry.value);
  }
  return output;
}

String? _matchingListKey(
  String rowText,
  Map<String, List<dynamic>> listFields,
) {
  for (final listEntry in listFields.entries) {
    final list = listEntry.value;
    if (list.isEmpty || list.first is! Map) {
      continue;
    }

    final firstItem = list.first as Map;
    for (final itemKey in firstItem.keys) {
      if (rowText.contains('{{$itemKey}}')) {
        return listEntry.key;
      }
    }
  }
  return null;
}

void _replaceTemplateTagsInElement(
  XmlElement element,
  Map<String, dynamic> values,
) {
  for (final paragraph in element.findAllElements('w:p')) {
    _replaceTemplateTagsInTextNodes(paragraph.findAllElements('w:t'), values);
  }
}

void _replaceTemplateTagsInTextNodes(
  Iterable<XmlElement> textElements,
  Map<String, dynamic> values,
) {
  final elements = textElements.toList();
  if (elements.isEmpty) {
    return;
  }

  final originalTexts = elements.map((element) => element.innerText).toList();
  final combinedText = originalTexts.join();
  final matches = RegExp(
    r'\{\{([^{}]+)\}\}',
    caseSensitive: false,
  ).allMatches(combinedText).toList();
  if (matches.isEmpty) {
    return;
  }

  final outputTexts = originalTexts.toList();
  for (final match in matches.reversed) {
    final tagName = match.group(1)!.trim();
    final value = _lookupTemplateValue(values, tagName);
    final replacement = value == null ? '' : _docxTextValue(value);
    final start = _textPositionForStart(originalTexts, match.start);
    final end = _textPositionForEnd(originalTexts, match.end);

    if (start.index == end.index) {
      final text = outputTexts[start.index];
      outputTexts[start.index] =
          text.substring(0, start.offset) +
          replacement +
          text.substring(end.offset);
      continue;
    }

    outputTexts[start.index] =
        outputTexts[start.index].substring(0, start.offset) + replacement;
    for (var index = start.index + 1; index < end.index; index++) {
      outputTexts[index] = '';
    }
    outputTexts[end.index] = outputTexts[end.index].substring(end.offset);
  }

  for (var index = 0; index < elements.length; index++) {
    elements[index].innerText = outputTexts[index];
  }
}

String _replaceWholeXmlTags(String content, Map<String, dynamic> fields) {
  var output = content;
  fields.forEach((key, value) {
    if (value is List || value == null) {
      return;
    }
    output = output.replaceAll(
      RegExp('\\{\\{${RegExp.escape(key)}\\}\\}', caseSensitive: false),
      _escapeXml(_docxTextValue(value)),
    );
  });
  return output.replaceAll(RegExp(r'\{\{.*?\}\}'), '');
}

Object? _lookupTemplateValue(Map<String, dynamic> values, String key) {
  if (values.containsKey(key)) {
    return values[key];
  }

  final normalizedKey = key.toLowerCase();
  for (final entry in values.entries) {
    if (entry.key.toLowerCase() == normalizedKey) {
      return entry.value;
    }
  }
  return null;
}

_TextPosition _textPositionForStart(List<String> texts, int offset) {
  var cursor = 0;
  for (var index = 0; index < texts.length; index++) {
    final length = texts[index].length;
    if (offset < cursor + length || (length == 0 && offset == cursor)) {
      return _TextPosition(index, offset - cursor);
    }
    cursor += length;
  }
  return _TextPosition(texts.length - 1, texts.last.length);
}

_TextPosition _textPositionForEnd(List<String> texts, int offset) {
  if (offset <= 0) {
    return const _TextPosition(0, 0);
  }

  final target = offset - 1;
  var cursor = 0;
  for (var index = 0; index < texts.length; index++) {
    final length = texts[index].length;
    if (target < cursor + length) {
      return _TextPosition(index, target - cursor + 1);
    }
    cursor += length;
  }
  return _TextPosition(texts.length - 1, texts.last.length);
}

String _docxTextValue(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is bool) {
    return value ? '\u2713' : ' ';
  }
  if (value is List) {
    return value
        .map(_docxTextValue)
        .where((item) => item.isNotEmpty)
        .join(', ');
  }
  if (value is Map) {
    return value.entries
        .map((entry) => '${entry.key}: ${_docxTextValue(entry.value)}')
        .where((item) => item.trim().isNotEmpty)
        .join('; ');
  }

  final text = '$value'.trim();
  if (text == 'Yes') {
    return '\u2713';
  }
  if (text == 'No') {
    return ' ';
  }
  return text;
}

class _TextPosition {
  const _TextPosition(this.index, this.offset);

  final int index;
  final int offset;
}

class _ExportedInformationRow {
  const _ExportedInformationRow(this.field, this.response);

  final String field;
  final String response;
}

String _escapeXml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;')
      .replaceAll('\n', '<w:br/>');
}

String _escapeXmlText(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
