import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/staff_labels.dart';

class StaffStatus {
  const StaffStatus({
    required this.role,
    required this.forcePasswordChange,
    required this.isPrimaryAdmin,
  });

  final String role;
  final bool forcePasswordChange;
  final bool isPrimaryAdmin;

  factory StaffStatus.fromJson(Map<String, dynamic> json) => StaffStatus(
        role: json['role'] as String? ?? 'user',
        forcePasswordChange: json['force_password_change'] as bool? ?? false,
        isPrimaryAdmin: json['is_primary_admin'] as bool? ?? false,
      );
}

/// Failure reported by a staff Edge Function (`admin-create-staff`,
/// `admin-reset-staff-password`, `staff-change-password`,
/// `admin-delete-account`).
///
/// [toString] carries the server error code and message, so
/// `friendlyError` can match its known keys; [arabicMessage] gives copy for
/// the codes this app knows and is meant to be passed as its `fallback`.
class StaffFunctionException implements Exception {
  const StaffFunctionException(this.code, {this.status, this.message});

  factory StaffFunctionException.from(FunctionException error) {
    final details = error.details;
    final code = StaffLabels.functionErrorCode(details) ?? 'unknown_error';
    String? message;
    if (details is Map && details['message'] is String) {
      message = details['message'] as String;
    }
    return StaffFunctionException(code, status: error.status, message: message);
  }

  final String code;
  final int? status;
  final String? message;

  String? get arabicMessage => StaffLabels.functionErrorLabel(code);

  @override
  String toString() =>
      'StaffFunctionException($code${message == null ? '' : ': $message'})';
}

/// Arabic fallback for [error] when it is a [StaffFunctionException] with a
/// known code; null otherwise (the generic message is then used).
String? staffFunctionErrorMessage(Object error) =>
    error is StaffFunctionException ? error.arabicMessage : null;

class StaffRepository {
  StaffRepository(this._client);
  final SupabaseClient _client;

  /// Role and password state of the signed-in account.
  ///
  /// `my_staff_status` returns no row for a suspended profile; in that case
  /// this keeps the historical behaviour of reporting role `user`. Callers
  /// that must distinguish suspension use `my_account_state()` first (the
  /// session landing screen does), so this method stays stable for them.
  Future<StaffStatus> myStatus() async {
    final result = await _client.rpc('my_staff_status');
    final rows = (result as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) {
      return const StaffStatus(
        role: 'user',
        forcePasswordChange: false,
        isPrimaryAdmin: false,
      );
    }
    return StaffStatus.fromJson(rows.first);
  }

  Future<List<Map<String, dynamic>>> serviceAreas() async {
    final rows = await _client
        .from('service_areas')
        .select('id,code,name_ar,kind,parent_id')
        .eq('active', true)
        .order('name_ar');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Areas the signed-in staff member may report on.
  Future<List<Map<String, dynamic>>> reportAreas() async {
    return reportAreasFor(await myStatus());
  }

  /// Same as [reportAreas] for a status the caller already loaded, so the
  /// status RPC is not called twice.
  Future<List<Map<String, dynamic>>> reportAreasFor(StaffStatus status) async {
    if (status.role == 'admin') return serviceAreas();
    if (status.role != 'supervisor') return const [];
    return myAssignedAreas();
  }

  /// Areas assigned to the signed-in staff member (RLS: own rows only).
  Future<List<Map<String, dynamic>>> myAssignedAreas() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('staff_area_assignments')
        .select('service_areas!inner(id,code,name_ar,kind,parent_id)')
        .eq('user_id', userId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((row) => Map<String, dynamic>.from(row['service_areas'] as Map))
        .toList();
  }

  Future<String> createServiceArea({
    required String code,
    required String nameAr,
    required String kind,
    String? parentId,
  }) async {
    final result = await _client.rpc('admin_create_service_area', params: {
      'p_code': code.trim(),
      'p_name_ar': nameAr.trim(),
      'p_kind': kind,
      'p_parent_id': parentId,
    });
    return result as String;
  }

  Future<void> setServiceAreaActive(String areaId, bool active) async {
    await _client.rpc(
      'admin_set_service_area_active',
      params: {'p_area_id': areaId, 'p_active': active},
    );
  }

  /// Creates a courier or supervisor account. Throws
  /// [StaffFunctionException] when the function rejects the request.
  Future<void> createStaff({
    required String email,
    required String temporaryPassword,
    required String fullName,
    required String role,
    required List<String> areaIds,
  }) async {
    await _invoke('admin-create-staff', {
      'email': email.trim(),
      'password': temporaryPassword,
      'full_name': fullName.trim(),
      'role': role,
      'area_ids': areaIds,
    });
  }

  /// Sets a new temporary password for a courier or supervisor through the
  /// `admin-reset-staff-password` Edge Function. The staff member is forced
  /// to change it at the next sign-in. Throws [StaffFunctionException] when
  /// the function rejects the request.
  Future<void> resetStaffPassword(String userId, String password) async {
    await _invoke('admin-reset-staff-password', {
      'user_id': userId,
      'password': password,
    });
  }

  /// Changes the signed-in staff member's password. [currentPassword] is
  /// required by the function unless the profile has a forced change pending.
  /// Throws [StaffFunctionException] when the function rejects the request.
  Future<void> changePassword(String password, {String? currentPassword}) async {
    await _invoke('staff-change-password', {
      'password': password,
      if (currentPassword != null && currentPassword.isNotEmpty)
        'current_password': currentPassword,
    });
    await _client.auth.refreshSession();
  }

  /// supabase_flutter 2.x throws [FunctionException] for any non-2xx
  /// response, so there is no status code to inspect on success.
  Future<void> _invoke(String name, Map<String, dynamic> body) async {
    final session = _client.auth.currentSession;
    if (session == null) throw const StaffFunctionException('unauthorized');
    try {
      await _client.functions.invoke(
        name,
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
        body: body,
      );
    } on FunctionException catch (error) {
      throw StaffFunctionException.from(error);
    }
  }
}
