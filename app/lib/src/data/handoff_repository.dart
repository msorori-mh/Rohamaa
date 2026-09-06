import 'package:supabase_flutter/supabase_flutter.dart';

class UserHandoff {
  const UserHandoff({
    required this.deliveryId,
    required this.deliveryCode,
    required this.kind,
    required this.itemCode,
    required this.itemType,
    required this.status,
  });

  final String deliveryId;
  final String deliveryCode;
  final String kind;
  final String itemCode;
  final String itemType;
  final String status;

  factory UserHandoff.fromJson(Map<String, dynamic> json) => UserHandoff(
        deliveryId: json['delivery_id'] as String,
        deliveryCode: json['delivery_code'] as String,
        kind: json['handoff_kind'] as String,
        itemCode: json['item_code'] as String,
        itemType: json['item_type'] as String,
        status: json['delivery_status'] as String,
      );
}

class HandoffRepository {
  HandoffRepository(this._client);
  final SupabaseClient _client;

  Future<List<UserHandoff>> myHandoffs() async {
    final rows = await _client.rpc('user_my_handoffs');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(UserHandoff.fromJson)
        .toList();
  }

  Future<String> issuePin({required String deliveryId, required String kind}) async {
    final result = await _client.rpc('user_issue_handoff_pin', params: {
      'p_delivery_id': deliveryId,
      'p_kind': kind,
    });
    return result as String;
  }
}
