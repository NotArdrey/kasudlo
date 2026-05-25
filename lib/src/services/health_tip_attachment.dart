import 'dart:typed_data';

class PickedHealthTipAttachment {
  const PickedHealthTipAttachment({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;
}

String guessAttachmentMimeType(String fileName) {
  final normalized = fileName.toLowerCase();
  if (normalized.endsWith('.png')) {
    return 'image/png';
  }
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (normalized.endsWith('.gif')) {
    return 'image/gif';
  }
  if (normalized.endsWith('.webp')) {
    return 'image/webp';
  }
  if (normalized.endsWith('.pdf')) {
    return 'application/pdf';
  }
  if (normalized.endsWith('.doc')) {
    return 'application/msword';
  }
  if (normalized.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (normalized.endsWith('.xls')) {
    return 'application/vnd.ms-excel';
  }
  if (normalized.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (normalized.endsWith('.ppt')) {
    return 'application/vnd.ms-powerpoint';
  }
  if (normalized.endsWith('.pptx')) {
    return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
  }
  if (normalized.endsWith('.txt')) {
    return 'text/plain';
  }
  if (normalized.endsWith('.csv')) {
    return 'text/csv';
  }
  return 'application/octet-stream';
}
