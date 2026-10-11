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

    test('suspension wins over every other state', () {
      const state = AccountState(
        role: 'admin',
        isSuspended: true,
        forcePasswordChange: true,
        deletionStatus: 'processing',
      );
      expect(state.isBlocked, isTrue);
      expect(state.gate, AccountGate.suspended);
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

    test('greeting follows the local hour', () {
      expect(OperationRules.greetingForHour(4), 'صباح الخير');
      expect(OperationRules.greetingForHour(11), 'صباح الخير');
      expect(OperationRules.greetingForHour(12), 'مساء الخير');
      expect(OperationRules.greetingForHour(20), 'مساء الخير');
      expect(OperationRules.greetingForHour(2), 'مساء الخير');
    });
  });
}
