import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../core/utils.dart';

/// التقاط صورة الدواء من الكاميرا أو المعرض وضغطها لتناسب التخزين في Firestore.
class ImageService {
  ImageService._();

  static final ImagePicker _picker = ImagePicker();

  /// الحد الأقصى لحجم الصورة بعد الضغط (قبل تحويلها إلى Base64).
  static const maxBytes = 650 * 1024;

  /// تُعيد بايتات صورة JPEG مضغوطة، أو null إذا ألغى المستخدم.
  static Future<Uint8List?> pick(ImageSource source) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 60,
        requestFullMetadata: false,
      );
    } catch (_) {
      throw const AppException(
        'تعذر فتح الكاميرا أو المعرض، تأكد من منح التطبيق الصلاحية',
      );
    }
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw const AppException(
        'الصورة كبيرة جداً، حاول تصوير الدواء مجدداً بإضاءة أقل تعقيداً',
      );
    }
    return bytes;
  }
}
