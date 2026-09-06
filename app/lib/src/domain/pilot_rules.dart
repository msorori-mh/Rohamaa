class PilotRules {
  PilotRules._();

  static const contributionAmountsYer = <int>[1000, 2000, 3000, 4000, 5000];
  static const maxDonationImages = 4;
  static const handoffPinLength = 4;

  static bool isAllowedContribution(int amount) =>
      contributionAmountsYer.contains(amount);

  static bool isValidHandoffPin(String pin) =>
      pin.length == handoffPinLength && int.tryParse(pin) != null;

  static bool canUploadMoreImages(int currentCount) =>
      currentCount >= 0 && currentCount < maxDonationImages;
}
