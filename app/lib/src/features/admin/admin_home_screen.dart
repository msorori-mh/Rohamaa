import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/admin_repository.dart';
import '../../data/operations_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import '../auth/change_password_screen.dart';
import '../reports/reports_screen.dart';
import 'accepted_matches_screen.dart';
import 'admin_dashboard_screen.dart' show ContributionReviewScreen;
import 'create_staff_screen.dart';
import 'item_matching_v2_screen.dart';
import 'need_discovery_admin_screen.dart';
import 'partner_management_screen.dart';
import 'risk_management_screen.dart';
import 'service_areas_screen.dart';
import 'service_incident_management_screen.dart';
import 'service_matching_screen.dart';
import 'user_management_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late Future<_AdminHomeData> _future;

  @override
  void initState() { super.initState(); _reload(); }
  void _reload() { _future = _load(); }
  Future<_AdminHomeData> _load() async {
    final client = Supabase.instance.client;
    final results = await Future.wait<dynamic>([
      AdminRepository(client).stats(),
      OperationsRepository(client).adminQueue(),
    ]);
    return _AdminHomeData(
      stats: results[0] as AdminStats,
      queue: results[1] as List<AdminQueueItem>,
    );
  }
  Future<void> _open(Widget screen) async { await Navigator.push(context, MaterialPageRoute(builder: (_) => screen)); if (mounted) setState(_reload); }

  Future<void> _openQueue(AdminQueueItem item) async {
    final Widget? screen = switch (item.actionKey) {
      'risks' => const RiskManagementScreen(),
      'incidents' => const ServiceIncidentManagementScreen(),
      'accepted_matches' => const AcceptedMatchesScreen(),
      'contributions' => const ContributionReviewScreen(),
      'partners' => const PartnerManagementScreen(),
      'item_matching' => const ItemMatchingV2Screen(),
      'needs' => const NeedDiscoveryAdminScreen(),
      'service_matching' => const ServiceMatchingScreen(),
      _ => null,
    };
    if (screen != null) {
      await _open(screen);
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذه العملية تحتاج تنسيقًا مباشرًا مع المشرف أو الموصل.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تشغيل رحماء'),
        actions: [
          IconButton(tooltip: 'تغيير كلمة المرور', onPressed: () => _open(const ChangePasswordScreen(role: 'admin', requiredChange: false)), icon: const Icon(Icons.password_outlined)),
          IconButton(tooltip: 'تسجيل الخروج', onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout)),
        ],
      ),
      body: FutureBuilder<_AdminHomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('تعذر تحميل لوحة التشغيل: ${snapshot.error}'));
          final data = snapshot.data!;
          final stats = data.stats;
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _Metric(label: 'تبرعات للمعالجة', value: stats.donations),
                  _Metric(label: 'احتياجات مفتوحة', value: stats.needs),
                  _Metric(label: 'توصيلات جارية', value: stats.deliveries),
                  _Metric(label: 'مساهمات نقدية معلقة', value: stats.pendingContributions),
                  _Metric(label: 'مخاطر مفتوحة', value: stats.openRiskFlags),
                ]),
                const SizedBox(height: 24),
                Row(children: [
                  const Expanded(child: Text('الأولوية الآن', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: RuhamaaColors.warmGoldSoft, borderRadius: BorderRadius.circular(20)),
                    child: Text('${data.queue.length} عملية', style: const TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 6),
                const Text('مرتبة حسب المخاطر والتعطل ثم مدة الانتظار، دون إظهار بيانات المستفيدين الشخصية.', style: TextStyle(color: RuhamaaColors.textMuted, height: 1.45)),
                const SizedBox(height: 12),
                if (data.queue.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(18), child: Row(children: [Icon(Icons.check_circle_outline_rounded, color: RuhamaaColors.success), SizedBox(width: 10), Expanded(child: Text('لا توجد عمليات معلقة في طابور الأولوية.'))])))
                else
                  ...data.queue.take(8).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PriorityItem(item: item, onTap: () => _openQueue(item)),
                  )),
                const SizedBox(height: 14),
                const Text('أدوات التشغيل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _Action(icon: Icons.analytics_outlined, title: 'التقارير الأساسية', subtitle: 'الأثر، نجاح التوصيل، الخدمات، المساهمات والمصروفات.', onTap: () => _open(const ReportsScreen())),
                _Action(icon: Icons.map_outlined, title: 'المدن والمناطق', subtitle: 'إدارة نطاقات الخدمة التي تُستخدم للتوصيل وإسناد المشرفين.', onTap: () => _open(const ServiceAreasScreen())),
                _Action(icon: Icons.person_add_alt_1_outlined, title: 'إنشاء حساب فريق رحماء', subtitle: 'إنشاء موصل أو مشرف مدينة/منطقة ببريد وكلمة مرور ابتدائية.', onTap: () => _open(const CreateStaffScreen())),
                _Action(icon: Icons.fact_check_outlined, title: 'احتياجات راجعها رحماء', subtitle: 'راجع الطلبات واكتب بطاقة محايدة تحفّز العطاء دون كشف الهوية.', onTap: () => _open(const NeedDiscoveryAdminScreen())),
                _Action(icon: Icons.hub_outlined, title: 'مطابقة الأشياء V2', subtitle: 'مراجعة شفافة للتصنيف والنوع والمقاس/العمر/الصف والملاءمة قبل إرسال العرض.', onTap: () => _open(const ItemMatchingV2Screen())),
                _Action(icon: Icons.handyman_outlined, title: 'الوقت والمهارات', subtitle: 'راجع عروض الأفراد وطابقها بطلبات الخدمات.', onTap: () => _open(const ServiceMatchingScreen())),
                _Action(icon: Icons.storefront_outlined, title: 'شركاء رحماء', subtitle: 'تحقق من المحلات والورش والصالونات قبل السماح بعروض خدمات باسمها.', onTap: () => _open(const PartnerManagementScreen())),
                _Action(icon: Icons.report_problem_outlined, title: 'بلاغات الخدمات', subtitle: 'راجع بلاغات الخصوصية، الرسوم غير المتفق عليها، التصوير، عدم الحضور وجودة التنفيذ.', onTap: () => _open(const ServiceIncidentManagementScreen())),
                _Action(icon: Icons.delivery_dining_outlined, title: 'مطابقات جاهزة للتوصيل', subtitle: 'أسند الموصل والدراجة بعد قبول المستفيد.', onTap: () => _open(const AcceptedMatchesScreen())),
                _Action(icon: Icons.payments_outlined, title: 'المساهمات التشغيلية', subtitle: 'اعتمد المساهمة بعد تأكيد استلامها نقدًا من المندوب.', onTap: () => _open(const ContributionReviewScreen())),
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

class _AdminHomeData {
  const _AdminHomeData({required this.stats, required this.queue});
  final AdminStats stats;
  final List<AdminQueueItem> queue;
}

class _PriorityItem extends StatelessWidget {
  const _PriorityItem({required this.item, required this.onTap});
  final AdminQueueItem item;
  final VoidCallback onTap;
  @override Widget build(BuildContext context) {
    final urgent = item.priority >= 80;
    final age = item.ageHours < 24 ? '${item.ageHours.round()} ساعة' : '${(item.ageHours / 24).floor()} يوم';
    return Card(
      color: urgent ? RuhamaaColors.warmGoldSoft : RuhamaaColors.warmSurface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: urgent ? Colors.white : RuhamaaColors.softGreen,
          foregroundColor: urgent ? RuhamaaColors.warmGold : RuhamaaColors.primary,
          child: Icon(urgent ? Icons.priority_high_rounded : Icons.pending_actions_rounded),
        ),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('${item.subtitle}\n${item.code} • منذ $age'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: onTap,
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
