import 'package:supabase_flutter/supabase_flutter.dart';

import 'staff_repository.dart' show StaffFunctionException;

class AdminStats {
  const AdminStats({
    required this.donations,
    required this.needs,
    required this.deliveries,
    required this.pendingContributions,
    required this.openRiskFlags,
  });

  final int donations;
  final int needs;
  final int deliveries;
  final int pendingContributions;
  final int openRiskFlags;
}

class AdminRepository {
  AdminRepository(this._client);
  final SupabaseClient _client;

  /// Page size of the user management list.
  static const usersPageSize = 50;

  /// Upper bound for admin queues that are loaded in one request.
  static const queueLimit = 200;

  Future<String> myRole() async {
    final id = _client.auth.currentUser!.id;
    final row =
        await _client.from('profiles').select('role').eq('id', id).single();
    return row['role'] as String? ?? 'user';
  }

  static int _asCount(Object? value) => value is int ? value : 0;

  /// Dashboard counters. Uses PostgREST exact counts (one row fetched per
  /// query) instead of downloading id lists, and runs the queries together.
  Future<AdminStats> stats() async {
    Future<int> donations() async {
      final response = await _client
          .from('donations')
          .select('id')
          .inFilter('status', ['submitted', 'under_review', 'available'])
          .limit(1)
          .count(CountOption.exact);
      return _asCount(response.count);
    }

    Future<int> needs() async {
      final response = await _client
          .from('needs')
          .select('id')
          .inFilter('status', ['submitted', 'waiting', 'candidate_found'])
          .limit(1)
          .count(CountOption.exact);
      return _asCount(response.count);
    }

    Future<int> deliveries() async {
      final response = await _client
          .from('deliveries')
          .select('id')
          .neq('status', 'delivered')
          .limit(1)
          .count(CountOption.exact);
      return _asCount(response.count);
    }

    Future<int> contributions() async {
      final response = await _client
          .from('contributions')
          .select('id')
          .eq('status', 'pending')
          .limit(1)
          .count(CountOption.exact);
      return _asCount(response.count);
    }

    Future<int> risks() async {
      final response = await _client
          .from('risk_flags')
          .select('id')
          .eq('resolved', false)
          .limit(1)
          .count(CountOption.exact);
      return _asCount(response.count);
    }

    final results = await Future.wait<int>([
      donations(),
      needs(),
      deliveries(),
      contributions(),
      risks(),
    ]);
    return AdminStats(
      donations: results[0],
      needs: results[1],
      deliveries: results[2],
      pendingContributions: results[3],
      openRiskFlags: results[4],
    );
  }

