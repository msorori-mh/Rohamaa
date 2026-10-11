import 'package:supabase_flutter/supabase_flutter.dart';

/// A row the server just created: its id and the server-generated code.
class CreatedOperation {
  const CreatedOperation({required this.id, required this.publicCode});

  final String id;
  final String publicCode;
}

class ItemRepositoryV2 {
  ItemRepositoryV2(this._client);

  final SupabaseClient _client;

  String get userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('User must be authenticated');
    return id;
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
    return rows.first['id'] as String?;
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

  /// Creates a donation. `public_code` and `status` are set by the server
  /// and read back from the insert response.
  Future<CreatedOperation> createDonation({
    required String category,
    required String categoryGroup,
    required String itemTypeKey,
    required String title,
    required String condition,
    required Map<String, String> attributes,
    String? description,
    String? addressId,
    String? inspiredByDiscoveryCardId,
  }) async {
    final cleanAttributes = Map<String, String>.fromEntries(
      attributes.entries.where((entry) => entry.value.trim().isNotEmpty),
    );
    final row = await _client.from('donations').insert({
      'user_id': userId,
      'category': category,
      'category_version': 2,
      'category_group': categoryGroup,
      'item_type_key': itemTypeKey,
      'item_attributes': cleanAttributes,
      'item_type': title.trim(),
      'condition': condition,
      'description': description == null || description.trim().isEmpty ? null : description.trim(),
      'address_id': addressId,
      'inspired_by_discovery_card_id': inspiredByDiscoveryCardId,
    }).select('id,public_code').single();
    return CreatedOperation(
      id: row['id'] as String,
      publicCode: '${row['public_code'] ?? ''}',
    );
  }

  /// Creates a need. `public_code` and `status` are set by the server and
  /// read back from the insert response.
  Future<CreatedOperation> createNeed({
    required String category,
    required String categoryGroup,
    required String itemTypeKey,
    required String title,
    required Map<String, String> attributes,
    required String privateDetails,
    required bool acceptsUsed,
    String? addressId,
  }) async {
    final cleanAttributes = Map<String, String>.fromEntries(
      attributes.entries.where((entry) => entry.value.trim().isNotEmpty),
    );
    final row = await _client.from('needs').insert({
      'user_id': userId,
      'category': category,
      'category_version': 2,
      'category_group': categoryGroup,
      'item_type_key': itemTypeKey,
      'item_attributes': cleanAttributes,
      'item_type': title.trim(),
      'reason': privateDetails.trim(),
      'accepts_used': acceptsUsed,
      'address_id': addressId,
    }).select('id,public_code').single();
    return CreatedOperation(
      id: row['id'] as String,
      publicCode: '${row['public_code'] ?? ''}',
    );
  }
}
