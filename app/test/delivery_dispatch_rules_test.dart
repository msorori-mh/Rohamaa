import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/delivery_dispatch_rules.dart';

void main() {
  group('DeliveryDispatchRules', () {
    test('new assignment requires a courier response before pickup', () {
      expect(DeliveryDispatchRules.canRespond('assigned'), isTrue);
      expect(DeliveryDispatchRules.canVerifyPickup('assigned'), isFalse);
      expect(DeliveryDispatchRules.statusLabel('assigned'), 'بانتظار ردك');
    });

    test('pickup and dropoff actions follow the guarded sequence', () {
      expect(DeliveryDispatchRules.canVerifyPickup('heading_to_pickup'), isTrue);
      expect(DeliveryDispatchRules.canStartDropoff('picked_up'), isTrue);
      expect(DeliveryDispatchRules.canVerifyDropoff('picked_up'), isFalse);
      expect(DeliveryDispatchRules.canVerifyDropoff('heading_to_recipient'), isTrue);
    });

    test('failed and rescheduled tasks wait for admin', () {
      expect(DeliveryDispatchRules.waitsForAdmin('failed'), isTrue);
      expect(DeliveryDispatchRules.waitsForAdmin('rescheduled'), isTrue);
      expect(DeliveryDispatchRules.canReportProblem('rescheduled'), isFalse);
    });
  });
}
