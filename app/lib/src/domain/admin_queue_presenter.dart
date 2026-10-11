import 'delivery_dispatch_rules.dart';
import 'risk_flag_presenter.dart';
import 'staff_labels.dart';

/// Title and subtitle of one admin priority-queue row, ready to display.
class AdminQueueCopy {
  const AdminQueueCopy({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

/// Rebuilds the copy of `admin_operations_overview` rows on the client.
///
/// For some queue kinds the server concatenates a fixed Arabic prefix with a
/// raw database key (rule code, severity, status, incident type):
///
/// * `risk`: title `'إشارة مخاطر: ' || rule_code`, subtitle
///   `'الأولوية ' || severity`
/// * `service_incident`: title `'بلاغ خدمة: ' || incident_type`, subtitle
///   `'الحالة ' || status`
/// * `delivery`: subtitle `'الحالة ' || status`
/// * `account_deletion`: subtitle `'الحالة ' || status`
///
/// Those keys are replaced with Arabic labels here. Every other kind carries
/// text a person typed (item name, partner name) or a fixed Arabic title and
/// is shown as it is.
abstract final class AdminQueuePresenter {
  static const _riskTitlePrefix = 'إشارة مخاطر:';
  static const _incidentTitlePrefix = 'بلاغ خدمة:';
  static const _statusPrefix = 'الحالة';
  static const _severityPrefix = 'الأولوية';

  /// The raw key that follows [prefix] in a server-built string.
  static String keyAfter(String text, String prefix) {
    final trimmed = text.trim();
    if (!trimmed.startsWith(prefix)) return trimmed;
    return trimmed.substring(prefix.length).trim();
  }

  static AdminQueueCopy present({
    required String kind,
    required String title,
    required String subtitle,
  }) {
    switch (kind) {
      case 'risk':
        final rule = keyAfter(title, _riskTitlePrefix);
        final severity = keyAfter(subtitle, _severityPrefix);
        return AdminQueueCopy(
          title: RiskFlagPresenter.ruleLabels[rule] ?? 'إشارة مخاطر تحتاج مراجعة',
          subtitle: 'الأولوية: ${RiskFlagPresenter.severityLabel(severity)}',
        );
      case 'service_incident':
        final type = keyAfter(title, _incidentTitlePrefix);
        final status = keyAfter(subtitle, _statusPrefix);
        return AdminQueueCopy(
          title: 'بلاغ خدمة: ${StaffLabels.incidentTypeLabel(type)}',
          subtitle: StaffLabels.incidentStatusLabel(status),
        );
      case 'delivery':
        final status = keyAfter(subtitle, _statusPrefix);
        return AdminQueueCopy(
          title: 'توصيل يحتاج إعادة إسناد',
          subtitle: DeliveryDispatchRules.adminStatusLabel(status),
        );
      case 'account_deletion':
        final status = keyAfter(subtitle, _statusPrefix);
        return AdminQueueCopy(
          title: status == 'processing'
              ? 'حذف حساب لم يكتمل'
              : 'طلب حذف حساب ينتظر القرار',
          subtitle: status == 'processing'
              ? 'بدأ تنفيذ الحذف ولم ينتهِ. أعد المحاولة من شاشة الطلبات.'
              : StaffLabels.deletionStatusLabel(status),
        );
      default:
        return AdminQueueCopy(title: title, subtitle: subtitle);
    }
  }
}
