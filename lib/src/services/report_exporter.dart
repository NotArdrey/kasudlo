// ignore_for_file: unused_element

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models.dart';
import '../survey_schema.dart';
import 'report_file_saver_stub.dart'
    if (dart.library.html) 'report_file_saver_web.dart';

const _collegeLogoAsset = 'assets/template/college-of-nursing.png';
const _universityLogoAsset = 'assets/template/bulacan-state-university.png';
const _regularFontAsset = 'assets/fonts/Roboto-Regular.ttf';
const _boldFontAsset = 'assets/fonts/Roboto-Bold.ttf';
const _italicFontAsset = 'assets/fonts/Roboto-Italic.ttf';
const _boldItalicFontAsset = 'assets/fonts/Roboto-BoldItalic.ttf';
const _templatePdfPageAssets = [
  'assets/template/cdx_pdf/page-01.png',
  'assets/template/cdx_pdf/page-02.png',
  'assets/template/cdx_pdf/page-03.png',
  'assets/template/cdx_pdf/page-04.png',
  'assets/template/cdx_pdf/page-05.png',
  'assets/template/cdx_pdf/page-06.png',
];
const _templatePdfPageFormat = PdfPageFormat(612, 935);
const _pdfCheckMark = '__KASUDLO_PDF_CHECK_MARK__';

enum ReportExportFormat { pdf, docs }

extension ReportExportFormatLabel on ReportExportFormat {
  String get label => switch (this) {
    ReportExportFormat.pdf => 'PDF',
    ReportExportFormat.docs => 'Docs',
  };

  String get fileExtension => switch (this) {
    ReportExportFormat.pdf => 'pdf',
    ReportExportFormat.docs => 'docx',
  };

  String get mimeType => switch (this) {
    ReportExportFormat.pdf => 'application/pdf',
    ReportExportFormat.docs =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };
}

class ReportExportResult {
  const ReportExportResult({
    required this.fileName,
    required this.savedLocation,
    required this.recordCount,
    required this.format,
  });

  final String fileName;
  final String savedLocation;
  final int recordCount;
  final ReportExportFormat format;
}

Future<ReportExportResult> exportReportRecords({
  required List<HealthSubmission> submissions,
  required ReportExportFormat format,
  DateTime? exportedAt,
}) async {
  final exportTime = exportedAt ?? DateTime.now();
  final sortedSubmissions = submissions.toList()
    ..sort((a, b) => a.respondentName.compareTo(b.respondentName));
  final fileName =
      'kasudlo-community-survey-${DateFormat('yyyyMMdd-HHmmss').format(exportTime)}.${format.fileExtension}';
  final bytes = format == ReportExportFormat.pdf
      ? await _buildPdfBytes(sortedSubmissions)
      : await _buildDocxBytes(sortedSubmissions);
  final savedLocation = await saveExportFile(
    bytes: bytes,
    fileName: fileName,
    mimeType: format.mimeType,
  );

  return ReportExportResult(
    fileName: fileName,
    savedLocation: savedLocation,
    recordCount: sortedSubmissions.length,
    format: format,
  );
}

Future<List<int>> _buildDocxBytes(List<HealthSubmission> submissions) async {
  final archive = Archive();
  void addFile(String name, String content) {
    archive.addFile(ArchiveFile.string(name, content));
  }

  Future<void> addAssetFile(String name, String assetPath) async {
    archive.addFile(ArchiveFile.bytes(name, await _loadAssetBytes(assetPath)));
  }

  addFile('[Content_Types].xml', _contentTypesXml);
  addFile('_rels/.rels', _packageRelsXml);
  addFile('docProps/app.xml', _appPropsXml);
  addFile('docProps/core.xml', _corePropsXml());
  addFile('word/_rels/document.xml.rels', _documentRelsXml);
  addFile('word/styles.xml', _stylesXml);
  addFile('word/document.xml', _documentXml(submissions));
  await addAssetFile('word/media/college-of-nursing.png', _collegeLogoAsset);
  await addAssetFile(
    'word/media/bulacan-state-university.png',
    _universityLogoAsset,
  );

  return ZipEncoder().encode(archive);
}

String _documentXml(List<HealthSubmission> submissions) {
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..writeln(
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">',
    )
    ..writeln('<w:body>');

  for (var index = 0; index < submissions.length; index++) {
    if (index > 0) {
      buffer.writeln(_pageBreakParagraph());
    }
    buffer.write(_surveyDocumentSection(submissions[index], index));
  }

  buffer
    ..writeln(
      '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="720" w:right="540" w:bottom="720" w:left="540" w:header="360" w:footer="360" w:gutter="0"/></w:sectPr>',
    )
    ..writeln('</w:body>')
    ..writeln('</w:document>');

  return buffer.toString();
}

String _surveyDocumentSection(HealthSubmission submission, int sectionIndex) {
  final surveyData = submission.surveyData;
  final buffer = StringBuffer()
    ..writeln(_documentHeaderTable(sectionIndex))
    ..writeln(_paragraph('COMMUNITY SURVEY TOOL', center: true, bold: true))
    ..writeln(_paragraph('(NEED ASSESSMENT)', center: true, bold: true))
    ..writeln(
      _table([
        [
          'Control No.',
          _surveyString(surveyData, 'control_no'),
          'Number of Family',
          _surveyString(surveyData, 'number_of_family').isEmpty
              ? '${submission.familyMembersCount}'
              : _surveyString(surveyData, 'number_of_family'),
        ],
        [
          'Address',
          _surveyString(surveyData, 'address').isEmpty
              ? submission.address
              : _surveyString(surveyData, 'address'),
          'Date: 1st visit',
          _surveyString(surveyData, 'first_visit_date').isEmpty
              ? _dateOnly(submission.createdAt)
              : _surveyString(surveyData, 'first_visit_date'),
        ],
        [
          'Informant',
          _surveyString(surveyData, 'informant').isEmpty
              ? submission.respondentName
              : _surveyString(surveyData, 'informant'),
          '2nd visit',
          _surveyString(surveyData, 'second_visit_date'),
        ],
        [
          'Surveyed by',
          _surveyString(surveyData, 'surveyed_by'),
          '3rd visit',
          _surveyString(surveyData, 'third_visit_date'),
        ],
        [
          'Time Started',
          _surveyString(surveyData, 'time_started'),
          'Time Finished',
          _surveyString(surveyData, 'time_finished'),
          'Status of last visit',
          _surveyString(surveyData, 'status_of_last_visit').isEmpty
              ? submission.syncStatus.name
              : _surveyString(surveyData, 'status_of_last_visit'),
        ],
      ]),
    )
    ..writeln(_sectionHeading('I. Demographic Variable'))
    ..writeln(
      _table(_demographicTableRows(submission), headerRows: 1, fontSize: 11),
    )
    ..writeln(_sectionHeading('Type of Family'))
    ..writeln(
      _paragraph(
        'Based on composition: ( ) Nuclear   ( ) Extended   ( ) Dyad   ( ) Homosexual/Same Sex   ( ) Cohabiting/Communal   ( ) Blended Family   ( ) Living with Grandparent(s)   ( ) Single-parent',
      ),
    )
    ..writeln(
      _paragraph(
        'Based on locus of power: ( ) Patrifocal/Patriarchal   ( ) Matrifocal/Matriachial   ( ) Egalitarian   ( ) Matricentric',
      ),
    )
    ..writeln(
      _paragraph(
        'Based on place of residence: ( ) Patrilocal   ( ) Matrilocal   ( ) Bilocal (Ambilocal)   ( ) Neolocal',
      ),
    )
    ..writeln(
      _paragraph(
        'Based on descent: ( ) Patrilineal   ( ) Matrilineal   ( ) Bilateral',
      ),
    )
    ..writeln(_paragraph('Dialect Frequently used:'))
    ..writeln(_sectionHeading('II. Socio-economic, cultural and environmental'))
    ..writeln(
      _table([
        ['Social Indicators', ''],
        ['Services in the Community', ''],
        ['Institutional Facilities', ''],
        ['Organizations', ''],
        ['Tradition/Customs', ''],
        ['Recreational Facilities', ''],
        ['Mode of Transportation', ''],
        ['Mode of Communication', ''],
        ['Economic Indicator', ''],
        ['Income earners / Monthly Family Income / Expenditures', ''],
        ['Financial Source for Family expenditures', ''],
        ['Adequacy of Family Income', ''],
        ['Cultural Orientation regarding Illness', ''],
        ['Cultural Belief', ''],
        ['Cultural Perception', ''],
        ['Community Involvement', ''],
      ]),
    )
    ..writeln(_sectionHeading('Environmental Indicator'))
    ..writeln(
      _table([
        ['Home ownership / construction / rooms', ''],
        ['Lighting / ventilation / sanitary condition', ''],
        ['Water and sanitation status', submission.waterSanitation],
        ['Water source / storage / distance', ''],
        ['Food storage / cooking facilities', ''],
        ['Waste disposal', ''],
        ['Toilet facilities', ''],
        ['Drainage system', ''],
        ['Animals / vectors / breeding sites / housing congestion', ''],
      ]),
    )
    ..writeln(_sectionHeading('III. Health and Illness Pattern'))
    ..writeln(
      _table([
        ['Lifestyle Practices', ''],
        ['Use of Safety Precaution', ''],
        ['Smoker / drugs / alcohol', ''],
      ]),
    )
    ..writeln(_subHeading('Nutritional Status'))
    ..writeln(
      _table([
        ['Name', 'Age', 'Nutritional Status', 'Remarks'],
        ..._nutritionRows(submission),
      ], headerRows: 1),
    )
    ..writeln(
      _table([
        ['Dietary History / 24-Hour Food Recall', ''],
        ['Beliefs and Practices', ''],
        ['Person mostly consulted in times of sickness', ''],
        ['Measures taken in times of sickness', ''],
        ['Medication / treatment', ''],
        ['Medical / Dental Check-up', ''],
      ]),
    )
    ..writeln(_sectionHeading('Community Health programs'))
    ..writeln(
      _table([
        ['Health Services available in the barangay health center', ''],
      ]),
    )
    ..writeln(_subHeading('Immunization record'))
    ..writeln(
      _table([
        [
          'Name',
          'Age',
          'Gender',
          'Complete according to Age',
          'Incomplete according to Age',
          'Fully Immunized Child',
          'Remarks',
        ],
        ..._immunizationRows(submission),
      ], headerRows: 1),
    )
    ..writeln(
      _table([
        ['Ante-natal Registration', ''],
        ['Family Planning', ''],
      ]),
    )
    ..writeln(_sectionHeading('Health Indicators'))
    ..writeln(_subHeading('Morbidity'))
    ..writeln(
      _table([
        [
          'Name',
          'Age',
          'Gender',
          'Cause',
          'Intervention',
          'Admitted',
          'Not Admitted',
          'With',
          'Without',
        ],
        ..._morbidityRows(submission),
      ], headerRows: 1),
    )
    ..writeln(
      _table([
        ['Mortality within the past 12 months', ''],
        ['History / Presence of Non Communicable Disease in the Family', ''],
        ['History / Presence of Communicable Disease in the Family', ''],
        ['Blood Pressure Record for Ages 35 and above', ''],
        ['Awareness of health services offered by the BHC/RHU', ''],
      ]),
    )
    ..writeln(_sectionHeading('IV. Health Resource'))
    ..writeln(
      _table([
        ['Manpower Resources', ''],
        ['Material Resources', ''],
      ]),
    )
    ..writeln(_sectionHeading('V. Political / Leadership Patterns'))
    ..writeln(
      _table([
        ['Political / Leadership Patterns', ''],
        ['Conditions / events / issues that cause social conflicts', ''],
        ['Practices / approaches effective in setting issues', ''],
      ]),
    )
    ..writeln(
      _sectionHeading(
        'VI. Concerns / suggestions regarding the life style in the area in general.',
      ),
    )
    ..writeln(
      _table([
        ['Community concerns', _listOrBlank(submission.communityConcerns)],
        ['Notes', submission.notes],
      ]),
    );

  final surveySections = _surveyResponseSections(submission);
  if (surveySections.isNotEmpty) {
    buffer.writeln(_sectionHeading('Captured PDF Field Responses'));
    for (final section in surveySections) {
      buffer
        ..writeln(_subHeading(section.title))
        ..writeln(
          _table(
            [
              ['Field', 'Response'],
              for (final row in section.rows) [row.field, row.response],
            ],
            headerRows: 1,
            fontSize: 10,
          ),
        );
    }
  }

  return buffer.toString();
}

List<List<String>> _demographicTableRows(HealthSubmission submission) {
  return [
    [
      '#',
      'Name of Family Member',
      'Relation-ship to the Head of the Family',
      'Gender',
      'Age',
      'Birth M',
      'Birth D',
      'Birth Y',
      'Marital Status',
      'Religion',
      'Highest Educational COMPLETED',
      'Occupation Status',
      'If Employed',
      'Location',
      'Category',
      'Place of Origin',
      'Length of Residence',
    ],
    ..._demographicRows(submission),
  ];
}

List<List<String>> _demographicRows(HealthSubmission submission) {
  final surveyMemberRows = _surveyMapRows(
    submission.surveyData['family_members'],
  );
  if (surveyMemberRows.isNotEmpty) {
    return [
      for (var index = 0; index < surveyMemberRows.length; index++)
        _demographicSurveyRow(surveyMemberRows[index], index),
    ];
  }

  final rows = <List<String>>[
    [
      '1',
      submission.respondentName,
      'Head',
      '',
      submission.respondentAge?.toString() ?? '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
    ],
  ];

  for (var index = 0; index < submission.familyMembers.length; index++) {
    final member = submission.familyMembers[index];
    rows.add([
      '${index + 2}',
      member.name,
      member.relationship,
      '',
      member.age?.toString() ?? '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
    ]);
  }

  return rows;
}

List<List<String>> _demographicTemplateRows(HealthSubmission submission) {
  final surveyMemberRows = _surveyMapRows(
    submission.surveyData['family_members'],
  );
  if (surveyMemberRows.isNotEmpty) {
    return [
      for (var index = 0; index < surveyMemberRows.length; index++)
        _demographicTemplateSurveyRow(surveyMemberRows[index], index),
    ];
  }

  return _demographicRows(submission);
}

List<String> _demographicSurveyRow(Map<String, dynamic> row, int index) {
  String value(String key, [List<String> aliases = const []]) {
    for (final candidateKey in [key, ...aliases]) {
      final candidateValue = _surveyValueLabel(row[candidateKey]);
      if (candidateValue.isNotEmpty) {
        return candidateValue;
      }
    }
    return '';
  }

  return [
    value('member_no').isEmpty ? '${index + 1}' : value('member_no'),
    value('name_of_family_member', ['name']),
    value('relationship_to_head', ['relationship']),
    value('gender'),
    value('age'),
    value('birthdate_month'),
    value('birthdate_day'),
    value('birthdate_year'),
    value('marital_status'),
    value('religion') == 'Others' ? value('religion_other') : value('religion'),
    value('highest_educational_completed'),
    value('occupation_status'),
    value('employment_type_if_employed'),
    value('place_of_work_location'),
    value('place_of_work_category'),
    value('place_of_origin'),
    value('length_of_residence'),
  ];
}

List<String> _demographicTemplateSurveyRow(
  Map<String, dynamic> row,
  int index,
) {
  String value(String key, [List<String> aliases = const []]) =>
      _surveyRowValue(row, key, aliases);

  return [
    value('member_no').isEmpty ? '${index + 1}' : value('member_no'),
    value('name_of_family_member', ['name']),
    value('relationship_to_head', ['relationship']),
    _choiceCode(value('gender'), const {'male': '1', 'female': '2'}),
    value('age'),
    value('birthdate_month'),
    value('birthdate_day'),
    value('birthdate_year'),
    _choiceCode(value('marital_status'), const {
      'child': '1',
      'single': '2',
      'married': '3',
      'married but separated': '4',
      'widow': '5',
      'widower': '6',
    }),
    _choiceCode(value('religion'), const {
      'roman catholic': '1',
      'muslim': '2',
      'iglesia ni cristo': '3',
      'born again christian': '4',
      'jehovahs witness': '5',
      'jehovah witness': '5',
      'protestant methodist evangelical baptist adventist': '6',
      'others': '7',
    }),
    _choiceCode(value('highest_educational_completed'), const {
      'pre elementary': '1',
      'pre elem': '1',
      'elementary level': '2',
      'elem level': '2',
      'elementary graduate': '3',
      'elem grad': '3',
      'high school level': '4',
      'high school graduate': '5',
      'vocational': '6',
      'short course': '7',
      'college level': '8',
      'college graduate': '9',
      'post graduate': '10',
      'over 7 years old without formal schooling': '11',
      'less than 5 years old': '12',
      'sped': '13',
    }),
    _choiceCode(value('occupation_status'), const {
      'employed': '1',
      'unemployed': '2',
      'minor below 18 years old': '3',
    }),
    _choiceCode(value('employment_type_if_employed'), const {
      'regular full time': '1',
      'regular part time': '2',
      'contractual 6 months': '3',
      'contractual every week': '4',
      'contractual everyday': '5',
      'self employed': '6',
      'seasonal': '7',
      'ofw': '8',
      'contractual by job offer': '9',
    }),
    _choiceCode(value('place_of_work_location'), const {
      'within the community': '1',
      'within the municipality city': '2',
      'outside the municipality city': '3',
      'ofw outside the country': '4',
    }),
    _choiceCode(value('place_of_work_category'), const {
      'in house': '1',
      'field': '2',
      'office': '3',
    }),
    _choiceCode(value('place_of_origin'), const {
      'metro manila': '1',
      'central luzon': '2',
      'northern luzon': '3',
      'southern luzon': '4',
      'visayas region': '5',
      'mindanao region': '6',
    }),
    _compactResidenceLength(value('length_of_residence')),
  ];
}

String _compactResidenceLength(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final numeric = RegExp(r'\d+(?:\.\d+)?').firstMatch(trimmed);
  return numeric?.group(0) ?? trimmed;
}

String _surveyRowValue(
  Map<String, dynamic> row,
  String key, [
  List<String> aliases = const [],
]) {
  for (final candidateKey in [key, ...aliases]) {
    final candidateValue = _surveyValueLabel(row[candidateKey]);
    if (candidateValue.isNotEmpty) {
      return candidateValue;
    }
  }
  return '';
}

