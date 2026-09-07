import 'package:supabase_flutter/supabase_flutter.dart';

class NeedDiscoveryCard {
  const NeedDiscoveryCard({
    required this.id,
    required this.category,
    required this.categoryGroup,
    required this.itemTypeKey,
    required this.attributes,
    required this.itemType,
    required this.title,
    required this.detail,
    required this.cityLabel,
    required this.waitDays,
  });

  final String id;
  final String category;
  final String? categoryGroup;
  final String? itemTypeKey;
  final Map<String, String> attributes;
  final String itemType;
  final String title;
  final String? detail;
  final String cityLabel;
  final int waitDays;

  factory NeedDiscoveryCard.fromMap(Map<String, dynamic> row) {
    final rawAttributes = row['item_attributes'];
    final attributes = rawAttributes is Map
        ? rawAttributes.map((key, value) => MapEntry('$key', '$value')).cast<String, String>()
        : <String, String>{};
    return NeedDiscoveryCard(
      id: '${row['card_id']}',
      category: '${row['category']}',
      categoryGroup: row['category_group'] as String?,
      itemTypeKey: row['item_type_key'] as String?,
      attributes: attributes,
      itemType: '${row['item_type']}',
      title: '${row['display_title']}',
      detail: row['display_detail'] as String?,
      cityLabel: '${row['city_label']}',
      waitDays: (row['wait_days'] as num?)?.toInt() ?? 0,
    );
  }
}

class NeedDiscoveryRepository {
  NeedDiscoveryRepository(this._client);

  final SupabaseClient _client;

  Future<List<NeedDiscoveryCard>> cards({String? category, int limit = 30}) async {
    final rows = await _client.rpc('discovery_need_cards_v2', params: {
      'p_category': category,
      'p_limit': limit,
    });
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(NeedDiscoveryCard.fromMap)
        .toList();
  }

  Future<List<Map<String, dynamic>>> adminOpenNeeds() async {
    final rows = await _client
        .from('needs')
        .select('id,public_code,category,category_version,category_group,item_type_key,item_attributes,item_type,description,reason,accepts_used,status,created_at')
        .inFilter('status', ['submitted', 'waiting', 'candidate_found'])
        .order('created_at', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminCards() async {
    final rows = await _client
        .from('need_discovery_cards')
        .select('id,need_id,category,category_group,item_type_key,item_attributes,item_type,display_title,display_detail,city_label,is_active,published_at,updated_at')
        .order('published_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<String> publish({
    required String needId,
    required String title,
    required String detail,
    String cityLabel = 'مأرب',
  }) async {
    final id = await _client.rpc('admin_publish_need_discovery_card', params: {
      'p_need_id': needId,
      'p_display_title': title,
      'p_display_detail': detail,
      'p_city_label': cityLabel,
    });
    return id as String;
  }

  Future<void> unpublish(String cardId) async {
    await _client.rpc('admin_unpublish_need_discovery_card', params: {
      'p_card_id': cardId,
    });
  }
}
