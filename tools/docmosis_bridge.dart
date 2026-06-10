// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _templatePath = 'docmosis_tagged_template.docx';
const _docmosisJarPath = 'tools/docmosis/docmosisJava4.9.0/java-4.9.0.jar';
const _rendererSourcePath = 'tools/docmosis/DocmosisRenderer.java';
const _rendererClassDirPath = 'tools/docmosis/build/classes';
const _rendererClassPath =
    'tools/docmosis/build/classes/DocmosisRenderer.class';
const _javaHomePath = r'E:\Tools\Java\Temurin21';
const _javaBinPath = r'E:\Tools\Java\Temurin21\bin';
const _libreOfficeProgramPath = r'E:\Tools\LibreOffice\program';

Future<void> main() async {
  final port =
      int.tryParse(Platform.environment['DOCMOSIS_BRIDGE_PORT'] ?? '') ?? 8787;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('Docmosis bridge listening on http://127.0.0.1:$port/render');
  print('Template: ${File(_templatePath).absolute.path}');

  await for (final request in server) {
    await _handleRequest(request);
  }
}

Future<void> _handleRequest(HttpRequest request) async {
  _addCorsHeaders(request.response);

  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }

  if (request.method != 'POST' || request.uri.path != '/render') {
    await _sendText(request.response, HttpStatus.notFound, 'Not found.');
    return;
  }

  try {
    await _ensureRendererCompiled();

    final body = await utf8.decoder.bind(request).join();
    final payload = jsonDecode(body);
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object.');
    }

    final fields = payload['fields'];
    if (fields is! Map<String, dynamic>) {
      throw const FormatException('Expected fields to be a JSON object.');
    }

    final fileName = _safeFileName(
      '${payload['fileName'] ?? 'docmosis-output.docx'}',
    );
    final outputBytes = await _render(fields);

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType(
      'application',
      'vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    request.response.headers.set(
      'content-disposition',
      'attachment; filename="$fileName"',
    );
    request.response.add(outputBytes);
    await request.response.close();
  } catch (error, stackTrace) {
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    await _sendText(
      request.response,
      HttpStatus.internalServerError,
      'Docmosis render failed: $error',
    );
  }
}

Future<List<int>> _render(Map<String, dynamic> fields) async {
  final template = File(_templatePath);
  final jar = File(_docmosisJarPath);
  final classDir = Directory(_rendererClassDirPath);

  if (!template.existsSync()) {
    throw StateError('Template not found at ${template.absolute.path}.');
  }
  if (!jar.existsSync()) {
    throw StateError('Docmosis JAR not found at ${jar.absolute.path}.');
  }

  final tempDir = await Directory.systemTemp.createTemp('kasudlo-docmosis-');
  try {
    final dataFile = File(_join(tempDir.path, 'data.json'));
    final outputFile = File(_join(tempDir.path, 'output.docx'));
    await dataFile.writeAsString(jsonEncode(fields), encoding: utf8);

    final result = await Process.run(
      _toolPath('java'),
      [
        '-cp',
        [
          classDir.absolute.path,
          jar.absolute.path,
        ].join(_javaClassPathSeparator),
        'DocmosisRenderer',
        template.path,
        outputFile.path,
        dataFile.path,
      ],
      environment: _toolEnvironment(),
      workingDirectory: Directory.current.path,
    );

    if (result.exitCode != 0) {
      throw StateError(
        'java exited with ${result.exitCode}\n${result.stdout}\n${result.stderr}',
      );
    }
    if (!outputFile.existsSync()) {
      throw StateError('Docmosis completed without writing output.docx.');
    }

    return outputFile.readAsBytesSync();
  } finally {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}

Future<void> _ensureRendererCompiled() async {
  final source = File(_rendererSourcePath);
  final jar = File(_docmosisJarPath);
  final classDir = Directory(_rendererClassDirPath);
  final classFile = File(_rendererClassPath);

  if (!source.existsSync()) {
    throw StateError(
      'Docmosis renderer source not found at ${source.absolute.path}.',
    );
  }
  if (!jar.existsSync()) {
    throw StateError('Docmosis JAR not found at ${jar.absolute.path}.');
  }

  if (classFile.existsSync()) {
    final classUpdated = classFile.lastModifiedSync();
    final sourceUpdated = source.lastModifiedSync();
    if (!sourceUpdated.isAfter(classUpdated)) {
      return;
    }
  }

  if (!classDir.existsSync()) {
    classDir.createSync(recursive: true);
  }

  final result = await Process.run(
    _toolPath('javac'),
    ['-cp', jar.path, '-d', classDir.path, source.path],
    environment: _toolEnvironment(),
    workingDirectory: Directory.current.path,
  );

  if (result.exitCode != 0) {
    throw StateError(
      'javac exited with ${result.exitCode}\n${result.stdout}\n${result.stderr}',
    );
  }
}

Future<void> _sendText(
  HttpResponse response,
  int statusCode,
  String text,
) async {
  if (response.headers.value(HttpHeaders.accessControlAllowOriginHeader) ==
      null) {
    _addCorsHeaders(response);
  }
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.text;
  response.write(text);
  await response.close();
}

void _addCorsHeaders(HttpResponse response) {
  response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
  response.headers.set(
    HttpHeaders.accessControlAllowMethodsHeader,
    'POST, OPTIONS',
  );
  response.headers.set(
    HttpHeaders.accessControlAllowHeadersHeader,
    'content-type',
  );
}

String _safeFileName(String value) {
  final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-').trim();
  return cleaned.isEmpty ? 'docmosis-output.docx' : cleaned;
}

String _join(String first, String second) =>
    '$first${Platform.pathSeparator}$second';

String get _javaClassPathSeparator => Platform.isWindows ? ';' : ':';

String _toolPath(String name) {
  final extension = Platform.isWindows ? '.exe' : '';
  if (name == 'java' || name == 'javac') {
    return _join(_javaBinPath, '$name$extension');
  }
  return name;
}

Map<String, String> _toolEnvironment() {
  final path = [
    _javaBinPath,
    _libreOfficeProgramPath,
    Platform.environment['PATH'] ?? Platform.environment['Path'] ?? '',
  ].where((part) => part.trim().isNotEmpty).join(';');

  return {
    ...Platform.environment,
    'JAVA_HOME': _javaHomePath,
    'PATH': path,
    'Path': path,
  };
}