String _incomeEarnerName(
  HealthSubmission submission,
  Map<String, dynamic> row,
) {
  final explicitName = _surveyRowValue(row, 'family_member_name', [
    'name_of_family_member',
    'name',
  ]);
  if (explicitName.isNotEmpty) {
    return explicitName;
  }

  final memberNo = _surveyRowValue(row, 'family_member_no', ['member_no']);
  final lookupNo = memberNo.isEmpty
      ? _surveyRowValue(row, 'earner_no')
      : memberNo;
  if (lookupNo.isEmpty) {
    return '';
  }

  final surveyMemberRows = _surveyMapRows(
    submission.surveyData['family_members'],
  );
  for (var index = 0; index < surveyMemberRows.length; index++) {
    final memberRow = surveyMemberRows[index];
    final candidateNo = _surveyRowValue(memberRow, 'member_no');
    final fallbackNo = '${index + 1}';
    if (_sameMemberNumber(
      candidateNo.isEmpty ? fallbackNo : candidateNo,
      lookupNo,
    )) {
      return _surveyRowValue(memberRow, 'name_of_family_member', ['name']);
    }
  }

  for (final member in submission.familyMembers) {
    final memberNo = _surveyValueLabel(member.details['member_no']);
    if (_sameMemberNumber(memberNo, lookupNo)) {
      return member.name;
    }
  }
  if (_sameMemberNumber(lookupNo, '1')) {
    return submission.respondentName;
  }
  final familyMembersIncludeRespondent =
      submission.familyMembers.isNotEmpty &&
      _normalizeSurveyChoice(submission.familyMembers.first.name) ==
          _normalizeSurveyChoice(submission.respondentName);
  for (var index = 0; index < submission.familyMembers.length; index++) {
    final impliedNo = familyMembersIncludeRespondent ? index + 1 : index + 2;
    if (_sameMemberNumber(lookupNo, '$impliedNo')) {
      return submission.familyMembers[index].name;
    }
  }

  return '';
}

bool _sameMemberNumber(String left, String right) {
  final normalizedLeft = left.trim();
  final normalizedRight = right.trim();
  if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
    return false;
  }

  final leftNumber = num.tryParse(normalizedLeft);
  final rightNumber = num.tryParse(normalizedRight);
  if (leftNumber != null && rightNumber != null) {
    return leftNumber == rightNumber;
  }

  return normalizedLeft == normalizedRight;
}

String _choiceCode(String value, Map<String, String> codes) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  if (RegExp(r'^\d+$').hasMatch(trimmed)) {
    return trimmed;
  }
  final normalized = trimmed
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  return codes[normalized] ?? trimmed;
}

List<List<String>> _nutritionRows(HealthSubmission submission) {
  return [
    [
      submission.respondentName,
      submission.respondentAge?.toString() ?? '',
      submission.nutritionalStatus,
      '',
    ],
    for (final member in submission.familyMembers)
      [member.name, member.age?.toString() ?? '', member.nutritionalStatus, ''],
  ];
}

List<List<String>> _immunizationRows(HealthSubmission submission) {
  return [
    _immunizationRow(
      name: submission.respondentName,
      age: submission.respondentAge?.toString() ?? '',
      vaccinationStatus: submission.vaccinationStatus,
    ),
    for (final member in submission.familyMembers)
      _immunizationRow(
        name: member.name,
        age: member.age?.toString() ?? '',
        vaccinationStatus: member.vaccinationStatus,
      ),
  ];
}

List<String> _immunizationRow({
  required String name,
  required String age,
  required String vaccinationStatus,
}) {
  final status = vaccinationStatus.toLowerCase();
  final incomplete = status.contains('incomplete');
  final complete = !incomplete && status.contains('complete');

  return [
    name,
    age,
    '',
    complete ? 'X' : '',
    incomplete ? 'X' : '',
    complete ? 'X' : '',
    vaccinationStatus,
  ];
}

List<List<String>> _morbidityRows(HealthSubmission submission) {
  final rows = <List<String>>[];

  if (submission.healthProblems.isNotEmpty) {
    rows.add([
      submission.respondentName,
      submission.respondentAge?.toString() ?? '',
      '',
      _listOrBlank(submission.healthProblems),
      '',
      '',
      '',
      'X',
      '',
    ]);
  }

  for (final member in submission.familyMembers) {
    if (member.healthProblems.isEmpty) {
      continue;
    }

    rows.add([
      member.name,
      member.age?.toString() ?? '',
      '',
      _listOrBlank(member.healthProblems),
      '',
      '',
      '',
      'X',
      '',
    ]);
  }

  if (rows.isEmpty) {
    rows.add(List.filled(9, ''));
  }

  return rows;
}

String _documentHeaderTable(int sectionIndex) {
  final centerContent = [
    _paragraph(
      'BULACAN STATE UNIVERSITY',
      center: true,
      bold: true,
      fontSize: 18,
    ),
    _paragraph('Alliance Expertise Team', center: true, fontSize: 18),
    _paragraph('COLLEGE OF NURSING', center: true, bold: true, fontSize: 18),
    _paragraph('City of Malolos', center: true, fontSize: 18),
  ].join();

  return '''
<w:tbl>
  <w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders></w:tblPr>
  <w:tr>
    ${_rawTableCell(_documentImageParagraph('rId3', 'Bulacan State University Logo', 681990, 681990, sectionIndex * 2 + 1), width: 1500)}
    ${_rawTableCell(centerContent, width: 8160)}
    ${_rawTableCell(_documentImageParagraph('rId2', 'College of Nursing Logo', 667385, 667385, sectionIndex * 2 + 2), width: 1500)}
  </w:tr>
</w:tbl>
''';
}

String _rawTableCell(String content, {required int width}) {
  return '<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>$content</w:tc>';
}

String _documentImageParagraph(
  String relationshipId,
  String name,
  int width,
  int height,
  int docPrId,
) {
  final escapedName = _xmlEscape(name);
  return '''
<w:p>
  <w:pPr><w:jc w:val="center"/></w:pPr>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0">
        <wp:extent cx="$width" cy="$height"/>
        <wp:docPr id="$docPrId" name="$escapedName"/>
        <wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>
        <a:graphic>
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic>
              <pic:nvPicPr><pic:cNvPr id="0" name="$escapedName"/><pic:cNvPicPr/></pic:nvPicPr>
              <pic:blipFill><a:blip r:embed="$relationshipId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
              <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$width" cy="$height"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
''';
}

String _table(
  List<List<String>> rows, {
  int headerRows = 0,
  int fontSize = 18,
}) {
  final buffer = StringBuffer()
    ..writeln('<w:tbl>')
    ..writeln(
      '<w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="000000"/><w:left w:val="single" w:sz="4" w:space="0" w:color="000000"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/><w:right w:val="single" w:sz="4" w:space="0" w:color="000000"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="000000"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="000000"/></w:tblBorders></w:tblPr>',
    );

  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    buffer.writeln('<w:tr>');
    for (final cell in rows[rowIndex]) {
      final shaded = rowIndex < headerRows;
      buffer
        ..writeln('<w:tc>')
        ..writeln('<w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr>')
        ..writeln(_paragraph(cell, fontSize: fontSize, bold: shaded))
        ..writeln('</w:tc>');
    }
    buffer.writeln('</w:tr>');
  }

  buffer.writeln('</w:tbl>');
  return buffer.toString();
}

String _sectionHeading(String text) {
  return _paragraph(text, bold: true, fontSize: 22, spacingBefore: 160);
}

String _subHeading(String text) {
  return _paragraph(text, bold: true, fontSize: 20, spacingBefore: 120);
}

String _paragraph(
  String text, {
  bool bold = false,
  bool center = false,
  int fontSize = 20,
  int spacingBefore = 0,
}) {
  final escapedText = _xmlEscape(_valueOrBlank(text));
  final jc = center ? '<w:jc w:val="center"/>' : '';
  final spacing = spacingBefore > 0
      ? '<w:spacing w:before="$spacingBefore" w:after="40"/>'
      : '<w:spacing w:after="40"/>';
  final boldTag = bold ? '<w:b/>' : '';

  return '<w:p><w:pPr>$jc$spacing</w:pPr><w:r><w:rPr>$boldTag<w:sz w:val="$fontSize"/></w:rPr><w:t xml:space="preserve">$escapedText</w:t></w:r></w:p>';
}

String _pageBreakParagraph() {
  return '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';
}

String _dateOnly(DateTime value) => DateFormat('MMM d, yyyy').format(value);

Future<Uint8List> _loadAssetBytes(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

String _xmlEscape(String value) => const HtmlEscape().convert(value);

String _valueOrBlank(String value) => value.trim();

String _listOrBlank(List<String> values) => values.join(', ');

class _SurveyExportSection {
  const _SurveyExportSection({required this.title, required this.rows});

  final String title;
  final List<_SurveyExportRow> rows;
}

class _SurveyExportRow {
  const _SurveyExportRow({required this.field, required this.response});

  final String field;
  final String response;
}

List<_SurveyExportSection> _surveyResponseSections(
  HealthSubmission submission,
) {
  final surveyData = submission.surveyData;
  if (surveyData.isEmpty) {
    return const [];
  }

  final sections = <_SurveyExportSection>[];
  final exportedKeys = <String>{};
  for (final section in surveySections) {
    final rows = <_SurveyExportRow>[];
    for (final field in section.fields) {
      if (field.type == SurveyFieldType.note ||
          field.type == SurveyFieldType.heading) {
        continue;
      }

      exportedKeys.add(field.key);
      final value = surveyData[field.key];
      if (!_surveyValueHasContent(value)) {
        continue;
      }
      rows.addAll(_surveyFieldRows(field, value));
    }
    if (rows.isNotEmpty) {
      sections.add(_SurveyExportSection(title: section.title, rows: rows));
    }
  }

  final extraRows = <_SurveyExportRow>[];
  for (final entry in surveyData.entries) {
    if (exportedKeys.contains(entry.key) ||
        !_surveyValueHasContent(entry.value)) {
      continue;
    }
    extraRows.add(
      _SurveyExportRow(
        field: _surveyLabelFromKey(entry.key),
        response: _surveyValueLabel(entry.value),
      ),
    );
  }
  if (extraRows.isNotEmpty) {
    sections.add(
      _SurveyExportSection(
        title: 'Additional Captured Fields',
        rows: extraRows,
      ),
    );
  }

  return sections;
}

List<_SurveyExportRow> _surveyFieldRows(SurveyField field, Object? value) {
  if (field.type != SurveyFieldType.repeatableTable) {
    return [
      _SurveyExportRow(field: field.label, response: _surveyValueLabel(value)),
    ];
  }

  final rows = <_SurveyExportRow>[];
  final tableRows = _surveyMapRows(value);
  for (var index = 0; index < tableRows.length; index++) {
    final row = tableRows[index];
    final rowLabel = '${field.label} row ${index + 1}';
    final exportedChildKeys = <String>{};

    for (final childField in field.fields) {
      if (childField.type == SurveyFieldType.note ||
          childField.type == SurveyFieldType.heading) {
        continue;
      }

      exportedChildKeys.add(childField.key);
      final childValue = row[childField.key];
      if (!_surveyValueHasContent(childValue)) {
        continue;
      }
      rows.add(
        _SurveyExportRow(
          field: '$rowLabel - ${childField.label}',
          response: _surveyValueLabel(childValue),
        ),
      );
    }

    for (final entry in row.entries) {
      if (exportedChildKeys.contains(entry.key) ||
          !_surveyValueHasContent(entry.value)) {
        continue;
      }
      rows.add(
        _SurveyExportRow(
          field: '$rowLabel - ${_surveyLabelFromKey(entry.key)}',
          response: _surveyValueLabel(entry.value),
        ),
      );
    }
  }

  return rows;
}

String _surveyRowLabel(List<SurveyField> fields, Map<String, dynamic> row) {
  final parts = <String>[];
  for (final field in fields) {
    final value = row[field.key];
    if (!_surveyValueHasContent(value)) {
      continue;
    }
    parts.add('${field.label}: ${_surveyValueLabel(value)}');
  }
  return parts.join('; ');
}

String _surveyLabelFromKey(String key) {
  return key
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

List<Map<String, dynamic>> _surveyMapRows(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
  return const [];
}

String _surveyString(Map<String, dynamic> data, String key) {
  return _surveyValueLabel(data[key]);
}

String _surveyValueLabel(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is List) {
    return value
        .map(_surveyValueLabel)
        .where((item) => item.isNotEmpty)
        .join(', ');
  }
  if (value is Map) {
    return value.entries
        .where((entry) => _surveyValueHasContent(entry.value))
        .map((entry) => '${entry.key}: ${_surveyValueLabel(entry.value)}')
        .join('; ');
  }
  if (value is bool) {
    return value ? 'Yes' : 'No';
  }
  return '$value'.trim();
}

bool _surveyValueHasContent(Object? value) {
  if (value == null) {
    return false;
  }
  if (value is String) {
    return value.trim().isNotEmpty;
  }
  if (value is List) {
    return value.isNotEmpty;
  }
  if (value is Map) {
    return value.isNotEmpty;
  }
  return true;
}

String _corePropsXml() {
  final timestamp = DateTime.now().toUtc().toIso8601String();
  return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>KASUDLO Community Survey Tool</dc:title>
  <dc:creator>KASUDLO</dc:creator>
  <cp:lastModifiedBy>KASUDLO</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">$timestamp</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$timestamp</dcterms:modified>
</cp:coreProperties>
''';
}

const _contentTypesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
''';

const _packageRelsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
''';

const _documentRelsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/college-of-nursing.png"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/bulacan-state-university.png"/>
</Relationships>
''';

const _appPropsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>KASUDLO</Application>
</Properties>
''';

const _stylesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:sz w:val="20"/></w:rPr>
  </w:style>
</w:styles>
''';

Future<List<int>> _buildPdfBytes(List<HealthSubmission> submissions) async {
  final regularFont = pw.Font.ttf(await rootBundle.load(_regularFontAsset));
  final boldFont = pw.Font.ttf(await rootBundle.load(_boldFontAsset));
  final italicFont = pw.Font.ttf(await rootBundle.load(_italicFontAsset));
  final boldItalicFont = pw.Font.ttf(
    await rootBundle.load(_boldItalicFontAsset),
  );
  final theme = pw.ThemeData.withFont(
    base: regularFont,
    bold: boldFont,
    italic: italicFont,
    boldItalic: boldItalicFont,
  );
  final document = pw.Document(title: 'KASUDLO Community Survey Tool');
  final templatePages = [
    for (final asset in _templatePdfPageAssets)
      pw.MemoryImage(await _loadAssetBytes(asset)),
  ];

  if (submissions.isEmpty) {
    _addTemplatePdfRecord(document, null, templatePages, theme);
    return document.save();
  }

  for (final submission in submissions) {
    _addTemplatePdfRecord(document, submission, templatePages, theme);
  }

  return document.save();
}

void _addTemplatePdfRecord(
  pw.Document document,
  HealthSubmission? submission,
  List<pw.ImageProvider> templatePages,
  pw.ThemeData theme,
) {
  for (var pageIndex = 0; pageIndex < templatePages.length; pageIndex++) {
    document.addPage(
      pw.Page(
        pageFormat: _templatePdfPageFormat,
        margin: pw.EdgeInsets.zero,
        theme: theme,
        build: (context) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Stack(
            children: [
              pw.Positioned.fill(
                child: pw.Image(templatePages[pageIndex], fit: pw.BoxFit.fill),
              ),
              if (submission != null)
                ..._templatePdfOverlay(submission, pageIndex),
            ],
          ),
        ),
      ),
    );
  }
}

void _addSurveyDataPdfAppendix(
  pw.Document document,
  HealthSubmission submission,
  pw.ThemeData theme,
) {
  final sections = _surveyResponseSections(submission);
  if (sections.isEmpty) {
    return;
  }

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      theme: theme,
      build: (context) => [
        _surveyPdfAppendixTitle(submission),
        for (final section in sections) ..._surveyPdfSection(section),
      ],
    ),
  );
}

pw.Widget _surveyPdfAppendixTitle(HealthSubmission submission) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Captured PDF Field Responses',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        [
          submission.respondentName,
          submission.address,
        ].where((value) => value.trim().isNotEmpty).join(' | '),
        style: const pw.TextStyle(fontSize: 8),
      ),
      pw.SizedBox(height: 12),
    ],
  );
}

List<pw.Widget> _surveyPdfSection(_SurveyExportSection section) {
  return [
    pw.Text(
      section.title,
      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 4),
    pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellAlignment: pw.Alignment.topLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.05),
        1: pw.FlexColumnWidth(1.95),
      },
      data: [
        ['Field', 'Response'],
        for (final row in section.rows) [row.field, row.response],
      ],
    ),
    pw.SizedBox(height: 10),
  ];
}

List<pw.Widget> _templatePdfOverlay(
  HealthSubmission submission,
  int pageIndex,
) {
  return switch (pageIndex) {
    0 => _templatePageOneOverlay(submission),
    1 => _templatePageTwoOverlay(submission),
    2 => _templatePageThreeOverlay(submission),
    3 => _templatePageFourOverlay(submission),
    4 => _templatePageFiveOverlay(submission),
    5 => _templatePageSixOverlay(submission),
    _ => const <pw.Widget>[],
  };
}

