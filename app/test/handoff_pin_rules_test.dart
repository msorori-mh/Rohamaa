import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/handoff_pin_rules.dart';

void main() {
  final issuedAt = DateTime(2026, 10, 11, 9, 0, 0);
  final pin = IssuedHandoffPin(pin: '0421', issuedAt: issuedAt);

  group('HandoffPinRules', () {
    test('a PIN can be issued only in the matching courier phase', () {
      expect(HandoffPinRules.canIssue(kind: 'pickup', status: 'heading_to_pickup'), isTrue);
      expect(HandoffPinRules.canIssue(kind: 'pickup', status: 'assigned'), isFalse);
      expect(HandoffPinRules.canIssue(kind: 'pickup', status: 'rescheduled'), isFalse);
      expect(HandoffPinRules.canIssue(kind: 'pickup', status: 'heading_to_recipient'), isFalse);
      expect(HandoffPinRules.canIssue(kind: 'delivery', status: 'heading_to_recipient'), isTrue);
      expect(HandoffPinRules.canIssue(kind: 'delivery', status: 'picked_up'), isFalse);
      expect(HandoffPinRules.canIssue(kind: 'delivery', status: 'delivered'), isFalse);
      expect(HandoffPinRules.canIssue(kind: 'other', status: 'heading_to_pickup'), isFalse);
    });

    test('cached PINs are dropped once their handoff leaves the issuable status', () {
      final pickupKey = HandoffPinRules.cacheKey(userId: 'u1', deliveryId: 'd1', kind: 'pickup');
      final deliveryKey = HandoffPinRules.cacheKey(userId: 'u1', deliveryId: 'd2', kind: 'delivery');
      final otherUserKey = HandoffPinRules.cacheKey(userId: 'u2', deliveryId: 'd1', kind: 'pickup');
      expect(pickupKey, 'u1:d1:pickup');

      // d1 is still heading to pickup; d2 was reported failed / reassigned.
      expect(
        HandoffPinRules.staleKeys(
          cachedKeys: [pickupKey, deliveryKey, otherUserKey],
          userId: 'u1',
          issuableKeys: {pickupKey},
        ),
        {deliveryKey},
      );
      // A handoff that disappeared from the list is dropped too.
      expect(
        HandoffPinRules.staleKeys(
          cachedKeys: [pickupKey, deliveryKey],
          userId: 'u1',
          issuableKeys: const <String>{},
        ),
        {pickupKey, deliveryKey},
      );
      // Another account's PINs are never touched.
      expect(
        HandoffPinRules.staleKeys(
          cachedKeys: [otherUserKey],
          userId: 'u1',
          issuableKeys: const <String>{},
        ),
        isEmpty,
      );
    });

    test('the PIN expires ten minutes after it was requested', () {
      expect(pin.expiresAt, issuedAt.add(const Duration(minutes: 10)));
      expect(HandoffPinRules.isExpired(pin, issuedAt), isFalse);
      expect(
        HandoffPinRules.isExpired(pin, issuedAt.add(const Duration(minutes: 9, seconds: 59))),
        isFalse,
      );
      expect(HandoffPinRules.isExpired(pin, issuedAt.add(const Duration(minutes: 10))), isTrue);
      expect(HandoffPinRules.isExpired(pin, issuedAt.add(const Duration(hours: 1))), isTrue);
    });

    test('remaining time never goes negative', () {
      expect(
        HandoffPinRules.remaining(pin, issuedAt.add(const Duration(minutes: 4))),
        const Duration(minutes: 6),
      );
      expect(
        HandoffPinRules.remaining(pin, issuedAt.add(const Duration(minutes: 30))),
        Duration.zero,
      );
    });

    test('countdown text shows minutes and seconds', () {
      expect(HandoffPinRules.clock(const Duration(minutes: 9, seconds: 5)), '09:05');
      expect(HandoffPinRules.clock(const Duration(seconds: 59)), '00:59');
      expect(HandoffPinRules.clock(Duration.zero), '00:00');
      expect(
        HandoffPinRules.countdownLabel(const Duration(minutes: 9, seconds: 5)),
        contains('09:05'),
      );
      expect(HandoffPinRules.countdownLabel(Duration.zero), contains('انتهت'));
    });
  });
}
