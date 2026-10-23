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

  /// Delivery statuses that are finished for the donor and the recipient.
  /// 'failed' means an admin cancelled the delivery: the donation went back
  /// to available and the need to waiting, so nothing is in progress.
  static const closedDeliveryStatuses = <String>{'delivered', 'failed'};

  static bool isDeliveryClosed(String status) =>
      closedDeliveryStatuses.contains(status);

  /// Service offers/requests in these statuses have nothing left to complete.
  static const _finishedServiceStatuses = <String>{
    'rejected',
    'cancelled',
    'withdrawn',
  };

  /// Whether a follow-up card renders its "continue" button. The follow-up
  /// screen itself is `/handoffs`, so a row that only points back to it has
  /// no button, and a rejected or cancelled service has nothing to continue.
  static bool showsAction({
    required String kind,
    required String status,
    required bool requiresAction,
    required String serverRoute,
  }) {
    if (!requiresAction) return false;
    if (serverRoute == '/handoffs') return false;
    if ((kind == 'service_offer' || kind == 'service_request') &&
        _finishedServiceStatuses.contains(status)) {
      return false;
    }
    return true;
  }

  /// Where a notification opens. A notification written for a proposed
  /// service match (`entity_type` 'service_matches', dedupe key ending in
  /// ':proposed') is answered in the offers screen, like [actionRoute]. When
  /// the row does not carry that information the server route is kept.
  static String notificationRoute({
    required String? entityType,
    required String? dedupeKey,
    required String serverRoute,
  }) {
    if (entityType == 'service_matches' &&
        dedupeKey != null &&
        dedupeKey.endsWith(':proposed')) {
      return actionRoute(
        kind: 'service_match',
        status: 'proposed',
        serverRoute: serverRoute,
      );
    }
    return serverRoute;
  }

  /// Adds a request id to a tab route that takes one (`/offers`,
  /// `/handoffs`), so that asking for the same tab twice in a row is still
  /// seen as a new request by the tab screen.
  static String withRequestId(String route, int requestId) {
    final path = route.split('?').first;
    if (path != '/offers' && path != '/handoffs') return route;
    final uri = Uri.parse(route);
    final query = <String, String>{...uri.queryParameters, 't': '$requestId'};
    return Uri(path: uri.path, queryParameters: query).toString();
  }

  /// Greeting for the local hour (0-23).
  static String greetingForHour(int hour) {
    if (hour >= 4 && hour < 12) return 'صباح الخير';
    return 'مساء الخير';
  }

  /// The first word of a profile name, or null when there is no usable name
  /// (empty, or something that is clearly not a name such as an e-mail
  /// address or a phone number).
  static String? firstName(String? fullName) {
    final text = fullName?.trim() ?? '';
    if (text.isEmpty) return null;
    final first = text.split(RegExp(r'\s+')).first;
    if (first.contains('@') || RegExp(r'\d').hasMatch(first)) return null;
    return first;
  }

  /// Home greeting, e.g. «مساء الخير، محمد», or the plain greeting when the
  /// name is unknown.
  static String greetingWithName(int hour, String? fullName) {
    final greeting = greetingForHour(hour);
    final name = firstName(fullName);
    return name == null ? greeting : '$greeting، $name';
  }
}
