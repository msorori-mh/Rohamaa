abstract final class DeliveryDispatchRules {
  static const pendingStatuses = {'assigned'};
  static const pickupStatuses = {'heading_to_pickup'};
  static const dropoffPreviewStatuses = {'picked_up'};
  static const dropoffStatuses = {'heading_to_recipient'};
  static const waitingForAdminStatuses = {'failed', 'rescheduled'};

  static bool canRespond(String status) => pendingStatuses.contains(status);
  static bool canVerifyPickup(String status) => pickupStatuses.contains(status);
  static bool canStartDropoff(String status) => dropoffPreviewStatuses.contains(status);
  static bool canVerifyDropoff(String status) => dropoffStatuses.contains(status);
  static bool canReportProblem(String status) =>
      pickupStatuses.contains(status) || dropoffPreviewStatuses.contains(status) || dropoffStatuses.contains(status);
  static bool waitsForAdmin(String status) => waitingForAdminStatuses.contains(status);

  static String statusLabel(String status) => switch (status) {
        'assigned' => 'بانتظار ردك',
        'heading_to_pickup' => 'في الطريق للاستلام',
        'picked_up' => 'تم الاستلام',
        'heading_to_recipient' => 'في الطريق للتسليم',
        'rescheduled' => 'بانتظار إعادة التنسيق',
        'failed' => 'تحتاج تدخل الفريق',
        _ => status.replaceAll('_', ' '),
      };
}
