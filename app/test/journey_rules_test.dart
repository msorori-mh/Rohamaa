import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/journey_rules.dart';

void main() {
  group('JourneyRules', () {
    test('every journey has five labelled steps', () {
      expect(JourneyRules.donationSteps, hasLength(JourneyRules.stepCount));
      expect(JourneyRules.needSteps, hasLength(JourneyRules.stepCount));
      expect(JourneyRules.stepsFor('donation')[2], 'وُجد من يحتاجه');
      expect(JourneyRules.stepsFor('need')[2], 'وُجد ما يناسبك');
    });

    test('donation statuses map to their step', () {
      const expected = <String, int>{
        'draft': 0,
        'submitted': 0,
        'under_review': 1,
        'available': 1,
        'matched': 2,
        'pickup_scheduled': 2,
        'picked_up': 3,
        'out_for_delivery': 3,
        'delivered': 4,
      };
      for (final entry in expected.entries) {
        expect(JourneyRules.currentStep('donation', entry.key), entry.value, reason: entry.key);
      }
    });

    test('need statuses map to their step', () {
      const expected = <String, int>{
        'submitted': 0,
        'waiting': 1,
        'confirmed': 1,
        'candidate_found': 2,
        'matched': 2,
        'delivery_scheduled': 2,
        'fulfilled': 4,
      };
      for (final entry in expected.entries) {
        expect(JourneyRules.currentStep('need', entry.key), entry.value, reason: entry.key);
      }
    });

    test('stopped, unknown and other kinds have no step', () {
      expect(JourneyRules.currentStep('donation', 'cancelled'), isNull);
      expect(JourneyRules.currentStep('donation', 'rejected'), isNull);
      expect(JourneyRules.currentStep('need', 'cancelled'), isNull);
      expect(JourneyRules.currentStep('need', 'expired'), isNull);
      expect(JourneyRules.currentStep('donation', 'some_future_status'), isNull);
      expect(JourneyRules.currentStep('delivery', 'picked_up'), isNull);
      expect(JourneyRules.hasJourney('service_offer'), isFalse);
      expect(JourneyRules.hasJourney('need'), isTrue);
    });

    test('in progress means started and not arrived', () {
      expect(JourneyRules.isInProgress('donation', 'submitted'), isTrue);
      expect(JourneyRules.isInProgress('donation', 'picked_up'), isTrue);
      expect(JourneyRules.isInProgress('donation', 'delivered'), isFalse);
      expect(JourneyRules.isInProgress('donation', 'cancelled'), isFalse);
      expect(JourneyRules.isInProgress('need', 'waiting'), isTrue);
      expect(JourneyRules.isInProgress('need', 'fulfilled'), isFalse);
      expect(JourneyRules.isComplete('need', 'fulfilled'), isTrue);
      expect(JourneyRules.isComplete('donation', 'matched'), isFalse);
    });

    test('progress segments follow the step', () {
      expect(JourneyRules.filledSegments('donation', 'submitted'), 1);
      expect(JourneyRules.filledSegments('donation', 'matched'), 3);
      expect(JourneyRules.filledSegments('donation', 'delivered'), 5);
      expect(JourneyRules.filledSegments('donation', 'cancelled'), 0);
    });
  });
}
