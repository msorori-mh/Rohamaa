import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceIncidentRepository {
  ServiceIncidentRepository(this._client);

  final SupabaseClient _client;

  String get userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('User must be authenticated');
    return id;
  }

  Future<List<Map<String, dynamic>>> serviceHistory({int limit = 50}) async {
    final rows = await _client.rpc('user_service_history', params: {'p_limit': limit});
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> report({
    required String serviceMatchId,
    required String incidentType,
    required String description,
  }) async {
    await _client.from('service_incidents').insert({
      'service_match_id': serviceMatchId,
      'reporter_user_id': userId,
      'incident_type': incidentType,
      'description': description.trim(),
      'status': 'open',
    });
  }

  Future<List<Map<String, dynamic>>> myIncidents() async {
    final rows = await _client
        .from('service_incidents')
        .select('id,service_match_id,incident_type,description,status,resolution,created_at,resolved_at')
        .eq('reporter_user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminIncidents() async {
    final rows = await _client
        .from('service_incidents')
        .select('id,service_match_id,reporter_user_id,incident_type,description,status,resolution,created_at,resolved_at')
        .inFilter('status', ['open', 'reviewing'])
        .order('created_at', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> resolve(String incidentId, {required bool dismissed, required String resolution}) async {
    await _client.rpc('admin_resolve_service_incident', params: {
      'p_incident_id': incidentId,
      'p_status': dismissed ? 'dismissed' : 'resolved',
      'p_resolution': resolution,
    });
  }
}
