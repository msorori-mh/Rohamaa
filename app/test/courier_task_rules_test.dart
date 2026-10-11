import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/courier_task_rules.dart';

void main() {
  group('CourierTaskRules PIN validation', () {
    test('accepts exactly four digits', () {
      expect(CourierTaskRules.isValidPin('0000'), isTrue);
      expect(CourierTaskRules.isValidPin('4821'), isTrue);
      expect(CourierTaskRules.isValidPin(' 4821 '), isTrue);
      expect(CourierTaskRules.pinError('4821'), isNull);
    });

    test('rejects empty, short, long and non-digit input with a message', () {
      for (final value in <String?>[null, '', '   ', '12', '123', '12345']) {
        expect(CourierTaskRules.isValidPin(value), isFalse, reason: 'value: $value');
        expect(CourierTaskRules.pinError(value), isNotNull, reason: 'value: $value');
      }
      for (final value in ['12a4', 'abcd', '12 4', '-123', '12.4']) {
        expect(CourierTaskRules.isValidPin(value), isFalse, reason: value);
        expect(CourierTaskRules.pinError(value), isNotNull, reason: value);
      }
    });

    test('Arabic-Indic and Persian digits are normalized to ASCII', () {
      expect(CourierTaskRules.normalizedPin(' ١٢٣٤ '), '1234');
      expect(CourierTaskRules.normalizedPin('۰۹۸۷'), '0987');
      expect(CourierTaskRules.normalizedPin(null), '');
      expect(CourierTaskRules.isValidPin('١٢٣٤'), isTrue);
      expect(CourierTaskRules.pinError('١٢٣٤'), isNull);
      expect(CourierTaskRules.pinError('١٢٣'), isNotNull);
      expect(CourierTaskRules.pinInputPattern.hasMatch('٧'), isTrue);
      expect(CourierTaskRules.pinInputPattern.hasMatch('7'), isTrue);
      expect(CourierTaskRules.pinInputPattern.hasMatch('a'), isFalse);
    });

    test('messages distinguish empty, non-digit and wrong length', () {
      final empty = CourierTaskRules.pinError('');
      final letters = CourierTaskRules.pinError('12a4');
      final short = CourierTaskRules.pinError('123');
      expect({empty, letters, short}.length, 3);
    });

    test('rejected-PIN copy covers every cause and asks for a new code', () {
      const message = CourierTaskRules.pinRejectedMessage;
      expect(message, contains('غير صحيح'));
      expect(message, contains('انتهت صلاحيته'));
      expect(message, contains('لم يُصدر بعد'));
      expect(message, contains('اطلب من صاحب العملية إظهار رمز جديد'));
      // Remaining attempts are not knowable client-side.
      expect(RegExp(r'[0-9]').hasMatch(message), isFalse);
    });
  });

  group('CourierTaskRules failure report', () {
    test('parties and reasons match the server contract', () {
      expect(CourierTaskRules.failureParties.keys.toSet(), {
        'donor',
        'beneficiary',
        'courier',
        'other',
      });
      expect(CourierTaskRules.failureReasons.keys.toSet(), {
        'no_answer',
        'not_present',
        'wrong_address',
        'item_not_ready',
        'item_rejected',
        'vehicle_issue',
        'weather',
        'other',
      });
    });

    test('every party and reason has an Arabic label', () {
      final arabic = RegExp(r'[؀-ۿ]');
      final latin = RegExp(r'[A-Za-z_]');
      for (final label in [
        ...CourierTaskRules.failureParties.values,
        ...CourierTaskRules.failureReasons.values,
      ]) {
        expect(arabic.hasMatch(label), isTrue, reason: label);
        expect(latin.hasMatch(label), isFalse, reason: label);
      }
      expect(CourierTaskRules.failurePartyLabel('donor'), 'المتبرع');
      expect(CourierTaskRules.failureReasonLabel('no_answer'), 'لا يوجد رد');
    });

    test('unknown codes fall back to a neutral label', () {
      expect(CourierTaskRules.failurePartyLabel('alien'), 'طرف آخر');
      expect(CourierTaskRules.failureReasonLabel('alien'), 'سبب آخر');
    });

    test('note is optional and limited to 500 characters', () {
      expect(CourierTaskRules.failureNoteMaxLength, 500);
      expect(CourierTaskRules.failureNoteError(null), isNull);
      expect(CourierTaskRules.failureNoteError(''), isNull);
      expect(CourierTaskRules.failureNoteError('ا' * 500), isNull);
      expect(CourierTaskRules.failureNoteError('ا' * 501), isNotNull);
    });

    test('empty notes are sent as null and others are trimmed', () {
      expect(CourierTaskRules.normalizedNote(null), isNull);
      expect(CourierTaskRules.normalizedNote('   '), isNull);
      expect(CourierTaskRules.normalizedNote('  لم يرد  '), 'لم يرد');
    });
  });

  group('CourierTaskRules contact links', () {
    test('builds a tel: URI and strips formatting', () {
      expect(CourierTaskRules.telUri('777000001').toString(), 'tel:777000001');
      expect(
        CourierTaskRules.telUri('+967 777-000-001').toString(),
        'tel:+967777000001',
      );
    });

    test('returns null when no dialable number is present', () {
      expect(CourierTaskRules.telUri(null), isNull);
      expect(CourierTaskRules.telUri(''), isNull);
      expect(CourierTaskRules.telUri('لا يوجد'), isNull);
      expect(CourierTaskRules.telUri('+'), isNull);
    });

    test('builds the Google Maps search URI for a coordinate', () {
      expect(
        CourierTaskRules.mapsUri(15.4, 45.3).toString(),
        'https://www.google.com/maps/search/?api=1&query=15.4,45.3',
      );
    });

    test('returns null for missing or impossible coordinates', () {
      expect(CourierTaskRules.mapsUri(null, 45.3), isNull);
      expect(CourierTaskRules.mapsUri(15.4, null), isNull);
      expect(CourierTaskRules.mapsUri(91, 45.3), isNull);
      expect(CourierTaskRules.mapsUri(15.4, 181), isNull);
      expect(CourierTaskRules.mapsUri(double.nan, 45.3), isNull);
    });
  });

  test('cash pledge answer labels cover all three states', () {
    final labels = {
      CourierTaskRules.pledgeAnswerLabel(null),
      CourierTaskRules.pledgeAnswerLabel(true),
      CourierTaskRules.pledgeAnswerLabel(false),
    };
    expect(labels.length, 3);
  });
}
