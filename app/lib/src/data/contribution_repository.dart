import 'package:supabase_flutter/supabase_flutter.dart';

class ContributionRepository {
  ContributionRepository(this._client);
  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('User must be authenticated');
    return id;
  }

  Future<void> createContribution({
    required int amountYer,
    required String paymentMethod,
    String? paymentReference,
    String? donationId,
    String? needId,
    String? deliveryId,
  }) async {
    final code = 'PAY-MRB-${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('contributions').insert({
      'public_code': code,
      'user_id': _userId,
      'donation_id': donationId,
      'need_id': needId,
      'delivery_id': deliveryId,
      'amount_yer': amountYer,
      'payment_method': paymentMethod,
      'payment_reference': paymentReference?.trim().isEmpty == true ? null : paymentReference?.trim(),
      'status': 'pending',
    });
  }
}
