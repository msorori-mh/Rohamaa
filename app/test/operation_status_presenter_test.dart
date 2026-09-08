import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/operation_status_presenter.dart';

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
      expect(copy.nextStep, contains('فريق رحماء'));
    });

    test('gives fulfilled needs a completed outcome', () {
      final copy = OperationStatusPresenter.present('need', 'fulfilled');
      expect(copy.label, 'تم تلبية الطلب');
      expect(copy.attention, isFalse);
    });
  });
}
