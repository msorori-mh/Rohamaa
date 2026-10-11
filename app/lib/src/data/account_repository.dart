import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/account_state.dart';
import '../domain/staff_labels.dart';

/// The person's own contact details and default pickup/delivery address.
class DeliveryProfile {
  const DeliveryProfile({
    this.fullName,
    this.phone,
    this.addressId,
    this.serviceAreaId,
    this.area,
    this.description,
    this.latitude,
    this.longitude,
  });

  final String? fullName;
  final String? phone;
  final String? addressId;
  final String? serviceAreaId;
  final String? area;
  final String? description;
  final double? latitude;
  final double? longitude;

  bool get hasPosition => latitude != null && longitude != null;
}

/// Account-level calls for the signed-in person: state, password, deletion
/// request and the delivery profile.
class AccountRepository {
  AccountRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('jwt expired');
    return id;
  }

  /// Reads `my_account_state()`. Works for suspended accounts too, so the app
  /// can explain why access is blocked instead of showing a generic error.
  Future<AccountState> myState() async {
    dynamic result;
    try {
      result = await _client.rpc('my_account_state');
    } on PostgrestException catch (error) {
      // PGRST202 / 42883: the function is not deployed on this backend yet.
      // Fall back to the older staff-status call so sign-in keeps working.
      if (error.code != 'PGRST202' && error.code != '42883') rethrow;
      result = await _client.rpc('my_staff_status');
    }
    if (result is List) {
      if (result.isEmpty) return AccountState.community;
      final first = result.first;
      if (first is Map) return AccountState.fromJson(Map<String, dynamic>.from(first));
      return AccountState.community;
    }
    if (result is Map) return AccountState.fromJson(Map<String, dynamic>.from(result));
    return AccountState.community;
  }

  /// Calls the `staff-change-password` Edge Function. [currentPassword] may be
  /// omitted only when the server forces a password change.
  ///
  /// Returns normally whenever the password was changed, including the
  /// `profile_update_failed` answer. The server ends the other sessions and
  /// may end this one too, so the local session is always dropped afterwards
  /// and the person signs in again with the new password.
  Future<void> changeStaffPassword({
    required String password,
    String? currentPassword,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) throw StateError('jwt expired');
    final body = <String, dynamic>{'password': password};
    if (currentPassword != null && currentPassword.isNotEmpty) {
      body['current_password'] = currentPassword;
    }
    try {
      final response = await _client.functions.invoke(
        'staff-change-password',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
        body: body,
      );
      if (response.status < 200 || response.status >= 300) {
        final code = StaffLabels.functionErrorCode(response.data);
        if (!StaffLabels.passwordChangedDespite(code)) {
          // Carries only the server error code; mapped by friendlyError().
          throw StateError('${response.data}');
        }
      }
    } on FunctionException catch (error) {
      final code = StaffLabels.functionErrorCode(error.details);
      if (!StaffLabels.passwordChangedDespite(code)) rethrow;
    }
    await signOutLocally();
  }

  /// Drops the session on this device without calling the server (the
  /// server-side session may already be gone). Never throws.
  Future<void> signOutLocally() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // Nothing else can be done here; the caller checks the session.
    }
  }

  Future<void> requestDeletion() async {
    await _client.rpc('request_account_deletion');
  }

  Future<void> cancelDeletionRequest() async {
    await _client.rpc('cancel_account_deletion_request');
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<List<Map<String, dynamic>>> activeServiceAreas() async {
    final rows = await _client
        .from('service_areas')
        .select('id,code,name_ar,kind,parent_id')
        .eq('active', true)
        .order('kind')
        .order('name_ar');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// The profile plus the address the app treats as the default one.
  Future<DeliveryProfile> deliveryProfile() async {
    final userId = _userId;
    final profileRows = await _client
        .from('profiles')
        .select('full_name,phone')
        .eq('id', userId)
        .limit(1);
    final addressRows = await _client
        .from('addresses')
        .select('id,service_area_id,area,description,latitude,longitude,is_default,created_at')
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false)
        .limit(1);
    final profiles = (profileRows as List).cast<Map<String, dynamic>>();
    final addresses = (addressRows as List).cast<Map<String, dynamic>>();
    final profile = profiles.isEmpty ? const <String, dynamic>{} : profiles.first;
    final address = addresses.isEmpty ? const <String, dynamic>{} : addresses.first;
    return DeliveryProfile(
      fullName: profile['full_name'] as String?,
      phone: profile['phone'] as String?,
      addressId: address['id'] as String?,
      serviceAreaId: address['service_area_id'] as String?,
      area: address['area'] as String?,
      description: address['description'] as String?,
      latitude: (address['latitude'] as num?)?.toDouble(),
      longitude: (address['longitude'] as num?)?.toDouble(),
    );
  }

  /// Saves the contact details and updates the existing default address in
  /// place. A new address row is inserted only when the person has none.
  Future<void> saveDeliveryProfile({
    required String fullName,
    required String phone,
    required String serviceAreaId,
    required String area,
    required String description,
    String? addressId,
    double? latitude,
    double? longitude,
  }) async {
    final userId = _userId;
    await _client
        .from('profiles')
        .update({'full_name': fullName, 'phone': phone})
        .eq('id', userId);

    final address = <String, dynamic>{
      'service_area_id': serviceAreaId,
      'area': area,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
    };

    if (addressId != null) {
      final updated = await _client
          .from('addresses')
          .update({...address, 'is_default': true})
          .eq('id', addressId)
          .eq('user_id', userId)
          .select('id');
      if ((updated as List).isNotEmpty) return;
    }

    await _client
        .from('addresses')
        .update({'is_default': false})
        .eq('user_id', userId)
        .eq('is_default', true);
    await _client.from('addresses').insert({
      ...address,
      'user_id': userId,
      'label': 'الافتراضي',
      'is_default': true,
    });
  }
}
