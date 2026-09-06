import 'package:supabase_flutter/supabase_flutter.dart';

class MatchOffer {
  const MatchOffer({
    required this.matchId,
    required this.needCode,
    required this.donationCode,
    required this.itemType,
    required this.category,
    required this.condition,
  });

  final String matchId;
  final String needCode;
  final String donationCode;
  final String itemType;
  final String category;
  final String? condition;

  factory MatchOffer.fromJson(Map<String, dynamic> json) => MatchOffer(
        matchId: json['match_id'] as String,
        needCode: json['need_code'] as String,
        donationCode: json['donation_code'] as String,
        itemType: json['item_type'] as String,
        category: json['category'] as String,
        condition: json['item_condition'] as String?,
      );
}

class MatchOfferRepository {
  MatchOfferRepository(this._client);
  final SupabaseClient _client;

  Future<List<MatchOffer>> pendingOffers() async {
    final rows = await _client.rpc('user_pending_match_offers');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(MatchOffer.fromJson)
        .toList();
  }

  Future<void> respond(String matchId, {required bool accept}) async {
    await _client.rpc('user_respond_match_offer', params: {
      'p_match_id': matchId,
      'p_accept': accept,
    });
  }
}
