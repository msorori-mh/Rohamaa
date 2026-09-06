import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/admin_repository.dart';
import '../reports/reports_screen.dart';
import 'accepted_matches_screen.dart';
import 'admin_dashboard_screen.dart' show ContributionReviewScreen, MatchingQueueScreen;
import 'create_staff_screen.dart';
import 'risk_management_screen.dart';
import 'user_management_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late Future<AdminStats> _future;

  @override
  void initState() { super.initState(); _reload(); }
  void _reload() { _future = AdminRepository(Supabase.instance.client).stats(); }
  Future<void> _open(Widget screen) async { await Navigator.push(context, MaterialPageRoute(builder: (_) => screen)); if (mounted) setState(_reload); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تشغيل سند'),
        actions: [IconButton(tooltip: 'تسجيل الخروج', onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout))],
      ),
      body: FutureBuilder<AdminStats>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('تعذر تحميل لوحة التشغيل: ${snapshot.error}'));
          final stats = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _Metric(label: 'تبرعات للمعالجة', value: stats.donations),
                  _Metric(label: 'احتياجات مفتوحة', value: stats.needs),
                  _Metric(label: 'توصيلات جارية', value: stats.deliveries),
                  _Metric(label: 'مساهمات معلقة', value: stats.pendingContributions),
                  _Metric(label: 'مخاطر مفتوحة', value: stats.openRiskFlags),
                ]),
                const SizedBox(height: 24),
                _Action(icon: Icons.analytics_outlined, title: 'التقارير الأساسية', subtitle: 'الأثر، نجاح التوصيل، المساهمات، المصروفات ونسبة تغطية التشغيل.', onTap: () => _open(const ReportsScreen())),
                _Action(icon: Icons.person_add_alt_1_outlined, title: 'إنشاء حساب فريق سند', subtitle: 'إنشاء موصل أو مشرف مدينة/منطقة ببريد وكلمة مرور ابتدائية.', onTap: () => _open(const CreateStaffScreen())),
                _Action(icon: Icons.hub_outlined, title: 'المطابقة', subtitle: 'أرسل عروض مطابقة خاصة للمستفيدين.', onTap: () => _open(const MatchingQueueScreen())),
                _Action(icon: Icons.delivery_dining_outlined, title: 'مطابقات جاهزة للتوصيل', subtitle: 'أسند المندوب والدراجة بعد قبول المستفيد.', onTap: () => _open(const AcceptedMatchesScreen())),
                _Action(icon: Icons.payments_outlined, title: 'المساهمات التشغيلية', subtitle: 'تحقق من أرقام الحوالات واعتمد أو ارفض.', onTap: () => _open(const ContributionReviewScreen())),
                _Action(icon: Icons.shield_outlined, title: 'مراجعة المخاطر', subtitle: 'راجع الإشارات وسجّل قرار المراجعة.', onTap: () => _open(const RiskManagementScreen())),
                _Action(icon: Icons.manage_accounts_outlined, title: 'المستخدمون والموصلون', subtitle: 'إدارة الأدوار وتجميد الحسابات عند الضرورة.', onTap: () => _open(const UserManagementScreen())),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label; final int value;
  @override Widget build(BuildContext context) => SizedBox(width: 190, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$value', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)), Text(label)]))));
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  @override Widget build(BuildContext context) => Card(child: ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_left), onTap: onTap));
}
