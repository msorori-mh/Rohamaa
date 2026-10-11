import 'partner_form_rules.dart';

/// Rules and Arabic labels for a person's own service offers and requests.
/// Status values mirror the SQL checks on `service_offers`, `service_requests`
/// and `service_matches`.
class ServiceFlowRules {
  const ServiceFlowRules._();

  static const int titleMax = 160;
  static const int detailsMax = 2000;
  static const int noteMax = 2000;

  /// Offer statuses that are not tied to a match yet.
  static const Set<String> withdrawableOfferStatuses = <String>{
    'submitted',
    'approved',
    'paused',
  };

  /// Request statuses that are not tied to a match yet.
  static const Set<String> cancellableRequestStatuses = <String>{
    'submitted',
    'reviewing',
  };

  static bool canWithdrawOffer(String? status) {
    return withdrawableOfferStatuses.contains(status);
  }

  static bool canCancelRequest(String? status) {
    return cancellableRequestStatuses.contains(status);
  }

  /// Label for an offer. A closed or matched offer keeps that label whatever
  /// its verification state is.
  static String offerStatusLabel(String? status, String? verification) {
    if (status == 'cancelled') return 'تم السحب';
    if (status == 'completed') return 'اكتملت الخدمة';
    if (status == 'rejected') return 'لم تُقبل الخدمة';
    if (status == 'matched') return 'تم العثور على احتياج مناسب';
    if (verification == 'rejected') return 'يحتاج مراجعة أو تعديل';
    if (verification != 'verified') return 'قيد مراجعة عطاء';
    if (status == 'approved') return 'متاح للمطابقة';
    if (status == 'paused') return 'متوقف مؤقتًا';
    return 'قيد المراجعة';
  }

  static String requestStatusLabel(String? status) {
    switch (status) {
      case 'submitted':
        return 'تم التسجيل ويجري البحث';
      case 'reviewing':
        return 'يراجع عطاء الاحتياج';
      case 'matched':
        return 'تم العثور على مهارة مناسبة';
      case 'scheduled':
        return 'تم ترتيب الموعد';
      case 'completed':
        return 'اكتملت الخدمة';
      case 'rejected':
        return 'لم يُقبل الطلب';
      case 'cancelled':
        return 'تم الإلغاء';
      default:
        return 'قيد المتابعة';
    }
  }

  static String matchStatusLabel(String? status) {
    switch (status) {
      case 'proposed':
        return 'بانتظار موافقة الطرفين';
      case 'accepted':
        return 'وافق الطرفان ويجري التنسيق';
      case 'scheduled':
        return 'تم ترتيب الموعد';
      case 'completed':
        return 'اكتملت الخدمة';
      case 'declined':
        return 'لم تتم المطابقة';
      case 'cancelled':
        return 'أُلغيت العملية';
      default:
        return 'قيد المتابعة';
    }
  }

  /// Hours typed by the person (Arabic digits allowed), or null when the
  /// value is not within the server range: above 0 and at most 24.
  static double? parseHours(String? value) {
    final text = PartnerFormRules.asciiDigits((value ?? '').trim())
        .replaceAll('٫', '.')
        .replaceAll(',', '.');
    final hours = double.tryParse(text);
    if (hours == null || hours <= 0 || hours > 24) return null;
    return hours;
  }

  static String? validateHours(String? value) {
    return parseHours(value) == null ? 'حدد عدد ساعات بين 1 و24.' : null;
  }

  static String? validateTitle(String? value, {required String emptyMessage}) {
    final text = value?.trim() ?? '';
    if (text.length < 3) return emptyMessage;
    if (text.length > titleMax) {
      return 'العنوان طويل جدًا (الحد $titleMax حرفًا).';
    }
    return null;
  }

  static String? validateDetails(
    String? value, {
    required String emptyMessage,
  }) {
    final text = value?.trim() ?? '';
    if (text.length < 8) return emptyMessage;
    if (text.length > detailsMax) {
      return 'النص طويل جدًا (الحد $detailsMax حرفًا).';
    }
    return null;
  }

  static String? validateOptionalNote(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > noteMax) return 'النص طويل جدًا (الحد $noteMax حرفًا).';
    return null;
  }
}
