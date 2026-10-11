/// A donation's photos as loaded for a reviewer: how many exist on the
/// server and the short-lived signed URLs that could be prepared.
class DonationPhotoSet {
  const DonationPhotoSet({required this.total, required this.urls});

  /// Photos attached to the donation on the server.
  final int total;

  /// Signed URLs, one per photo that could be signed.
  final List<String> urls;

  /// The donation really has no photos.
  bool get isEmpty => total == 0;

  /// Photos exist but none could be signed: a loading problem, not "no
  /// photos".
  bool get signingFailed => total > 0 && urls.isEmpty;

  /// Photos that exist but could not be signed.
  int get missing => total > urls.length ? total - urls.length : 0;
}

/// Rules for donation photos. They mirror the storage bucket limits
/// (`donation-images`: 5 MB, JPEG/PNG/WebP) so that a photo is rejected with
/// a clear message on the phone instead of failing during upload.
class DonationImageRules {
  const DonationImageRules._();

  static const int maxImages = 4;
  static const int maxBytes = 5 * 1024 * 1024;

  static const Map<String, String> _contentTypes = <String, String>{
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static const String unsupportedTypeMessage =
      'نوع الصورة غير مدعوم. استخدم صورة JPG أو PNG أو WebP.';
  static const String tooLargeMessage =
      'حجم الصورة أكبر من 5 ميجابايت. اختر صورة أصغر.';
  static const String emptyFileMessage = 'ملف الصورة فارغ. اختر صورة أخرى.';
  static const String tooManyMessage = 'يمكن إضافة 4 صور كحد أقصى.';

  /// Lower-case extension of [fileName] without the dot, or an empty string.
  static String extensionOf(String fileName) {
    final name = fileName.trim();
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  static String _normalizeMime(String? mimeType) {
    final value = (mimeType ?? '').trim().toLowerCase();
    return value == 'image/jpg' ? 'image/jpeg' : value;
  }

  /// The content type to upload with, or null when the file is not an
  /// accepted image. A known extension wins; otherwise a known mime type
  /// reported by the picker is used.
  static String? contentTypeFor({required String fileName, String? mimeType}) {
    final byExtension = _contentTypes[extensionOf(fileName)];
    if (byExtension != null) return byExtension;
    final mime = _normalizeMime(mimeType);
    return _contentTypes.containsValue(mime) ? mime : null;
  }

  /// File extension to store for an accepted [contentType].
  static String extensionForContentType(String contentType) {
    switch (contentType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        return 'jpg';
    }
  }

  /// Arabic reason the image cannot be uploaded, or null when it is valid.
  ///
  /// A file is rejected when its extension or its reported mime type names
  /// something other than JPEG, PNG or WebP, when it is empty, or when it is
  /// larger than the bucket limit.
  static String? validate({
    required String fileName,
    required int sizeBytes,
    String? mimeType,
  }) {
    final extension = extensionOf(fileName);
    final mime = _normalizeMime(mimeType);
    if (extension.isNotEmpty && !_contentTypes.containsKey(extension)) {
      return unsupportedTypeMessage;
    }
    if (mime.isNotEmpty && !_contentTypes.containsValue(mime)) {
      return unsupportedTypeMessage;
    }
    if (contentTypeFor(fileName: fileName, mimeType: mimeType) == null) {
      return unsupportedTypeMessage;
    }
    if (sizeBytes <= 0) return emptyFileMessage;
    if (sizeBytes > maxBytes) return tooLargeMessage;
    return null;
  }

  /// One photo that takes longer than this counts as a failed photo, so a
  /// stalled connection never keeps the person waiting.
  static const Duration uploadTimeout = Duration(seconds: 60);

  /// Title of the confirmation shown before leaving the result view, or null
  /// when the person can leave straight away.
  static String? leaveWarningTitle({required bool uploading, required int pending}) {
    if (uploading) return 'الصور ما زالت تُرفع';
    if (pending > 0) return 'لم تُرفع كل الصور';
    return null;
  }

  /// Body of the confirmation shown before leaving the result view, or null
  /// when nothing is uploading and no photo is waiting for a retry.
  static String? leaveWarningMessage({required bool uploading, required int pending}) {
    if (uploading) {
      return 'تبرعك مسجّل. إذا غادرت الآن يستمر رفع الصور ما دام التطبيق مفتوحًا، '
          'وقد لا تكتمل بعض الصور.';
    }
    if (pending > 0) {
      return pending == 1
          ? 'تبرعك مسجّل، لكن صورة واحدة لم تُرفع. إذا غادرت الآن سيبقى التبرع بدونها.'
          : 'تبرعك مسجّل، لكن $pending صور لم تُرفع. إذا غادرت الآن سيبقى التبرع بدونها.';
    }
    return null;
  }

  /// How many more photos may be added when [existing] are already attached.
  static int remainingSlots(int existing) {
    final left = maxImages - existing;
    return left < 0 ? 0 : left;
  }
}
