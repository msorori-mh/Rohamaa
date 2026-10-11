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
      expect(
        DeliveryDispatchRules.canVerifyDropoff('heading_to_recipient'),
        isTrue,
      );
    });

    test('rescheduled tasks wait for admin and failed is terminal', () {
      expect(DeliveryDispatchRules.waitsForAdmin('failed'), isFalse);
      expect(DeliveryDispatchRules.isClosed('failed'), isTrue);
      expect(DeliveryDispatchRules.waitsForAdmin('rescheduled'), isTrue);
      expect(DeliveryDispatchRules.canReportProblem('rescheduled'), isFalse);
      expect(
        DeliveryDispatchRules.waitingForAdminMessage,
        'بانتظار إعادة الإسناد من الإدارة',
      );
    });

    test('exactly one courier action group is available per open status', () {
      const statuses = [
        'assigned',
        'heading_to_pickup',
        'picked_up',
        'heading_to_recipient',
        'rescheduled',
      ];
      for (final status in statuses) {
        final groups = [
          DeliveryDispatchRules.canRespond(status),
          DeliveryDispatchRules.canVerifyPickup(status),
          DeliveryDispatchRules.canStartDropoff(status),
          DeliveryDispatchRules.canVerifyDropoff(status),
          DeliveryDispatchRules.waitsForAdmin(status),
        ].where((enabled) => enabled).length;
        expect(groups, 1, reason: status);
      }
    });

    test('failure report is offered only on an active leg', () {
      expect(DeliveryDispatchRules.canReportProblem('assigned'), isFalse);
      expect(
        DeliveryDispatchRules.canReportProblem('heading_to_pickup'),
        isTrue,
      );
      expect(DeliveryDispatchRules.canReportProblem('picked_up'), isTrue);
      expect(
        DeliveryDispatchRules.canReportProblem('heading_to_recipient'),
        isTrue,
      );
      expect(DeliveryDispatchRules.canReportProblem('failed'), isFalse);
      expect(DeliveryDispatchRules.canReportProblem('delivered'), isFalse);
    });

    test('cash pledges are listed only during pickup and dropoff phases', () {
      expect(DeliveryDispatchRules.showsCashPledges('assigned'), isFalse);
      expect(
        DeliveryDispatchRules.showsCashPledges('heading_to_pickup'),
        isTrue,
      );
      expect(DeliveryDispatchRules.showsCashPledges('picked_up'), isTrue);
      expect(
        DeliveryDispatchRules.showsCashPledges('heading_to_recipient'),
        isTrue,
      );
      expect(DeliveryDispatchRules.showsCashPledges('rescheduled'), isFalse);
      expect(DeliveryDispatchRules.showsCashPledges('delivered'), isFalse);
    });

    test('closed and unknown statuses offer no courier action', () {
      for (final status in ['delivered', 'cancelled', 'something_new']) {
        expect(DeliveryDispatchRules.canRespond(status), isFalse);
        expect(DeliveryDispatchRules.canVerifyPickup(status), isFalse);
        expect(DeliveryDispatchRules.canStartDropoff(status), isFalse);
        expect(DeliveryDispatchRules.canVerifyDropoff(status), isFalse);
        expect(DeliveryDispatchRules.canReportProblem(status), isFalse);
        expect(DeliveryDispatchRules.waitsForAdmin(status), isFalse);
      }
      expect(DeliveryDispatchRules.isClosed('delivered'), isTrue);
      expect(DeliveryDispatchRules.isClosed('cancelled'), isTrue);
      expect(DeliveryDispatchRules.isClosed('assigned'), isFalse);
    });

    test('admin can reassign only the states the RPC accepts', () {
      expect(DeliveryDispatchRules.canAdminReassign('assigned'), isTrue);
      expect(DeliveryDispatchRules.canAdminReassign('failed'), isFalse);
      expect(DeliveryDispatchRules.canAdminReassign('rescheduled'), isTrue);
      expect(
        DeliveryDispatchRules.canAdminReassign('heading_to_pickup'),
        isFalse,
      );
      expect(DeliveryDispatchRules.canAdminReassign('picked_up'), isFalse);
      expect(DeliveryDispatchRules.canAdminReassign('delivered'), isFalse);
    });

    test('admin cancel is hidden only for closed deliveries', () {
      expect(DeliveryDispatchRules.canAdminCancel('assigned'), isTrue);
      expect(DeliveryDispatchRules.canAdminCancel('rescheduled'), isTrue);
      expect(DeliveryDispatchRules.canAdminCancel('picked_up'), isTrue);
      expect(DeliveryDispatchRules.canAdminCancel('delivered'), isFalse);
      expect(DeliveryDispatchRules.canAdminCancel('cancelled'), isFalse);
    });

    test('labels never expose raw status keys', () {
      final arabic = RegExp(r'[؀-ۿ]');
      final latin = RegExp(r'[A-Za-z_]');
      const statuses = [
        'assigned',
        'heading_to_pickup',
        'picked_up',
        'heading_to_recipient',
        'failed',
        'rescheduled',
        'delivered',
        'cancelled',
        'unexpected_status',
      ];
      for (final status in statuses) {
        for (final label in [
          DeliveryDispatchRules.statusLabel(status),
          DeliveryDispatchRules.adminStatusLabel(status),
        ]) {
          expect(arabic.hasMatch(label), isTrue, reason: status);
          expect(latin.hasMatch(label), isFalse, reason: status);
        }
      }
      expect(
        DeliveryDispatchRules.adminStatusLabel('assigned'),
        'بانتظار رد الموصل',
      );
    });

    test('pledges are still loaded after delivery', () {
      expect(DeliveryDispatchRules.loadsCashPledges('delivered'), isTrue);
      expect(DeliveryDispatchRules.loadsCashPledges('heading_to_recipient'), isTrue);
      expect(DeliveryDispatchRules.loadsCashPledges('assigned'), isFalse);
      expect(DeliveryDispatchRules.loadsCashPledges('rescheduled'), isFalse);
      expect(DeliveryDispatchRules.loadsCashPledges('failed'), isFalse);
    });

    test('the task stays open after delivery only for unanswered pledges', () {
      expect(DeliveryDispatchRules.staysOpenAfterDelivery(const <bool?>[]), isFalse);
      expect(DeliveryDispatchRules.staysOpenAfterDelivery(const [true, false]), isFalse);
      expect(DeliveryDispatchRules.staysOpenAfterDelivery(const [true, null]), isTrue);
      expect(DeliveryDispatchRules.hasUnansweredPledge(const [null]), isTrue);
    });

    test('a pledge answer is write-once', () {
      expect(DeliveryDispatchRules.canAnswerPledge(null), isTrue);
      expect(DeliveryDispatchRules.canAnswerPledge(true), isFalse);
      expect(DeliveryDispatchRules.canAnswerPledge(false), isFalse);
    });

    test('a task reassigned after pickup resumes at the dropoff phase', () {
      expect(
        DeliveryDispatchRules.resumesAtDropoff(
          status: 'assigned',
          pickupArea: null,
          dropoffArea: 'الروضة',
        ),
        isTrue,
      );
      expect(
        DeliveryDispatchRules.resumesAtDropoff(
          status: 'assigned',
          pickupArea: 'المجمع',
          dropoffArea: null,
        ),
        isFalse,
      );
      expect(
        DeliveryDispatchRules.resumesAtDropoff(
          status: 'assigned',
          pickupArea: null,
          dropoffArea: null,
        ),
        isFalse,
      );
      expect(
        DeliveryDispatchRules.resumesAtDropoff(
          status: 'picked_up',
          pickupArea: null,
          dropoffArea: 'الروضة',
        ),
        isFalse,
      );
    });

    test('the accept message follows the status the server returned', () {
      expect(
        DeliveryDispatchRules.acceptedMessage('heading_to_pickup'),
        contains('موقع الاستلام'),
      );
      expect(
        DeliveryDispatchRules.acceptedMessage('picked_up'),
        contains('موقع التسليم'),
      );
      expect(
        DeliveryDispatchRules.acceptedMessage('picked_up'),
        isNot(contains('موقع الاستلام')),
      );
      expect(
        DeliveryDispatchRules.acceptedMessage('unexpected'),
        contains('موقع الاستلام'),
      );
    });

    test('admin can pause only an active courier leg', () {
      for (final status in ['heading_to_pickup', 'picked_up', 'heading_to_recipient']) {
        expect(DeliveryDispatchRules.canAdminPause(status), isTrue, reason: status);
        expect(DeliveryDispatchRules.canAdminReassign(status), isFalse, reason: status);
      }
      for (final status in ['assigned', 'rescheduled', 'delivered', 'failed', 'cancelled', 'x']) {
        expect(DeliveryDispatchRules.canAdminPause(status), isFalse, reason: status);
      }
    });

    test('a pause needs a reason of 3 to 500 characters', () {
      expect(DeliveryDispatchRules.pauseReasonError(null), isNotNull);
      expect(DeliveryDispatchRules.pauseReasonError('  ab '), isNotNull);
      expect(DeliveryDispatchRules.pauseReasonError('تعطل المركبة'), isNull);
      expect(DeliveryDispatchRules.pauseReasonError('س' * 500), isNull);
      expect(DeliveryDispatchRules.pauseReasonError('س' * 501), isNotNull);
    });

    test('rejection reasons match the server list and have labels', () {
      expect(DeliveryDispatchRules.rejectionReasons.keys.toSet(), {
        'unavailable',
        'too_far',
        'vehicle_issue',
        'schedule_conflict',
        'other',
      });
      expect(
        DeliveryDispatchRules.rejectionReasonLabel('too_far'),
        'الموقع بعيد',
      );
      expect(
        DeliveryDispatchRules.rejectionReasonLabel('unknown'),
        'سبب آخر',
      );
    });
  });
}
