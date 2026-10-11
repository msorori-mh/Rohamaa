import 'package:supabase_flutter/supabase_flutter.dart';

class ContributionRepository {
  ContributionRepository(this._client);
  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('User must be authenticated');
    return id;
  }

  /// The code of the person's pending pledge for the same donation or need,
  /// or null when there is none. A pledge that is not tied to an operation is
  /// never treated as a duplicate.
  Future<String?> pendingPledgeCode({
    String? donationId,
    String? needId,
  }) async {
    if (donationId == null && needId == null) return null;
    var query = _client
        .from('contributions')
        .select('public_code')
        .eq('user_id', _userId)
        .eq('status', 'pending');
    if (donationId != null) query = query.eq('donation_id', donationId);
    if (needId != null) query = query.eq('need_id', needId);
    final rows = await query.limit(1);
    if ((rows as List).isEmpty) return null;
    return '${rows.first['public_code'] ?? ''}';
  }

  /// Registers a cash-to-courier pledge and returns its server-generated
  /// code. `public_code`, `status`, `verified_by` and `verified_at` are set by
  /// the server and are never sent from the app.
  Future<String> createContribution({
    required int amountYer,
    String? donationId,
    String? needId,
    String? deliveryId,
  }) async {
    final row = await _client.from('contributions').insert({
      'user_id': _userId,
      'donation_id': donationId,
      'need_id': needId,
      'delivery_id': deliveryId,
      'amount_yer': amountYer,
      'payment_method': 'cash_to_courier',
      'payment_reference': null,
    }).select('public_code').single();
    return '${row['public_code'] ?? ''}';
  }
}