List<pw.Widget> _templatePageOneOverlay(HealthSubmission submission) {
  final surveyData = submission.surveyData;
  final widgets = <pw.Widget>[
    _templateText(_surveyString(surveyData, 'control_no'), 77, 136),
    _templateText(
      _surveyString(surveyData, 'address').isEmpty
          ? submission.address
          : _surveyString(surveyData, 'address'),
      72,
      147,
      width: 120,
    ),
    _templateText(
      _surveyString(surveyData, 'informant').isEmpty
          ? submission.respondentName
          : _surveyString(surveyData, 'informant'),
      72,
      158,
      width: 120,
    ),
    _templateText(
      _surveyString(surveyData, 'surveyed_by'),
      84,
      169,
      width: 120,
    ),
    _templateText(
      _surveyString(surveyData, 'time_started'),
      86,
      180,
      width: 40,
    ),
    _templateText(
      _surveyString(surveyData, 'time_finished'),
      183,
      180,
      width: 40,
    ),
    _templateText(
      _surveyString(surveyData, 'number_of_family').isEmpty
          ? '${submission.familyMembersCount}'
          : _surveyString(surveyData, 'number_of_family'),
      500,
      136,
      width: 70,
    ),
    _templateText(
      _surveyString(surveyData, 'first_visit_date').isEmpty
          ? _dateOnly(submission.createdAt)
          : _surveyString(surveyData, 'first_visit_date'),
      498,
      147,
      width: 85,
    ),
    _templateText(
      _surveyString(surveyData, 'second_visit_date'),
      498,
      158,
      width: 85,
    ),
    _templateText(
      _surveyString(surveyData, 'third_visit_date'),
      498,
      169,
      width: 85,
    ),
    _templateText(
      _surveyString(surveyData, 'status_of_last_visit').isEmpty
          ? submission.syncStatus.name
          : _surveyString(surveyData, 'status_of_last_visit'),
      500,
      180,
      width: 80,
    ),
  ];

  final rows = _demographicTemplateRows(submission);
  const rowTop = 312.5;
  const rowHeight = 14.35;
  const rowTextOffset = 5.0;
  for (var index = 0; index < rows.length && index < 13; index++) {
    final row = rows[index];
    final top = rowTop + rowHeight * index + rowTextOffset;
    widgets
      ..add(
        _templateText(
          row[0],
          22.5,
          top,
          width: 18.5,
          size: 5.0,
          align: pw.TextAlign.center,
        ),
      )
      ..add(_templateText(row[1], 45.0, top, width: 110.5, size: 5.0))
      ..add(
        _templateText(
          row[2],
          159.0,
          top,
          width: 38.0,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateText(
          row[3],
          199.0,
          top,
          width: 20.5,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateText(
          row[4],
          220.5,
          top,
          width: 19.5,
          size: 5.0,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateText(
          row[5],
          241.0,
          top,
          width: 21.0,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateText(
          row[6],
          263.0,
          top,
          width: 21.5,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateText(
          row[7],
          285.5,
          top,
          width: 21.5,
          size: 4.6,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateText(
          row[8],
          308.0,
          top,
          width: 21.5,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateText(
          row[9],
          330.5,
          top,
          width: 26.0,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateText(
          row[10],
          358.0,
          top,
          width: 59.5,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateText(
          row[11],
          419.0,
          top,
          width: 27.0,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateText(
          row[12],
          447.5,
          top,
          width: 23.0,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateText(
          row[13],
          471.5,
          top,
          width: 30.0,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateText(
          row[14],
          503.0,
          top,
          width: 26.0,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateText(
          row[15],
          530.0,
          top,
          width: 24.0,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateText(
          row[16],
          555.0,
          top,
          width: 25.0,
          size: 4.4,
          align: pw.TextAlign.center,
        ),
      );
  }

  final religionOtherText = _surveyMapRows(surveyData['family_members'])
      .map((row) => _surveyRowValue(row, 'religion_other'))
      .where((value) => value.trim().isNotEmpty)
      .toSet()
      .join(', ');
  _addTemplateTextIfNotEmpty(
    widgets,
    religionOtherText,
    445,
    985,
    width: 150,
    size: 4.8,
  );

  void mark(String key, String choice, double left, double top) {
    _addTemplateMarkIf(
      widgets,
      _surveyHasChoice(surveyData, key, choice),
      left,
      top,
      optionWidth: 14.0,
    );
  }

  mark('family_composition_type', 'Nuclear', 158, 1329);
  mark('family_composition_type', 'Extended', 349, 1329);
  mark('family_composition_type', 'Dyad', 517, 1329);
  mark('family_composition_type', 'Homosexual/Same Sex', 736, 1329);
  mark('family_composition_type', 'Cohabiting/Communal', 158, 1348);
  mark('family_composition_type', 'Blended Family', 349, 1348);
  mark('family_composition_type', 'Living with Grandparent(s)', 517, 1348);
  mark('family_composition_type', 'Single-parent', 736, 1348);

  mark('family_locus_of_power', 'Patrifocal/Patriarchal', 158, 1398);
  mark('family_locus_of_power', 'Matrifocal/Matriarchal', 349, 1398);
  mark('family_locus_of_power', 'Egalitarian', 567, 1398);
  mark('family_locus_of_power', 'Matricentric', 736, 1398);

  return widgets;
}

List<pw.Widget> _templatePageTwoOverlay(HealthSubmission submission) {
  final data = submission.surveyData;
  final widgets = <pw.Widget>[];

  void mark(String key, String choice, double left, double top) {
    _addTemplateMarkIf(widgets, _surveyHasChoice(data, key, choice), left, top);
  }

  void markAny(String key, List<String> choices, double left, double top) {
    _addTemplateMarkIf(
      widgets,
      _surveyHasAnyChoice(data, key, choices),
      left,
      top,
    );
  }

  void text(String key, double left, double top, {double width = 150}) {
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyString(data, key),
      left,
      top,
      width: width,
    );
  }

  void rank(String key, double left, double top) {
    _addTemplateMarkIf(
      widgets,
      _surveyString(data, key).trim().isNotEmpty,
      left,
      top,
      value: _surveyString(data, key),
      size: 6.4,
    );
  }

  mark('family_place_of_residence', 'Patrilocal', 215, 89);
  mark('family_place_of_residence', 'Matrilocal', 388, 89);
  mark('family_place_of_residence', 'Bilocal/Ambilocal', 560, 89);
  mark('family_place_of_residence', 'Neolocal', 791, 89);

  mark('family_descent', 'Patrilineal', 215, 138);
  mark('family_descent', 'Matrilineal', 388, 139);
  mark('family_descent', 'Bilateral', 560, 139);
  text('dialect_frequently_used', 315, 177, width: 370);

  mark('services_in_community', 'Religious services', 330, 271);
  markAny(
    'services_in_community',
    const ['Livelihood Services', 'livelihood service'],
    503,
    271,
  );
  mark('services_in_community', 'livelihood service', 676, 271);
  mark('services_in_community', 'Health Services', 330, 289);
  mark('services_in_community', 'Garbage collection', 503, 289);
  mark('services_in_community', 'Peace and Order', 676, 289);

  mark('institutional_facilities', 'Brgy. Hall', 272, 304);
  mark('institutional_facilities', 'Health Station', 445, 304);
  mark('institutional_facilities', 'Church', 618, 304);
  mark('institutional_facilities', 'School', 791, 304);

  mark('organizations', 'Senior Citizen', 272, 322);
  mark('organizations', 'Youth', 445, 322);
  mark('organizations', 'Others', 618, 322);
  text('organizations_other', 675, 316, width: 150);

  mark('traditions_customs', 'Bayanihan', 272, 339);
  mark('traditions_customs', 'Palabra de Honor', 445, 339);
  mark('traditions_customs', 'Pakikisama', 618, 339);
  mark('traditions_customs', 'Ningas Kugon', 791, 337);
  mark('traditions_customs', 'Fiestas', 272, 355);
  mark('traditions_customs', 'Close family ties', 445, 356);
  mark('traditions_customs', 'Respect for elderly', 618, 355);
  mark('traditions_customs', 'Others', 272, 372);
  text('traditions_customs_other', 330, 365, width: 150);

  mark('recreational_facilities', 'Volleyball/Basketball court', 272, 388);
  mark('recreational_facilities', 'Playground', 503, 387);
  mark('recreational_facilities', 'Plaza', 618, 387);
  mark('recreational_facilities', 'Others', 733, 387);
  text('recreational_facilities_other', 790, 381, width: 150);

  mark('mode_of_transportation', 'Tricycle', 272, 405);
  mark('mode_of_transportation', 'Jeep', 445, 403);
  mark('mode_of_transportation', 'PUJ/PUV', 503, 405);
  mark('mode_of_transportation', 'Bicycle', 618, 405);
  mark('mode_of_transportation', 'Private vehicle', 733, 405);

  mark('mode_of_communication', 'Postal system', 330, 420);
  mark('mode_of_communication', 'Internet', 503, 421);
  mark('mode_of_communication', 'Telephone', 676, 420);
  mark('mode_of_communication', 'Cell phone', 791, 420);
  mark('mode_of_communication', 'Two-way radio', 330, 438);
  mark('mode_of_communication', 'Others', 503, 438);
  text('mode_of_communication_other', 570, 432, width: 160);

  final incomeEarners = _surveyMapRows(data['income_earners']);
  text('income_earner_count', 380, 508, width: 28);
  for (var index = 0; index < incomeEarners.length && index < 4; index++) {
    final row = incomeEarners[index];
    final top = 508.0 + index * 18.0;
    _addTemplateTextIfNotEmpty(
      widgets,
      _incomeEarnerName(submission, row),
      455,
      top,
      width: 100,
    );
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'family_position'),
      670,
      top,
      width: 130,
    );
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'income_php'),
      840,
      top,
      width: 80,
    );
  }

  mark('monthly_family_income_combined', 'Less than 5,000', 157, 604);
  mark('monthly_family_income_combined', '5,001-10,000', 157, 620);
  mark('monthly_family_income_combined', '10,001-15,000', 157, 637);
  mark('monthly_family_income_combined', '15,001-20,000', 157, 653);
  mark('monthly_family_income_combined', '20,001-25,000', 157, 670);
  mark('monthly_family_income_combined', '25,001-30,000', 388, 604);
  mark('monthly_family_income_combined', '30,001-35,000', 388, 620);
  mark('monthly_family_income_combined', '35,001-40,000', 388, 637);
  mark('monthly_family_income_combined', '40,001-45,000', 388, 653);
  mark('monthly_family_income_combined', '45,001-50,000', 388, 670);
  mark('monthly_family_income_combined', '50,001 and above', 618, 604);

  mark('financial_sources', 'Employment', 157, 718);
  mark('financial_sources', 'Business', 330, 718);
  mark('financial_sources', 'Pension', 445, 718);
  mark('financial_sources', 'Help from relative/friends', 560, 718);
  mark('financial_sources', 'Others', 791, 718);
  text('financial_sources_other', 850, 712, width: 110);

  mark('monthly_family_expenditures', 'Less than 5,000', 157, 751);
  mark('monthly_family_expenditures', '5,001-10,000', 157, 769);
  mark('monthly_family_expenditures', '10,001-15,000', 157, 786);
  mark('monthly_family_expenditures', '15,001-20,000', 157, 802);
  mark('monthly_family_expenditures', '20,001-25,000', 157, 819);
  mark('monthly_family_expenditures', '25,001-30,000', 388, 751);
  mark('monthly_family_expenditures', '30,001-35,000', 388, 769);
  mark('monthly_family_expenditures', '35,001-40,000', 388, 786);
  mark('monthly_family_expenditures', '40,001-45,000', 388, 802);
  mark('monthly_family_expenditures', '45,001-50,000', 388, 819);
  mark('monthly_family_expenditures', '50,001 and above', 618, 751);

  rank('priority_food_rank', 157, 851);
  rank('priority_clothing_rank', 330, 851);
  rank('priority_education_rank', 503, 851);
  rank('priority_utilities_rank', 676, 851);
  rank('priority_health_rank', 157, 869);
  rank('priority_recreation_rank', 330, 869);
  rank('priority_savings_rank', 503, 869);

  mark('family_income_adequacy', 'Adequate', 157, 902);
  mark('family_income_adequacy', 'Not Adequate', 330, 902);

  mark(
    'cultural_orientation_illness',
    'Illness is caused by physiologic factor, e.g. infection',
    157,
    985,
  );
  mark(
    'cultural_orientation_illness',
    'Illness is caused by supernatural phenomenon, e.g. kulam, balis',
    157,
    1002,
  );
  mark(
    'cultural_orientation_illness',
    'Illness is a punishment from God',
    157,
    1019,
  );
  mark(
    'cultural_orientation_illness',
    'Illness is caused by other person',
    157,
    1035,
  );
  mark(
    'cultural_orientation_illness',
    'Illness is caused by change in weather',
    157,
    1052,
  );
  mark('cultural_orientation_illness', 'Others', 157, 1068);
  text('cultural_orientation_illness_other', 224, 1062, width: 200);

  mark(
    'cultural_belief_health_restoration',
    'Health can be restored by God/other spiritual faith',
    157,
    1116,
  );
  mark(
    'cultural_belief_health_restoration',
    'Health can be restored by faith healers',
    157,
    1134,
  );
  mark(
    'cultural_belief_health_restoration',
    'Health can be restored by supernatural power, e.g. tawas, hilot, hula',
    157,
    1151,
  );
  mark(
    'cultural_belief_health_restoration',
    'Health can be restored by health personnel, e.g. doctors, nurses',
    157,
    1168,
  );

  mark(
    'cultural_perception_health_practices',
    'Always practices local cultural practices about health matters',
    157,
    1216,
  );
  mark(
    'cultural_perception_health_practices',
    'Sometimes practices local cultural practices about health matters',
    157,
    1233,
  );
  mark(
    'cultural_perception_health_practices',
    'Does not practice any local cultural practices about health matters',
    157,
    1250,
  );

  mark(
    'community_involvement',
    'Actively joins fiesta, religious procession, local cultural practices',
    157,
    1299,
  );
  mark('community_involvement', 'Does not actively join', 618, 1298);

  mark('home_ownership', 'Owned', 388, 1380);
  mark('home_ownership', 'Rented', 503, 1380);
  mark('home_ownership', 'Rent-free', 618, 1380);
  mark('home_ownership', 'Lease/Least to own', 733, 1380);
  mark('home_ownership', 'Squatting/informal settlers', 388, 1399);
  mark('home_ownership', 'Professional squatters', 618, 1399);

  return widgets;
}

List<pw.Widget> _templatePageThreeOverlay(HealthSubmission submission) {
  final data = submission.surveyData;
  final widgets = <pw.Widget>[];

  void mark(String key, String choice, double left, double top) {
    _addTemplateMarkIf(widgets, _surveyHasChoice(data, key, choice), left, top);
  }

  void markYesNo(String key, double yesLeft, double noLeft, double top) {
    _addTemplateMarkIf(widgets, _surveyIsYes(data, key), yesLeft, top);
    _addTemplateMarkIf(widgets, _surveyIsNo(data, key), noLeft, top);
  }

  void text(String key, double left, double top, {double width = 150}) {
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyString(data, key),
      left,
      top,
      width: width,
    );
  }

  mark('home_construction_materials', 'Light', 388, 56);
  mark('home_construction_materials', 'Mixed', 503, 56);
  mark('home_construction_materials', 'Strong/Concrete', 618, 56);
  mark('sleeping_rooms_count', '1', 388, 74);
  mark('sleeping_rooms_count', '2', 503, 74);
  mark('sleeping_rooms_count', '3', 618, 74);
  mark('sleeping_rooms_count', '4', 737, 74);
  mark('sleeping_rooms_count', '5', 857, 72);
  mark('sleeping_rooms_count', 'None/no partition', 388, 90);
  mark('home_space_adequacy', 'Adequate', 388, 107);
  mark('home_space_adequacy', 'Inadequate', 560, 105);
  mark('lighting_facility', 'Electricity', 388, 124);
  mark('lighting_facility', 'Kerosene', 560, 124);
  mark('lighting_facility', 'Others', 733, 122);
  text('lighting_facility_other', 795, 118, width: 120);
  mark('lighting_adequacy', 'Adequate', 388, 140);
  mark('lighting_adequacy', 'Inadequate', 560, 140);
  mark('ventilation_adequacy', 'Adequate', 388, 156);
  mark('ventilation_adequacy', 'Inadequate', 560, 156);
  mark('general_sanitary_condition', 'Generally clean', 388, 173);
  mark('general_sanitary_condition', 'Dirty', 560, 173);

  mark('water_supply_ownership', 'Private', 388, 238);
  mark('water_supply_ownership', 'Public', 503, 238);
  mark('water_source_cooking', 'Deep well', 388, 289);
  mark('water_source_cooking', 'Local Water District', 503, 287);
  mark('water_source_cooking', 'Commercial', 676, 288);
  mark('water_source_cooking', 'Others', 791, 287);
  text('water_source_cooking_other', 850, 283, width: 95);
  mark('water_source_drinking', 'Deep well', 388, 306);
  mark('water_source_drinking', 'Local Water District', 503, 306);
  mark('water_source_drinking', 'Commercial', 676, 306);
  mark('water_source_drinking', 'Others', 791, 306);
  text('water_source_drinking_other', 850, 301, width: 95);
  mark('water_source_bathing_cr_flushing', 'Deep well', 388, 322);
  mark('water_source_bathing_cr_flushing', 'Local Water District', 503, 322);
  mark('water_source_bathing_cr_flushing', 'Commercial', 676, 322);
  mark('water_source_bathing_cr_flushing', 'Others', 791, 322);
  text('water_source_bathing_cr_flushing_other', 850, 317, width: 95);
  markYesNo('water_potability_key_informant', 445, 560, 354);
  mark('water_storage', 'None/direct from faucet or pipe', 157, 387);
  mark('water_storage', 'Large covered container with faucet', 157, 405);
  mark('water_storage', 'Large uncovered container with faucet', 157, 422);
  mark('water_storage', 'Large covered container without faucet', 157, 438);
  mark('water_storage', 'Large uncovered container without faucet', 157, 455);
  mark('water_storage', 'Others', 157, 471);
  text('water_storage_other', 285, 468, width: 300);
  text('water_source_distance_from_house', 440, 489, width: 180);

  mark('food_storage_cover_status', 'Covered', 272, 552);
  mark('food_storage_cover_status', 'Uncovered', 445, 552);
  mark('food_storage_type', 'Refrigerator', 272, 571);
  mark('food_storage_type', 'Cabinet', 445, 571);
  mark('food_storage_type', 'Basket', 618, 569);
  mark('food_storage_type', 'Table', 791, 569);
  mark('cooking_facility', 'Electric stove', 272, 587);
  mark('cooking_facility', 'Gas stove', 445, 587);
  mark('cooking_facility', 'Firewood/charcoal', 618, 587);
  mark('cooking_facility', 'Others', 791, 587);
  text('cooking_facility_other', 850, 584, width: 100);
  mark('cooking_area_sanitary_condition', 'Generally clean', 445, 604);
  mark('cooking_area_sanitary_condition', 'Dirty', 618, 604);

  mark('garbage_storage', 'Container', 330, 685);
  mark('garbage_storage', 'None', 503, 685);
  mark('waste_segregation', 'Practiced', 330, 703);
  mark('waste_segregation', 'Not Practiced', 503, 703);
  final wasteIsPracticed = _surveyHasChoice(
    data,
    'waste_segregation',
    'Practiced',
  );
  final wasteIsNotPracticed = _surveyHasChoice(
    data,
    'waste_segregation',
    'Not Practiced',
  );
  if (wasteIsPracticed) {
    mark('waste_disposal_method_if_practiced', 'Hog-feeding', 272, 735);
    mark('waste_disposal_method_if_practiced', 'Open dumping', 445, 735);
    mark('waste_disposal_method_if_practiced', 'Burial in pit', 618, 735);
    mark('waste_disposal_method_if_practiced', 'Collected', 272, 753);
    mark('waste_disposal_method_if_practiced', 'Composting', 445, 753);
    mark('waste_disposal_method_if_practiced', 'Open burning', 618, 753);
    mark(
      'reason_for_practicing_waste_segregation',
      'Environmentally friendly',
      272,
      786,
    );
    mark(
      'reason_for_practicing_waste_segregation',
      'Barangay ordinance which is strictly monitored',
      503,
      786,
    );
    mark(
      'reason_for_practicing_waste_segregation',
      'Use for business',
      272,
      803,
    );
    mark('reason_for_practicing_waste_segregation', 'Others', 503, 803);
    text('reason_for_practicing_waste_segregation_other', 610, 798, width: 220);
  }
  if (wasteIsNotPracticed) {
    mark('waste_disposal_method_if_not_practiced', 'Hog-feeding', 272, 834);
    mark('waste_disposal_method_if_not_practiced', 'Open dumping', 445, 834);
    mark('waste_disposal_method_if_not_practiced', 'Burial in pit', 618, 834);
    mark('waste_disposal_method_if_not_practiced', 'Collected', 272, 852);
    mark('waste_disposal_method_if_not_practiced', 'Composting', 445, 852);
    mark('waste_disposal_method_if_not_practiced', 'Open burning', 618, 852);
    mark(
      'reason_for_not_practicing_waste_segregation',
      'Not aware of effects',
      272,
      884,
    );
    mark(
      'reason_for_not_practicing_waste_segregation',
      'No time to do it',
      565,
      884,
    );
    mark(
      'reason_for_not_practicing_waste_segregation',
      'Long-time practice of family',
      272,
      902,
    );
    mark(
      'reason_for_not_practicing_waste_segregation',
      'No barangay/municipality ordinance',
      565,
      902,
    );
  }

  mark('toilet_ownership', 'Owned', 388, 950);
  mark('toilet_ownership', 'Shared/Public', 560, 950);
  mark('toilet_ownership', 'None', 733, 950);
  mark('toilet_type', 'Ballot system', 215, 983);
  mark('toilet_type', 'Pail system', 388, 983);
  mark('toilet_type', 'Overhung latrine', 560, 983);
  mark('toilet_type', 'Water-sealed', 215, 1001);
  mark('toilet_type', 'Flush type', 388, 1001);
  mark('toilet_type', 'None', 560, 1001);
  mark('toilet_type', 'Other', 733, 999);
  text('toilet_type_other', 795, 1000, width: 120);
  mark('toilet_location_from_water_source', 'Less than 20 ft.', 388, 1018);
  mark('toilet_location_from_water_source', '20 ft. beyond', 560, 1018);
  mark('toilet_sanitary_condition', 'Generally clean', 388, 1035);
  mark('toilet_sanitary_condition', 'Dirty', 560, 1035);

  mark('drainage_system', 'Open drainage', 388, 1066);
  mark('drainage_system', 'Blind drainage', 560, 1066);
  mark('drainage_system', 'None', 733, 1066);
  mark('drainage_condition', 'Flowing', 388, 1084);
  mark('drainage_condition', 'Stagnant', 560, 1084);
  markYesNo('has_rabies_carrier_animals', 445, 560, 1115);

  final animalRows = _surveyMapRows(data['rabies_carrier_animals']);
  for (var index = 0; index < animalRows.length && index < 1; index++) {
    final row = animalRows[index];
    final top = 1209.0 + index * 17.0;
    final markTop = 1206.0 + index * 17.0;
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'animal_kind'),
      50,
      top,
      width: 110,
      size: 5.6,
    );
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'animal_number'),
      205,
      top,
      width: 50,
      size: 5.6,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(row['kept_inside_yard']).isNotEmpty,
      358,
      markTop,
      size: 6.0,
      optionBox: false,
      optionHeight: 17.0,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(row['kept_free_outside']).isNotEmpty,
      515,
      markTop,
      size: 6.0,
      optionBox: false,
      optionHeight: 17.0,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(row['with_regular_vaccination']).isNotEmpty,
      685,
      markTop,
      size: 6.0,
      optionBox: false,
      optionHeight: 17.0,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(row['without_vaccination']).isNotEmpty,
      835,
      markTop,
      size: 6.0,
      optionBox: false,
      optionHeight: 17.0,
    );
  }

  mark('vector_control_measures', 'Fumigation', 157, 1273);
  mark('vector_control_measures', 'Insecticides', 272, 1273);
  mark('vector_control_measures', 'Setting traps', 388, 1273);
  mark('vector_control_measures', 'Cleaning the yard', 503, 1273);
  mark('vector_control_measures', 'None', 676, 1273);
  markYesNo('has_breeding_sites_observed', 157, 272, 1322);
  markYesNo('housing_congestion_observed', 560, 676, 1339);
  markYesNo('has_industrial_establishment_or_factory_observed', 560, 676, 1357);

  return widgets;
}

List<pw.Widget> _templatePageFourOverlay(HealthSubmission submission) {
  final data = submission.surveyData;
  final widgets = <pw.Widget>[];

  void mark(String key, String choice, double left, double top) {
    _addTemplateMarkIf(widgets, _surveyHasChoice(data, key, choice), left, top);
  }

  void markCell(String key, String choice, double left, double top) {
    _addTemplateMarkIf(
      widgets,
      _surveyHasChoice(data, key, choice),
      left,
      top,
      optionBox: false,
    );
  }

  void markYesNo(String key, double yesLeft, double noLeft, double top) {
    _addTemplateMarkIf(widgets, _surveyIsYes(data, key), yesLeft, top);
    _addTemplateMarkIf(widgets, _surveyIsNo(data, key), noLeft, top);
  }

  void text(String key, double left, double top, {double width = 150}) {
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyString(data, key),
      left,
      top,
      width: width,
    );
  }

  markCell('uses_safety_devices_when_necessary', 'Practice', 620, 156);
  markCell('uses_safety_devices_when_necessary', 'Not Practiced', 790, 156);
  markYesNo('has_cigarette_smoker_in_family', 733, 791, 207);
  _addTemplateMarkIf(
    widgets,
    _surveyString(
      data,
      'smoking_frequency_sticks_or_packs_per_day',
    ).trim().isNotEmpty,
    848,
    207,
  );
  _addTemplateTextIfNotEmpty(
    widgets,
    _surveyString(data, 'smoking_frequency_sticks_or_packs_per_day'),
    520,
    224,
    width: 120,
    size: 4.8,
  );

  final smokingRows = _surveyMapRows(data['cigarette_smokers']);
  for (var index = 0; index < smokingRows.length && index < 2; index++) {
    final row = smokingRows[index];
    final top = 264.0 + index * 18.0;
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'name'),
      50,
      top,
      width: 200,
      size: 5.8,
    );
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'age'),
      313,
      top,
      width: 70,
      size: 5.8,
    );
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'age_started_smoking'),
      520,
      top,
      width: 130,
      size: 5.8,
    );
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'reason'),
      735,
      top,
      width: 190,
      size: 5.8,
    );
  }

  markYesNo('uses_prohibited_or_dangerous_drugs', 618, 733, 310);
  _addTemplateMarkIf(
    widgets,
    _surveyString(data, 'types_of_drugs').trim().isNotEmpty,
    848,
    310,
  );
  text('types_of_drugs', 452, 324, width: 145);

  final drugRows = _surveyMapRows(data['drug_users']);
  for (var index = 0; index < drugRows.length && index < 2; index++) {
    final row = drugRows[index];
    final top = 365.0 + index * 18.0;
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'name'),
      50,
      top,
      width: 200,
      size: 5.8,
    );
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'age'),
      313,
      top,
      width: 70,
      size: 5.8,
    );
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'age_started_using_drugs'),
      520,
      top,
      width: 130,
      size: 5.8,
    );
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'reason'),
      735,
      top,
      width: 190,
      size: 5.8,
    );
  }

  final alcoholRows = _surveyMapRows(data['alcohol_drinkers']);
  for (var index = 0; index < alcoholRows.length && index < 3; index++) {
    final row = alcoholRows[index];
    final top = 468.0 + index * 18.0;
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'name'),
      50,
      top,
      width: 200,
      size: 5.8,
    );
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'age'),
      255,
      top,
      width: 60,
      size: 5.8,
    );
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'age_started_drinking_alcohol'),
      340,
      top,
      width: 160,
      size: 5.8,
    );
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'frequency'),
      526,
      top,
      width: 170,
      size: 5.8,
    );
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'reason'),
      725,
      top,
      width: 180,
      size: 5.8,
    );
  }

  final nutritionRows = _anthropometricRows(submission);
  const anthropometricTop = 650.0;
  const anthropometricRowHeight = 18.0;
  for (var index = 0; index < nutritionRows.length && index < 4; index++) {
    final row = nutritionRows[index];
    final top = anthropometricTop + anthropometricRowHeight * index;
    widgets
      ..add(_templateCellTextPx(row[0], 38, top, width: 205, size: 5.0))
      ..add(_templateCellTextPx(row[1], 255, top, width: 35, size: 4.8))
      ..add(_templateCellTextPx(row[2], 308, top, width: 32, size: 4.8))
      ..add(_templateCellTextPx(row[3], 354, top, width: 30, size: 4.8))
      ..add(_templateCellTextPx(row[4], 408, top, width: 38, size: 4.8))
      ..add(_templateCellTextPx(row[5], 455, top, width: 50, size: 4.4))
      ..add(_templateCellTextPx(row[6], 520, top, width: 48, size: 4.6))
      ..add(_templateCellTextPx(row[7], 590, top, width: 48, size: 4.6))
      ..add(_templateCellTextPx(row[8], 662, top, width: 48, size: 4.6))
      ..add(_templateCellTextPx(row[9], 735, top, width: 50, size: 4.4))
      ..add(_templateCellTextPx(row[10], 805, top, width: 45, size: 4.6))
      ..add(_templateCellTextPx(row[11], 865, top, width: 50, size: 4.4));
  }

  final recallRows = _surveyMapRows(data['food_recall_24_hour']);
  const recallTops = {
    'breakfast': 774.0,
    'snack': 791.0,
    'lunch': 808.0,
    'dinner': 843.0,
    'midnight snack': 860.0,
    'midnightsnack': 860.0,
  };
  var snackIndex = 0;
  for (final row in recallRows) {
    final normalizedTime = _normalizeSurveyChoice(
      _surveyRowValue(row, 'time_of_day'),
    );
    var top = recallTops[normalizedTime];
    if (normalizedTime == 'snack') {
      top = snackIndex == 0 ? 791.0 : 826.0;
      snackIndex++;
    }
    if (top == null) {
      continue;
    }
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'date'),
      42,
      top,
      width: 130,
      size: 5.4,
    );
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'food_taken'),
      545,
      top,
      width: 380,
      size: 5.4,
    );
  }

  mark('first_food_choice', 'Meat only', 330, 906);
  mark('first_food_choice', 'Fish', 445, 906);
  mark('first_food_choice', 'Vegetable', 560, 906);
  mark('first_food_choice', 'Mixed', 676, 906);
  mark('first_food_choice', 'Others', 772, 906);
  text('first_food_choice_other', 850, 901, width: 80);
  mark('first_food_choice_servings', '1', 330, 924);
  mark('first_food_choice_servings', '2-3', 445, 924);
  mark('first_food_choice_servings', '4-5 and above', 560, 924);
  mark('second_food_choice', 'Meat', 330, 941);
  mark('second_food_choice', 'Fish', 445, 941);
  mark('second_food_choice', 'Vegetable', 560, 940);
  mark('second_food_choice', 'Mixed', 676, 939);
  mark('second_food_choice', 'Others', 772, 939);
  text('second_food_choice_other', 850, 935, width: 80);
  mark('second_food_choice_servings', '1', 330, 958);
  mark('second_food_choice_servings', '2-3', 445, 957);
  mark('second_food_choice_servings', '4-5 and above', 560, 957);

  mark('reason_for_food_choices', 'It is healthy', 330, 989);
  mark('reason_for_food_choices', 'Own preference', 445, 989);
  mark('reason_for_food_choices', 'Affordable', 618, 989);
  mark('reason_for_food_choices', 'Personal belief/practices', 330, 1007);
  mark('reason_for_food_choices', 'Health condition', 560, 1005);
  mark('reason_for_not_choosing_other_food_options', 'Not healthy', 445, 1038);
  mark(
    'reason_for_not_choosing_other_food_options',
    'Own preference',
    560,
    1038,
  );
  mark(
    'reason_for_not_choosing_other_food_options',
    'Not affordable',
    712,
    1038,
  );
  mark(
    'reason_for_not_choosing_other_food_options',
    'Personal belief/religious practices',
    445,
    1057,
  );
  mark(
    'reason_for_not_choosing_other_food_options',
    'Health condition',
    712,
    1056,
  );

  mark('food_intake_frequency', 'Everyday', 445, 1088);
  mark('food_intake_frequency', 'Twice a week', 568, 1088);
  mark('food_intake_frequency', 'Once a week', 711, 1088);
  mark('food_intake_frequency', 'Others', 445, 1106);
  text('food_intake_frequency_other', 560, 1102, width: 220);
  mark('food_prepared_for_mealtime', 'Prepared at home', 330, 1138);
  mark('food_prepared_for_mealtime', 'Bought outside', 560, 1138);
  mark('food_preparation_frequency', 'Everyday', 330, 1156);
  mark('food_preparation_frequency', 'Twice a week', 445, 1154);
  mark('food_preparation_frequency', 'Once a week', 560, 1156);
  mark('food_preparation_frequency', 'Others', 711, 1154);
  text('food_preparation_frequency_other', 805, 1151, width: 120);

  mark('bought_food_source', 'Restaurant/Fast food', 330, 1187);
  mark('bought_food_source', 'Carinderia', 560, 1187);
  mark('bought_food_source', 'Food cart', 330, 1205);
  mark(
    'bought_food_source',
    'Food cart, e.g. fried chicken sa kanto, provent, calamares',
    330,
    1205,
  );
  mark('reason_for_bought_food_option', 'Convenient', 330, 1237);
  mark('reason_for_bought_food_option', 'Cheaper', 445, 1237);
  mark('reason_for_bought_food_option', 'Healthy', 560, 1237);
  mark('reason_for_bought_food_option', 'Variety of choices', 330, 1255);
  mark('reason_for_bought_food_option', 'Others', 560, 1255);
  text('reason_for_bought_food_option_other', 680, 1251, width: 220);

  mark('canned_preserved_food_frequency', 'Everyday', 330, 1305);
  mark('canned_preserved_food_frequency', 'Every other day', 445, 1303);
  mark('canned_preserved_food_frequency', 'Every week', 618, 1303);
  mark('canned_preserved_food_frequency', 'Sometimes', 733, 1303);
  mark('canned_preserved_food_frequency', 'Never', 848, 1303);
  mark('grilled_food_frequency', 'Everyday', 330, 1336);
  mark('grilled_food_frequency', 'Every other day', 445, 1336);
  mark('grilled_food_frequency', 'Every week', 618, 1336);
  mark('grilled_food_frequency', 'Sometimes', 733, 1336);
  mark('grilled_food_frequency', 'Never', 848, 1336);
  mark('carbonated_beverage_frequency', 'Everyday', 330, 1369);
  mark('carbonated_beverage_frequency', 'Every other day', 445, 1369);
  mark('carbonated_beverage_frequency', 'Every week', 618, 1369);
  mark('carbonated_beverage_frequency', 'Occasionally', 330, 1388);
  mark('carbonated_beverage_frequency', 'Sometimes', 445, 1388);
  mark('carbonated_beverage_frequency', 'Never', 618, 1388);

  return widgets;
}

