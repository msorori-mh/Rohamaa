import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/admin_repository.dart';
import '../../data/operations_repository.dart';
import '../../data/recovery_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import '../auth/change_password_screen.dart';
import '../reports/reports_screen.dart';
import 'accepted_matches_screen.dart';
import 'admin_dashboard_screen.dart' show ContributionReviewScreen;
import 'create_staff_screen.dart';
import 'item_matching_v2_screen.dart';
import 'need_discovery_admin_screen.dart';
import 'partner_management_screen.dart';
import 'recovery_inventory_screen.dart';
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
  _QueueFilter _filter = _QueueFilter.all;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AdminHomeData> _load() async {
    final client = Supabase.instance.client;
    final results = await Future.wait<dynamic>([
      AdminRepository(client).stats(),
      OperationsRepository(client).adminQueue(),
      RecoveryRepository(client).priorities(),
    ]);
    final recovery = results[2] as List<AdminRecoveryPriorityItem>;
    final recoveryDonationIds = recovery.map((item) => item.id).toSet();
    final queue = <AdminQueueItem>[
      ...(results[1] as List<AdminQueueItem>).where(
        (item) => item.kind != 'donation' || !recoveryDonationIds.contains(item.id),
      ),
      ...recovery.map(
        (item) => AdminQueueItem(
          key: item.key,
          kind: item.kind,
          id: item.id,
          code: item.code,
          title: item.title,
          subtitle: item.subtitle,
          priority: item.priority,
          ageHours: item.ageHours,
          actionKey: item.actionKey,
        ),
      ),
    ]..sort((a, b) {
        final byPriority = b.priority.compareTo(a.priority);
        return byPriority != 0 ? byPriority : b.ageHours.compareTo(a.ageHours);
      });
    return _AdminHomeData(
      stats: results[0] as AdminStats,
      queue: queue.take(50).toList(),
      refreshedAt: DateTime.now(),
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _refresh();
  }

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
      'recovery' => const RecoveryInventoryScreen(),
      _ => null,
    };
    if (screen != null) {
      await _open(screen);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذه العملية تحتاج تنسيقًا مباشرًا مع المشرف أو الموصل.')),
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج؟'),
        content: const Text('سيتم إنهاء جلسة الإدارة على هذا الجهاز.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            key: const Key('admin-confirm-sign-out'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed == true) await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: RuhamaaColors.pageGradient),
        child: SafeArea(
          bottom: false,
          child: FutureBuilder<_AdminHomeData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _AdminLoadError(onRetry: _refresh);
              }
              final data = snapshot.data!;
              final visibleQueue = data.queue.where(_filter.accepts).take(8).toList();
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  key: const Key('admin-operations-scroll'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _AdminHero(
                      refreshedAt: data.refreshedAt,
                      urgentCount: data.queue.where((item) => item.priority >= 80).length,
                      onRefresh: _refresh,
                      onPassword: () => _open(
                        const ChangePasswordScreen(role: 'admin', requiredChange: false),
                      ),
                      onSignOut: _signOut,
                    ),
                    Transform.translate(
                      offset: const Offset(0, -30),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _MetricsPanel(stats: data.stats),
                            const SizedBox(height: 22),
                            _SectionHeading(
                              title: 'الأولوية الآن',
                              subtitle: 'مرتبة حسب الخطورة ومدة الانتظار دون كشف بيانات خاصة.',
                              badge: '${data.queue.length} عملية',
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _QueueFilter.values
                                    .map(
                                      (filter) => Padding(
                                        padding: const EdgeInsetsDirectional.only(end: 8),
                                        child: ChoiceChip(
                                          label: Text(filter.label),
                                          selected: _filter == filter,
                                          onSelected: (_) => setState(() => _filter = filter),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (visibleQueue.isEmpty)
                              const _AdminEmpty(text: 'لا توجد عمليات معلقة ضمن هذا التصنيف.')
                            else
                              ...visibleQueue.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _PriorityItem(item: item, onTap: () => _openQueue(item)),
                                ),
                              ),
                            _ToolGroup(
                              icon: Icons.inventory_2_outlined,
                              title: 'الاستلام والتأهيل',
                              subtitle: 'من وصول العطاء إلى جاهزيته للمطابقة.',
                              tools: [
                                _Tool(Icons.warehouse_outlined, 'التأهيل والمخزون', 'استلام، فحص A–D، تنظيف، إصلاح أو تدوير.', RuhamaaColors.primaryBright, () => _open(const RecoveryInventoryScreen())),
                                _Tool(Icons.fact_check_outlined, 'الاحتياجات الموثوقة', 'مراجعة الطلب وصياغة بطاقة تحفظ الخصوصية.', RuhamaaColors.blue, () => _open(const NeedDiscoveryAdminScreen())),
                              ],
                            ),
                            _ToolGroup(
                              icon: Icons.hub_outlined,
                              title: 'المطابقة والتنفيذ',
                              subtitle: 'تحويل الموارد والخدمات المتاحة إلى عمليات مكتملة.',
                              tools: [
                                _Tool(Icons.join_inner_rounded, 'مطابقة الأشياء', 'مراجعة الملاءمة وإرسال عرض المطابقة.', RuhamaaColors.vividGold, () => _open(const ItemMatchingV2Screen())),
                                _Tool(Icons.handyman_outlined, 'الوقت والمهارات', 'مطابقة عروض الأفراد بطلبات الخدمات.', RuhamaaColors.rose, () => _open(const ServiceMatchingScreen())),
                                _Tool(Icons.delivery_dining_outlined, 'جاهز للتوصيل', 'إسناد الموصل والدراجة بعد قبول المستفيد.', RuhamaaColors.primary, () => _open(const AcceptedMatchesScreen())),
                              ],
                            ),
                            _ToolGroup(
                              icon: Icons.health_and_safety_outlined,
                              title: 'السلامة والحوكمة',
                              subtitle: 'معالجة الاستثناءات وحماية الثقة في المنظومة.',
                              tools: [
                                _Tool(Icons.shield_outlined, 'مراجعة المخاطر', 'فحص الإشارات وتوثيق قرار المراجعة.', RuhamaaColors.rose, () => _open(const RiskManagementScreen())),
                                _Tool(Icons.report_problem_outlined, 'بلاغات الخدمات', 'الخصوصية، عدم الحضور وجودة التنفيذ.', RuhamaaColors.vividGold, () => _open(const ServiceIncidentManagementScreen())),
                                _Tool(Icons.storefront_outlined, 'شركاء رحماء', 'اعتماد الورش والمحلات ومقدمي الخدمات.', RuhamaaColors.blue, () => _open(const PartnerManagementScreen())),
                                _Tool(Icons.payments_outlined, 'المساهمات التشغيلية', 'تأكيد المبالغ النقدية المستلمة ميدانيًا.', RuhamaaColors.primaryBright, () => _open(const ContributionReviewScreen())),
                              ],
                            ),
                            _ToolGroup(
                              icon: Icons.settings_suggest_outlined,
                              title: 'الإدارة والتحليل',
                              subtitle: 'تهيئة نطاق التشغيل والفريق وقياس الأثر.',
                              tools: [
                                _Tool(Icons.analytics_outlined, 'التقارير الأساسية', 'الأثر، التوصيل، الخدمات والمصروفات.', RuhamaaColors.primary, () => _open(const ReportsScreen())),
                                _Tool(Icons.map_outlined, 'المدن والمناطق', 'نطاقات الخدمة وإسناد المشرفين.', RuhamaaColors.blue, () => _open(const ServiceAreasScreen())),
                                _Tool(Icons.person_add_alt_1_outlined, 'إضافة فريق', 'إنشاء حساب موصل أو مشرف تشغيل.', RuhamaaColors.vividGold, () => _open(const CreateStaffScreen())),
                                _Tool(Icons.manage_accounts_outlined, 'المستخدمون والأدوار', 'إدارة الصلاحيات وتجميد الحسابات.', RuhamaaColors.rose, () => _open(const UserManagementScreen())),
                              ],
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'مركز تشغيل رحماء • مأرب',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AdminHomeData {
  const _AdminHomeData({required this.stats, required this.queue, required this.refreshedAt});
  final AdminStats stats;
  final List<AdminQueueItem> queue;
  final DateTime refreshedAt;
}

enum _QueueFilter {
  all('الكل'),
  urgent('عاجل'),
  matching('المطابقة'),
  delivery('التوصيل'),
  safeguards('الضبط');

  const _QueueFilter(this.label);
  final String label;

  bool accepts(AdminQueueItem item) => switch (this) {
        _QueueFilter.all => true,
        _QueueFilter.urgent => item.priority >= 80,
        _QueueFilter.matching => const {'item_matching', 'needs', 'service_matching'}.contains(item.actionKey),
        _QueueFilter.delivery => item.actionKey == 'accepted_matches' || item.kind == 'delivery',
        _QueueFilter.safeguards => const {'risks', 'incidents', 'contributions', 'partners'}.contains(item.actionKey),
      };
}

class _AdminHero extends StatelessWidget {
  const _AdminHero({
    required this.refreshedAt,
    required this.urgentCount,
    required this.onRefresh,
    required this.onPassword,
    required this.onSignOut,
  });

  final DateTime refreshedAt;
  final int urgentCount;
  final VoidCallback onRefresh;
  final VoidCallback onPassword;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final minute = refreshedAt.minute.toString().padLeft(2, '0');
    return Container(
      height: 224,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      decoration: const BoxDecoration(
        gradient: RuhamaaColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), shape: BoxShape.circle),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مركز التشغيل', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    Text('لوحة إدارة رحماء', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              if (Navigator.canPop(context))
                IconButton(
                  tooltip: 'العودة',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ),
              PopupMenuButton<String>(
                iconColor: Colors.white,
                tooltip: 'خيارات الإدارة',
                onSelected: (value) {
                  if (value == 'password') onPassword();
                  if (value == 'logout') onSignOut();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'password', child: Text('تغيير كلمة المرور')),
                  PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
                ],
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  urgentCount == 0 ? 'لا توجد حالات عاجلة الآن' : '$urgentCount حالات تحتاج تدخلك العاجل',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 19),
                label: Text('${refreshedAt.hour}:$minute'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricsPanel extends StatelessWidget {
  const _MetricsPanel({required this.stats});
  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(Icons.inventory_2_outlined, 'تبرعات للمعالجة', stats.donations, RuhamaaColors.primaryBright),
      _MetricData(Icons.favorite_outline_rounded, 'احتياجات مفتوحة', stats.needs, RuhamaaColors.rose),
      _MetricData(Icons.delivery_dining_outlined, 'توصيلات جارية', stats.deliveries, RuhamaaColors.blue),
      _MetricData(Icons.payments_outlined, 'مساهمات معلقة', stats.pendingContributions, RuhamaaColors.vividGold),
      _MetricData(Icons.gpp_maybe_outlined, 'مخاطر مفتوحة', stats.openRiskFlags, RuhamaaColors.primary),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 700 ? 5 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: metrics.map((metric) => SizedBox(width: width, child: _Metric(data: metric))).toList(),
            );
          },
        ),
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.icon, this.label, this.value, this.color);
  final IconData icon;
  final String label;
  final int value;
  final Color color;
}

class _Metric extends StatelessWidget {
  const _Metric({required this.data});
  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 105),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: data.color.withValues(alpha: .08), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, color: data.color, size: 22),
              const Spacer(),
              Text('${data.value}', style: TextStyle(color: data.color, fontSize: 27, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          Text(data.label, maxLines: 2, style: const TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w700, height: 1.25)),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle, this.badge});
  final String title;
  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.4)),
            ],
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: RuhamaaColors.warmGoldSoft, borderRadius: BorderRadius.circular(18)),
            child: Text(badge!, style: const TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w800)),
          ),
        ],
      ],
    );
  }
}

