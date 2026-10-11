/// Validation for the contact details people enter in the delivery profile.
abstract final class ContactRules {
  static const maxNameLength = 120;
  static const maxAreaLength = 120;
  static const maxDescriptionLength = 300;

  static const _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';
  static const _easternArabicDigits = '۰۱۲۳۴۵۶۷۸۹';

  static final RegExp _separators = RegExp(r'[\s\-().]');
  static final RegExp _localMobile = RegExp(r'^7[0-9]{8}$');

  /// Converts Arabic-Indic digits to ASCII digits so numbers typed with an
  /// Arabic keyboard validate the same way.
  static String toAsciiDigits(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final arabicIndex = _arabicIndicDigits.indexOf(char);
      if (arabicIndex >= 0) {
        buffer.write(arabicIndex);
        continue;
      }
      final easternIndex = _easternArabicDigits.indexOf(char);
      if (easternIndex >= 0) {
        buffer.write(easternIndex);
        continue;
      }
      buffer.write(char);
    }
    return buffer.toString();
  }

  /// Returns the 9-digit local Yemen mobile number (starting with 7), or null
  /// when [input] is not a valid Yemen mobile number. Accepts the optional
  /// prefixes +967, 00967 and 0.
  static String? normalizeYemenMobile(String? input) {
    if (input == null) return null;
    var value = toAsciiDigits(input).replaceAll(_separators, '');
    if (value.isEmpty) return null;
    if (value.startsWith('+967')) {
      value = value.substring(4);
    } else if (value.startsWith('00967')) {
      value = value.substring(5);
    } else if (value.startsWith('0')) {
      value = value.substring(1);
    }
    return _localMobile.hasMatch(value) ? value : null;
  }

  static String? validatePhone(String? input) {
    if (input == null || input.trim().isEmpty) return 'أدخل رقم الهاتف';
    if (normalizeYemenMobile(input) == null) {
      return 'أدخل رقم جوال يمني صحيحًا من 9 أرقام يبدأ بـ 7';
    }
    return null;
  }

  static String? validateFullName(String? input) {
    final value = (input ?? '').trim();
    if (value.isEmpty) return 'أدخل الاسم';
    if (value.length < 2) return 'الاسم قصير جدًا';
    if (value.length > maxNameLength) {
      return 'الاسم أطول من المسموح ($maxNameLength حرفًا)';
    }
    return null;
  }

  static String? validateArea(String? input) {
    final value = (input ?? '').trim();
    if (value.isEmpty) return 'أدخل الحي أو المنطقة';
    if (value.length > maxAreaLength) return 'النص أطول من المسموح';
    return null;
  }

  /// The address description is required only when no GPS position was
  /// captured, so the courier still has enough detail to find the place.
  static String? validateDescription(String? input, {required bool hasPosition}) {
    final value = (input ?? '').trim();
    if (value.length > maxDescriptionLength) return 'الوصف أطول من المسموح';
    if (!hasPosition && value.length < 5) {
      return 'اكتب وصفًا واضحًا للعنوان أو حدّد موقعك الحالي';
    }
    return null;
  }
}
