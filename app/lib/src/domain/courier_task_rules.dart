/// Pure validation and label rules for courier task actions.
abstract final class CourierTaskRules {
  static const pinLength = 4;
  static const failureNoteMaxLength = 500;

  static final RegExp _pinPattern = RegExp(r'^[0-9]{4}$');
  static final RegExp _digitsOnly = RegExp(r'^[0-9]+$');

  /// Characters accepted while typing a PIN: ASCII digits plus the
  /// Arabic-Indic and Persian digits that Arabic keyboards may produce.
  static final RegExp pinInputPattern =
      RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]');

  /// Converts Arabic-Indic (٠-٩) and Persian (۰-۹) digits to ASCII digits,
  /// because the server only accepts `[0-9]{4}`.
  static String normalizeDigits(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + rune - 0x06F0);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// Trimmed PIN with ASCII digits, as it must be sent to the server.
  static String normalizedPin(String? value) =>
      normalizeDigits((value ?? '').trim());

  static bool isValidPin(String? value) =>
      _pinPattern.hasMatch(normalizedPin(value));

  /// Inline message for the PIN field; null when the PIN is well formed.
  static String? pinError(String? value) {
    final text = normalizedPin(value);
    if (text.isEmpty) return 'أدخل الرمز المكوّن من 4 أرقام.';
    if (!_digitsOnly.hasMatch(text)) return 'الرمز أرقام فقط.';
    if (text.length != pinLength) return 'الرمز يتكوّن من 4 أرقام بالضبط.';
    return null;
  }

  /// Shown when `verify_delivery_pin` returns false. The remaining attempts
  /// are not knowable on the client, so the copy does not mention a count.
  static const pinRejectedMessage =
      'لم يُقبل الرمز: قد يكون غير صحيح، أو انتهت صلاحيته، أو لم يُصدر بعد. '
      'اطلب من صاحب العملية إظهار رمز جديد.';

  /// Parties accepted by `courier_report_delivery_failure`.
  static const failureParties = <String, String>{
    'donor': 'المتبرع',
    'beneficiary': 'صاحب الطلب',
    'courier': 'الموصل',
    'other': 'طرف آخر',
  };

  /// Parties offered in the failure dialog for a delivery in [status]. Once
  /// the item is collected the server no longer accepts 'donor'.
  static Map<String, String> failurePartiesFor(String status) {
    const afterPickup = {'picked_up', 'heading_to_recipient'};
    if (!afterPickup.contains(status)) return failureParties;
    return <String, String>{
      for (final entry in failureParties.entries)
        if (entry.key != 'donor') entry.key: entry.value,
    };
  }

  /// Reason codes accepted by `courier_report_delivery_failure`.
  static const failureReasons = <String, String>{
    'no_answer': 'لا يوجد رد',
    'not_present': 'الشخص غير موجود',
    'wrong_address': 'العنوان غير صحيح',
    'item_not_ready': 'التبرع غير جاهز',
    'item_rejected': 'لم يتم قبول التبرع',
    'vehicle_issue': 'مشكلة في وسيلة النقل',
    'weather': 'حالة الطقس',
    'other': 'سبب آخر',
  };

  static String failurePartyLabel(String party) =>
      failureParties[party] ?? 'طرف آخر';

  static String failureReasonLabel(String reason) =>
      failureReasons[reason] ?? 'سبب آخر';

  /// Null when the optional note is acceptable.
  static String? failureNoteError(String? value) {
    final text = (value ?? '').trim();
    if (text.length > failureNoteMaxLength) {
      return 'الملاحظة أطول من $failureNoteMaxLength حرفًا.';
    }
    return null;
  }

  /// Trimmed note, or null when empty (the RPC stores null).
  static String? normalizedNote(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }

  /// `tel:` URI for a phone number, or null if nothing dialable remains.
  static Uri? telUri(String? phone) {
    if (phone == null) return null;
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.replaceAll('+', '').length < 3) return null;
    return Uri(scheme: 'tel', path: cleaned);
  }

  /// Google Maps search URI for a coordinate, or null when it is unusable.
  static Uri? mapsUri(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return null;
    if (latitude.isNaN || longitude.isNaN) return null;
    if (latitude < -90 || latitude > 90) return null;
    if (longitude < -180 || longitude > 180) return null;
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
  }

  /// Courier answer on a cash pledge (`courier_received`): null = not yet.
  static String pledgeAnswerLabel(bool? received) => switch (received) {
        true => 'أكدت استلام المبلغ',
        false => 'سجّلت أن المبلغ لم يُستلم',
        null => 'لم تسجّل إجابتك بعد',
      };
}
