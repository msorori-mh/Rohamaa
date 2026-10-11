/// A handoff PIN returned by the server together with the local time the
/// request was sent, so the app can show the same PIN until it expires
/// instead of generating a new one on every tap.
class IssuedHandoffPin {
  const IssuedHandoffPin({required this.pin, required this.issuedAt});

  final String pin;
  final DateTime issuedAt;

  DateTime get expiresAt => issuedAt.add(HandoffPinRules.validity);
}

abstract final class HandoffPinRules {
  /// Mirrors `user_issue_handoff_pin`: the PIN is valid for 10 minutes.
  static const validity = Duration(minutes: 10);

  /// Mirrors `user_issue_handoff_pin`: the donor can issue the pickup PIN only
  /// while the courier is heading to pickup, and the recipient can issue the
  /// delivery PIN only while the courier is heading to them.
  static bool canIssue({required String kind, required String status}) {
    if (kind == 'pickup') return status == 'heading_to_pickup';
    if (kind == 'delivery') return status == 'heading_to_recipient';
    return false;
  }

  static Duration remaining(IssuedHandoffPin pin, DateTime now) {
    final left = pin.expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  static bool isExpired(IssuedHandoffPin pin, DateTime now) =>
      remaining(pin, now) == Duration.zero;

  /// mm:ss, e.g. 09:05.
  static String clock(Duration remaining) {
    final total = remaining.isNegative ? 0 : remaining.inSeconds;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static String countdownLabel(Duration remaining) {
    if (remaining <= Duration.zero) {
      return 'انتهت صلاحية الرمز. أنشئ رمزًا جديدًا.';
    }
    return 'ينتهي الرمز خلال ${clock(remaining)}';
  }
}
