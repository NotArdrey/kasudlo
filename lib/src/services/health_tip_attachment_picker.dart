import 'health_tip_attachment.dart';
import 'health_tip_attachment_picker_stub.dart'
    if (dart.library.html) 'health_tip_attachment_picker_web.dart'
    if (dart.library.io) 'health_tip_attachment_picker_io.dart'
    as impl;

export 'health_tip_attachment.dart';

bool get supportsDirectAttachmentPicker => impl.supportsDirectAttachmentPicker;

bool get supportsAttachmentPathImport => impl.supportsAttachmentPathImport;

Future<PickedHealthTipAttachment?> pickHealthTipAttachment() {
  return impl.pickHealthTipAttachment();
}

Future<PickedHealthTipAttachment?> readHealthTipAttachmentFromPath(
  String filePath,
) {
  return impl.readHealthTipAttachmentFromPath(filePath);
}
