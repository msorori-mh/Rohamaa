/// The five-step journey a donation or a request goes through, as shown on
/// the home card and in the follow-up list. Derived only from the status the
/// server reports; nothing here is stored.
abstract final class JourneyRules {
  static const stepCount = 5;

  static const donationSteps = <String>[
    'أُرسل',
    'راجعه الفريق',
    'وُجد من يحتاجه',
    'استلمه الموصل',
    'وصل',
  ];

  static const needSteps = <String>[
    'أُرسل',
    'راجعه الفريق',
    'وُجد ما يناسبك',
    'استلمه الموصل',
    'وصل',
  ];

  /// Whether [kind] is an operation that has a journey.
  static bool hasJourney(String kind) => kind == 'donation' || kind == 'need';

  /// Step labels for [kind] ('donation' or 'need').
  static List<String> stepsFor(String kind) =>
      kind == 'need' ? needSteps : donationSteps;

  /// Index (0-4) of the step the operation has reached, or null when the
  /// status is not part of the journey: a withdrawn, rejected or expired
  /// operation, an unknown status, or a kind without a journey.
  static int? currentStep(String kind, String status) {
    if (kind == 'donation') {
      return switch (status) {
        'draft' || 'submitted' => 0,
        'under_review' || 'available' => 1,
        'matched' || 'pickup_scheduled' => 2,
        'picked_up' || 'out_for_delivery' => 3,
        'delivered' => 4,
        _ => null,
      };
    }
    if (kind == 'need') {
      return switch (status) {
        'submitted' => 0,
        'waiting' || 'confirmed' => 1,
        'candidate_found' || 'matched' || 'delivery_scheduled' => 2,
        'fulfilled' => 4,
        _ => null,
      };
    }
    return null;
  }

  /// True when the journey reached its last step (delivered / fulfilled).
  static bool isComplete(String kind, String status) =>
      currentStep(kind, status) == stepCount - 1;

  /// True for a donation or a request that is still on its way: it has a
  /// journey step and has not arrived yet. These are the operations the home
  /// card can show.
  static bool isInProgress(String kind, String status) {
    final step = currentStep(kind, status);
    return step != null && step < stepCount - 1;
  }

  /// How many of the five progress segments are filled.
  static int filledSegments(String kind, String status) {
    final step = currentStep(kind, status);
    return step == null ? 0 : step + 1;
  }
}
