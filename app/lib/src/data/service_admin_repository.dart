import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceAdminRepository {
  ServiceAdminRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> pendingOffers() async {
    final rows = await _client
        .from('service_offers')
        .select('id,public_code,provider_kind,category,service_type,title,description,available_hours,availability_note,materials_mode,pricing_mode,status,verification_status,created_at')
        .inFilter('verification_status', ['pending', 'rejected'])
        .order('created_at', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> approveOffer(String offerId) async {
    await _client.from('service_offers').update({
      'verification_status': 'verified',
      'status': 'approved',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', offerId);
  }

  Future<void> rejectOffer(String offerId) async {
    await _client.from('service_offers').update({
      'verification_status': 'rejected',
      'status': 'rejected',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', offerId);
  }

  Future<List<Map<String, dynamic>>> openRequests() async {
    final rows = await _client
        .from('service_requests')
        .select('id,public_code,category,service_type,title,details,estimated_hours,preferred_time_note,materials_available,status,created_at')
        .inFilter('status', ['submitted', 'reviewing'])
        .order('created_at', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> markRequestReviewing(String requestId) async {
    await _client.from('service_requests').update({
      'status': 'reviewing',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  Future<List<Map<String, dynamic>>> candidates(String requestId) async {
    final rows = await _client.rpc('admin_service_match_candidates', params: {
      'p_request_id': requestId,
    });
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<String> createMatch({
    required String requestId,
    required String offerId,
    String? note,
  }) async {
    final id = await _client.rpc('admin_create_service_match', params: {
      'p_request_id': requestId,
      'p_offer_id': offerId,
      'p_scheduled_at': null,
      'p_note': note,
    });
    return id as String;
  }

  Future<List<Map<String, dynamic>>> acceptedMatches() async {
    final rows = await _client
        .from('service_matches')
        .select(
          'id,status,scheduled_at,operational_note,provider_response,requester_response,'
          'service_offers!inner(id,title,provider_kind,category,service_type,available_hours),'
          'service_requests!inner(id,title,details,service_type,category,preferred_time_note)',
        )
        .inFilter('status', ['accepted', 'scheduled'])
        .order('updated_at', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> scheduleMatch({
    required String matchId,
    required DateTime scheduledAt,
    String? note,
  }) async {
    await _client.rpc('admin_schedule_service_match', params: {
      'p_match_id': matchId,
      'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'p_note': note,
    });
  }

  Future<void> completeMatch(String matchId) async {
    await _client.rpc('admin_complete_service_match', params: {
      'p_match_id': matchId,
    });
  }
}