  Future<List<Map<String, dynamic>>> donationsQueue() async {
    final rows = await _client
        .from('donations')
        .select(
          'id,public_code,category,category_version,category_group,'
          'item_type_key,item_attributes,item_type,condition,status,created_at',
        )
        .inFilter('status', ['submitted', 'under_review', 'available'])
        .order('created_at')
        .limit(queueLimit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> matchCandidates(String donationId) async {
    final raw = await _client.rpc('admin_match_candidates', params: {
      'p_donation_id': donationId,
      'p_limit': 20,
    });
    final candidates = (raw as List).cast<Map<String, dynamic>>();
    if (candidates.isEmpty) return candidates;

    final ids = candidates.map((row) => '${row['need_id']}').toList();
    final detailRows = await _client
        .from('needs')
        .select(
          'id,category,category_version,category_group,item_type_key,'
          'item_attributes,item_type,accepts_used',
        )
        .inFilter('id', ids);
    final byId = <String, Map<String, dynamic>>{
      for (final row in (detailRows as List).cast<Map<String, dynamic>>())
        '${row['id']}': row,
    };
    return candidates.map((row) {
      final detail = byId['${row['need_id']}'];
      return {...row, if (detail != null) ...detail};
    }).toList();
  }

  Future<String> approveMatch(String donationId, String needId) async {
    final result = await _client.rpc(
      'admin_approve_match',
      params: {'p_donation_id': donationId, 'p_need_id': needId},
    );
    return result as String;
  }

  /// Signed, short-lived URLs of a donation's photos for reviewers.
  /// A photo whose URL cannot be signed is skipped instead of failing all.
  Future<List<String>> donationImageUrls(String donationId) async {
    final rows = await _client.rpc(
      'admin_donation_image_paths',
      params: {'p_donation_id': donationId},
    );
    final paths = (rows as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['storage_path'])
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toList();
    final urls = <String>[];
    for (final path in paths) {
      try {
        urls.add(
          await _client.storage
              .from('donation-images')
              .createSignedUrl(path, 600),
        );
      } catch (_) {
        // One unreadable photo must not hide the others.
      }
    }
    return urls;
  }

  Future<List<Map<String, dynamic>>> acceptedMatchesAwaitingDelivery() async {
    final rows = await _client.rpc('admin_accepted_matches_queue');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> pendingContributions() async {
    final rows = await _client
        .from('contributions')
        .select(
          'id,public_code,amount_yer,payment_method,payment_reference,'
          'created_at,courier_received',
        )
        .eq('status', 'pending')
        .order('created_at')
        .limit(queueLimit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> verifyContribution(
    String id,
    bool verified, {
    String? note,
  }) async {
    await _client.rpc('admin_verify_contribution', params: {
      'p_contribution_id': id,
      'p_verified': verified,
      'p_note': note,
    });
  }

  Future<List<Map<String, dynamic>>> riskQueue() async {
    final rows = await _client
        .from('risk_flags')
        .select(
          'id,rule_code,severity,details,created_at,user_id,need_id,'
          'donation_id,delivery_id',
        )
        .eq('resolved', false)
        .order('created_at')
        .limit(queueLimit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> resolveRisk(String id, String resolution) async {
    await _client.rpc(
      'admin_resolve_risk',
      params: {'p_risk_id': id, 'p_resolution': resolution},
    );
  }

  /// One page of profiles, newest first. [from] is the zero-based offset.
  Future<List<Map<String, dynamic>>> users({
    int from = 0,
    int limit = usersPageSize,
  }) async {
    final rows = await _client
        .from('profiles')
        .select(
          'id,full_name,phone,staff_email,role,is_suspended,is_primary_admin,'
          'force_password_change,created_at',
        )
        .order('created_at', ascending: false)
        .range(from, from + limit - 1);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> setUserRole(String userId, String role) async {
    await _client.rpc(
      'admin_set_user_role',
      params: {'p_user_id': userId, 'p_role': role},
    );
  }

  Future<void> setUserSuspension(
    String userId,
    bool suspended,
    String reason,
  ) async {
    await _client.rpc('admin_set_user_suspension', params: {
      'p_user_id': userId,
      'p_suspended': suspended,
      'p_reason': reason,
    });
  }

  Future<List<Map<String, dynamic>>> activeCouriers() async {
    final rows = await _client
        .from('couriers')
        .select('user_id,active,profiles!inner(full_name)')
        .eq('active', true);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> activeVehicles() async {
    final rows = await _client
        .from('vehicles')
        .select('id,code,kind,active')
        .eq('active', true)
        .order('code');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createDelivery({
    required String matchId,
    required String courierId,
    String? vehicleId,
  }) async {
    final rows = await _client.rpc('admin_create_delivery', params: {
      'p_match_id': matchId,
      'p_courier_id': courierId,
      'p_vehicle_id': vehicleId,
    });
    return (rows as List).cast<Map<String, dynamic>>().single;
  }

  Future<List<Map<String, dynamic>>> deliveryDispatchQueue() async {
    final rows = await _client.rpc('admin_delivery_dispatch_queue');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> reassignDelivery({
    required String deliveryId,
    required String courierId,
    String? vehicleId,
  }) async {
    await _client.rpc('admin_reassign_delivery', params: {
      'p_delivery_id': deliveryId,
      'p_courier_id': courierId,
      'p_vehicle_id': vehicleId,
    });
  }

  Future<void> cancelDelivery({
    required String deliveryId,
    required String reason,
  }) async {
    await _client.rpc('admin_cancel_delivery', params: {
      'p_delivery_id': deliveryId,
      'p_reason': reason,
    });
  }

  /// Rows: request_id, user_id, full_name, requested_at, status,
  /// open_operations.
  Future<List<Map<String, dynamic>>> accountDeletionQueue() async {
    final rows = await _client.rpc('admin_account_deletion_queue');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Approves (irreversibly deletes the account) or rejects a deletion
  /// request through the `admin-delete-account` Edge Function. Returns the
  /// resulting status (`completed` or `rejected`). Throws
  /// [StaffFunctionException] when the function rejects the request.
  Future<String> decideAccountDeletion({
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'admin-delete-account',
        body: {
          'request_id': requestId,
          'approve': approve,
          'note': note ?? '',
        },
      );
      final data = response.data;
      if (data is Map && data['status'] is String) {
        return data['status'] as String;
      }
      return approve ? 'completed' : 'rejected';
    } on FunctionException catch (error) {
      throw StaffFunctionException.from(error);
    }
  }
}