List<pw.Widget> _templatePageFiveOverlay(HealthSubmission submission) {
  final data = submission.surveyData;
  final widgets = <pw.Widget>[];

  void mark(String key, String choice, double left, double top) {
    _addTemplateMarkIf(widgets, _surveyHasChoice(data, key, choice), left, top);
  }

  void text(String key, double left, double top, {double width = 150}) {
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyString(data, key),
      left,
      top,
      width: width,
    );
  }

  mark('personnel_consulted_during_illness', 'Doctor', 505, 124);
  mark('personnel_consulted_during_illness', 'Nurse', 618, 124);
  mark('personnel_consulted_during_illness', 'Midwife', 734, 124);
  mark('personnel_consulted_during_illness', 'Hilot', 832, 124);
  mark('personnel_consulted_during_illness', 'Albularyo', 505, 142);
  mark('personnel_consulted_during_illness', 'Faith Healer', 619, 142);
  mark('personnel_consulted_during_illness', 'Elderly', 735, 142);
  mark(
    'measures_taken_during_illness',
    'Consult a private health worker',
    399,
    157,
  );
  mark(
    'measures_taken_during_illness',
    'See a known community healer',
    639,
    157,
  );
  mark(
    'measures_taken_during_illness',
    'Consult a Rural Health Team',
    400,
    175,
  );
  mark('measures_taken_during_illness', 'Self-Medication', 638, 175);
  mark('measures_taken_during_illness', 'None', 803, 175);
  mark('medication_treatment_during_illness', 'Prescribed by Doctor', 510, 190);
  mark(
    'medication_treatment_during_illness',
    'Self-Medication/OTC drugs',
    726,
    190,
  );
  mark('medication_treatment_during_illness', 'Herbals', 512, 208);
  mark('medication_treatment_during_illness', 'Others', 642, 208);
  text('medication_treatment_during_illness_other', 760, 203, width: 150);
  mark('medical_checkup_frequency', 'Once a year', 512, 226);
  mark('medical_checkup_frequency', 'Twice a year', 642, 226);
  mark('medical_checkup_frequency', 'More than a year', 780, 225);
  mark('dental_checkup_frequency', 'Once a year', 505, 242);
  mark('dental_checkup_frequency', 'Twice a year', 642, 242);
  mark('dental_checkup_frequency', 'More than a year', 780, 241);
  text('barangay_health_center_services_available', 555, 315, width: 300);

  final immunizationRows = _immunizationTemplateRows(submission);
  const immunizationTop = 406.0;
  const immunizationRowHeight = 42.0;
  for (var index = 0; index < immunizationRows.length && index < 2; index++) {
    final row = immunizationRows[index];
    final top = immunizationTop + immunizationRowHeight * index;
    widgets
      ..add(_templateTextPx(row[0], 27, top, width: 80, size: 4.8))
      ..add(_templateTextPx(row[1], 118, top, width: 35, size: 4.8))
      ..add(_templateTextPx(row[2], 160, top, width: 50, size: 4.4))
      ..add(
        _templateTextPx(
          _shortTemplateDateOrMark(row[3]),
          223,
          top,
          width: 30,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateTextPx(
          _shortTemplateDateOrMark(row[4]),
          266,
          top,
          width: 30,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateTextPx(
          _shortTemplateDateOrMark(row[5]),
          313,
          top,
          width: 30,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateTextPx(
          _shortTemplateDateOrMark(row[6]),
          360,
          top,
          width: 30,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateTextPx(
          _shortTemplateDateOrMark(row[7]),
          405,
          top,
          width: 45,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateTextPx(
          _shortTemplateDateOrMark(row[8]),
          464,
          top,
          width: 45,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateTextPx(
          _shortTemplateDateOrMark(row[9]),
          521,
          top,
          width: 45,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateTextPx(
          _shortTemplateDateOrMark(row[10]),
          580,
          top,
          width: 30,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateTextPx(
          _shortTemplateDateOrMark(row[11]),
          625,
          top,
          width: 30,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateTextPx(
          _shortTemplateDateOrMark(row[12]),
          672,
          top,
          width: 30,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(
        _templateTextPx(
          _shortTemplateDateOrMark(row[13]),
          718,
          top,
          width: 30,
          size: 4.8,
          align: pw.TextAlign.center,
        ),
      )
      ..add(_templateTextPx(row[14], 765, top, width: 55, size: 4.8))
      ..add(_templateTextPx(row[15], 828, top, width: 45, size: 4.8))
      ..add(_templateTextPx(row[16], 884, top, width: 45, size: 4.5));
  }

  final antenatalRows = _surveyMapRows(data['antenatal_registrations']);
  for (var index = 0; index < antenatalRows.length && index < 2; index++) {
    final row = antenatalRows[index];
    final topPx = 562.0 + index * 18.0;
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'name'),
      52,
      topPx,
      width: 130,
      size: 5.6,
    );
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyRowValue(row, 'aog'),
      205,
      topPx,
      width: 75,
      size: 5.6,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(row['prenatal_checkup_with_regular']).isNotEmpty,
      335,
      topPx,
      size: 6.0,
      optionBox: false,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(row['prenatal_checkup_with_not_regular']).isNotEmpty,
      470,
      topPx,
      size: 6.0,
      optionBox: false,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(row['prenatal_checkup_without']).isNotEmpty,
      610,
      topPx,
      size: 6.0,
      optionBox: false,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(row['tetanus_vaccination_with']).isNotEmpty,
      735,
      topPx,
      size: 6.0,
      optionBox: false,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(row['tetanus_vaccination_without']).isNotEmpty,
      840,
      topPx,
      size: 6.0,
      optionBox: false,
    );
  }

  mark('family_planning_status', 'Acceptor', 239, 641);
  mark('family_planning_status', 'Non-Acceptor', 239, 724);
  final isFamilyPlanningAcceptor = _surveyHasChoice(
    data,
    'family_planning_status',
    'Acceptor',
  );
  final isFamilyPlanningNonAcceptor = _surveyHasChoice(
    data,
    'family_planning_status',
    'Non-Acceptor',
  );
  if (isFamilyPlanningAcceptor) {
    mark(
      'family_planning_acceptor_reasons',
      'Good for health of family',
      388,
      658,
    );
    mark('family_planning_acceptor_reasons', 'Personal belief', 676, 658);
    mark('family_planning_acceptor_reasons', 'Religious belief', 388, 676);
    mark('family_planning_acceptor_reasons', 'Influence by others', 676, 676);
    mark('family_planning_acceptor_reasons', 'Others', 388, 693);
    text('family_planning_acceptor_reason_other', 510, 688, width: 120);

    _addTemplateMarkIf(
      widgets,
      _yesNoMark(
            data['permanent_method_female_sterilization_btl'],
          ).isNotEmpty ||
          _yesNoMark(
            data['permanent_method_male_sterilization_vasectomy'],
          ).isNotEmpty,
      128,
      824,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(data['permanent_method_female_sterilization_btl']).isNotEmpty,
      380,
      824,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(
        data['permanent_method_male_sterilization_vasectomy'],
      ).isNotEmpty,
      704,
      824,
    );
    final hasSupplyMethod = [
      'supply_method_pills',
      'supply_method_iud',
      'supply_method_injectable',
      'supply_method_condoms',
      'supply_method_implant',
    ].any((key) => _yesNoMark(data[key]).isNotEmpty);
    _addTemplateMarkIf(widgets, hasSupplyMethod, 128, 842);
    _addTemplateMarkIf(widgets, hasSupplyMethod, 157, 857);
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(data['supply_method_pills']).isNotEmpty,
      480,
      857,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(data['supply_method_iud']).isNotEmpty,
      532,
      857,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(data['supply_method_injectable']).isNotEmpty,
      567,
      857,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(data['supply_method_condoms']).isNotEmpty,
      669,
      857,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(data['supply_method_implant']).isNotEmpty,
      756,
      857,
    );
    final hasFertilityMethod = [
      'fertility_method_cervical_mucus_billings',
      'fertility_method_basal_body_temperature',
      'fertility_method_sympto_thermal',
      'fertility_method_standard_days',
      'fertility_method_lactational_amenorrhea',
    ].any((key) => _yesNoMark(data[key]).isNotEmpty);
    _addTemplateMarkIf(widgets, hasFertilityMethod, 166, 890);
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(data['fertility_method_cervical_mucus_billings']).isNotEmpty,
      480,
      890,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(data['fertility_method_basal_body_temperature']).isNotEmpty,
      733,
      890,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(data['fertility_method_sympto_thermal']).isNotEmpty,
      480,
      908,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(data['fertility_method_standard_days']).isNotEmpty,
      733,
      908,
    );
    _addTemplateMarkIf(
      widgets,
      _yesNoMark(data['fertility_method_lactational_amenorrhea']).isNotEmpty,
      480,
      925,
    );
  }
  if (isFamilyPlanningNonAcceptor) {
    mark(
      'family_planning_non_acceptor_reasons',
      'Bad for health of family',
      388,
      741,
    );
    mark('family_planning_non_acceptor_reasons', 'Personal belief', 676, 741);
    mark('family_planning_non_acceptor_reasons', 'Religious belief', 388, 759);
    mark(
      'family_planning_non_acceptor_reasons',
      'Influence by others',
      676,
      759,
    );
    mark('family_planning_non_acceptor_reasons', 'Others', 388, 776);
    text('family_planning_non_acceptor_reason_other', 510, 771, width: 120);
  }

  pw.Widget healthCellText(
    String value,
    double left,
    double top, {
    double width = 120,
    double size = 5.0,
  }) {
    final verticalOffset = _isPdfCheckMark(_valueOrBlank(value)) ? 9.5 : 6.5;
    return _templateCellTextPx(
      value,
      left,
      top,
      width: width,
      size: size,
      verticalOffset: verticalOffset,
    );
  }

  final morbidityRows = _morbidityTemplateRows(submission);
  const morbidityTop = 1038.0;
  const morbidityRowHeight = 18.0;
  for (var index = 0; index < morbidityRows.length && index < 4; index++) {
    final row = morbidityRows[index];
    final top = morbidityTop + morbidityRowHeight * index;
    widgets
      ..add(healthCellText(row[0], 40, top, width: 95))
      ..add(healthCellText(row[1], 160, top, width: 70))
      ..add(healthCellText(row[2], 275, top, width: 100))
      ..add(healthCellText(row[3], 405, top, width: 100))
      ..add(healthCellText(row[4], 525, top, width: 45))
      ..add(healthCellText(row[5], 625, top, width: 45))
      ..add(healthCellText(row[6], 745, top, width: 45))
      ..add(healthCellText(row[7], 850, top, width: 45));
  }

  final mortalityRows = _mortalityTemplateRows(submission);
  const conditionRowHeight = 18.0;
  for (var index = 0; index < mortalityRows.length && index < 3; index++) {
    final row = mortalityRows[index];
    final top = 1140.0 + conditionRowHeight * index;
    widgets
      ..add(healthCellText(row[0], 40, top, width: 200))
      ..add(healthCellText(row[1], 272, top, width: 160))
      ..add(healthCellText(row[2], 515, top, width: 160))
      ..add(healthCellText(row[3], 740, top, width: 180));
  }

  final ncdRows = _nonCommunicableDiseaseTemplateRows(submission);
  for (var index = 0; index < ncdRows.length && index < 3; index++) {
    final row = ncdRows[index];
    final top = 1244.0 + conditionRowHeight * index;
    widgets
      ..add(healthCellText(row[0], 40, top, width: 200))
      ..add(healthCellText(row[1], 272, top, width: 160))
      ..add(healthCellText(row[2], 515, top, width: 160))
      ..add(healthCellText(row[3], 740, top, width: 180));
  }

  final cdRows = _communicableDiseaseTemplateRows(submission);
  for (var index = 0; index < cdRows.length && index < 3; index++) {
    final row = cdRows[index];
    final top = 1345.0 + conditionRowHeight * index;
    widgets
      ..add(healthCellText(row[0], 40, top, width: 200))
      ..add(healthCellText(row[1], 272, top, width: 160))
      ..add(healthCellText(row[2], 515, top, width: 160))
      ..add(healthCellText(row[3], 740, top, width: 180));
  }

  return widgets;
}

List<pw.Widget> _templatePageSixOverlay(HealthSubmission submission) {
  final data = submission.surveyData;
  final widgets = <pw.Widget>[];

  void mark(String key, String choice, double left, double top) {
    _addTemplateMarkIf(widgets, _surveyHasChoice(data, key, choice), left, top);
  }

  void text(String key, double left, double top, {double width = 150}) {
    _addTemplateTextIfNotEmpty(
      widgets,
      _surveyString(data, key),
      left,
      top,
      width: width,
    );
  }

  final bpRows = _bloodPressureTemplateRows(submission);
  const bpTop = 119.0;
  const conditionRowHeight = 18.0;
  for (var index = 0; index < bpRows.length && index < 3; index++) {
    final row = bpRows[index];
    final top = bpTop + conditionRowHeight * index;
    widgets
      ..add(
        _templateCellTextPx(
          row[0],
          40,
          top,
          width: 200,
          size: 5.0,
          verticalOffset: 9.5,
        ),
      )
      ..add(
        _templateCellTextPx(
          row[1],
          272,
          top,
          width: 160,
          size: 5.0,
          verticalOffset: 9.5,
        ),
      )
      ..add(
        _templateCellTextPx(
          row[2],
          515,
          top,
          width: 160,
          size: 5.0,
          verticalOffset: 9.5,
        ),
      )
      ..add(
        _templateCellTextPx(
          row[3],
          740,
          top,
          width: 180,
          size: 5.0,
          verticalOffset: 9.5,
        ),
      );
  }

  mark('awareness_of_bhc_rhu_health_services', 'Aware', 503, 192);
  mark('awareness_of_bhc_rhu_health_services', 'Unaware', 618, 192);

  text('health_manpower_categories_available', 378, 300, width: 440);
  text('health_manpower_geographical_distribution', 270, 317, width: 540);
  final teamSummary =
      _surveyString(data, 'rhu_team_per_population_summary').trim().isNotEmpty
      ? _surveyString(data, 'rhu_team_per_population_summary')
      : [
          _surveyString(data, 'physician_count_per_population'),
          _surveyString(data, 'nurse_count_per_population'),
          _surveyString(data, 'midwife_count_per_population'),
          _surveyString(data, 'other_rhu_team_count_per_population'),
        ].where((value) => value.trim().isNotEmpty).join('; ');
  _addTemplateTextIfNotEmpty(
    widgets,
    teamSummary,
    675,
    330,
    width: 245,
    size: 4.8,
  );
  _addTemplateTextIfNotEmpty(
    widgets,
    _surveyString(data, 'existing_manpower_development_policies'),
    382,
    349,
    width: 545,
    size: 4.8,
  );
  text('rhu_physicians_schedule', 215, 383, width: 220);
  text('rhu_nurse_schedule', 183, 400, width: 250);
  text('bhc_midwife_schedule', 205, 418, width: 230);

  mark('health_budget_expenditures_availability', 'Available', 388, 474);
  mark('health_budget_expenditures_availability', 'Not Available', 503, 474);
  text('health_budget_amount_per_year_php', 845, 481, width: 100);
  mark('supplies_equipment_availability', 'Available 100%', 388, 492);
  mark('supplies_equipment_availability', 'Limited Supplies', 503, 492);
  mark('supplies_equipment_availability', 'Not Available', 676, 490);

  mark('recognized_formal_elected_leaders', 'Captain', 219, 573);
  mark('recognized_formal_elected_leaders', 'Kagawad', 388, 573);
  mark('recognized_non_formal_leaders', 'Elderly', 219, 591);
  mark('recognized_non_formal_leaders', 'BHW', 388, 591);
  mark('recognized_non_formal_leaders', 'Influential person', 503, 589);
  mark('recognized_non_formal_leaders', 'Religious leader', 219, 608);
  mark('recognized_non_formal_leaders', 'Neighbor', 388, 608);

  mark('social_conflict_causes', 'Gossip', 100, 656);
  mark('social_conflict_causes', 'Family conflict', 215, 656);
  mark('social_conflict_causes', 'Drugs', 388, 656);
  mark('social_conflict_causes', 'Riot', 503, 656);
  mark('social_conflict_causes', 'Alcohol drinking', 618, 658);
  mark('social_conflict_causes', 'Others', 100, 674);
  text('social_conflict_causes_other', 170, 668, width: 180);

  mark(
    'conflict_resolution_approaches',
    'Settlement among involved parties',
    100,
    722,
  );
  mark('conflict_resolution_approaches', 'Brgy. hearing', 388, 722);
  mark('conflict_resolution_approaches', 'Endorsed to local police', 503, 722);
  mark('conflict_resolution_approaches', 'Others', 100, 740);
  text('conflict_resolution_approaches_other', 170, 734, width: 180);

  final concernText = [
    _surveyString(data, 'general_lifestyle_area_concerns_suggestions'),
    _listOrBlank(submission.communityConcerns),
    submission.notes,
  ].where((value) => value.trim().isNotEmpty).join(' ');
  final lines = _wrapOverlayText(concernText, 100).take(5).toList();

  widgets.addAll([
    for (var index = 0; index < lines.length; index++)
      _templateTextPx(
        lines[index],
        46,
        799 + index * 19,
        width: 489,
        size: 5.8,
      ),
  ]);

  return widgets;
}

pw.Widget _templateText(
  String text,
  double left,
  double top, {
  double width = 100,
  double size = 6.2,
  pw.TextAlign align = pw.TextAlign.left,
}) {
  final value = _valueOrBlank(text);
  if (_isPdfCheckMark(value)) {
    final markExtent = width < size + 2.2 ? width : size + 2.2;
    final markLeft = left + (width - markExtent) / 2;
    return _templateCheckMark(
      markLeft,
      top,
      width: markExtent,
      height: markExtent,
      strokeWidth: size / 6,
    );
  }

  return pw.Positioned(
    left: left,
    top: top,
    child: pw.SizedBox(
      width: width,
      child: pw.Text(
        value,
        maxLines: 1,
        textAlign: align,
        style: pw.TextStyle(fontSize: size),
      ),
    ),
  );
}

const _templateImageWidthPx = 979.0;
const _templateImageHeightPx = 1496.0;

double _templatePxX(double value) =>
    value * _templatePdfPageFormat.width / _templateImageWidthPx;

double _templatePxY(double value) =>
    value * _templatePdfPageFormat.height / _templateImageHeightPx;

pw.Widget _templateTextPx(
  String text,
  double left,
  double top, {
  double width = 120,
  double size = 6.2,
  pw.TextAlign align = pw.TextAlign.left,
}) {
  return _templateText(
    text,
    _templatePxX(left),
    _templatePxY(top),
    width: _templatePxX(width),
    size: size,
    align: align,
  );
}

pw.Widget _templateCellTextPx(
  String text,
  double left,
  double top, {
  double width = 120,
  double size = 6.2,
  double verticalOffset = 7.0,
  pw.TextAlign align = pw.TextAlign.left,
}) {
  return _templateTextPx(
    text,
    left,
    top + verticalOffset,
    width: width,
    size: size,
    align: align,
  );
}

pw.Widget _templateMarkPx(
  double left,
  double top, {
  String value = _pdfCheckMark,
  double size = 6.8,
  bool optionBox = true,
  double optionWidth = 28.0,
  double optionHeight = 18.0,
}) {
  const markBoxWidth = 14.0;
  const markBoxHeight = 14.0;
  final markLeft = optionBox ? left + (optionWidth - markBoxWidth) / 2 : left;
  final markTop = top + (optionHeight - markBoxHeight) / 2;
  final markValue = _valueOrBlank(value);
  final markWidth = _templatePxX(markBoxWidth);
  final markHeight = _templatePxY(markBoxHeight);

  return pw.Positioned(
    left: _templatePxX(markLeft),
    top: _templatePxY(markTop),
    child: pw.SizedBox(
      width: markWidth,
      height: markHeight,
      child: _isPdfCheckMark(markValue)
          ? _checkMarkPaint(markWidth, markHeight, strokeWidth: size / 6)
          : pw.Center(
              child: pw.Text(
                markValue,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: size),
              ),
            ),
    ),
  );
}

bool _isPdfCheckMark(String value) => value == _pdfCheckMark;

pw.Widget _templateCheckMark(
  double left,
  double top, {
  required double width,
  required double height,
  required double strokeWidth,
}) {
  return pw.Positioned(
    left: left,
    top: top,
    child: _checkMarkPaint(width, height, strokeWidth: strokeWidth),
  );
}

pw.Widget _checkMarkPaint(
  double width,
  double height, {
  required double strokeWidth,
}) {
  return pw.CustomPaint(
    size: PdfPoint(width, height),
    painter: (canvas, size) {
      canvas
        ..moveTo(size.x * 0.16, size.y * 0.48)
        ..lineTo(size.x * 0.38, size.y * 0.22)
        ..lineTo(size.x * 0.86, size.y * 0.76)
        ..setStrokeColor(PdfColors.black)
        ..setLineWidth(strokeWidth)
        ..strokePath();
    },
  );
}

void _addTemplateMarkIf(
  List<pw.Widget> widgets,
  bool condition,
  double left,
  double top, {
  String value = _pdfCheckMark,
  double size = 6.8,
  bool optionBox = true,
  double optionWidth = 28.0,
  double optionHeight = 18.0,
}) {
  if (!condition) {
    return;
  }
  widgets.add(
    _templateMarkPx(
      left,
      top,
      value: value,
      size: size,
      optionBox: optionBox,
      optionWidth: optionWidth,
      optionHeight: optionHeight,
    ),
  );
}

void _addTemplateTextIfNotEmpty(
  List<pw.Widget> widgets,
  String text,
  double left,
  double top, {
  double width = 120,
  double size = 5.2,
}) {
  if (text.trim().isEmpty) {
    return;
  }
  widgets.add(_templateTextPx(text, left, top, width: width, size: size));
}

String _normalizeSurveyChoice(Object? value) {
  return _surveyValueLabel(value)
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool _surveyHasChoice(Map<String, dynamic> data, String key, String choice) {
  final value = data[key];
  final target = _normalizeSurveyChoice(choice);
  if (target.isEmpty) {
    return false;
  }
  if (value is List) {
    return value.any((item) => _normalizeSurveyChoice(item) == target);
  }
  final normalized = _normalizeSurveyChoice(value);
  return normalized == target;
}

bool _surveyHasAnyChoice(
  Map<String, dynamic> data,
  String key,
  Iterable<String> choices,
) {
  return choices.any((choice) => _surveyHasChoice(data, key, choice));
}

bool _surveyIsYes(Map<String, dynamic> data, String key) {
  final normalized = _normalizeSurveyChoice(data[key]);
  return normalized == 'yes' || normalized == 'true' || normalized == '1';
}

bool _surveyIsNo(Map<String, dynamic> data, String key) {
  final normalized = _normalizeSurveyChoice(data[key]);
  return normalized == 'no' || normalized == 'false' || normalized == '0';
}

bool _rowHasContent(Map<String, dynamic> row, String key) {
  return _surveyValueHasContent(row[key]);
}

String _shortTemplateDateOrMark(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.toLowerCase() == 'yes' ||
      trimmed.toLowerCase() == 'true' ||
      trimmed.toLowerCase() == 'x') {
    return _pdfCheckMark;
  }
  return _pdfCheckMark;
}

List<String> _wrapOverlayText(String text, int width) {
  final cleaned = _valueOrBlank(text);
  if (cleaned.isEmpty) {
    return const [];
  }
  final words = cleaned.split(RegExp(r'\s+'));
  final lines = <String>[];
  var current = '';
  for (final word in words) {
    final next = current.isEmpty ? word : '$current $word';
    if (next.length <= width) {
      current = next;
    } else {
      lines.add(current);
      current = word;
    }
  }
  if (current.isNotEmpty) {
    lines.add(current);
  }
  return lines;
}

void _addSurveyPdfPages(
  pw.Document document,
  HealthSubmission submission,
  pw.ImageProvider collegeLogo,
  pw.ImageProvider universityLogo,
  pw.ThemeData theme,
) {
  final pages = [
    _surveyPdfPageOne(submission, universityLogo, collegeLogo),
    _surveyPdfPageTwo(),
    _surveyPdfPageThree(submission),
    _surveyPdfPageFour(submission),
    _surveyPdfPageFive(submission),
    _surveyPdfPageSix(submission),
  ];

  for (final page in pages) {
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(20, 22, 20, 22),
        theme: theme,
        build: (context) => page,
      ),
    );
  }
}

pw.Widget _surveyPdfPageOne(
  HealthSubmission submission,
  pw.ImageProvider universityLogo,
  pw.ImageProvider collegeLogo,
) {
  return _pdfFormPage(
    pageNumber: '1',
    children: [
      _pdfTemplateHeader(universityLogo, collegeLogo),
      pw.SizedBox(height: 8),
      _pdfVisitLines(submission),
      pw.SizedBox(height: 8),
      _formText('I.  Demographic Variable', bold: true),
      pw.SizedBox(height: 6),
      _pdfDemographicGrid(submission),
      pw.SizedBox(height: 12),
      _pdfLegend(),
      pw.SizedBox(height: 12),
      _pdfWorkLegend(),
    ],
  );
}

pw.Widget _surveyPdfPageTwo() {
  return _pdfFormPage(
    pageNumber: '2',
    footerLeft: 'CDX Tool Revised: 01 / 02-16-2024',
    children: [
      _formText('a.    Type of Family:', bold: true),
      pw.SizedBox(height: 10),
      _formText('Based on composition:'),
      _optionRow([
        '( ) Nuclear',
        '( ) Extended',
        '( ) Dyad',
        '( ) Homosexual/Same Sex',
      ], leftIndent: 28),
      _optionRow([
        '( ) Cohabiting/Communal',
        '( ) Blended Family',
        '( ) Living with Grandparent(s)',
        '( ) Single- parent',
      ], leftIndent: 28),
      pw.SizedBox(height: 6),
      _formText('Based on locus of power'),
      _optionRow([
        '( ) Patrifocal/Patriarchal',
        '( ) Matrifocal/Matriarchal',
        '( ) Egalitarian',
        '( ) Matricentric',
      ], leftIndent: 28),
      pw.SizedBox(height: 6),
      _formText('Based on place of residence'),
      _optionRow([
        '( ) Patrilocal',
        '( ) Matrilocal',
        '( ) Bilocal (Ambilocal)',
        '( ) Neolocal',
      ], leftIndent: 58),
      pw.SizedBox(height: 6),
      _formText('Based on descent'),
      _optionRow([
        '( ) Patrilineal',
        '( ) Matrilineal',
        '( ) Bilateral',
      ], leftIndent: 58),
      pw.SizedBox(height: 10),
      _inlineUnderline('b.    Dialect Frequently used:', '', width: 230),
      pw.SizedBox(height: 12),
      _formText(
        'II.  Socio- economic, cultural and environmental (Multiple Response)',
        bold: true,
        italicTail: '(Multiple Response)',
      ),
      pw.SizedBox(height: 9),
      _underlinedTitle('1.    Social Indicators'),
      _choiceLine('A.', 'Services in the Community:', [
        '( ) Religious services',
        '( ) Livelihood Services',
        '( ) livelihood service',
        '( ) Health Services',
        '( ) Garbage collection',
        '( ) Peace and Order',
      ]),
      _choiceLine('B.', 'Institutional Facilities:', [
        '( ) Brgy. Hall',
        '( ) Health Station',
        '( ) Church',
        '( ) School',
      ]),
      _choiceLine('C.', 'Organizations:', [
        '( ) Senior Citizen',
        '( ) Youth',
        '( ) Others __________',
      ]),
      _choiceLine('D.', 'Tradition/Customs:', [
        '( ) Bayanihan',
        '( ) Palabra de Honor',
        '( ) Pakikisama',
        '( ) Ningas Kugon',
        '( ) Fiestas',
        '( ) Close family ties',
        '( ) Respect for elderly',
        '( ) Others____________',
      ]),
      _choiceLine('E.', 'Recreational Facilities:', [
        '( ) Volleyball/Basketball court',
        '( ) Playground',
        '( ) Plaza',
        '( ) Others_______________',
      ]),
      _choiceLine('F.', 'Mode of Transportation:', [
        '( ) Tricycle',
        '( ) Jeep',
        '( ) PUJ/PUV',
        '( ) Bicycle',
        '( ) Private vehicle',
      ]),
      _choiceLine('G.', 'Mode of Communication:', [
        '( ) Postal system',
        '( ) Internet',
        '( ) Telephone',
        '( ) Cell phone',
        '( ) Two- way radio',
        '( ) Others, specify: ____________',
      ]),
      pw.SizedBox(height: 10),
      _underlinedTitle('2.    Economic Indicator:'),
      _incomeEarnersBlock(),
      pw.SizedBox(height: 6),
      _choiceLine('B.', 'Monthly Family Income (combined)', [
        '( ) less than 5,000',
        '( ) 5,001- 10,000',
        '( ) 10,001- 15,000',
        '( ) 15,001- 20,000',
        '( ) 20,001- 25,000',
        '( ) 25,001- 30,000',
        '( ) 30,001- 35,000',
        '( ) 35,001- 40,000',
        '( ) 40,001- 45,000',
        '( ) 45,001- 50,000',
        '( ) 50,001 and above',
      ]),
      _choiceLine('C.', 'Financial Source for Family expenditures:', [
        '( ) Employment',
        '( ) Business',
        '( ) Pension',
        '( ) Help from relative/friends',
        '( ) Others:',
      ]),
      _choiceLine('D.', 'Monthly Family Expenditures:', [
        '( ) less than 5,000',
        '( ) 5,001- 10,000',
        '( ) 10,001- 15,000',
        '( ) 15,001- 20,000',
        '( ) 20,001- 25,000',
        '( ) 25,001- 30,000',
        '( ) 30,001- 35,000',
        '( ) 35,001- 40,000',
        '( ) 40,001- 45,000',
        '( ) 45,001- 50,000',
        '( ) 50,001 and above',
      ]),
      _choiceLine(
        'E.',
        'Priorities and Expenditure ( family\'s priority by ranking 1-7 where 1 is the highest priority)',
        [
          '( ) Food',
          '( ) Clothing',
          '( ) Education',
          '( ) Utilities',
          '( ) Health',
          '( ) Recreation',
          '( ) Savings',
        ],
      ),
      _choiceLine('F.', 'Adequacy of Family Income:', [
        '( ) Adequate',
        '( ) Not Adequate',
      ]),
      pw.SizedBox(height: 9),
      _underlinedTitle('3.    Cultural Indicator:'),
      _choiceLine(
        'A.',
        'Cultural Orientation regarding Illness (Multiple Response)',
        [
          '( ) believe that illness is caused by physiologic factor e. g. infection',
          '( ) believe that illness is caused by supernatural phenomenon e. g. kulam, balis',
          '( ) believe that illness is a punishment from GOD',
          '( ) believe that illness is caused by other person',
          '( ) believe that illness is caused by change in weather',
          '( ) others:________________',
        ],
      ),
      _choiceLine('B.', 'Cultural Belief: (Multiple Response)', [
        '( ) health can be restored by GOD/ other spiritual faith',
        '( ) health can be restored by faith healers',
        '( ) health can be restored by supernatural power e.g. tawas, nilot, hula',
        '( ) health can be restored by health personnel e. g. doctors, nurses',
      ]),
      _choiceLine('C.', 'Cultural Perception', [
        '( ) always practices local cultural practices about health matters',
        '( ) sometimes practices local cultural practices about health matters',
      ]),
    ],
  );
}

pw.Widget _surveyPdfPageThree(HealthSubmission submission) {
  return _pdfFormPage(
    pageNumber: '3',
    children: [
      _formText(
        '( ) does not practice any local cultural practices about health matters',
      ),
      pw.SizedBox(height: 8),
      _choiceLine('D.', 'Community Involvement', [
        '( ) Actively join fiesta, religious procession, local cultural practices',
        '( ) does not actively join',
      ]),
      pw.SizedBox(height: 9),
      _underlinedTitle('4.    Environmental Indicator'),
      pw.SizedBox(height: 6),
      _formText('A.    Home', italic: true),
      _choiceLine('a.', 'Ownership:', [
        '( ) Owned',
        '( ) Rented',
        '( ) Rent- free',
        '( ) Least to own',
        '( ) squatting/informal settlers',
        '( ) professional squatters',
      ], leftIndent: 28),
      _choiceLine('b.', 'Construction materials used:', [
        '( ) Light',
        '( ) Mixed',
        '( ) Strong (Concrete)',
      ], leftIndent: 28),
      _choiceLine('c.', 'Number of rooms used for sleeping:', [
        '( ) 1',
        '( ) 2',
        '( ) 3',
        '( ) 4',
        '( ) 5',
        '( ) None (no partition)',
      ], leftIndent: 28),
      _choiceLine('d.', 'Adequacy of space:', [
        '( ) Adequate',
        '( ) Inadequate',
      ], leftIndent: 28),
      _choiceLine('e.', 'Lighting facility:', [
        '( ) Electricity',
        '( ) Kerosene',
        '( ) Others, specify:',
      ], leftIndent: 28),
      _choiceLine('f.', 'Adequacy of Lighting:', [
        '( ) Adequate',
        '( ) Inadequate',
      ], leftIndent: 28),
      _choiceLine('g.', 'Ventilation:', [
        '( ) Adequate',
        '( ) Inadequate',
      ], leftIndent: 28),
      _choiceLine('h.', 'General Sanitary condition:', [
        _filledChoiceText(submission.waterSanitation),
        '( ) Generally clean',
        '( ) Dirty',
      ], leftIndent: 28),
      pw.SizedBox(height: 8),
      _formText('B.    Water Supply:', italic: true),
      _choiceLine('a.', 'Ownership:', [
        '( ) Private',
        '( ) Public',
      ], leftIndent: 28),
      _choiceLine(
        'b.',
        'Water Source:    NOTE: If deep well, proceed to letter "e".',
        [
          'Cooking: ( ) Deep well   ( ) Local Water District   ( ) Commercial   ( ) Others:________',
          'Drinking: ( ) Deep well   ( ) Local Water District   ( ) Commercial   ( ) Others:________',
          'Bathing/CR/Flushing: ( ) Deep well   ( ) Local Water District   ( ) Commercial   ( ) Others:________',
        ],
        leftIndent: 28,
      ),
      _choiceLine('c.', 'Potability (according to key informant):', [
        '( ) Yes',
        '( ) No',
      ], leftIndent: 28),
      _choiceLine('d.', 'Storage:', [
        '( ) None (direct from the faucet or pipe)',
        '( ) Large covered container with faucet',
        '( ) Large uncovered container with faucet',
        '( ) Large covered container without faucet',
        '( ) Large uncovered container without faucet',
        '( ) Others, specify: __________________________',
      ], leftIndent: 28),
      _inlineUnderline(
        'e.    Distance of source of water from the house:',
        '',
        width: 130,
      ),
      pw.SizedBox(height: 8),
      _formText('C.    Food Storage/ Cooking Facilities:', italic: true),
      _choiceLine('a.', 'Food Storage:', [
        '( ) Covered',
        '( ) Uncovered',
      ], leftIndent: 28),
      _choiceLine('b.', 'Storage:', [
        '( ) Refrigerator',
        '( ) Cabinet',
        '( ) Basket',
        '( ) Table',
      ], leftIndent: 28),
      _choiceLine('c.', 'Cooking Facility:', [
        '( ) Electric stove',
        '( ) Gas stove',
        '( ) Firewood/charcoal',
        '( ) Others:_______',
      ], leftIndent: 28),
      _choiceLine('d.', 'Sanitary condition ( base on observation):', [
        '( ) Generally clean',
        '( ) Dirty',
      ], leftIndent: 28),
      pw.SizedBox(height: 8),
      _formText('D.    Waste Disposal:', italic: true),
      _choiceLine('a.', 'Refuse and Garbage', [
        '1. Storage:        ( ) Container        ( ) None',
        '2. Waste Segregation:   ( ) Practiced        ( ) Not Practiced',
        '2.1 If practiced, method of disposal:',
        '     ( ) Hog-feeding        ( ) Open dumping        ( ) Burial in pit',
        '     ( ) Collected          ( ) Composting          ( ) Open burning',
        '2.2 Reason for practicing:',
        '     ( ) Environmentally friendly        ( ) Barangay ordinance which is strictly monitored',
        '     ( ) Use for business                 ( ) Others, specify:________________________',
        '2.3 If not practiced, method of disposal:',
        '     ( ) Hog-feeding        ( ) Open dumping        ( ) Burial in pit',
        '     ( ) Collected          ( ) Composting          ( ) Open burning',
        '2.4 Reason for not practicing',
        '     ( ) Not aware of effects        ( ) No time to do it',
        '     ( ) Long-time practice of family        ( ) No barangay/municipality ordinance',
      ], leftIndent: 28),
      _choiceLine('b.', 'Toilet Facilities:', [
        '1. Ownership:       ( ) Owned        ( ) Shared/Public        ( ) None',
        '2. Type:            ( ) Ballot system        ( ) Pail system        ( ) Overhung latrine',
        '                   ( ) Water- sealed        ( ) Flush type        ( ) None        ( ) Other: __________',
        '3. Location from source of water:   ( ) Less than 20 ft.   ( ) 20 ft. beyond',
        '4. Sanitary condition:              ( ) Generally clean    ( ) Dirty',
      ], leftIndent: 28),
      _choiceLine('c.', 'Drainage System:', [
        'Condition:        ( ) Open drainage        ( ) Blind drainage        ( ) None',
        '                  ( ) Flowing              ( ) Stagnant',
      ], leftIndent: 28),
      pw.SizedBox(height: 6),
      _choiceLine('E.', 'Presence of Animals that are Rabies carriers:', [
        '( ) Yes',
        '( ) No',
      ]),
      pw.SizedBox(height: 4),
      _formText('            a.    If yes, animals raised', italic: true),
      _pdfSmallTable([
        [
          'Kind',
          'Number',
          'Kept Where',
          '',
          'With regular\nvaccination',
          'Without vaccination',
        ],
        ['', '', 'Inside the Yard', 'Free Outside', '', ''],
        ['', '', '', '', '', ''],
      ], fontSize: 6.5),
    ],
  );
}

pw.Widget _surveyPdfPageFour(HealthSubmission submission) {
  return _pdfFormPage(
    pageNumber: '4',
    footerLeft: 'CDX Tool Revised: 01 / 02-16-2024',
    children: [
      _pdfSmallTable(
        [
          ['', '', '', '', '', ''],
        ],
        fontSize: 4.8,
        cellPadding: 1,
      ),
      _choiceLine(
        'b.',
        'Practices measures done to control insects/vectors of diseases:',
        [
          '( ) Fumigation',
          '( ) Insecticides',
          '( ) setting traps',
          '( ) Cleaning the yard',
          '( ) None',
        ],
        leftIndent: 46,
      ),
      _choiceLine('c.', 'Presence of breeding sites (for observation):', [
        '( ) Yes',
        '( ) No',
      ], leftIndent: 46),
      _choiceLine('F.', 'Housing Congestion (for observation):', [
        '( ) Yes',
        '( ) No',
      ]),
      _choiceLine(
        'G.',
        'Presence of Industrial establishment/factory/ies (for observation):',
        ['( ) Yes', '( ) No'],
      ),
      pw.SizedBox(height: 14),
      _formText('III.   HEALTH AND ILLNESS PATTERN', bold: true),
      pw.SizedBox(height: 8),
      _underlinedTitle('1.    LIFESTYLE PRACTICES'),
      _formText(
        'A.                                      Use of Safety Precaution',
      ),
      _pdfSmallTable(
        [
          ['', 'Practice', 'Not Practiced'],
          [
            '1. Use safety devices when necessary e. g. Helmet, safety belts',
            '',
            '',
          ],
        ],
        fontSize: 6.4,
        cellPadding: 1.3,
      ),
      pw.SizedBox(height: 8),
      _choiceLine(
        'B.',
        'Is there a member of the family who is a cigarette smoker?',
        ['( ) Yes', '( ) No', '( ) Frequency/sticks or packs per day'],
        leftIndent: 18,
      ),
      _pdfSmallTable(
        [
          ['Name', 'Age', 'Age started smoking', 'Reason'],
          ..._blankRows(4, 3),
        ],
        fontSize: 6.2,
        cellPadding: 1.2,
      ),
      pw.SizedBox(height: 6),
      _choiceLine('C.', 'Use of prohibited / dangerous drugs:', [
        '( ) Yes',
        '( ) No',
        '( ) Types of Drugs : _______/Solvent',
      ], leftIndent: 18),
      _pdfSmallTable(
        [
          ['Name', 'Age', 'Age started using drugs', 'Reason'],
          ..._blankRows(4, 3),
        ],
        fontSize: 6.2,
        cellPadding: 1.2,
      ),
      pw.SizedBox(height: 6),
      _formText(
        'D.                                      Drinks alcoholic beverages',
      ),
      _pdfSmallTable(
        [
          [
            'Name',
            'Age',
            'Age started drinking alcohol',
            'Frequency',
            'Reason',
          ],
          ..._blankRows(5, 4),
        ],
        fontSize: 6.2,
        cellPadding: 1.2,
      ),
      pw.SizedBox(height: 8),
      _underlinedTitle('2.    NUTRITIONAL STATUS'),
      _formText('A.    Anthropometric Data (5 years below)'),
      _pdfSmallTable(
        [
          [
            'Name',
            'Age in\nmos.',
            'Wt. in\nkg.',
            'Ht. in\nm',
            'BMI\n(Wt. in kg /\nHt. in m2)',
            'Remarks',
            'Waist\nCircumference\n(WC) in cm.',
            'Hips\nCircumference\n(HC) in cm.',
            'Waist / Hips Ratio\n(WC/HC)',
            'Remarks',
            'Mid Upper\nArm Circular',
            'Remarks',
          ],
          ..._anthropometricRows(submission),
        ],
        fontSize: 4.6,
        cellPadding: 1,
      ),
      _formText(
        '      Legend for indices of Nutritional Status: Weight for Age (WFA)',
        size: 6.4,
      ),
      pw.SizedBox(height: 5),
      _formText('B.    Dietary History'),
      _formText('      24- Hour Food Recall'),
      _pdfSmallTable(
        [
          ['Date', 'Time of the day', 'Food taken'],
          ['', 'BREAKFAST', ''],
          ['', 'SNACK', ''],
          ['', 'LUNCH', ''],
          ['', 'SNACK', ''],
          ['', 'DINNER', ''],
          ['', 'MIDNIGHTSNACK', ''],
        ],
        fontSize: 6.2,
        cellPadding: 1.2,
      ),
      _choiceLine('C.', 'Food usually/most taken (General)', [
        'a. First choice: ( ) Meat only   ( ) Fish   ( ) Vegetable   ( ) Mixed   ( ) Others, specify:___',
        'b. Number of servings: ( ) 1   ( ) 2-3   ( ) 4-5 and above',
        'c. Second choice: ( ) Meat   ( ) Fish   ( ) Vegetable   ( ) Mixed   ( ) Others, specify:___',
        'd. Number of servings: ( ) 1   ( ) 2-3   ( ) 4-5 and above',
      ], leftIndent: 18),
      _choiceLine('D.', 'Reason for choices:', [
        '( ) Its healthy',
        '( ) Own preference',
        '( ) Affordable',
        '( ) personal belief/practices',
        '( ) Health condition',
      ], leftIndent: 18),
      _choiceLine('E.', 'Reason for not choosing other options:', [
        '( ) Not healthy',
        '( ) Own preference',
        '( ) Not affordable',
        '( ) personal belief/religious practices',
        '( ) Health condition',
      ], leftIndent: 18),
      _choiceLine(
        'F.',
        'From the above response, how frequent is the intake?',
        [
          '( ) Everyday',
          '( ) Twice a week',
          '( ) Once a week',
          '( ) Others, specify: __________________________',
        ],
        leftIndent: 18,
      ),
      _choiceLine('G.', 'How is food prepared for mealtime?', [
        '( ) Prepared at home',
        '( ) Bought outside',
      ], leftIndent: 18),
      _choiceLine('H.', 'How often?', [
        '( ) Everyday',
        '( ) Twice a week',
        '( ) Once a week',
        '( ) Others, specify:_____________',
      ], leftIndent: 18),
    ],
  );
}

pw.Widget _surveyPdfPageFive(HealthSubmission submission) {
  return _pdfFormPage(
    pageNumber: '5',
    children: [
      _choiceLine('I.', 'If bought outside, is it from the:', [
        '( ) Restaurant/Fast food',
        '( ) Carinderia',
        '( ) Food cart e.g. Fried chicken sa kanto, provent, calamares',
      ], leftIndent: 18),
      _choiceLine('J.', 'Reason for the above option:', [
        '( ) Convenient',
        '( ) Cheaper',
        '( ) Healthy',
        '( ) Variety of choices',
        '( ) Others, specify: _________________________________',
      ], leftIndent: 18),
      _choiceLine(
        'K.',
        'Takes/eat canned/ preserved food e. g. Lucky me noodles, Maling, luncheon meat:',
        [
          '( ) Everyday',
          '( ) Every other day',
          '( ) Every week',
          '( ) Sometimes',
          '( ) Never',
        ],
        leftIndent: 18,
      ),
      _choiceLine('L.', 'Takes/eat grilled foods:', [
        '( ) Everyday',
        '( ) Every other day',
        '( ) Every week',
        '( ) Sometimes',
        '( ) Never',
      ], leftIndent: 18),
      _choiceLine('M.', 'Drinks carbonated beverages:', [
        '( ) Everyday',
        '( ) Every other day',
        '( ) Every week',
        '( ) Sometimes',
        '( ) Never',
      ], leftIndent: 18),
      pw.SizedBox(height: 9),
      _underlinedTitle('3.    BELIEFS AND PRACTICES'),
      _choiceLine(
        'A.',
        'Person/nel mostly consulted in times of sickness/illness:',
        [
          '( ) Doctor',
          '( ) Nurse',
          '( ) Midwife',
          '( ) Hilot',
          '( ) Albularyo',
          '( ) Faith Healer',
          '( ) Elderly',
        ],
        leftIndent: 18,
      ),
      _choiceLine('B.', 'Measures taken in times of sickness/illness:', [
        '( ) Consult a private health worker',
        '( ) See a known community healer',
        '( ) Consult a Rural Health Team',
        '( ) Self- Medication',
        '( ) None',
      ], leftIndent: 18),
      _choiceLine(
        'C.',
        'Medication/ treatment taken in times of sickness/illness:',
        [
          '( ) Prescribed by Doctor',
          '( ) Self-Medication/OTC drugs',
          '( ) Herbals',
          '( ) Others, specify: __________________',
        ],
        leftIndent: 18,
      ),
      _choiceLine(
        'D.',
        'Medical Check-Up whether in private or government institution:',
        ['( ) once a year', '( ) twice a year', '( ) more than a year'],
        leftIndent: 18,
      ),
      _choiceLine(
        'E.',
        'Dental Check-Up whether in private or government clinic:',
        ['( ) once a year', '( ) twice a year', '( ) more than a year'],
        leftIndent: 18,
      ),
      pw.SizedBox(height: 9),
      _underlinedTitle('4.    COMMUNITY HEALTH PROGRAMS'),
      _inlineUnderline(
        'A.    What are the Health Services available in the barangay health center?',
        '',
        width: 160,
      ),
      pw.SizedBox(height: 4),
      _formText('B.    Immunization record'),
      _pdfSmallTable(
        [
          [
            'Name',
            'Age\nin\nmos',
            'Gender',
            'BCG',
            'DPT\n1',
            'DPT\n2',
            'DPT3',
            'Hepa B\n1',
            'Hepa B\n2',
            'Hepa B\n3',
            'OPV\n1',
            'OPV\n2',
            'OPV\n3',
            'Meas\nles',
            'Complete\naccording\nto Age',
            'Incom\nplete\naccord\nto Age',
            'Fully\nImmun\nized\nChild',
          ],
          ..._immunizationTemplateRows(submission),
          ..._blankRows(17, 2),
        ],
        fontSize: 4.4,
        cellPadding: 0.9,
      ),
      pw.SizedBox(height: 8),
      _formText('C.    Ante- natal Registration'),
      _pdfSmallTable(
        [
          [
            'Name',
            'AOG',
            'Pre- Natal Check- Up\nWith\nRegular',
            'Not Regular',
            'Without',
            'Tetanus Vaccination\nWith',
            'Without',
          ],
          ..._blankRows(7, 3),
        ],
        fontSize: 5.6,
        cellPadding: 1.1,
      ),
      pw.SizedBox(height: 6),
      _formText(
        'D.    Family Planning [only for: Women who are 12 yrs. (menarche age) to 40-45 yrs. (until menopause age); with partner(s); or plans to get pregnant.]',
        italicTail:
            '[only for: Women who are 12 yrs. (menarche age) to 40-45 yrs. (until menopause age); with partner(s); or plans to get pregnant.]',
      ),
      _formText(
        '      1.    Family Planning: ( ) Acceptor                         Reason:',
      ),
      _optionRow([
        '( ) Good for health of family',
        '( ) Personal belief',
        '( ) Religious belief',
        '( ) Influence by others',
        '( ) Others, Specify:____________',
      ], leftIndent: 210),
      _formText('                  ( ) Non- Acceptor                  Reason:'),
      _optionRow([
        '( ) Bad for health of family',
        '( ) Personal belief',
        '( ) Religious belief',
        '( ) Influence by others',
        '( ) Others, Specify:____________',
      ], leftIndent: 210),
      pw.SizedBox(height: 5),
      _formText('      2.    Modern Methods Used:'),
      _formText(
        '            ( ) A. Permanent method       Like:   ( ) Female sterilization / Bilateral Tubal Ligation       ( ) Male sterilization / Vasectomy',
      ),
      _formText(
        '            ( ) B. Temporary method:      ( ) a. Supply Methods       Like: ( ) Pills  ( ) IUD  ( ) Injectable  ( ) Condoms  ( ) Implant',
      ),
      _formText(
        '            ( ) b. Fertility Awareness-Based Method        Like: ( ) Cervical Mucus Method / Billings Ovu. Method   ( ) Basal Body Temperature (BBT)',
      ),
      _formText(
        '                                                                 ( ) Sympto-Thermal Method   ( ) Standard Days Method (SDM)   ( ) Lactational Amenorrhea Method (LAM)',
      ),
      pw.SizedBox(height: 8),
      _underlinedTitle('5.    HEALTH INDICATORS'),
      _formText('A.    Morbidity'),
      _pdfSmallTable(
        [
          [
            'Name',
            'Age',
            'Gender',
            'Cause',
            'Intervention\nWith',
            'Without',
            'Admitted',
            'Not Admitted',
          ],
          ..._morbidityTemplateRows(submission),
          ..._blankRows(8, 3),
        ],
        fontSize: 5.7,
        cellPadding: 1.1,
      ),
      pw.SizedBox(height: 6),
      _formText('B.    Mortality (within the past 12 months)'),
      _pdfSmallTable(
        [
          ['Name', 'Age', 'Gender', 'Cause of death'],
        ],
        fontSize: 6.2,
        cellPadding: 1.1,
      ),
    ],
  );
}

pw.Widget _surveyPdfPageSix(HealthSubmission submission) {
  return _pdfFormPage(
    pageNumber: '6',
    footerLeft: 'CDX Tool Revised: 01 / 02-16-2024',
    children: [
      _pdfSmallTable(
        _withBlankRows(_mortalityTemplateRows(submission), 4, 4),
        fontSize: 6,
        cellPadding: 1.1,
      ),
      pw.SizedBox(height: 8),
      _formText(
        'C.    History/ Presence of Non Communicable Disease in the Family',
        underline: true,
      ),
      _pdfSmallTable(
        [
          ['Name', 'Age', 'Gender', 'NCD'],
          ..._withBlankRows(
            _nonCommunicableDiseaseTemplateRows(submission),
            4,
            3,
          ),
        ],
        fontSize: 6.1,
        cellPadding: 1.1,
      ),
      pw.SizedBox(height: 8),
      _formText(
        'D.    History / Presence of Communicable Disease in the Family',
        underline: true,
      ),
      _pdfSmallTable(
        [
          ['Name', 'Age', 'Gender', 'CD'],
          ..._withBlankRows(_communicableDiseaseTemplateRows(submission), 4, 3),
        ],
        fontSize: 6.1,
        cellPadding: 1.1,
      ),
      pw.SizedBox(height: 8),
      _formText('E.    Blood Pressure Record for Ages 35 and above'),
      _pdfSmallTable(
        [
          ['Name', 'Age', 'Gender', 'BP'],
          ..._withBlankRows(_bloodPressureTemplateRows(submission), 4, 3),
        ],
        fontSize: 6.1,
        cellPadding: 1.1,
      ),
      pw.SizedBox(height: 8),
      _choiceLine(
        'F.',
        'Awareness of health services offered by the BHC/ RHU:',
        ['( ) Aware', '( ) Unaware'],
        leftIndent: 18,
      ),
      pw.SizedBox(height: 10),
      _formText(
        'IV.   Health Resource: (Key Informant interview with the Barangay Officials)',
        bold: true,
      ),
      pw.SizedBox(height: 8),
      _formText('1.        Manpower Resources'),
      pw.SizedBox(height: 8),
      _formText(
        'A.    Categories of health manpower available\n'
        'B.    Geographical distribution\n'
        'C.    Number of Physician, Nurse, midwife and other members of RHU team per population\n'
        'D.    Existing manpower development/ policies\n'
        'E.    Schedule of consultation at Barangay Health Center\n'
        '      RHU Physicians:________________________________\n'
        '      RHU Nurse:____________________________________\n'
        '      BHC Midwife:__________________________________',
      ),
      pw.SizedBox(height: 10),
      _formText('2.        Material Resources'),
      pw.SizedBox(height: 8),
      _choiceLine('A.', 'Health and Budget Expenditures:', [
        '( ) Available',
        '( ) Not-Available',
        'Amount per year: Php___________',
      ], leftIndent: 18),
      _choiceLine('B.', 'Availability of supplies and equipment:', [
        '( ) Available100%',
        '( ) Limited Supplies',
        '( ) Not-Available',
      ], leftIndent: 18),
      pw.SizedBox(height: 10),
      _formText('V.   Political/ Leadership Patterns:', bold: true),
      pw.SizedBox(height: 8),
      _choiceLine('1.', 'Recognized Leaders:\nFormal/Elected:\nNon-formal:', [
        '( ) Captain',
        '( ) Kagawad',
        '( ) Elderly',
        '( ) BHW',
        '( ) Influential person',
        '( ) Religious leader',
        '( ) Neighbor',
      ], leftIndent: 18),
      _choiceLine(
        '2.',
        'Conditions/ events/ issues that cause social conflicts/ upheavals within the community',
        [
          '( ) Gossip',
          '( ) Family conflict',
          '( ) Drugs',
          '( ) Riot',
          '( ) Alcohol drinking',
          '( ) Others, specify:___________________',
        ],
        leftIndent: 18,
      ),
      _choiceLine(
        '3.',
        'Practices/ approaches which are effective in setting issues and concern within the community',
        [
          '( ) Settlement among involved parties',
          '( ) Brgy. hearing',
          '( ) Endorsed to local police',
          '( ) Others, specify:___________________',
        ],
        leftIndent: 18,
      ),
      pw.SizedBox(height: 10),
      _formText(
        'VI. Any concerns/suggestions regarding the life style you have in the area in general.',
        bold: true,
      ),
      pw.SizedBox(height: 8),
      _concernLines(submission),
    ],
  );
}

List<List<String>> _anthropometricRows(HealthSubmission submission) {
  final rows = [
    for (final row in _surveyMapRows(
      submission.surveyData['anthropometric_data_under_5'],
    ))
      [
        _surveyRowValue(row, 'name'),
        _surveyRowValue(row, 'age_in_months'),
        _surveyRowValue(row, 'weight_kg'),
        _surveyRowValue(row, 'height_m'),
        _surveyRowValue(row, 'bmi'),
        _surveyRowValue(row, 'bmi_remarks'),
        _surveyRowValue(row, 'waist_circumference_cm'),
        _surveyRowValue(row, 'hip_circumference_cm'),
        _surveyRowValue(row, 'waist_hip_ratio'),
        _surveyRowValue(row, 'waist_hip_ratio_remarks'),
        _surveyRowValue(row, 'mid_upper_arm_circumference'),
        _surveyRowValue(row, 'mid_upper_arm_remarks'),
      ],
  ];

  while (rows.length < 3) {
    rows.add(List.filled(12, ''));
  }
  return rows;
}

List<List<String>> _immunizationTemplateRows(HealthSubmission submission) {
  List<String> row(String name, String age, String status) {
    final lower = status.toLowerCase();
    final incomplete = lower.contains('incomplete');
    final complete = !incomplete && lower.contains('complete');
    return [
      name,
      age,
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      complete ? _pdfCheckMark : '',
      incomplete ? _pdfCheckMark : '',
      complete ? _pdfCheckMark : status,
    ];
  }

  final surveyRows = _surveyMapRows(
    submission.surveyData['immunization_records'],
  );
  if (surveyRows.isNotEmpty) {
    return [
      for (final surveyRow in surveyRows)
        [
          _surveyRowValue(surveyRow, 'name'),
          _surveyRowValue(surveyRow, 'age_in_months', ['age']),
          _surveyRowValue(surveyRow, 'gender'),
          _surveyRowValue(surveyRow, 'bcg'),
          _surveyRowValue(surveyRow, 'dpt_1'),
          _surveyRowValue(surveyRow, 'dpt_2'),
          _surveyRowValue(surveyRow, 'dpt_3'),
          _surveyRowValue(surveyRow, 'hepa_b_1'),
          _surveyRowValue(surveyRow, 'hepa_b_2'),
          _surveyRowValue(surveyRow, 'hepa_b_3'),
          _surveyRowValue(surveyRow, 'opv_1'),
          _surveyRowValue(surveyRow, 'opv_2'),
          _surveyRowValue(surveyRow, 'opv_3'),
          _surveyRowValue(surveyRow, 'measles'),
          _yesNoMark(surveyRow['complete_according_to_age']),
          _yesNoMark(surveyRow['incomplete_according_to_age']),
          _yesNoMark(surveyRow['fully_immunized_child']),
        ],
    ];
  }

  return [
    row(
      submission.respondentName,
      submission.respondentAge?.toString() ?? '',
      submission.vaccinationStatus,
    ),
    for (final member in submission.familyMembers)
      row(member.name, member.age?.toString() ?? '', member.vaccinationStatus),
  ];
}

List<List<String>> _morbidityTemplateRows(HealthSubmission submission) {
  final surveyRows = _surveyMapRows(submission.surveyData['morbidity_records']);
  if (surveyRows.isNotEmpty) {
    return [
      for (final row in surveyRows)
        [
          _surveyRowValue(row, 'name'),
          _surveyRowValue(row, 'age'),
          _surveyRowValue(row, 'gender'),
          _surveyRowValue(row, 'cause'),
          _yesNoMark(row['intervention_with']),
          _yesNoMark(row['intervention_without']),
          _yesNoMark(row['admitted']),
          _yesNoMark(row['not_admitted']),
        ],
    ];
  }

  final rows = <List<String>>[];
  if (submission.healthProblems.isNotEmpty) {
    rows.add([
      submission.respondentName,
      submission.respondentAge?.toString() ?? '',
      '',
      _listOrBlank(submission.healthProblems),
      _pdfCheckMark,
      '',
      '',
      '',
    ]);
  }
  for (final member in submission.familyMembers) {
    if (member.healthProblems.isEmpty) {
      continue;
    }
    rows.add([
      member.name,
      member.age?.toString() ?? '',
      '',
      _listOrBlank(member.healthProblems),
      _pdfCheckMark,
      '',
      '',
      '',
    ]);
  }
  return rows;
}

List<List<String>> _mortalityTemplateRows(HealthSubmission submission) => [
  for (final row in _surveyMapRows(submission.surveyData['mortality_records']))
    [
      _surveyRowValue(row, 'name'),
      _surveyRowValue(row, 'age'),
      _surveyRowValue(row, 'gender'),
      _surveyRowValue(row, 'cause_of_death'),
    ],
];

List<List<String>> _nonCommunicableDiseaseTemplateRows(
  HealthSubmission submission,
) => [
  for (final row in _surveyMapRows(
    submission.surveyData['non_communicable_disease_records'],
  ))
    [
      _surveyRowValue(row, 'name'),
      _surveyRowValue(row, 'age'),
      _surveyRowValue(row, 'gender'),
      _surveyRowValue(row, 'ncd'),
    ],
];

List<List<String>> _communicableDiseaseTemplateRows(
  HealthSubmission submission,
) => [
  for (final row in _surveyMapRows(
    submission.surveyData['communicable_disease_records'],
  ))
    [
      _surveyRowValue(row, 'name'),
      _surveyRowValue(row, 'age'),
      _surveyRowValue(row, 'gender'),
      _surveyRowValue(row, 'cd'),
    ],
];

List<List<String>> _bloodPressureTemplateRows(HealthSubmission submission) {
  final surveyRows = _surveyMapRows(
    submission.surveyData['blood_pressure_records'],
  );
  if (surveyRows.isNotEmpty) {
    return [
      for (final row in surveyRows)
        [
          _surveyRowValue(row, 'name'),
          _surveyRowValue(row, 'age'),
          _surveyRowValue(row, 'gender'),
          _surveyRowValue(row, 'bp'),
        ],
    ];
  }

  final rows = <List<String>>[];

  void addRow(String name, int? age) {
    if (age == null || age < 35) {
      return;
    }
    rows.add([name, age.toString(), '', '']);
  }

  addRow(submission.respondentName, submission.respondentAge);
  for (final member in submission.familyMembers) {
    addRow(member.name, member.age);
  }

  return rows;
}

String _yesNoMark(Object? value) {
  if (value is bool) {
    return value ? _pdfCheckMark : '';
  }
  final normalized = '$value'.trim().toLowerCase();
  return normalized == 'yes' ||
          normalized == 'true' ||
          normalized == 'x' ||
          normalized == '1'
      ? _pdfCheckMark
      : '';
}

List<List<String>> _blankRows(int columns, int count) {
  return List.generate(count, (_) => List.filled(columns, ''));
}

List<List<String>> _withBlankRows(
  List<List<String>> rows,
  int columns,
  int minimumRows,
) {
  final blankCount = rows.length >= minimumRows ? 0 : minimumRows - rows.length;
  return [...rows, ..._blankRows(columns, blankCount)];
}

pw.Widget _concernLines(HealthSubmission submission) {
  final text = [
    _listOrBlank(submission.communityConcerns),
    submission.notes,
  ].where((value) => value.trim().isNotEmpty).join(' ');
  final lines = <String>[];
  if (text.isNotEmpty) {
    lines.add(text);
  }
  while (lines.length < 5) {
    lines.add('');
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final line in lines.take(5))
        pw.Container(
          width: 310,
          height: 12,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 0.45)),
          ),
          alignment: pw.Alignment.bottomLeft,
          child: _formText(line, size: 6.6),
        ),
    ],
  );
}

