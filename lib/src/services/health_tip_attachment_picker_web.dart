// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'health_tip_attachment.dart';

const supportsDirectAttachmentPicker = true;
const supportsAttachmentPathImport = false;

Future<PickedHealthTipAttachment?> pickHealthTipAttachment() async {
  final completer = Completer<PickedHealthTipAttachment?>();
  final input = html.FileUploadInputElement()
    ..style.display = 'none'
    ..multiple = false;
  html.document.body?.append(input);

  late final StreamSubscription<html.Event> subscription;
  subscription = input.onChange.listen((event) async {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return;
    }

    try {
      final bytes = await _readFileBytes(file);
      if (!completer.isCompleted) {
        completer.complete(
          PickedHealthTipAttachment(
            fileName: file.name,
            mimeType: file.type.isNotEmpty
                ? file.type
                : guessAttachmentMimeType(file.name),
            bytes: bytes,
          ),
        );
      }
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
  });

  input.click();

  try {
    return await completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => null,
    );
  } finally {
    await subscription.cancel();
    input.remove();
  }
}

Future<PickedHealthTipAttachment?> readHealthTipAttachmentFromPath(
  String filePath,
) async {
  return null;
}

Future<Uint8List> _readFileBytes(html.File file) {
  final completer = Completer<Uint8List>();
  final reader = html.FileReader();

  reader.onLoad.listen((event) {
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(Uint8List.view(result));
      return;
    }
    if (result is Uint8List) {
      completer.complete(result);
      return;
    }
    completer.completeError(StateError('Unable to read selected file.'));
  });
  reader.onError.listen((event) {
    completer.completeError(StateError('Unable to read selected file.'));
  });
  reader.readAsArrayBuffer(file);

  return completer.future;
}
