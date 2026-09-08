class RecoveryStatusCopy {
  const RecoveryStatusCopy(this.label, this.nextAction);
  final String label;
  final String? nextAction;
}

abstract final class ItemRecoveryRules {
  static const gradeLabels = <String, String>{
    'A': 'A — جاهز للاستخدام مباشرة',
    'B': 'B — يحتاج تنظيفًا وتجهيزًا',
    'C': 'C — يحتاج إصلاحًا',
    'D': 'D — غير صالح للاستخدام ويحوّل للتدوير',
  };

  static RecoveryStatusCopy status(String value) => switch (value) {
    'inspection_pending' => const RecoveryStatusCopy('بانتظار الفحص', 'inspect'),
    'cleaning_queued' => const RecoveryStatusCopy('بانتظار التنظيف', 'start_work'),
    'cleaning' => const RecoveryStatusCopy('قيد التنظيف', 'complete_work'),
    'repair_queued' => const RecoveryStatusCopy('بانتظار الإصلاح', 'start_work'),
    'repairing' => const RecoveryStatusCopy('قيد الإصلاح', 'complete_work'),
    'ready_for_distribution' => const RecoveryStatusCopy('جاهز لإعادة التوزيع', null),
    'recycling' => const RecoveryStatusCopy('بانتظار تسليم التدوير', 'confirm_recycling'),
    'recycled' => const RecoveryStatusCopy('تمت إعادة التدوير', null),
    'withdrawn' => const RecoveryStatusCopy('مُخرج من المخزون', null),
    _ => RecoveryStatusCopy(value.replaceAll('_', ' '), null),
  };
}
