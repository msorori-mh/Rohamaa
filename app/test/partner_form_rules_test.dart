import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/partner_form_rules.dart';

void main() {
  group('PartnerFormRules phone', () {
    test('accepts 9-digit Yemeni mobiles starting with 7', () {
      expect(PartnerFormRules.normalizeYemenMobile('777000001'), '777000001');
      expect(PartnerFormRules.normalizeYemenMobile('712345678'), '712345678');
      expect(PartnerFormRules.validatePhone('777000001'), isNull);
    });

    test('accepts the optional country and trunk prefixes', () {
      expect(PartnerFormRules.normalizeYemenMobile('+967777000001'), '777000001');
      expect(PartnerFormRules.normalizeYemenMobile('00967777000001'), '777000001');
      expect(PartnerFormRules.normalizeYemenMobile('0777000001'), '777000001');
      expect(PartnerFormRules.normalizeYemenMobile('+967 777-000-001'), '777000001');
    });

    test('accepts Arabic-Indic digits', () {
      expect(PartnerFormRules.normalizeYemenMobile('٧٧٧٠٠٠٠٠١'), '777000001');
      expect(PartnerFormRules.asciiDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    });

    test('rejects other numbers', () {
      for (final value in [
        '',
        '   ',
        '77700000',
        '7770000012',
        '677000001',
        '01234567',
        '+966777000001',
        '77700000a',
        '967777000001',
      ]) {
        expect(PartnerFormRules.normalizeYemenMobile(value), isNull, reason: value);
      }
      expect(PartnerFormRules.normalizeYemenMobile(null), isNull);
    });

    test('validator messages', () {
      expect(PartnerFormRules.validatePhone(null), isNotNull);
      expect(PartnerFormRules.validatePhone(''), isNotNull);
      expect(PartnerFormRules.validatePhone('12345'), isNotNull);
      expect(PartnerFormRules.validatePhone('+967 777 000 001'), isNull);
      // Valid digits, but longer than the 20 characters the server stores.
      expect(PartnerFormRules.validatePhone('+967  7  7  7  0  0  0  0  0  1'), isNotNull);
    });
  });

  group('PartnerFormRules text and capacity', () {
    test('name needs 3 to 120 characters', () {
      expect(PartnerFormRules.validateName(null), isNotNull);
      expect(PartnerFormRules.validateName(' اب '), isNotNull);
      expect(PartnerFormRules.validateName('صالون'), isNull);
      expect(PartnerFormRules.validateName('ا' * 120), isNull);
      expect(PartnerFormRules.validateName('ا' * 121), isNotNull);
    });

    test('description is optional up to 2000 characters', () {
      expect(PartnerFormRules.validateDescription(null), isNull);
      expect(PartnerFormRules.validateDescription(''), isNull);
      expect(PartnerFormRules.validateDescription('ا' * 2000), isNull);
      expect(PartnerFormRules.validateDescription('ا' * 2001), isNotNull);
    });

    test('capacity is a whole number between 1 and 100', () {
      expect(PartnerFormRules.parseCapacity('4'), 4);
      expect(PartnerFormRules.parseCapacity(' 100 '), 100);
      expect(PartnerFormRules.parseCapacity('١٢'), 12);
      expect(PartnerFormRules.parseCapacity('0'), isNull);
      expect(PartnerFormRules.parseCapacity('101'), isNull);
      expect(PartnerFormRules.parseCapacity('2.5'), isNull);
      expect(PartnerFormRules.parseCapacity('abc'), isNull);
      expect(PartnerFormRules.parseCapacity(null), isNull);
      expect(PartnerFormRules.validateCapacity('4'), isNull);
      expect(PartnerFormRules.validateCapacity('0'), isNotNull);
    });
  });
}
