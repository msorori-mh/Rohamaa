import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/risk_flag_presenter.dart';

void main() {
  group('RiskFlagPresenter', () {
    test('every rule code raised by the database has an Arabic label', () {
      const codes = [
        'HIGH_REQUEST_VELOCITY',
        'REPEAT_FULFILLED_CATEGORY',
        'ADDRESS_CHURN',
        'REPEATED_DELIVERY_NO_SHOW',
        'INVALID_DELIVERY_PIN',
        'many_open_needs',
        'high_need_request_velocity',
      ];
      final latin = RegExp(r'[A-Za-z_]');
      for (final code in codes) {
        final label = RiskFlagPresenter.ruleLabel(code);
        expect(label, isNotEmpty, reason: code);
        expect(latin.hasMatch(label), isFalse, reason: code);
      }
    });

    test('unknown rule codes are shown neutrally with the code for support',
        () {
      expect(
        RiskFlagPresenter.ruleLabel('BRAND_NEW_RULE'),
        'إشارة تحتاج مراجعة (BRAND_NEW_RULE)',
      );
      expect(RiskFlagPresenter.ruleLabel(null), 'إشارة تحتاج مراجعة');
      expect(RiskFlagPresenter.ruleLabel(''), 'إشارة تحتاج مراجعة');
    });

    test('severity labels cover the database enum', () {
      expect(RiskFlagPresenter.severityLabel('low'), 'منخفضة');
      expect(RiskFlagPresenter.severityLabel('medium'), 'متوسطة');
      expect(RiskFlagPresenter.severityLabel('high'), 'عالية');
      expect(RiskFlagPresenter.severityLabel('critical'), 'حرجة');
      expect(RiskFlagPresenter.severityLabel('weird'), 'غير محددة');
      expect(RiskFlagPresenter.severityLabel(null), 'غير محددة');
      expect(RiskFlagPresenter.isUrgent('high'), isTrue);
      expect(RiskFlagPresenter.isUrgent('critical'), isTrue);
      expect(RiskFlagPresenter.isUrgent('medium'), isFalse);
      expect(RiskFlagPresenter.isUrgent(null), isFalse);
    });

    test('details JSON becomes readable key/value lines', () {
      expect(
        RiskFlagPresenter.detailLines({'prior_24h': 5}),
        ['طلبات خلال آخر 24 ساعة: 5'],
      );
      expect(
        RiskFlagPresenter.detailLines({
          'fulfilled_last_120d': 2,
          'category': 'clothes',
        }),
        ['طلبات ملبّاة خلال 120 يومًا: 2', 'الفئة: ملابس'],
      );
      expect(
        RiskFlagPresenter.detailLines({'kind': 'pickup'}),
        ['مرحلة الرمز: الاستلام من المتبرع'],
      );
      expect(
        RiskFlagPresenter.detailLines({'kind': 'delivery'}),
        ['مرحلة الرمز: التسليم لصاحب الطلب'],
      );
      expect(
        RiskFlagPresenter.detailLines({
          'failures_60d': 3,
          'latest_reason': 'no_answer',
        }),
        ['حالات تعذر خلال 60 يومًا: 3', 'آخر سبب: لا يوجد رد'],
      );
    });

    test('unknown detail keys are shown neutrally, not dropped', () {
      expect(
        RiskFlagPresenter.detailLines({'mystery_metric': 7}),
        ['معلومة إضافية (mystery_metric): 7'],
      );
    });

    test('booleans, nulls and nested values are handled safely', () {
      expect(
        RiskFlagPresenter.detailLines({'mystery': true, 'other': null}),
        ['معلومة إضافية (mystery): نعم', 'معلومة إضافية (other): غير متوفر'],
      );
      expect(
        RiskFlagPresenter.detailLines({
          'nested': {'a': 1},
          'list': [1, 2],
          'open_need_count': 6,
        }),
        ['الطلبات المفتوحة: 6'],
      );
    });

    test('missing or malformed details produce no lines', () {
      expect(RiskFlagPresenter.detailLines(null), isEmpty);
      expect(RiskFlagPresenter.detailLines('text'), isEmpty);
      expect(RiskFlagPresenter.detailLines(<String, dynamic>{}), isEmpty);
    });
  });
}
