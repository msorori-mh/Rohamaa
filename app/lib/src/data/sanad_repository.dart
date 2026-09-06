import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SanadRepository {
  SanadRepository(this._client);
  final SupabaseClient _client;
  static const _uuid = Uuid();

  String get userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('User must be authenticated');
    return id;
  }

  String _publicCode(String prefix) {
    final suffix = _uuid.v4().replaceAll('-', '').substring(0, 10).toUpperCase();
    return 'SND-MRB-$prefix-$suffix';
  }

  Future<void> createDonation({
    required String title,
    required String description,
    required String condition,
    String category = 'other',
  }) async {
    await _client.from('donations').insert({
      'public_code': _publicCode('DON'),
      'user_id': userId,
      'category': category,
      'item_type': title,
      'description': description.isEmpty ? null : description,
      'condition': condition,
      'status': 'submitted',
    });
  }

  Future<void> createNeed({
    required String title,
    required String reason,
    required bool acceptsUsed,
    String category = 'other',
  }) async {
    await _client.from('needs').insert({
      'public_code': _publicCode('NEED'),
      'user_id': userId,
      'category': category,
      'item_type': title,
      'reason': reason,
      'accepts_used': acceptsUsed,
      'status': 'submitted',
    });
  }
}
