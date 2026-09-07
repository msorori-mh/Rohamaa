import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class PartnerRepository {
  PartnerRepository(this._client);

  final SupabaseClient _client;
  static const _uuid = Uuid();

  String get userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('User must be authenticated');
    return id;
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

  Future<String> registerPartner({
    required String displayName,
    required String partnerKind,
    required String description,
    required String contactPhone,
    required int monthlyCaseCapacity,
  }) async {
    final areaId = await defaultServiceAreaId();
    if (areaId == null) throw StateError('Operational service area is required');
    final id = await _client.rpc('user_register_service_partner', params: {
      'p_display_name': displayName.trim(),
      'p_partner_kind': partnerKind,
      'p_description': description.trim(),
      'p_contact_phone': contactPhone.trim(),
      'p_monthly_case_capacity': monthlyCaseCapacity,
      'p_service_area_id': areaId,
      'p_terms_version': 'v1',
    });
    return id as String;
  }

  Future<List<Map<String, dynamic>>> myPartners() async {
    final rows = await _client
        .from('service_partners')
        .select('id,public_code,display_name,partner_kind,description,contact_phone,monthly_case_capacity,verification_status,terms_version,terms_accepted_at,service_area_id,created_at,updated_at')
        .eq('owner_user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminPartners() async {
    final rows = await _client
        .from('service_partners')
        .select('id,public_code,owner_user_id,display_name,partner_kind,description,contact_phone,monthly_case_capacity,verification_status,terms_version,terms_accepted_at,service_area_id,admin_note,created_at,updated_at')
        .order('created_at', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> setPartnerStatus(String partnerId, String status, {String? note}) async {
    await _client.rpc('admin_set_service_partner_status', params: {
      'p_partner_id': partnerId,
      'p_status': status,
      'p_note': note,
    });
  }

  Future<String> createPartnerOffer({
    required String partnerId,
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
    final suffix = _uuid.v4().replaceAll('-', '').substring(0, 10).toUpperCase();
    final row = await _client.from('service_offers').insert({
      'public_code': 'RHM-MRB-SVC-$suffix',
      'user_id': userId,
      'service_area_id': await defaultServiceAreaId(),
      'provider_kind': 'business',
      'partner_id': partnerId,
      'category': category,
      'service_type': serviceType,
      'title': title.trim(),
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
}
