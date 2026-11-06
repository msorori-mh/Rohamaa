import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/admin_repository.dart';
import '../../domain/staff_labels.dart';

/// Paged list of users inside one statistics segment (admin only).
class UserSegmentScreen extends StatefulWidget {
  const UserSegmentScreen({super.key, required this.title, required this.segment});

  final String title;
  final String segment;

  static const pageSize = 50;

  @override
  State<UserSegmentScreen> createState() => _UserSegmentScreenState();
}

class _UserSegmentScreenState extends State<UserSegmentScreen> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;

  AdminRepository get _repo => AdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _load(more: false);
  }

  Future<void> _load({required bool more}) async {
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final page = await _repo.userSegment(
        widget.segment,
        offset: more ? _rows.length : 0,
        limit: UserSegmentScreen.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _rows = more ? [..._rows, ...page] : page;
        _hasMore = page.length >= UserSegmentScreen.pageSize;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error;
      });
      if (_rows.isNotEmpty) showErrorSnack(context, error);
    }
  }

  String _date(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(friendlyError(_error!), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => _load(more: false), child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('لا يوجد مستخدمون في هذه الفئة.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _rows.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == _rows.length) {
          if (!_hasMore) return const SizedBox.shrink();
          return Center(
            child: OutlinedButton(
              onPressed: _loadingMore ? null : () => _load(more: true),
              child: Text(_loadingMore ? 'جارٍ التحميل...' : 'تحميل المزيد'),
            ),
          );
        }
        return _UserRow(row: _rows[index], formatDate: _date);
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.row, required this.formatDate});

  final Map<String, dynamic> row;
  final String Function(String?) formatDate;

  @override
  Widget build(BuildContext context) {
    final name = (row['user_name'] as String?)?.trim();
    final phone = (row['user_phone'] as String?)?.trim();
    final role = row['user_role'] as String?;
    final suspended = row['user_suspended'] == true;
    final donations = (row['donations_count'] as num?)?.toInt() ?? 0;
    final needs = (row['needs_count'] as num?)?.toInt() ?? 0;

    return Card(
      child: ListTile(
        title: Text(name == null || name.isEmpty ? 'بدون اسم' : name),
        subtitle: Text(
          [
            StaffLabels.roleLabel(role),
            if (phone != null && phone.isNotEmpty) phone,
            'تسجيل: ${formatDate(row['user_created_at'] as String?)}',
            'آخر دخول: ${formatDate(row['user_last_sign_in_at'] as String?)}',
            'تبرعات: $donations • طلبات: $needs',
            if (suspended) 'الحساب مجمّد',
          ].join('\n'),
        ),
        isThreeLine: true,
      ),
    );
  }
}
