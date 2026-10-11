import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/contact_rules.dart';

void main() {
  group('ContactRules.normalizeYemenMobile', () {
    test('accepts a 9-digit local number starting with 7', () {
      expect(ContactRules.normalizeYemenMobile('777000001'), '777000001');
      expect(ContactRules.normalizeYemenMobile('712345678'), '712345678');
    });

    test('accepts the +967, 00967 and 0 prefixes', () {
      expect(ContactRules.normalizeYemenMobile('+967777000001'), '777000001');
      expect(ContactRules.normalizeYemenMobile('00967777000001'), '777000001');
      expect(ContactRules.normalizeYemenMobile('0777000001'), '777000001');
    });

    test('ignores spaces and dashes and understands Arabic digits', () {
      expect(ContactRules.normalizeYemenMobile(' +967 777-000-001 '), '777000001');
      expect(ContactRules.normalizeYemenMobile('٧٧٧٠٠٠٠٠١'), '777000001');
    });

    test('rejects numbers that are not Yemen mobile numbers', () {
      expect(ContactRules.normalizeYemenMobile(null), isNull);
      expect(ContactRules.normalizeYemenMobile(''), isNull);
      expect(ContactRules.normalizeYemenMobile('1234567'), isNull);
      expect(ContactRules.normalizeYemenMobile('77700000'), isNull);
      expect(ContactRules.normalizeYemenMobile('7770000011'), isNull);
      expect(ContactRules.normalizeYemenMobile('677000001'), isNull);
      expect(ContactRules.normalizeYemenMobile('01234567'), isNull);
      expect(ContactRules.normalizeYemenMobile('77700000a'), isNull);
      expect(ContactRules.normalizeYemenMobile('+966777000001'), isNull);
    });
  });

  group('ContactRules validators', () {
    test('phone validator returns a message only for invalid input', () {
      expect(ContactRules.validatePhone('777000001'), isNull);
      expect(ContactRules.validatePhone('+967 777 000 001'), isNull);
      expect(ContactRules.validatePhone(''), isNotNull);
      expect(ContactRules.validatePhone(null), isNotNull);
      expect(ContactRules.validatePhone('1234567'), isNotNull);
    });

    test('name is required and limited to 120 characters', () {
      expect(ContactRules.validateFullName('أحمد علي'), isNull);
      expect(ContactRules.validateFullName('   '), isNotNull);
      expect(ContactRules.validateFullName('أ'), isNotNull);
      expect(ContactRules.validateFullName('a' * ContactRules.maxNameLength), isNull);
      expect(ContactRules.validateFullName('a' * (ContactRules.maxNameLength + 1)), isNotNull);
    });

    test('area is required', () {
      expect(ContactRules.validateArea('الروضة'), isNull);
      expect(ContactRules.validateArea(' '), isNotNull);
      expect(ContactRules.validateArea('a' * (ContactRules.maxAreaLength + 1)), isNotNull);
    });

    test('description is optional only when a GPS position exists', () {
      expect(ContactRules.validateDescription('', hasPosition: true), isNull);
      expect(ContactRules.validateDescription('', hasPosition: false), isNotNull);
      expect(ContactRules.validateDescription('قرب', hasPosition: false), isNotNull);
      expect(ContactRules.validateDescription('بجوار المسجد الكبير', hasPosition: false), isNull);
      expect(
        ContactRules.validateDescription(
          'a' * (ContactRules.maxDescriptionLength + 1),
          hasPosition: true,
        ),
        isNotNull,
      );
    });
  });
}