pw.Widget _pdfFormPage({
  required List<pw.Widget> children,
  required String pageNumber,
  String footerLeft = '',
}) {
  return pw.Stack(
    children: [
      pw.Positioned.fill(
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
      pw.Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _formText(
              footerLeft,
              size: 6.8,
              color: PdfColors.grey700,
              italic: true,
            ),
            _formText(pageNumber, size: 9),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _pdfTemplateHeader(
  pw.ImageProvider universityLogo,
  pw.ImageProvider collegeLogo,
) {
  return pw.Center(
    child: pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Image(universityLogo, width: 44, height: 44),
            pw.SizedBox(width: 18),
            pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                _formText('BULACAN STATE UNIVERSITY', size: 10.5, bold: true),
                _formText('Alliance Expertise Team', size: 8.5),
                _formText('COLLEGE OF NURSING', size: 9.2, bold: true),
                _formText('City of Malolos', size: 8.5),
              ],
            ),
            pw.SizedBox(width: 18),
            pw.Image(collegeLogo, width: 44, height: 44),
          ],
        ),
        pw.SizedBox(height: 9),
        _formText('COMMUNITY SURVEY TOOL', size: 11, bold: true),
        _formText('(NEED ASSESSMENT)', size: 9.5, bold: true),
      ],
    ),
  );
}

