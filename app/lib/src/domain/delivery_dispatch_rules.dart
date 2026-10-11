/// Pure rules for the courier dispatch flow. No Flutter imports, so the logic
/// is unit-testable and shared by the courier and admin screens.
abstract final class DeliveryDispatchRules {
  static const pendingStatuses = {'assigned'};
  static const pickupStatuses = {'heading_to_pickup'};
  static const dropoffPreviewStatuses = {'picked_up'};
  static const dropoffStatuses = {'heading_to_recipient'};
  static const waitingForAdminStatuses = {'rescheduled'};

  /// 'failed' is terminal: only `admin_cancel_delivery` writes it.
  static const closedStatuses = {'delivered', 'cancelled', 'failed'};

  /// Statuses `admin_reassign_delivery` accepts.
  static const adminReassignableStatuses = {
    'assigned',
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

  /// The server keeps accepting pledge answers for 24 hours after delivery,
  /// so a delivered task still loads its pledges.
  static bool loadsCashPledges(String status) =>
      showsCashPledges(status) || status == 'delivered';

  /// True when at least one pledge has no courier answer yet. [answers] are
  /// the `courier_received` values (null = not answered).
  static bool hasUnansweredPledge(Iterable<bool?> answers) =>
      answers.any((answer) => answer == null);

  /// After a successful dropoff PIN the task screen stays open only while a
  /// cash pledge still needs the courier's answer.
  static bool staysOpenAfterDelivery(Iterable<bool?> pledgeAnswers) =>
      hasUnansweredPledge(pledgeAnswers);

  /// A pledge answer is write-once on the server.
  static bool canAnswerPledge(bool? courierReceived) => courierReceived == null;

  /// `courier_task_details` hides the pickup area and returns the dropoff
  /// area for an 'assigned' task that was reassigned after the item was
  /// collected: accepting it resumes at the dropoff phase.
  static bool resumesAtDropoff({
    required String status,
    String? pickupArea,
    String? dropoffArea,
  }) =>
      canRespond(status) && pickupArea == null && dropoffArea != null;

  /// Message after accepting an assignment. [nextStatus] is the status
  /// returned by `courier_respond_delivery`.
  static String acceptedMessage(String nextStatus) =>
      dropoffPreviewStatuses.contains(nextStatus) ||
              dropoffStatuses.contains(nextStatus)
          ? 'تم قبول المهمة. الشيء مستلم مسبقًا، توجّه الآن إلى موقع التسليم.'
          : 'تم قبول المهمة. يمكنك الآن التوجه إلى موقع الاستلام.';

  /// Statuses `admin_pause_delivery` accepts: an active courier leg that the
  /// admin stops so the task can be reassigned.
  static const adminPausableStatuses = {
    'heading_to_pickup',
    'picked_up',
    'heading_to_recipient',
  };

  static bool canAdminPause(String status) =>
      adminPausableStatuses.contains(status);

  static const pauseReasonMinLength = 3;
  static const pauseReasonMaxLength = 500;

  /// Inline message for the pause reason; null when acceptable.
  static String? pauseReasonError(String? value) {
    final text = (value ?? '').trim();
    if (text.length < pauseReasonMinLength) return 'اكتب سببًا واضحًا للإيقاف.';
    if (text.length > pauseReasonMaxLength) {
      return 'السبب أطول من $pauseReasonMaxLength حرفًا.';
    }
    return null;
  }

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
        'failed' => 'أُلغيت المهمة',
        'delivered' => 'تم التسليم',
        'cancelled' => 'أُلغيت المهمة',
        _ => 'حالة غير معروفة',
      };

  /// Label shown to the admin in the dispatch queue.
  static String adminStatusLabel(String status) => switch (status) {
        'assigned' => 'بانتظار رد الموصل',
        'rescheduled' => 'تحتاج إعادة إسناد',
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
