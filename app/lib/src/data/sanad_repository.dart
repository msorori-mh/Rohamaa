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

  Future<String> createDonation({
    required String title,
    required String description,
    required String condition,
    String category = 'other',
    String? addressId,
  }) async {
    final row = await _client.from('donations').insert({
      'public_code': _publicCode('DON'),
      'user_id': userId,
      'category': category,
      'item_type': title,
      'description': description.isEmpty ? null : description,
      'condition': condition,
      'address_id': addressId,
      'status': 'submitted',
    }).select('id').single();
    return row['id'] as String;
  }

  Future<String> createNeed({
    required String title,
    required String reason,
    required bool acceptsUsed,
    String category = 'other',
    String? addressId,
  }) async {
    final row = await _client.from('needs').insert({
      'public_code': _publicCode('NEED'),
      'user_id': userId,
      'category': category,
      'item_type': title,
      'reason': reason,
      'accepts_used': acceptsUsed,
      'address_id': addressId,
      'status': 'submitted',
    }).select('id').single();
    return row['id'] as String;
  }

  Future<String?> defaultAddressId() async {
    final rows = await _client
        .from('addresses')
        .select('id,service_area_id')
        .eq('user_id', userId)
        .not('service_area_id', 'is', null)
        .order('is_default', ascending: false)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return rows.first['id'] as String;
  }

  Future<bool> hasOperationalProfile() async {
    final profile = await _client.from('profiles').select('phone').eq('id', userId).single();
    final addresses = await _client
        .from('addresses')
        .select('id,service_area_id')
        .eq('user_id', userId)
        .not('service_area_id', 'is', null)
        .limit(1);
    final phone = (profile['phone'] as String?)?.trim() ?? '';
    return phone.isNotEmpty && (addresses as List).isNotEmpty;
  }
}