pw.Widget _pdfVisitLines(HealthSubmission submission) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 205,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _inlineUnderline('Control No.', '', width: 120),
            _inlineUnderline('Address:', submission.address, width: 145),
            _inlineUnderline(
              'Informant:',
              submission.respondentName,
              width: 140,
            ),
            _inlineUnderline('Surveyed by:', '', width: 132),
            pw.Row(
              children: [
                _inlineUnderline('Time Started:', '', width: 46),
                pw.SizedBox(width: 6),
                _inlineUnderline('Time Finished:', '', width: 44),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(
        width: 195,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _inlineUnderline(
              'Number of Family:',
              '${submission.familyMembersCount}',
              width: 78,
            ),
            _inlineUnderline(
              'Date:     1st visit',
              _dateOnly(submission.createdAt),
              width: 76,
            ),
            _inlineUnderline('          2nd visit', '', width: 84),
            _inlineUnderline('          3rd visit', '', width: 84),
            _inlineUnderline(
              'Status of last visit:',
              submission.syncStatus.name,
              width: 75,
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _pdfDemographicGrid(HealthSubmission submission) {
  final rows = _demographicRows(submission);
  while (rows.length < 12) {
    rows.add(List.filled(17, ''));
  }

  final widths = <int, pw.TableColumnWidth>{
    0: const pw.FixedColumnWidth(14),
    1: const pw.FixedColumnWidth(105),
    2: const pw.FixedColumnWidth(45),
    3: const pw.FixedColumnWidth(18),
    4: const pw.FixedColumnWidth(18),
    5: const pw.FixedColumnWidth(18),
    6: const pw.FixedColumnWidth(18),
    7: const pw.FixedColumnWidth(18),
    8: const pw.FixedColumnWidth(24),
    9: const pw.FixedColumnWidth(24),
    10: const pw.FixedColumnWidth(65),
    11: const pw.FixedColumnWidth(22),
    12: const pw.FixedColumnWidth(26),
    13: const pw.FixedColumnWidth(26),
    14: const pw.FixedColumnWidth(28),
    15: const pw.FixedColumnWidth(28),
    16: const pw.FixedColumnWidth(28),
  };

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.black, width: 0.55),
    columnWidths: widths,
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      pw.TableRow(
        children: [
          _demoHeader('#'),
          _demoHeader('NAME OF FAMILY MEMBER'),
          _demoHeader(
            'RELATION\n-SHIP TO\nTHE HEAD\nOF THE\nFAMILY',
            size: 4.2,
          ),
          _demoVerticalHeader('GENDER'),
          _demoVerticalHeader('AGE'),
          _demoHeader('BIRTHDATE\n\nM', size: 5.2),
          _demoHeader('\n\nD', size: 5.2),
          _demoHeader('\n\nY', size: 5.2),
          _demoVerticalHeader('MARITAL STATUS'),
          _demoVerticalHeader('RELIGION'),
          _demoHeader(
            'HIGHEST\nEDUCATIONAL\nCOMPLETED\n(3 YEARS OLD\nAND ABOVE)',
            size: 4.4,
          ),
          _demoVerticalHeader('STATUS'),
          _demoVerticalHeader('If EMPLOYED'),
          _demoVerticalHeader('LOCATION'),
          _demoVerticalHeader('CATEGORY'),
          _demoVerticalHeader('PLACE OF ORIGIN'),
          _demoVerticalHeader('LENGTH OF RESIDENCE'),
        ],
      ),
      for (final row in rows)
        pw.TableRow(
          children: [
            for (final cell in row)
              pw.Container(
                height: 11.8,
                alignment: pw.Alignment.centerLeft,
                padding: const pw.EdgeInsets.symmetric(horizontal: 1.2),
                child: _formText(cell, size: 5.8),
              ),
          ],
        ),
    ],
  );
}

pw.Widget _demoHeader(String text, {double size = 5}) {
  return pw.Container(
    height: 122,
    alignment: pw.Alignment.center,
    padding: const pw.EdgeInsets.all(1.2),
    child: _formText(text, size: size, bold: true, align: pw.TextAlign.center),
  );
}

pw.Widget _demoVerticalHeader(String text) {
  return pw.Container(
    height: 122,
    alignment: pw.Alignment.center,
    padding: const pw.EdgeInsets.all(1),
    child: _formText(
      text.replaceAll(' ', '\n').split('').join('\n'),
      size: 4.8,
      align: pw.TextAlign.center,
    ),
  );
}

pw.Widget _pdfLegend() {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _legendColumn('LEGEND:\nGender:\n1- Male\n2- Female', width: 86),
      _legendColumn(
        'Marital Status:\n1- Child\n2- Single\n3- Married\n4- Married but Separated\n5- Widow\n6- Widower',
        width: 140,
      ),
      _legendColumn(
        'Religion:\n1- Roman Catholic\n2- Muslim\n3- Iglesia ni Cristo\n4- Born Again Christian\n5- Jehova\'s Witness\n6-Protestant (Methodist;\n   Evangelical; Baptist; Adventist)\n7-others: ___________________',
        width: 170,
      ),
      _legendColumn(
        'Education:\n1- Pre- elem.                 8- College Level\n2- Elem. Level                9- College Grad.\n3- Elem. Grad.               10- Post- Grad.\n4- High School Level         11- Over 7 years\n5- High School Grad              old w/o formal\n6- Vocational                    schooling\n7- Short Course              12- <5 yeas old\n                              13- SPED',
        width: 155,
      ),
    ],
  );
}

