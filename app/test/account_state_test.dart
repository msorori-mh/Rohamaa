import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/account_state.dart';
import 'package:ruhamaa/src/domain/operation_rules.dart';

void main() {
  group('AccountState', () {
    test('parses the my_account_state row', () {
      final state = AccountState.fromJson({
        'role': 'courier',
        'is_suspended': false,
        'force_password_change': true,
        'deletion_status': null,
      });
      expect(state.role, 'courier');
      expect(state.isStaff, isTrue);
      expect(state.forcePasswordChange, isTrue);
      expect(state.deletionStatus, isNull);
      expect(state.gate, AccountGate.passwordChange);
    });

    test('missing values default to an ordinary active account', () {
      final state = AccountState.fromJson(const <String, dynamic>{});
      expect(state.role, 'user');
      expect(state.isSuspended, isFalse);
      expect(state.isBlocked, isFalse);
      expect(state.gate, AccountGate.community);
    });

    test('suspension wins over role routing and password change', () {
      const state = AccountState(
        role: 'admin',
        isSuspended: true,
        forcePasswordChange: true,
      );
      expect(state.isBlocked, isTrue);
      expect(state.gate, AccountGate.suspended);
      expect(
        const AccountState(role: 'user', isSuspended: true, deletionStatus: 'pending').gate,
        AccountGate.suspended,
      );
      expect(
        const AccountState(role: 'user', isSuspended: true, deletionStatus: 'rejected').gate,
        AccountGate.suspended,
      );
    });

    test('deletion states are tested before the suspension flag', () {
      // The server suspends the account while its deletion is processed.
      const processing = AccountState(
        role: 'user',
        isSuspended: true,
        deletionStatus: 'processing',
      );
      const completed = AccountState(
        role: 'courier',
        isSuspended: true,
        forcePasswordChange: true,
        deletionStatus: 'completed',
      );
      expect(processing.gate, AccountGate.deletionProcessing);
      expect(completed.gate, AccountGate.deleted);
      expect(processing.isBlocked, isTrue);
      expect(completed.isBlocked, isTrue);
    });

    test('deletion in progress or completed blocks the account', () {
      const processing = AccountState(role: 'user', deletionStatus: 'processing');
      const completed = AccountState(role: 'user', deletionStatus: 'completed');
      expect(processing.gate, AccountGate.deletionProcessing);
      expect(completed.gate, AccountGate.deleted);
      expect(processing.isBlocked, isTrue);
      expect(completed.isBlocked, isTrue);
    });

    test('a pending or rejected deletion request does not block the account', () {
      const pending = AccountState(role: 'user', deletionStatus: 'pending');
      const rejected = AccountState(role: 'user', deletionStatus: 'rejected');
      expect(pending.isBlocked, isFalse);
      expect(pending.deletionPending, isTrue);
      expect(pending.gate, AccountGate.community);
      expect(rejected.deletionRejected, isTrue);
      expect(rejected.gate, AccountGate.community);
    });

    test('staff are routed by role', () {
      expect(const AccountState(role: 'admin').gate, AccountGate.admin);
      expect(const AccountState(role: 'supervisor').gate, AccountGate.supervisor);
      expect(const AccountState(role: 'courier').gate, AccountGate.courier);
      expect(const AccountState(role: 'user').gate, AccountGate.community);
    });

    test('a forced password change applies to staff only', () {
      expect(
        const AccountState(role: 'user', forcePasswordChange: true).gate,
        AccountGate.community,
      );
      expect(
        const AccountState(role: 'supervisor', forcePasswordChange: true).gate,
        AccountGate.passwordChange,
      );
    });
  });

  group('OperationRules', () {
    test('donations can be cancelled only before matching', () {
      for (final status in ['draft', 'submitted', 'under_review', 'available']) {
        expect(OperationRules.canCancel(kind: 'donation', status: status), isTrue, reason: status);
      }
      for (final status in ['matched', 'pickup_scheduled', 'picked_up', 'delivered', 'cancelled', 'rejected']) {
        expect(OperationRules.canCancel(kind: 'donation', status: status), isFalse, reason: status);
      }
    });

    test('needs can be cancelled only before matching', () {
      for (final status in ['submitted', 'waiting', 'candidate_found', 'confirmed']) {
        expect(OperationRules.canCancel(kind: 'need', status: status), isTrue, reason: status);
      }
      for (final status in ['matched', 'delivery_scheduled', 'fulfilled', 'cancelled', 'expired']) {
        expect(OperationRules.canCancel(kind: 'need', status: status), isFalse, reason: status);
      }
    });

    test('other operation kinds have no cancel action here', () {
      expect(OperationRules.canCancel(kind: 'item_processing', status: 'available'), isFalse);
      expect(OperationRules.canCancel(kind: 'delivery', status: 'assigned'), isFalse);
      expect(OperationRules.canCancel(kind: 'service_offer', status: 'submitted'), isFalse);
    });

    test('a proposed service match opens the offers screen', () {
      expect(
        OperationRules.actionRoute(kind: 'service_match', status: 'proposed', serverRoute: '/my-services'),
        '/offers?tab=1',
      );
      expect(
        OperationRules.actionRoute(kind: 'service_match', status: 'scheduled', serverRoute: '/my-services'),
        '/my-services',
      );
      expect(
        OperationRules.actionRoute(kind: 'item_match', status: 'offered', serverRoute: '/offers'),
        '/offers',
      );
    });

    test('delivered and cancelled deliveries are closed for the community', () {
      expect(OperationRules.closedDeliveryStatuses, {'delivered', 'failed'});
      expect(OperationRules.isDeliveryClosed('delivered'), isTrue);
      expect(OperationRules.isDeliveryClosed('failed'), isTrue);
      for (final status in ['assigned', 'heading_to_pickup', 'picked_up', 'heading_to_recipient', 'rescheduled']) {
        expect(OperationRules.isDeliveryClosed(status), isFalse, reason: status);
      }
    });

    test('the continue button is shown only when there is somewhere to go', () {
      bool shows(String kind, String status, {bool requires = true, String route = '/my-services'}) =>
          OperationRules.showsAction(
            kind: kind,
            status: status,
            requiresAction: requires,
            serverRoute: route,
          );
      expect(shows('item_match', 'offered', route: '/offers'), isTrue);
      expect(shows('service_match', 'proposed'), isTrue);
      expect(shows('service_match', 'proposed', requires: false), isFalse);
      expect(shows('delivery', 'rescheduled', route: '/handoffs'), isFalse);
      expect(shows('service_offer', 'rejected'), isFalse);
      expect(shows('service_offer', 'cancelled'), isFalse);
      expect(shows('service_offer', 'withdrawn'), isFalse);
      expect(shows('service_request', 'rejected'), isFalse);
      expect(shows('service_request', 'cancelled'), isFalse);
      expect(shows('service_request', 'matched'), isTrue);
    });

    test('a notification about a proposed service match opens the offers screen', () {
      expect(
        OperationRules.notificationRoute(
          entityType: 'service_matches',
          dedupeKey: 'service_matches:provider:1b2c:proposed',
          serverRoute: '/my-services',
        ),
        '/offers?tab=1',
      );
      expect(
        OperationRules.notificationRoute(
          entityType: 'service_matches',
          dedupeKey: 'service_matches:requester:1b2c:scheduled',
          serverRoute: '/my-services',
        ),
        '/my-services',
      );
      expect(
        OperationRules.notificationRoute(
          entityType: 'service_offers',
          dedupeKey: 'service_offers:1b2c:proposed',
          serverRoute: '/my-services',
        ),
        '/my-services',
      );
      expect(
        OperationRules.notificationRoute(entityType: null, dedupeKey: null, serverRoute: '/handoffs'),
        '/handoffs',
      );
    });

    test('a request id is added to tab routes that take one', () {
      expect(OperationRules.withRequestId('/offers?tab=1', 7), '/offers?tab=1&t=7');
      expect(OperationRules.withRequestId('/offers', 7), '/offers?t=7');
      expect(OperationRules.withRequestId('/handoffs?tab=2&t=1', 9), '/handoffs?tab=2&t=9');
      expect(OperationRules.withRequestId('/my-services', 7), '/my-services');
      expect(OperationRules.withRequestId('/home', 7), '/home');
    });

    test('greeting follows the local hour', () {
      expect(OperationRules.greetingForHour(4), 'صباح الخير');
      expect(OperationRules.greetingForHour(11), 'صباح الخير');
      expect(OperationRules.greetingForHour(12), 'مساء الخير');
      expect(OperationRules.greetingForHour(20), 'مساء الخير');
      expect(OperationRules.greetingForHour(2), 'مساء الخير');
    });

    test('first name is the first word of a real name', () {
      expect(OperationRules.firstName('محمد أحمد الصالح'), 'محمد');
      expect(OperationRules.firstName('  سارة  '), 'سارة');
      expect(OperationRules.firstName('محمد\tعلي'), 'محمد');
      expect(OperationRules.firstName(''), isNull);
      expect(OperationRules.firstName('   '), isNull);
      expect(OperationRules.firstName(null), isNull);
      expect(OperationRules.firstName('user@example.com'), isNull);
      expect(OperationRules.firstName('777000001'), isNull);
    });

    test('home greeting adds the first name when known', () {
      expect(OperationRules.greetingWithName(20, 'محمد أحمد'), 'مساء الخير، محمد');
      expect(OperationRules.greetingWithName(9, 'سارة'), 'صباح الخير، سارة');
      expect(OperationRules.greetingWithName(9, null), 'صباح الخير');
      expect(OperationRules.greetingWithName(20, ' '), 'مساء الخير');
    });
  });
}
