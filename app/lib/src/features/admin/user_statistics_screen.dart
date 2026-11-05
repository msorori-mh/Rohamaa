import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/admin_repository.dart';
import '../../theme/ruhamaa_theme.dart';

/// Aggregate user counts. Shows totals only; no individual user is listed.
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
            _StatTile(label: 'إجمالي المستخدمين', value: _int(s['total_users']), color: RuhamaaColors.primary),
            _StatTile(label: 'حسابات مجمّدة', value: _int(s['suspended']), color: RuhamaaColors.rose),
            _StatTile(label: 'تسجيلات آخر 7 أيام', value: _int(s['new_last_7_days']), color: RuhamaaColors.blue),
            _StatTile(label: 'تسجيلات آخر 30 يومًا', value: _int(s['new_last_30_days']), color: RuhamaaColors.blue),
            _StatTile(label: 'نشطون آخر 30 يومًا', value: _int(s['active_last_30_days']), color: RuhamaaColors.primaryBright),
          ]),
          _section('المتبرعون والمحتاجون', [
            _StatTile(label: 'متبرعون', value: _int(s['donors']), color: RuhamaaColors.primary),
            _StatTile(label: 'محتاجون (لديهم طلبات)', value: _int(s['beneficiaries']), color: RuhamaaColors.vividGold),
            _StatTile(label: 'متبرع ومحتاج معًا', value: _int(s['donors_and_beneficiaries']), color: RuhamaaColors.blue),
            _StatTile(label: 'بدون تبرع أو طلب', value: _int(s['neither']), color: RuhamaaColors.rose),
          ]),
          _section('حسب الدور', [
            _StatTile(label: 'مستخدمون', value: _int(byRole['user']), color: RuhamaaColors.primary),
            _StatTile(label: 'موصلون', value: _int(byRole['courier']), color: RuhamaaColors.blue),
            _StatTile(label: 'مشرفون', value: _int(byRole['supervisor']), color: RuhamaaColors.vividGold),
            _StatTile(label: 'مدراء', value: _int(byRole['admin']), color: RuhamaaColors.rose),
          ]),
          const SizedBox(height: 8),
          Text(
            'أرقام إجمالية فقط، ولا تعرض بيانات أي مستخدم بعينه.',
            style: const TextStyle(color: Colors.black54, fontFamily: 'Tajawal'),
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
  const _StatTile({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
