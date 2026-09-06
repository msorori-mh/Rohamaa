import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryTask {
  const DeliveryTask({
    required this.id,
    required this.publicCode,
    required this.status,
  });

  final String id;
  final String publicCode;
  final String status;

  factory DeliveryTask.fromJson(Map<String, dynamic> json) => DeliveryTask(
        id: json['id'] as String,
        publicCode: json['public_code'] as String,
        status: json['status'] as String,
      );
}

class DeliveryRepository {
  DeliveryRepository(this._client);
  final SupabaseClient _client;

  Future<List<DeliveryTask>> myTasks() async {
    final rows = await _client
        .from('deliveries')
        .select('id, public_code, status')
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(DeliveryTask.fromJson)
        .toList();
  }

  Future<bool> verifyPin({
    required String deliveryId,
    required String pin,
    required String kind,
    double? latitude,
    double? longitude,
  }) async {
    final result = await _client.rpc('verify_delivery_pin', params: {
      'p_delivery_id': deliveryId,
      'p_pin': pin,
      'p_kind': kind,
      'p_latitude': latitude,
      'p_longitude': longitude,
    });
    return result == true;
  }
}
