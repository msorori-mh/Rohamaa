import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/delivery_dispatch_rules.dart';

class DeliveryTask {
  const DeliveryTask({
    required this.id,
    required this.publicCode,
    required this.status,
    this.offerExpiresAt,
  });

  final String id;
  final String publicCode;
  final String status;
  final DateTime? offerExpiresAt;

  factory DeliveryTask.fromJson(Map<String, dynamic> json) => DeliveryTask(
        id: json['id'] as String,
        publicCode: json['public_code'] as String,
        status: json['status'] as String,
        offerExpiresAt: json['offer_expires_at'] == null
            ? null
            : DateTime.tryParse('${json['offer_expires_at']}'),
      );
}

class CourierTaskDetails {
  const CourierTaskDetails({
    required this.deliveryId,
    required this.publicCode,
    required this.status,
    this.pickupArea,
    this.pickupDescription,
    this.pickupLatitude,
    this.pickupLongitude,
    this.pickupPhone,
    this.dropoffArea,
    this.dropoffDescription,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.dropoffPhone,
  });

  final String deliveryId;
  final String publicCode;
  final String status;
  final String? pickupArea;
  final String? pickupDescription;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String? pickupPhone;
  final String? dropoffArea;
  final String? dropoffDescription;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final String? dropoffPhone;

  factory CourierTaskDetails.fromJson(Map<String, dynamic> j) =>
      CourierTaskDetails(
        deliveryId: j['delivery_id'] as String,
        publicCode: j['public_code'] as String,
        status: j['status'] as String,
        pickupArea: j['pickup_area'] as String?,
        pickupDescription: j['pickup_description'] as String?,
        pickupLatitude: (j['pickup_latitude'] as num?)?.toDouble(),
        pickupLongitude: (j['pickup_longitude'] as num?)?.toDouble(),
        pickupPhone: j['pickup_phone'] as String?,
        dropoffArea: j['dropoff_area'] as String?,
        dropoffDescription: j['dropoff_description'] as String?,
        dropoffLatitude: (j['dropoff_latitude'] as num?)?.toDouble(),
        dropoffLongitude: (j['dropoff_longitude'] as num?)?.toDouble(),
        dropoffPhone: j['dropoff_phone'] as String?,
      );
}

/// A cash contribution pledged for a delivery that the courier collects.
class CashPledge {
  const CashPledge({
    required this.contributionId,
    required this.publicCode,
    required this.amountYer,
    this.courierReceived,
  });

  final String contributionId;
  final String publicCode;
  final int amountYer;

  /// null = the courier has not answered yet.
  final bool? courierReceived;

  factory CashPledge.fromJson(Map<String, dynamic> json) => CashPledge(
        contributionId: '${json['contribution_id']}',
        publicCode: '${json['public_code'] ?? ''}',
        amountYer: (json['amount_yer'] as num?)?.toInt() ?? 0,
        courierReceived: json['courier_received'] as bool?,
      );
}

/// The task is no longer assigned to this courier (reassigned, cancelled or
/// completed), so `courier_task_details` returned no row.
class TaskUnavailableException implements Exception {
  const TaskUnavailableException();

  @override
  String toString() => 'TaskUnavailableException';
}

class DeliveryRepository {
  DeliveryRepository(this._client);
  final SupabaseClient _client;

  /// Open tasks visible to the signed-in courier (RLS scopes the rows).
  /// Closed states are filtered here rather than in the query so that a
  /// status value the database enum does not have can never break the load.
  Future<List<DeliveryTask>> myTasks() async {
    final rows = await _client
        .from('deliveries')
        .select('id, public_code, status, offer_expires_at')
        .neq('status', 'delivered')
        .order('created_at')
        .limit(200);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(DeliveryTask.fromJson)
        .where((task) => !DeliveryDispatchRules.isClosed(task.status))
        .toList();
  }

  Future<CourierTaskDetails> details(String deliveryId) async {
    final rows = await _client.rpc(
      'courier_task_details',
      params: {'p_delivery_id': deliveryId},
    );
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) throw const TaskUnavailableException();
    return CourierTaskDetails.fromJson(list.first);
  }

  /// Returns false when the PIN is wrong, expired, not issued yet or out of
  /// attempts; the server does not say which.
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

  Future<String> respond({
    required String deliveryId,
    required bool accept,
    String? reason,
  }) async {
    final result = await _client.rpc('courier_respond_delivery', params: {
      'p_delivery_id': deliveryId,
      'p_accept': accept,
      'p_reason': reason,
    });
    return '$result';
  }

  Future<void> startDropoff(String deliveryId) async {
    await _client.rpc(
      'courier_start_dropoff',
      params: {'p_delivery_id': deliveryId},
    );
  }

  Future<void> reportFailure({
    required String deliveryId,
    required String party,
    required String reasonCode,
    String? note,
    double? latitude,
    double? longitude,
  }) async {
    await _client.rpc('courier_report_delivery_failure', params: {
      'p_delivery_id': deliveryId,
      'p_party': party,
      'p_reason_code': reasonCode,
      'p_note': note,
      'p_latitude': latitude,
      'p_longitude': longitude,
    });
  }

  Future<List<CashPledge>> cashPledges(String deliveryId) async {
    final rows = await _client.rpc(
      'courier_delivery_cash_pledges',
      params: {'p_delivery_id': deliveryId},
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(CashPledge.fromJson)
        .toList();
  }

  Future<void> confirmCashPledge({
    required String contributionId,
    required bool received,
  }) async {
    await _client.rpc('courier_confirm_cash_pledge', params: {
      'p_contribution_id': contributionId,
      'p_received': received,
    });
  }
}
