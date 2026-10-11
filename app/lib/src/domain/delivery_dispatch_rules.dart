/// Pure rules for the courier dispatch flow. No Flutter imports, so the logic
/// is unit-testable and shared by the courier and admin screens.
abstract final class DeliveryDispatchRules {
  static const pendingStatuses = {'assigned'};
  static const pickupStatuses = {'heading_to_pickup'};
  static const dropoffPreviewStatuses = {'picked_up'};
  static const dropoffStatuses = {'heading_to_recipient'};
  static const waitingForAdminStatuses = {'failed', 'rescheduled'};
  static const closedStatuses = {'delivered', 'cancelled'};

  /// Statuses `admin_reassign_delivery` accepts.
  static const adminReassignableStatuses = {
    'assigned',
    'failed',
    'rescheduled',
  };

  static const waitingForAdminMessage = 'بانتظار إعادة الإسناد من الإدارة';

  static bool canRespond(String status) => pendingStatuses.contains(status);
  static bool canVerifyPickup(String status) => pickupStatuses.contains(status);
  static bool canStartDropoff(String status) =>
      dropoffPreviewStatuses.contains(status);
  static bool canVerifyDropoff(String status) =>
      dropoffStatuses.contains(status);
  static bool canReportProblem(String status) =>
      pickupStatuses.contains(status) ||
      dropoffPreviewStatuses.contains(status) ||
      dropoffStatuses.contains(status);
  static bool waitsForAdmin(String status) =>
      waitingForAdminStatuses.contains(status);
  static bool isClosed(String status) => closedStatuses.contains(status);

  /// Cash pledges are collected while the courier is on an active leg
  /// (pickup or dropoff), never before accepting or after a failure report.
  static bool showsCashPledges(String status) => canReportProblem(status);

  static bool canAdminReassign(String status) =>
      adminReassignableStatuses.contains(status);

  /// The server decides which states can really be cancelled; the UI only
  /// hides the action for deliveries that are already closed.
  static bool canAdminCancel(String status) => !isClosed(status);

  /// Label shown to the courier.
  static String statusLabel(String status) => switch (status) {
        'assigned' => 'بانتظار ردك',
        'heading_to_pickup' => 'في الطريق للاستلام',
        'picked_up' => 'تم الاستلام',
        'heading_to_recipient' => 'في الطريق للتسليم',
        'rescheduled' => 'بانتظار إعادة التنسيق',
        'failed' => 'تحتاج تدخل الفريق',
        'delivered' => 'تم التسليم',
        'cancelled' => 'أُلغيت المهمة',
        _ => 'حالة غير معروفة',
      };

  /// Label shown to the admin in the dispatch queue.
  static String adminStatusLabel(String status) => switch (status) {
        'assigned' => 'بانتظار رد الموصل',
        'rescheduled' => 'تحتاج إعادة إسناد',
        'failed' => 'متعثرة وتحتاج إعادة إسناد',
        _ => statusLabel(status),
      };

  /// Reasons a courier may give when declining an assignment
  /// (`courier_respond_delivery`).
  static const rejectionReasons = <String, String>{
    'unavailable': 'غير متاح الآن',
    'too_far': 'الموقع بعيد',
    'vehicle_issue': 'مشكلة في وسيلة النقل',
    'schedule_conflict': 'تعارض في الوقت',
    'other': 'سبب آخر',
  };

  static String rejectionReasonLabel(String reason) =>
      rejectionReasons[reason] ?? 'سبب آخر';
}
