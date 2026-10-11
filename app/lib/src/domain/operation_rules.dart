/// Which of the person's own operations can still be withdrawn. Mirrors the
/// status lists in `user_cancel_donation` / `user_cancel_need`.
abstract final class OperationRules {
  static const cancellableDonationStatuses = <String>{
    'draft',
    'submitted',
    'under_review',
    'available',
  };

  static const cancellableNeedStatuses = <String>{
    'submitted',
    'waiting',
    'candidate_found',
    'confirmed',
  };

  static bool canCancel({required String kind, required String status}) {
    return switch (kind) {
      'donation' => cancellableDonationStatuses.contains(status),
      'need' => cancellableNeedStatuses.contains(status),
      _ => false,
    };
  }

  /// Where a card's "continue" button must go. A proposed service match is
  /// answered in the offers screen (services tab), not in "my services".
  static String actionRoute({
    required String kind,
    required String status,
    required String serverRoute,
  }) {
    if (kind == 'service_match' && status == 'proposed') return '/offers?tab=1';
    return serverRoute;
  }

  /// Greeting for the local hour (0-23).
  static String greetingForHour(int hour) {
    if (hour >= 4 && hour < 12) return 'صباح الخير';
    return 'مساء الخير';
  }
}
