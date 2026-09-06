import 'package:supabase_flutter/supabase_flutter.dart';

class StaffStatus {
  const StaffStatus({required this.role, required this.forcePasswordChange, required this.isPrimaryAdmin});
  final String role;
  final bool forcePasswordChange;
  final bool isPrimaryAdmin;

  factory StaffStatus.fromJson(Map<String, dynamic> json) => StaffStatus(
        role: json['role'] as String? ?? 'user',
        forcePasswordChange: json['force_password_change'] as bool? ?? false,
        isPrimaryAdmin: json['is_primary_admin'] as bool? ?? false,
      );
}

class StaffRepository {
  StaffRepository(this._client);
  final SupabaseClient _client;

  Future<StaffStatus> myStatus() async {
    final result = await _client.rpc('my_staff_status');
    final rows = (result as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return const StaffStatus(role: 'user', forcePasswordChange: false, isPrimaryAdmin: false);
    return StaffStatus.fromJson(rows.first);
  }

  Future<List<Map<String, dynamic>>> serviceAreas() async {
    final rows = await _client.from('service_areas').select('id,code,name_ar,kind,parent_id').eq('active', true).order('name_ar');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> reportAreas() async {
    final status = await myStatus();
    if (status.role == 'admin') return serviceAreas();
    if (status.role != 'supervisor') return const [];
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('staff_area_assignments')
        .select('service_areas!inner(id,code,name_ar,kind,parent_id)')
        .eq('user_id', userId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((row) => Map<String, dynamic>.from(row['service_areas'] as Map))
        .toList();
  }

  Future<void> createStaff({
    required String email,
    required String temporaryPassword,
    required String fullName,
    required String role,
    required List<String> areaIds,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) throw StateError('Not authenticated');
    final response = await _client.functions.invoke(
      'admin-create-staff',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
      body: {
        'email': email.trim(),
        'password': temporaryPassword,
        'full_name': fullName.trim(),
        'role': role,
        'area_ids': areaIds,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('تعذر إنشاء الحساب: ${response.data}');
    }
  }

  Future<void> changePassword(String password) async {
    final session = _client.auth.currentSession;
    if (session == null) throw StateError('Not authenticated');
    final response = await _client.functions.invoke(
      'staff-change-password',
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
      body: {'password': password},
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('تعذر تغيير كلمة المرور: ${response.data}');
    }
    await _client.auth.refreshSession();
  }
}