pw.Widget _pdfWorkLegend() {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _formText('TYPE OF WORK:', bold: true),
      pw.SizedBox(height: 6),
      _formText('STATUS:', bold: true),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _legendColumn(
            '1 - Employed\n   1- Regular Full-time\n   2- Regular Part- time\n   3- Contractual 6 months\n   4- Contractual every week\n   5- Contractual everyday\n   6- Self- Employed\n   7- Seasonal\n   8- OFW\n   9- Contractual by job offer',
            width: 160,
          ),
          _legendColumn(
            'Place of Work:\nLocation:\n1- with in the community\n2- with in the municipality/city\n3- outside the municipality/city\n4- OFW- outside the country',
            width: 170,
          ),
          _legendColumn(
            'Category:\n1- In-House\n2- Field\n3- Office',
            width: 120,
          ),
          _legendColumn(
            'Place of Origin:\n1- Metro Manila\n2- Central Luzon\n3- Northern Luzon\n4- Southern Luzon\n5- Visayas Region\n6- Mindanao Region',
            width: 120,
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      _formText(
        '2 – Unemployed (and other conditions such as: Senior, PWD, Retired and/or with Health condition)',
        size: 6.6,
      ),
      _formText('3 – Minor (below majority of age 18y.o.)', size: 6.6),
    ],
  );
}

