import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/operation_status_presenter.dart';

/// Every status `user_operations_center` can return, per operation kind
/// (database enums and check constraints).
const _statusesByKind = <String, List<String>>{
  'donation': [
    'draft', 'submitted', 'under_review', 'available', 'matched', 'pickup_scheduled',
    'picked_up', 'out_for_delivery', 'delivered', 'cancelled', 'rejected',
  ],
  'need': [
    'submitted', 'waiting', 'candidate_found', 'confirmed', 'matched',
    'delivery_scheduled', 'fulfilled', 'cancelled', 'expired',
  ],
  'item_match': ['offered', 'accepted', 'declined', 'cancelled'],
  'item_processing': [
    'inspection_pending', 'cleaning_queued', 'cleaning', 'repair_queued', 'repairing',
    'ready_for_distribution', 'recycling', 'recycled', 'withdrawn',
  ],
  'delivery': [
    'assigned', 'heading_to_pickup', 'picked_up', 'heading_to_recipient',
    'delivered', 'failed', 'rescheduled',
  ],
  'service_offer': [
    'submitted', 'approved', 'paused', 'matched', 'completed', 'rejected', 'cancelled', 'withdrawn',
  ],
  'service_request': [
    'submitted', 'reviewing', 'matched', 'scheduled', 'completed', 'rejected', 'cancelled',
  ],
  'service_match': ['proposed', 'accepted', 'declined', 'scheduled', 'completed', 'cancelled'],
};

final _latinOrUnderscore = RegExp(r'[A-Za-z_]');

void main() {
  group('OperationStatusPresenter', () {
    test('marks an offered match as requiring a user decision', () {
      final copy = OperationStatusPresenter.present('item_match', 'offered');
      expect(copy.attention, isTrue);
      expect(copy.label, 'ينتظر قرارك');
    });

    test('explains delivery failures without exposing private details', () {
      final copy = OperationStatusPresenter.present('delivery', 'failed');
      expect(copy.attention, isTrue);
      expect(copy.nextStep, contains('فريق عطاء'));
    });

    test('gives fulfilled needs a completed outcome', () {
      final copy = OperationStatusPresenter.present('need', 'fulfilled');
      expect(copy.label, 'تم تلبية الطلب');
      expect(copy.attention, isFalse);
    });

    test('every database status has dedicated Arabic copy', () {
      for (final entry in _statusesByKind.entries) {
        for (final status in entry.value) {
          final copy = OperationStatusPresenter.present(entry.key, status);
          final reason = '${entry.key}:$status';
          expect(copy.label, isNot(OperationStatusPresenter.fallbackLabel), reason: reason);
          expect(copy.label.trim(), isNotEmpty, reason: reason);
          expect(copy.nextStep.trim(), isNotEmpty, reason: reason);
          expect(_latinOrUnderscore.hasMatch(copy.label), isFalse, reason: reason);
          expect(_latinOrUnderscore.hasMatch(copy.nextStep), isFalse, reason: reason);
        }
      }
    });

    test('an unknown status shows a neutral label, never the raw key', () {
      final copy = OperationStatusPresenter.present('donation', 'some_future_status');
      expect(copy.label, OperationStatusPresenter.fallbackLabel);
      expect(copy.label.contains('some_future_status'), isFalse);
      expect(copy.label.contains('_'), isFalse);
      expect(copy.nextStep.trim(), isNotEmpty);

      final unknownKind = OperationStatusPresenter.present('new_kind', 'submitted');
      expect(unknownKind.label, OperationStatusPresenter.fallbackLabel);
    });

    test('a withdrawal by the person is not presented as a problem', () {
      expect(OperationStatusPresenter.present('donation', 'cancelled').attention, isFalse);
      expect(OperationStatusPresenter.present('need', 'cancelled').attention, isFalse);
      expect(OperationStatusPresenter.present('service_offer', 'cancelled').attention, isFalse);
      expect(OperationStatusPresenter.present('donation', 'rejected').attention, isTrue);
    });

    test('kind labels are Arabic and unknown kinds get a neutral label', () {
      for (final kind in _statusesByKind.keys) {
        expect(_latinOrUnderscore.hasMatch(OperationStatusPresenter.kindLabel(kind)), isFalse, reason: kind);
      }
      expect(OperationStatusPresenter.kindLabel('new_kind'), 'متابعة عطاء');
    });

    test('handoff copy differs for the donor and the recipient', () {
      final donor = OperationStatusPresenter.presentHandoff('pickup', 'heading_to_pickup');
      final recipient = OperationStatusPresenter.presentHandoff('delivery', 'heading_to_pickup');
      expect(donor.label, isNot(recipient.label));
      expect(donor.attention, isTrue);
      expect(recipient.attention, isFalse);

      final arriving = OperationStatusPresenter.presentHandoff('delivery', 'heading_to_recipient');
      expect(arriving.attention, isTrue);
      expect(arriving.nextStep, contains('رمز التسليم'));
    });

    test('handoff copy falls back to the delivery copy for shared statuses', () {
      for (final kind in ['pickup', 'delivery']) {
        for (final status in ['delivered', 'failed', 'rescheduled']) {
          final copy = OperationStatusPresenter.presentHandoff(kind, status);
          final expected = OperationStatusPresenter.present('delivery', status);
          expect(copy.label, expected.label, reason: '$kind:$status');
        }
      }
    });
  });
}
