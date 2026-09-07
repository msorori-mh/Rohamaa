import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/pilot_rules.dart';

void main() {
  group('PilotRules', () {
    test('accepts only configured contribution amounts', () {
      expect(PilotRules.isAllowedContribution(1000), isTrue);
      expect(PilotRules.isAllowedContribution(5000), isTrue);
      expect(PilotRules.isAllowedContribution(1500), isFalse);
      expect(PilotRules.isAllowedContribution(0), isFalse);
    });

    test('handoff PIN must be exactly four digits', () {
      expect(PilotRules.isValidHandoffPin('0000'), isTrue);
      expect(PilotRules.isValidHandoffPin('4821'), isTrue);
      expect(PilotRules.isValidHandoffPin('482'), isFalse);
      expect(PilotRules.isValidHandoffPin('48a1'), isFalse);
    });

    test('donation image limit is four', () {
      expect(PilotRules.canUploadMoreImages(0), isTrue);
      expect(PilotRules.canUploadMoreImages(3), isTrue);
      expect(PilotRules.canUploadMoreImages(4), isFalse);
    });
  });
}
