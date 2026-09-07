import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ServiceMatchOffer {
  const ServiceMatchOffer({
    required this.matchId,
    required this.mySide,
    required this.serviceTitle,
    required this.serviceType,
    required this.category,
    required this.status,
    required this.myResponse,
    required this.otherResponse,
    required this.scheduledAt,
  });

  final String matchId;
  final String mySide;
  final String serviceTitle;
  final String serviceType;
  final String category;
  final String status;
  final String myResponse;
  final String otherResponse;
  final DateTime? scheduledAt;

  factory ServiceMatchOffer.fromJson(Map<String, dynamic> json) => ServiceMatchOffer(
        matchId: json['match_id'] as String,
        mySide: json['my_side'] as String,
        serviceTitle: json['service_title'] as String,
        serviceType: json['service_type'] as String,
        category: json['category'] as String,
        status: json['status'] as String,
        myResponse: json['my_response'] as String,
        otherResponse: json['other_response'] as String,
        scheduledAt: json['scheduled_at'] == null
            ? null
            : DateTime.tryParse('${json['scheduled_at']}'),
      );
}

class ServiceRepository {
  ServiceRepository(this._client);

  final SupabaseClient _client;
  static const _uuid = Uuid();

  String get userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('User must be authenticated');
    return id;
  }

  String _publicCode(String prefix) {
    final suffix = _uuid.v4().replaceAll('-', '').substring(0, 10).toUpperCase();
    return 'RHM-MRB-$prefix-$suffix';
  }

  Future<String?> defaultServiceAreaId() async {
    final rows = await _client
        .from('addresses')
        .select('service_area_id')
        .eq('user_id', userId)
        .not('service_area_id', 'is', null)
        .order('is_default', ascending: false)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return rows.first['service_area_id'] as String?;
  }

  Future<String> createServiceOffer({
    required String providerKind,
    required String category,
    required String serviceType,
    required String title,
    required String description,
    required String availabilityMode,
    required double availableHours,
    required String availabilityNote,
    required String materialsMode,
    required String pricingMode,
  }) async {
    final row = await _client.from('service_offers').insert({
      'public_code': _publicCode('SVC'),
      'user_id': userId,
      'service_area_id': await defaultServiceAreaId(),
      'provider_kind': providerKind,
      'category': category,
      'service_type': serviceType,
      'title': title,
      'description': description.trim().isEmpty ? null : description.trim(),
      'availability_mode': availabilityMode,
      'available_hours': availableHours,
      'availability_note': availabilityNote.trim().isEmpty ? null : availabilityNote.trim(),
      'materials_mode': materialsMode,
      'pricing_mode': pricingMode,
      'verification_status': 'pending',
      'status': 'submitted',
    }).select('id').single();
    return row['id'] as String;
  }

  Future<String> createServiceRequest({
    required String category,
    required String serviceType,
    required String title,
    required String details,
    required double? estimatedHours,
    required String preferredTimeNote,
    required bool materialsAvailable,
  }) async {
    final row = await _client.from('service_requests').insert({
      'public_code': _publicCode('SRQ'),
      'user_id': userId,
      'service_area_id': await defaultServiceAreaId(),
      'category': category,
      'service_type': serviceType,
      'title': title,
      'details': details.trim(),
      'estimated_hours': estimatedHours,
      'preferred_time_note': preferredTimeNote.trim().isEmpty ? null : preferredTimeNote.trim(),
      'materials_available': materialsAvailable,
      'status': 'submitted',
    }).select('id').single();
    return row['id'] as String;
  }

  Future<List<Map<String, dynamic>>> myServiceOffers() async {
    final rows = await _client
        .from('service_offers')
        .select('id,public_code,category,service_type,title,available_hours,status,verification_status,created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> myServiceRequests() async {
    final rows = await _client
        .from('service_requests')
        .select('id,public_code,category,service_type,title,status,created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<ServiceMatchOffer>> pendingServiceMatches() async {
    final rows = await _client.rpc('user_pending_service_matches');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ServiceMatchOffer.fromJson)
        .toList();
  }

  Future<String> respondServiceMatch(String matchId, {required bool accept}) async {
    final result = await _client.rpc('user_respond_service_match', params: {
      'p_match_id': matchId,
      'p_accept': accept,
    });
    return result as String;
  }
}
