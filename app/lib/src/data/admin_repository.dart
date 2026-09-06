import 'package:supabase_flutter/supabase_flutter.dart';

class AdminStats {
  const AdminStats({required this.donations, required this.needs, required this.deliveries, required this.pendingContributions, required this.openRiskFlags});
  final int donations;
  final int needs;
  final int deliveries;
  final int pendingContributions;
  final int openRiskFlags;
}

class AdminRepository {
  AdminRepository(this._client);
  final SupabaseClient _client;

  Future<String> myRole() async {
    final id = _client.auth.currentUser!.id;
    final row = await _client.from('profiles').select('role').eq('id', id).single();
    return row['role'] as String? ?? 'user';
  }

  Future<AdminStats> stats() async {
    final donations = await _client.from('donations').select('id').inFilter('status', ['submitted', 'under_review', 'available']);
    final needs = await _client.from('needs').select('id').inFilter('status', ['submitted', 'waiting', 'candidate_found']);
    final deliveries = await _client.from('deliveries').select('id').neq('status', 'delivered');
    final contributions = await _client.from('contributions').select('id').eq('status', 'pending');
    final risks = await _client.from('risk_flags').select('id').eq('resolved', false);
    return AdminStats(
      donations: (donations as List).length,
      needs: (needs as List).length,
      deliveries: (deliveries as List).length,
      pendingContributions: (contributions as List).length,
      openRiskFlags: (risks as List).length,
    );
  }

  Future<List<Map<String, dynamic>>> donationsQueue() async {
    final rows = await _client.from('donations').select('id,public_code,category,item_type,condition,status,created_at').inFilter('status', ['submitted', 'under_review', 'available']).order('created_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> matchCandidates(String donationId) async {
    final rows = await _client.rpc('admin_match_candidates', params: {'p_donation_id': donationId, 'p_limit': 20});
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<String> approveMatch(String donationId, String needId) async {
    final result = await _client.rpc('admin_approve_match', params: {'p_donation_id': donationId, 'p_need_id': needId});
    return result as String;
  }

  Future<List<Map<String, dynamic>>> acceptedMatchesAwaitingDelivery() async {
    final rows = await _client.rpc('admin_accepted_matches_queue');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> pendingContributions() async {
    final rows = await _client.from('contributions').select('id,public_code,amount_yer,payment_method,payment_reference,created_at').eq('status', 'pending').order('created_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> verifyContribution(String id, bool verified, {String? note}) async {
    await _client.rpc('admin_verify_contribution', params: {'p_contribution_id': id, 'p_verified': verified, 'p_note': note});
  }

  Future<List<Map<String, dynamic>>> riskQueue() async {
    final rows = await _client.from('risk_flags').select('id,rule_code,severity,details,created_at,user_id,need_id,donation_id,delivery_id').eq('resolved', false).order('created_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> resolveRisk(String id, String resolution) async {
    await _client.rpc('admin_resolve_risk', params: {'p_risk_id': id, 'p_resolution': resolution});
  }

  Future<List<Map<String, dynamic>>> users() async {
    final rows = await _client
        .from('profiles')
        .select('id,full_name,phone,role,is_suspended,created_at')
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> setUserRole(String userId, String role) async {
    await _client.rpc('admin_set_user_role', params: {
      'p_user_id': userId,
      'p_role': role,
    });
  }

  Future<void> setUserSuspension(String userId, bool suspended, String reason) async {
    await _client.rpc('admin_set_user_suspension', params: {
      'p_user_id': userId,
      'p_suspended': suspended,
      'p_reason': reason,
    });
  }

  Future<List<Map<String, dynamic>>> activeCouriers() async {
    final rows = await _client.from('couriers').select('user_id,active,profiles!inner(full_name)').eq('active', true);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> activeVehicles() async {
    final rows = await _client.from('vehicles').select('id,code,kind,active').eq('active', true).order('code');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createDelivery({required String matchId, required String courierId, String? vehicleId}) async {
    final rows = await _client.rpc('admin_create_delivery', params: {'p_match_id': matchId, 'p_courier_id': courierId, 'p_vehicle_id': vehicleId});
    return (rows as List).cast<Map<String, dynamic>>().single;
  }
}
