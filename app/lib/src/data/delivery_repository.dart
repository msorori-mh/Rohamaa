import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryTask {
  const DeliveryTask({required this.id, required this.publicCode, required this.status});
  final String id;
  final String publicCode;
  final String status;
  factory DeliveryTask.fromJson(Map<String, dynamic> json) => DeliveryTask(id: json['id'] as String, publicCode: json['public_code'] as String, status: json['status'] as String);
}

class CourierTaskDetails {
  const CourierTaskDetails({
    required this.deliveryId, required this.publicCode, required this.status,
    this.pickupArea, this.pickupDescription, this.pickupLatitude, this.pickupLongitude, this.pickupPhone,
    this.dropoffArea, this.dropoffDescription, this.dropoffLatitude, this.dropoffLongitude, this.dropoffPhone,
  });
  final String deliveryId; final String publicCode; final String status;
  final String? pickupArea; final String? pickupDescription; final double? pickupLatitude; final double? pickupLongitude; final String? pickupPhone;
  final String? dropoffArea; final String? dropoffDescription; final double? dropoffLatitude; final double? dropoffLongitude; final String? dropoffPhone;
  factory CourierTaskDetails.fromJson(Map<String,dynamic> j)=>CourierTaskDetails(
    deliveryId:j['delivery_id'] as String, publicCode:j['public_code'] as String, status:j['status'] as String,
    pickupArea:j['pickup_area'] as String?, pickupDescription:j['pickup_description'] as String?, pickupLatitude:(j['pickup_latitude'] as num?)?.toDouble(), pickupLongitude:(j['pickup_longitude'] as num?)?.toDouble(), pickupPhone:j['pickup_phone'] as String?,
    dropoffArea:j['dropoff_area'] as String?, dropoffDescription:j['dropoff_description'] as String?, dropoffLatitude:(j['dropoff_latitude'] as num?)?.toDouble(), dropoffLongitude:(j['dropoff_longitude'] as num?)?.toDouble(), dropoffPhone:j['dropoff_phone'] as String?,
  );
}

class DeliveryRepository {
  DeliveryRepository(this._client);
  final SupabaseClient _client;

  Future<List<DeliveryTask>> myTasks() async {
    final rows = await _client.from('deliveries').select('id, public_code, status').neq('status','delivered').order('created_at');
    return (rows as List).cast<Map<String,dynamic>>().map(DeliveryTask.fromJson).toList();
  }

  Future<CourierTaskDetails> details(String deliveryId) async {
    final rows = await _client.rpc('courier_task_details', params: {'p_delivery_id': deliveryId});
    final list = (rows as List).cast<Map<String,dynamic>>();
    if (list.isEmpty) throw StateError('Task not available');
    return CourierTaskDetails.fromJson(list.first);
  }

  Future<bool> verifyPin({required String deliveryId, required String pin, required String kind, double? latitude, double? longitude}) async {
    final result = await _client.rpc('verify_delivery_pin', params: {'p_delivery_id': deliveryId,'p_pin': pin,'p_kind': kind,'p_latitude': latitude,'p_longitude': longitude});
    return result == true;
  }
}
