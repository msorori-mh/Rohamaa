import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/admin_repository.dart';
import '../../domain/staff_labels.dart';
import '../../theme/ruhamaa_theme.dart';
import 'staff_widgets.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users = const [];
  bool _loading = true;
  Object? _error;
  bool _hasMore = false;
  bool _loadingMore = false;
  final Set<String> _busyIds = <String>{};

  AdminRepository get _repo => AdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  /// Reloads from the first row, keeping as many rows as are already shown
  /// so the list does not jump back after an action on a later page.
  Future<void> _fetch() async {
    final wanted = _users.length > AdminRepository.usersPageSize
        ? _users.length
        : AdminRepository.usersPageSize;
    try {
      final rows = await _repo.users(from: 0, limit: wanted);
      if (!mounted) return;
      setState(() {
        _users = rows;
        _hasMore = rows.length >= wanted;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
      // With rows already on screen the error state is not rendered, so the
      // failed refresh is reported in a snackbar instead.
      if (_users.isNotEmpty) showErrorSnack(context, error);
    }
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _fetch();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final rows = await _repo.users(from: _users.length);
      if (!mounted) return;
      final known = _users.map((user) => user['id']).toSet();
      setState(() {
        _users = [
          ..._users,
          ...rows.where((user) => !known.contains(user['id'])),
        ];
        _hasMore = rows.length >= AdminRepository.usersPageSize;
      });
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _name(Map<String, dynamic> user) {
    final name = user['full_name'];
    return name is String && name.trim().isNotEmpty ? name : 'مستخدم بدون اسم';
  }

  String _roleChangeNote(String role) => switch (role) {
        'supervisor' =>
          'تنبيه: لا يمكن حاليًا إسناد مدن أو مناطق لمشرف موجود من التطبيق، '
              'وبدون منطقة مسندة لن تظهر له أي أرقام في التقارير. '
              'لإنشاء مشرف بمنطقته استخدم «إضافة فريق».',
        'courier' =>
          'سيُفعَّل الحساب كموصل ويمكن إسناد مهام التوصيل إليه مباشرة.',
        _ => 'ستُسحب صلاحيات الفريق من هذا الحساب ويعود مستخدمًا عاديًا.',
      };

  Future<void> _changeRole(Map<String, dynamic> user) async {
    final id = '${user['id']}';
    if (user['is_primary_admin'] == true || _busyIds.contains(id)) return;
    final current = user['role'] as String? ?? 'user';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('تغيير الدور'),
        children: [
          for (final role in StaffLabels.assignableRoles)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, role),
              child: Row(
                children: [
                  Icon(
                    role == current
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                  ),
                  const SizedBox(width: 12),
                  Text(StaffLabels.roleLabel(role)),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || selected == current || !mounted) return;
    final note = _roleChangeNote(selected);
    final confirmed = await confirmAction(
      context,
      title: 'تغيير دور ${_name(user)}؟',
      message: 'الدور الجديد: ${StaffLabels.roleLabel(selected)}.\n\n$note',
      confirmLabel: 'تأكيد التغيير',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyIds.add(id));
    try {
      await _repo.setUserRole(id, selected);
      if (!mounted) return;
      showInfoSnack(context, 'تم تحديث الدور.');
      await _fetch();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر تحديث الدور. حدّث القائمة ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _toggleSuspension(Map<String, dynamic> user) async {
    final id = '${user['id']}';
    if (user['is_primary_admin'] == true || _busyIds.contains(id)) return;
    final suspended = user['is_suspended'] as bool? ?? false;
    final values = await TextFieldsDialog.show(
      context,
      title: suspended ? 'إلغاء التجميد' : 'تجميد الحساب',
      intro: suspended
          ? 'سيستعيد ${_name(user)} استخدام حسابه.'
          : 'لن يتمكن ${_name(user)} من استخدام حسابه حتى يُلغى التجميد.',
      fields: [
        DialogField(
          id: 'reason',
          label: 'السبب التشغيلي',
          maxLines: 2,
          maxLength: 300,
          validator: requiredText(message: 'اكتب السبب (3 أحرف على الأقل).'),
        ),
      ],
    );
    final reason = values?['reason'];
    if (reason == null || !mounted) return;
    setState(() => _busyIds.add(id));
    try {
      await _repo.setUserSuspension(id, !suspended, reason);
      if (!mounted) return;
      showInfoSnack(
        context,
        suspended ? 'تم إلغاء تجميد الحساب.' : 'تم تجميد الحساب.',
      );
      await _fetch();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر تحديث الحساب. حدّث القائمة ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Widget _tile(Map<String, dynamic> user) {
    final id = '${user['id']}';
    final role = user['role'] as String? ?? 'user';
    final suspended = user['is_suspended'] as bool? ?? false;
    final primary = user['is_primary_admin'] as bool? ?? false;
    final temporary = user['force_password_change'] as bool? ?? false;
    final contact = (user['staff_email'] as String?) ??
        (user['phone'] as String?) ??
        'لا توجد بيانات اتصال';
    final flags = <String>[
      'الدور: ${StaffLabels.roleLabel(role)}',
      if (primary) 'الأدمن الرئيسي',
      if (suspended) 'مجمد',
      if (temporary) 'كلمة مرور مؤقتة',
    ];
    final Widget trailing;
    if (primary) {
      trailing = const Icon(Icons.lock_outline);
    } else if (_busyIds.contains(id)) {
      trailing = const InlineSpinner();
    } else {
      trailing = PopupMenuButton<String>(
        onSelected: (action) {
          if (action == 'role') _changeRole(user);
          if (action == 'suspend') _toggleSuspension(user);
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'role', child: Text('تغيير الدور')),
          PopupMenuItem(
            value: 'suspend',
            child: Text(suspended ? 'إلغاء التجميد' : 'تجميد الحساب'),
          ),
        ],
      );
    }
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            primary
                ? Icons.admin_panel_settings
                : role == 'courier'
                    ? Icons.delivery_dining
                    : role == 'supervisor'
                        ? Icons.supervisor_account
                        : Icons.person_outline,
          ),
        ),
        title: Text(_name(user)),
        subtitle: Text('${flags.join(' • ')}\n$contact'),
        isThreeLine: true,
        trailing: trailing,
      ),
    );
  }

  Widget _footer() {
    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'عدد الحسابات المعروضة: ${_users.length}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 12),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: OutlinedButton.icon(
        onPressed: _loadingMore ? null : _loadMore,
        icon: _loadingMore
            ? const InlineSpinner()
            : const Icon(Icons.expand_more_rounded),
        label: Text(_loadingMore ? 'جارٍ التحميل...' : 'تحميل المزيد'),
      ),
    );
  }

  Widget _body() {
    final error = _error;
    if (_loading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && _users.isEmpty) {
      return ErrorRetry(error: error, onRetry: _retry);
    }
    if (_users.isEmpty) {
      return const ScrollableEmpty(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('لا يوجد مستخدمون حتى الآن.'),
        ),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _users.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          index == _users.length ? _footer() : _tile(_users[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المستخدمون والأدوار')),
      body: RefreshIndicator(onRefresh: _fetch, child: _body()),
    );
  }
}