class _PriorityItem extends StatelessWidget {
  const _PriorityItem({required this.item, required this.onTap});
  final AdminQueueItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urgent = item.priority >= 80;
    final age = item.ageHours < 24 ? '${item.ageHours.round()} ساعة' : '${(item.ageHours / 24).floor()} يوم';
    final accent = urgent ? RuhamaaColors.rose : RuhamaaColors.primaryBright;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: accent.withValues(alpha: .11), borderRadius: BorderRadius.circular(16)),
                child: Icon(urgent ? Icons.priority_high_rounded : Icons.pending_actions_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                        if (urgent) const Text('عاجل', style: TextStyle(color: RuhamaaColors.rose, fontWeight: FontWeight.w900, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.subtitle, style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.35)),
                    const SizedBox(height: 7),
                    Text('${item.code} • منذ $age', style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 13),
                child: Icon(Icons.chevron_left_rounded, color: RuhamaaColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tool {
  const _Tool(this.icon, this.title, this.subtitle, this.color, this.onTap);
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

class _ToolGroup extends StatelessWidget {
  const _ToolGroup({required this.icon, required this.title, required this.subtitle, required this.tools});
  final IconData icon;
  final String title;
  final String subtitle;
  final List<_Tool> tools;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: RuhamaaColors.softGreen, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: RuhamaaColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                    Text(subtitle, style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 12, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 3 : 2;
              final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: tools.map((tool) => SizedBox(width: width, child: _ToolTile(tool: tool))).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool});
  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: RuhamaaColors.primaryDark.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: tool.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 154),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: tool.color, shape: BoxShape.circle),
                  child: Icon(tool.icon, color: Colors.white, size: 23),
                ),
                const SizedBox(height: 12),
                Text(tool.title, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w900, height: 1.25)),
                const SizedBox(height: 4),
                Text(
                  tool.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminEmpty extends StatelessWidget {
  const _AdminEmpty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.task_alt_rounded, color: RuhamaaColors.success),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: RuhamaaColors.textMuted, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}

class _AdminLoadError extends StatelessWidget {
  const _AdminLoadError({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.cloud_off_rounded, color: RuhamaaColors.rose, size: 54),
        const SizedBox(height: 16),
        const Text('تعذر تحميل مركز التشغيل', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('تحقق من الاتصال ثم حاول مجددًا. لم يتم تغيير أي بيانات.', textAlign: TextAlign.center, style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5)),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
      ],
    );
  }
}
