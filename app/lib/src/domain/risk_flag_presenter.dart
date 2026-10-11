import 'courier_task_rules.dart';

/// Turns `risk_flags` rows into Arabic copy for reviewers. Rule codes and
/// detail keys come from the SQL triggers; unknown ones are shown neutrally
/// instead of leaking raw identifiers as if they were explanations.
abstract final class RiskFlagPresenter {
  static const ruleLabels = <String, String>{
    'HIGH_REQUEST_VELOCITY': 'طلبات كثيرة خلال 24 ساعة',
    'REPEAT_FULFILLED_CATEGORY': 'طلب متكرر لفئة سبق تلبيتها',
    'ADDRESS_CHURN': 'تغيير متكرر للعنوان',
    'REPEATED_DELIVERY_NO_SHOW': 'تعذر تسليم متكرر بسبب الطرف نفسه',
    'INVALID_DELIVERY_PIN': 'إدخال رمز تسليم غير صحيح',
    'many_open_needs': 'عدد كبير من الطلبات المفتوحة',
    'high_need_request_velocity': 'طلبات كثيرة خلال 30 يومًا',
  };

  static const severityLabels = <String, String>{
    'low': 'منخفضة',
    'medium': 'متوسطة',
    'high': 'عالية',
    'critical': 'حرجة',
  };

  static const detailLabels = <String, String>{
    'prior_24h': 'طلبات خلال آخر 24 ساعة',
    'fulfilled_last_120d': 'طلبات ملبّاة خلال 120 يومًا',
    'category': 'الفئة',
    'addresses_last_14d': 'عناوين خلال 14 يومًا',
    'failures_60d': 'حالات تعذر خلال 60 يومًا',
    'latest_reason': 'آخر سبب',
    'kind': 'مرحلة الرمز',
    'open_need_count': 'الطلبات المفتوحة',
    'needs_last_30_days': 'طلبات خلال 30 يومًا',
    'resolution': 'نتيجة المراجعة',
  };

  static const _categoryLabels = <String, String>{
    'clothes': 'ملابس',
    'books': 'كتب وتعليم',
    'education': 'كتب وتعليم',
    'furniture': 'أثاث ومنزل',
    'home': 'أثاث ومنزل',
    'home_furniture': 'أثاث ومنزل',
    'electronics': 'إلكترونيات',
    'children': 'مستلزمات أطفال',
    'tools_trades': 'أدوات ومهن',
    'events': 'مناسبات',
    'other': 'أخرى',
  };

  static String ruleLabel(String? code) {
    if (code == null || code.isEmpty) return 'إشارة تحتاج مراجعة';
    return ruleLabels[code] ?? 'إشارة تحتاج مراجعة ($code)';
  }

  static String severityLabel(String? severity) =>
      severityLabels[severity] ?? 'غير محددة';

  static bool isUrgent(String? severity) =>
      severity == 'high' || severity == 'critical';

  static String _value(String key, Object? value) {
    if (value == null) return 'غير متوفر';
    if (value is bool) return value ? 'نعم' : 'لا';
    final text = '$value';
    switch (key) {
      case 'kind':
        if (text == 'pickup') return 'الاستلام من المتبرع';
        if (text == 'delivery') return 'التسليم لصاحب الطلب';
        return text;
      case 'latest_reason':
        return CourierTaskRules.failureReasons[text] ?? text;
      case 'category':
        return _categoryLabels[text] ?? text;
      default:
        return text;
    }
  }

  /// Readable `label: value` lines for the `details` JSON of a flag.
  static List<String> detailLines(Object? details) {
    if (details is! Map || details.isEmpty) return const <String>[];
    final lines = <String>[];
    for (final entry in details.entries) {
      final key = '${entry.key}';
      final value = entry.value;
      if (value is Map || value is List) continue;
      final label = detailLabels[key] ?? 'معلومة إضافية ($key)';
      lines.add('$label: ${_value(key, value)}');
    }
    return lines;
  }
}
