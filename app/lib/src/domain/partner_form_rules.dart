/// Validation rules for the partner registration form. Pure Dart so they can
/// be tested without widgets.
class PartnerFormRules {
  const PartnerFormRules._();

  static const int nameMin = 3;
  static const int nameMax = 120;
  static const int descriptionMax = 2000;
  static const int phoneMax = 20;
  static const int capacityMin = 1;
  static const int capacityMax = 100;

  static const String _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';
  static const String _easternArabicDigits = '۰۱۲۳۴۵۶۷۸۹';

  /// [input] with Arabic-Indic digits replaced by ASCII digits.
  static String asciiDigits(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final arabic = _arabicIndicDigits.indexOf(char);
      final eastern = _easternArabicDigits.indexOf(char);
      if (arabic >= 0) {
        buffer.write(arabic);
      } else if (eastern >= 0) {
        buffer.write(eastern);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  /// The 9-digit Yemeni mobile number (starting with 7) contained in [input],
  /// or null when [input] is not one. Accepts an optional `+967`, `00967` or
  /// `0` prefix, Arabic digits, spaces and dashes.
  static String? normalizeYemenMobile(String? input) {
    if (input == null) return null;
    var text = asciiDigits(input.trim()).replaceAll(RegExp(r'[\s\-]'), '');
    if (text.isEmpty) return null;
    if (text.startsWith('+967')) {
      text = text.substring(4);
    } else if (text.startsWith('00967')) {
      text = text.substring(5);
    } else if (text.startsWith('0') && text.length == 10) {
      text = text.substring(1);
    }
    return RegExp(r'^7[0-9]{8}$').hasMatch(text) ? text : null;
  }

  static String? validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'اكتب رقم تواصل النشاط.';
    if (text.length > phoneMax || normalizeYemenMobile(text) == null) {
      return 'اكتب رقم جوال يمنيًا صحيحًا من 9 أرقام يبدأ بـ 7.';
    }
    return null;
  }

  static String? validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < nameMin) return 'اكتب اسم النشاط (3 أحرف على الأقل).';
    if (text.length > nameMax) {
      return 'اسم النشاط طويل جدًا (الحد $nameMax حرفًا).';
    }
    return null;
  }

  static String? validateDescription(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > descriptionMax) {
      return 'الوصف طويل جدًا (الحد $descriptionMax حرفًا).';
    }
    return null;
  }

  /// The monthly capacity as a whole number in range, or null.
  static int? parseCapacity(String? value) {
    final number = int.tryParse(asciiDigits(value?.trim() ?? ''));
    if (number == null || number < capacityMin || number > capacityMax) {
      return null;
    }
    return number;
  }

  static String? validateCapacity(String? value) {
    return parseCapacity(value) == null
        ? 'اكتب رقمًا بين $capacityMin و$capacityMax.'
        : null;
  }
}
