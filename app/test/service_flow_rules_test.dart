import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/service_flow_rules.dart';

void main() {
  // Every value allowed by the SQL checks on the three service tables.
  const offerStatuses = ['submitted', 'approved', 'paused', 'matched', 'completed', 'rejected', 'cancelled'];
  const requestStatuses = ['submitted', 'reviewing', 'matched', 'scheduled', 'completed', 'rejected', 'cancelled'];
  const matchStatuses = ['proposed', 'accepted', 'declined', 'scheduled', 'completed', 'cancelled'];
  const verificationStatuses = ['pending', 'verified', 'rejected'];
  final latin = RegExp('[A-Za-z_]');

  group('withdraw and cancel eligibility', () {
    test('an offer can be withdrawn only before it is matched', () {
      expect(ServiceFlowRules.canWithdrawOffer('submitted'), isTrue);
      expect(ServiceFlowRules.canWithdrawOffer('approved'), isTrue);
      expect(ServiceFlowRules.canWithdrawOffer('paused'), isTrue);
      for (final status in ['matched', 'completed', 'rejected', 'cancelled', 'unknown', null]) {
        expect(ServiceFlowRules.canWithdrawOffer(status), isFalse, reason: '$status');
      }
    });

    test('a request can be cancelled only before it is matched', () {
      expect(ServiceFlowRules.canCancelRequest('submitted'), isTrue);
      expect(ServiceFlowRules.canCancelRequest('reviewing'), isTrue);
      for (final status in ['matched', 'scheduled', 'completed', 'rejected', 'cancelled', 'unknown', null]) {
        expect(ServiceFlowRules.canCancelRequest(status), isFalse, reason: '$status');
      }
    });

    test('eligible statuses are real statuses of their tables', () {
      expect(offerStatuses.toSet().containsAll(ServiceFlowRules.withdrawableOfferStatuses), isTrue);
      expect(requestStatuses.toSet().containsAll(ServiceFlowRules.cancellableRequestStatuses), isTrue);
    });
  });

  group('Arabic status labels', () {
    test('every offer status and verification pair has an Arabic label', () {
      for (final status in offerStatuses) {
        for (final verification in verificationStatuses) {
          final label = ServiceFlowRules.offerStatusLabel(status, verification);
          expect(label.trim(), isNotEmpty);
          expect(latin.hasMatch(label), isFalse, reason: '$status/$verification -> $label');
        }
      }
    });

    test('offer labels reflect the state the person cares about', () {
      expect(ServiceFlowRules.offerStatusLabel('submitted', 'pending'), 'قيد مراجعة عطاء');
      expect(ServiceFlowRules.offerStatusLabel('approved', 'verified'), 'متاح للمطابقة');
      expect(ServiceFlowRules.offerStatusLabel('paused', 'verified'), 'متوقف مؤقتًا');
      expect(ServiceFlowRules.offerStatusLabel('submitted', 'rejected'), 'يحتاج مراجعة أو تعديل');
      // A withdrawn offer says so even though it was never verified.
      expect(ServiceFlowRules.offerStatusLabel('cancelled', 'pending'), 'تم السحب');
      expect(ServiceFlowRules.offerStatusLabel('matched', 'verified'), 'تم العثور على احتياج مناسب');
    });

    test('every request and match status has an Arabic label', () {
      for (final status in requestStatuses) {
        final label = ServiceFlowRules.requestStatusLabel(status);
        expect(label.trim(), isNotEmpty);
        expect(latin.hasMatch(label), isFalse, reason: '$status -> $label');
      }
      for (final status in matchStatuses) {
        final label = ServiceFlowRules.matchStatusLabel(status);
        expect(label.trim(), isNotEmpty);
        expect(latin.hasMatch(label), isFalse, reason: '$status -> $label');
      }
      expect(ServiceFlowRules.requestStatusLabel('cancelled'), 'تم الإلغاء');
      expect(ServiceFlowRules.matchStatusLabel('scheduled'), 'تم ترتيب الموعد');
    });

    test('unknown values never leak the raw status', () {
      for (final label in [
        ServiceFlowRules.offerStatusLabel('new_status', 'verified'),
        ServiceFlowRules.offerStatusLabel(null, null),
        ServiceFlowRules.requestStatusLabel('new_status'),
        ServiceFlowRules.requestStatusLabel(null),
        ServiceFlowRules.matchStatusLabel('new_status'),
        ServiceFlowRules.matchStatusLabel(null),
      ]) {
        expect(label.trim(), isNotEmpty);
        expect(latin.hasMatch(label), isFalse, reason: label);
      }
    });
  });

  group('service form validators', () {
    test('hours must be above 0 and at most 24', () {
      expect(ServiceFlowRules.parseHours('3'), 3);
      expect(ServiceFlowRules.parseHours(' 1.5 '), 1.5);
      expect(ServiceFlowRules.parseHours('1,5'), 1.5);
      expect(ServiceFlowRules.parseHours('٣'), 3);
      expect(ServiceFlowRules.parseHours('24'), 24);
      expect(ServiceFlowRules.parseHours('0'), isNull);
      expect(ServiceFlowRules.parseHours('-2'), isNull);
      expect(ServiceFlowRules.parseHours('24.5'), isNull);
      expect(ServiceFlowRules.parseHours('abc'), isNull);
      expect(ServiceFlowRules.parseHours(null), isNull);
      expect(ServiceFlowRules.validateHours('3'), isNull);
      expect(ServiceFlowRules.validateHours('30'), isNotNull);
    });

    test('title, details and notes respect server limits', () {
      expect(ServiceFlowRules.validateTitle('اب', emptyMessage: 'مطلوب'), 'مطلوب');
      expect(ServiceFlowRules.validateTitle('سباكة', emptyMessage: 'مطلوب'), isNull);
      expect(ServiceFlowRules.validateTitle('ا' * 161, emptyMessage: 'مطلوب'), isNotNull);
      expect(ServiceFlowRules.validateDetails('قصير', emptyMessage: 'مطلوب'), 'مطلوب');
      expect(ServiceFlowRules.validateDetails('إصلاح تسريب في المطبخ', emptyMessage: 'مطلوب'), isNull);
      expect(ServiceFlowRules.validateDetails('ا' * 2001, emptyMessage: 'مطلوب'), isNotNull);
      expect(ServiceFlowRules.validateOptionalNote(null), isNull);
      expect(ServiceFlowRules.validateOptionalNote('ا' * 2001), isNotNull);
    });
  });
}