pw.Widget _legendColumn(String text, {required double width}) {
  return pw.SizedBox(width: width, child: _formText(text, size: 6.4));
}

pw.Widget _incomeEarnersBlock() {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(left: 28, top: 2, bottom: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 190,
          child: _formText('A.    How many Income earners per family(ies)?'),
        ),
        pw.SizedBox(
          width: 130,
          child: _formText('Earner 1:\nEarner 2:\nEarner 3:\nEarner 4:'),
        ),
        pw.SizedBox(
          width: 130,
          child: _formText(
            'Family position:____________\nFamily position:____________\nFamily position:____________\nFamily position:____________',
          ),
        ),
        pw.SizedBox(
          width: 90,
          child: _formText(
            'Php __________\nPhp __________\nPhp __________\nPhp __________',
          ),
        ),
      ],
    ),
  );
}

pw.Widget _choiceLine(
  String marker,
  String label,
  List<String> choices, {
  double leftIndent = 16,
}) {
  final text = choices.join('        ');
  return pw.Padding(
    padding: pw.EdgeInsets.only(left: leftIndent, top: 1.5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 18, child: _formText(marker)),
        pw.SizedBox(width: 150, child: _formText(label)),
        pw.Expanded(child: _formText(text)),
      ],
    ),
  );
}

pw.Widget _optionRow(List<String> options, {double leftIndent = 0}) {
  return pw.Padding(
    padding: pw.EdgeInsets.only(left: leftIndent, top: 1.5),
    child: pw.Row(
      children: [
        for (final option in options)
          pw.Expanded(child: _formText(option, size: 6.8)),
      ],
    ),
  );
}

pw.Widget _underlinedTitle(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(left: 14, bottom: 3),
    child: _formText(text, underline: true),
  );
}

pw.Widget _inlineUnderline(
  String label,
  String value, {
  required double width,
}) {
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      _formText(label, size: 7),
      pw.Container(
        width: width,
        padding: const pw.EdgeInsets.only(left: 2, bottom: 0.5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 0.45)),
        ),
        child: _formText(value, size: 7),
      ),
    ],
  );
}

String _filledChoiceText(String value) {
  final cleaned = _valueOrBlank(value);
  return cleaned.isEmpty ? '' : cleaned;
}

pw.Widget _pdfSmallTable(
  List<List<String>> rows, {
  int headerRows = 0,
  double fontSize = 7,
  double cellPadding = 2.5,
}) {
  final columnCount = rows.fold<int>(
    0,
    (largest, row) => row.length > largest ? row.length : largest,
  );
  final normalizedRows = [
    for (final row in rows)
      [...row, ...List.filled(columnCount - row.length, '')],
  ];

  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.35),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: {
        for (var index = 0; index < columnCount; index++)
          index: const pw.FlexColumnWidth(),
      },
      children: [
        for (var rowIndex = 0; rowIndex < normalizedRows.length; rowIndex++)
          pw.TableRow(
            children: [
              for (final cell in normalizedRows[rowIndex])
                pw.Padding(
                  padding: pw.EdgeInsets.all(cellPadding),
                  child: pw.Text(
                    _valueOrBlank(cell),
                    style: pw.TextStyle(
                      fontSize: fontSize,
                      fontWeight: rowIndex < headerRows
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}

pw.Widget _formText(
  String text, {
  double size = 7,
  bool bold = false,
  bool italic = false,
  bool underline = false,
  PdfColor color = PdfColors.black,
  pw.TextAlign align = pw.TextAlign.left,
  String? italicTail,
}) {
  final style = pw.TextStyle(
    fontSize: size,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
    decoration: underline ? pw.TextDecoration.underline : null,
    color: color,
  );

  if (italicTail == null || !text.contains(italicTail)) {
    return pw.Text(text, style: style, textAlign: align);
  }

  final before = text.replaceFirst(italicTail, '').trimRight();
  return pw.RichText(
    textAlign: align,
    text: pw.TextSpan(
      children: [
        pw.TextSpan(text: before, style: style),
        pw.TextSpan(
          text: ' $italicTail',
          style: style.copyWith(fontStyle: pw.FontStyle.italic),
        ),
      ],
    ),
  );
}
