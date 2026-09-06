import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/admin_repository.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = AdminRepository(Supabase.instance.client).users();
  }

  Future<void> _changeRole(Map<String, dynamic> user) async {
    final current = user['role'] as String? ?? 'user';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('تغيير الدور'),
        children: [
          for (final role in const ['user', 'courier', 'admin'])
            RadioListTile<String>(
              value: role,
              groupValue: current,
              title: Text(switch (role) {'user' => 'مستخدم', 'courier' => 'مندوب', 'admin' => 'مدير', _ => role}),
              onChanged: (value) => Navigator.pop(context, value),
            ),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث الدور: $e')));
    }
  }

  Future<void> _toggleSuspension(Map<String, dynamic> user) async {
    final suspended = user['is_suspended'] as bool? ?? false;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(suspended ? 'إلغاء التجميد' : 'تجميد الحساب'),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'السبب التشغيلي'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (confirmed != true || reason.length < 3) return;
    try {
      await AdminRepository(Supabase.instance.client).setUserSuspension(user['id'] as String, !suspended, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(suspended ? 'تم إلغاء تجميد الحساب.' : 'تم تجميد الحساب.')));
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث الحساب: $e')));
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
          if (snapshot.hasError) return Center(child: Text('تعذر تحميل المستخدمين: ${snapshot.error}'));
          final users = snapshot.data ?? const [];
          if (users.isEmpty) return const Center(child: Text('لا يوجد مستخدمون حتى الآن.'));
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final user = users[index];
                final role = user['role'] as String? ?? 'user';
                final suspended = user['is_suspended'] as bool? ?? false;
                return Card(
                  child: ListTile(
                    title: Text((user['full_name'] as String?)?.trim().isNotEmpty == true ? user['full_name'] as String : 'مستخدم بدون اسم'),
                    subtitle: Text('الدور: $role${suspended ? ' • مجمد' : ''}\n${user['phone'] ?? 'بدون رقم هاتف'}'),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        if (action == 'role') _changeRole(user);
                        if (action == 'suspend') _toggleSuspension(user);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'role', child: Text('تغيير الدور')),
                        PopupMenuItem(value: 'suspend', child: Text(suspended ? 'إلغاء التجميد' : 'تجميد الحساب')),
                      ],
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
