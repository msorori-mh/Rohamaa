import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/admin_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import 'user_segment_screen.dart';

/// Aggregate user counts. Each card opens the matching user list.
class UserStatisticsScreen extends StatefulWidget {
  const UserStatisticsScreen({super.key});

  @override
  State<UserStatisticsScreen> createState() => _UserStatisticsScreenState();
}

class _UserStatisticsScreenState extends State<UserStatisticsScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  Object? _error;

  AdminRepository get _repo => AdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await _repo.userStatistics();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  int _int(Object? value) => value is num ? value.toInt() : 0;

  void _open(String title, String segment) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserSegmentScreen(title: title, segment: segment),
      ),
    );
  }

  _StatTile _tile(String label, Object? value, Color color, String segment) {
    return _StatTile(
      label: label,
      value: _int(value),
      color: color,
      onTap: () => _open(label, segment),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إحصائيات المستخدمين'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _fetch,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _stats == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _stats == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(friendlyError(_error!), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _fetch, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }

    final s = _stats!;
    final byRole = Map<String, dynamic>.from(s['by_role'] as Map? ?? const {});

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('عام', [
            _tile('إجمالي المستخدمين', s['total_users'], RuhamaaColors.primary, 'all'),
            _tile('حسابات مجمّدة', s['suspended'], RuhamaaColors.rose, 'suspended'),
            _tile('تسجيلات آخر 7 أيام', s['new_last_7_days'], RuhamaaColors.blue, 'new_7_days'),
            _tile('تسجيلات آخر 30 يومًا', s['new_last_30_days'], RuhamaaColors.blue, 'new_30_days'),
            _tile('نشطون آخر 30 يومًا', s['active_last_30_days'], RuhamaaColors.primaryBright, 'active_30_days'),
          ]),
          _section('المتبرعون والمحتاجون', [
            _tile('متبرعون', s['donors'], RuhamaaColors.primary, 'donors'),
            _tile('محتاجون (لديهم طلبات)', s['beneficiaries'], RuhamaaColors.vividGold, 'beneficiaries'),
            _tile('متبرع ومحتاج معًا', s['donors_and_beneficiaries'], RuhamaaColors.blue, 'both'),
            _tile('بدون تبرع أو طلب', s['neither'], RuhamaaColors.rose, 'neither'),
          ]),
          _section('حسب الدور', [
            _tile('مستخدمون', byRole['user'], RuhamaaColors.primary, 'role_user'),
            _tile('موصلون', byRole['courier'], RuhamaaColors.blue, 'role_courier'),
            _tile('مشرفون', byRole['supervisor'], RuhamaaColors.vividGold, 'role_supervisor'),
            _tile('مدراء', byRole['admin'], RuhamaaColors.rose, 'role_admin'),
          ]),
          _section('النشاط (أرقام إجمالية فقط)', [
            _StatTile(label: 'إجمالي التبرعات', value: _int(s['donations_total']), color: RuhamaaColors.primary),
            _StatTile(label: 'تبرعات آخر 30 يومًا', value: _int(s['donations_last_30_days']), color: RuhamaaColors.primaryBright),
            _StatTile(label: 'إجمالي الطلبات', value: _int(s['needs_total']), color: RuhamaaColors.vividGold),
            _StatTile(label: 'طلبات آخر 30 يومًا', value: _int(s['needs_last_30_days']), color: RuhamaaColors.blue),
          ]),
          const SizedBox(height: 8),
          const Text(
            'اضغط على أي بطاقة لعرض قائمة المستخدمين فيها.',
            style: TextStyle(color: Colors.black54, fontFamily: 'Tajawal'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> tiles) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: tiles),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.color, this.onTap});

  final String label;
  final int value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
