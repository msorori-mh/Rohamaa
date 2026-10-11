import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/admin_repository.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});
  @override State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  @override void initState() { super.initState(); _reload(); }
  void _reload() { _future = AdminRepository(Supabase.instance.client).users(); }

  String _roleLabel(String role) => switch (role) {
        'user' => 'مستخدم', 'courier' => 'موصل', 'supervisor' => 'مشرف', 'admin' => 'مدير', _ => role,
      };

  Future<void> _changeRole(Map<String, dynamic> user) async {
    if (user['is_primary_admin'] == true) return;
    final current = user['role'] as String? ?? 'user';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('تغيير الدور'),
        children: [
          for (final role in const ['user', 'courier', 'supervisor'])
            SimpleDialogOption(onPressed: () => Navigator.pop(context, role), child: Row(children: [Icon(role == current ? Icons.check_circle : Icons.circle_outlined), const SizedBox(width: 12), Text(_roleLabel(role))])),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    try {
      await AdminRepository(Supabase.instance.client).setUserRole(user['id'] as String, selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الدور.')));
      setState(_reload);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث الدور: $e')));
    }
  }

  Future<void> _toggleSuspension(Map<String, dynamic> user) async {
    if (user['is_primary_admin'] == true) return;
    final suspended = user['is_suspended'] as bool? ?? false;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(suspended ? 'إلغاء التجميد' : 'تجميد الحساب'),
        content: TextField(controller: controller, maxLines: 2, decoration: const InputDecoration(labelText: 'السبب التشغيلي')),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد'))],
      ),
    );
    final reason = controller.text.trim(); controller.dispose();
    if (confirmed != true || reason.length < 3) return;
    try {
      await AdminRepository(Supabase.instance.client).setUserSuspension(user['id'] as String, !suspended, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(suspended ? 'تم إلغاء تجميد الحساب.' : 'تم تجميد الحساب.')));
      setState(_reload);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث الحساب: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المستخدمون والأدوار')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('تعذر تحميل المستخدمين. حاول مجددًا.'));
          final users = snapshot.data ?? const [];
          if (users.isEmpty) return const Center(child: Text('لا يوجد مستخدمون حتى الآن.'));
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.all(16), itemCount: users.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final user = users[index];
                final role = user['role'] as String? ?? 'user';
                final suspended = user['is_suspended'] as bool? ?? false;
                final primary = user['is_primary_admin'] as bool? ?? false;
                final temporary = user['force_password_change'] as bool? ?? false;
                final contact = (user['staff_email'] as String?) ?? (user['phone'] as String?) ?? 'لا توجد بيانات اتصال';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(primary ? Icons.admin_panel_settings : role == 'courier' ? Icons.delivery_dining : role == 'supervisor' ? Icons.supervisor_account : Icons.person_outline)),
                    title: Text((user['full_name'] as String?)?.trim().isNotEmpty == true ? user['full_name'] as String : 'مستخدم بدون اسم'),
                    subtitle: Text('الدور: ${_roleLabel(role)}${primary ? ' • الأدمن الرئيسي' : ''}${suspended ? ' • مجمد' : ''}${temporary ? ' • كلمة مرور مؤقتة' : ''}\n$contact'),
                    isThreeLine: true,
                    trailing: primary ? const Icon(Icons.lock_outline) : PopupMenuButton<String>(
                      onSelected: (action) { if (action == 'role') _changeRole(user); if (action == 'suspend') _toggleSuspension(user); },
                      itemBuilder: (_) => [const PopupMenuItem(value: 'role', child: Text('تغيير الدور')), PopupMenuItem(value: 'suspend', child: Text(suspended ? 'إلغاء التجميد' : 'تجميد الحساب'))],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
