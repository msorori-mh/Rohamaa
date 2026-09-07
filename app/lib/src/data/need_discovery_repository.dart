import 'package:supabase_flutter/supabase_flutter.dart';

class NeedDiscoveryCard {
  const NeedDiscoveryCard({
    required this.id,
    required this.category,
    required this.itemType,
    required this.title,
    required this.detail,
    required this.cityLabel,
    required this.waitDays,
  });

  final String id;
  final String category;
  final String itemType;
  final String title;
  final String? detail;
  final String cityLabel;
  final int waitDays;

  factory NeedDiscoveryCard.fromMap(Map<String, dynamic> row) {
    return NeedDiscoveryCard(
      id: '${row['card_id']}',
      category: '${row['category']}',
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
    final rows = await _client.rpc('discovery_need_cards', params: {
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
        .select('id,public_code,category,item_type,description,reason,accepts_used,status,created_at')
        .inFilter('status', ['submitted', 'waiting', 'candidate_found'])
        .order('created_at', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminCards() async {
    final rows = await _client
        .from('need_discovery_cards')
        .select('id,need_id,category,item_type,display_title,display_detail,city_label,is_active,published_at,updated_at')
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
