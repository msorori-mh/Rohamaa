import 'package:supabase_flutter/supabase_flutter.dart';

class SanadRepository {
  SanadRepository(this._client);
  final SupabaseClient _client;

  String get userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('User must be authenticated');
    return id;
  }

  Future<void> createDonation({
    required String title,
    required String description,
    required String condition,
  }) async {
    await _client.from('donations').insert({
      'donor_id': userId,
      'title': title,
      'description': description,
      'condition': condition,
      'status': 'submitted',
    });
  }

  Future<void> createNeed({
    required String title,
    required String reason,
    required bool acceptsUsed,
  }) async {
    await _client.from('needs').insert({
      'requester_id': userId,
      'title': title,
      'reason': reason,
      'accepts_used': acceptsUsed,
      'status': 'submitted',
    });
  }
}
