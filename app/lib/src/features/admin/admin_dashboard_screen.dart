import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/admin_repository.dart';
import 'delivery_assignment_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<AdminStats> _stats;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _stats = AdminRepository(Supabase.instance.client).stats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة تشغيل سند')),
      body: FutureBuilder<AdminStats>(
        future: _stats,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('تعذر تحميل لوحة الإدارة: ${snapshot.error}'));
          final s = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(label: 'تبرعات تنتظر المعالجة', value: s.donations, icon: Icons.inventory_2_outlined),
                    _StatCard(label: 'احتياجات مفتوحة', value: s.needs, icon: Icons.front_hand_outlined),
                    _StatCard(label: 'عمليات توصيل جارية', value: s.deliveries, icon: Icons.delivery_dining_outlined),
                    _StatCard(label: 'مساهمات بانتظار التحقق', value: s.pendingContributions, icon: Icons.payments_outlined),
                    _StatCard(label: 'إشارات خطر مفتوحة', value: s.openRiskFlags, icon: Icons.shield_outlined),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('التشغيل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _AdminAction(icon: Icons.hub_outlined, title: 'المطابقة', subtitle: 'راجع التبرعات واختر أفضل احتياج مطابق.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchingQueueScreen()))),
                _AdminAction(icon: Icons.verified_outlined, title: 'التحقق من المساهمات', subtitle: 'اعتمد أو ارفض مرجع التحويل بعد المراجعة.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContributionReviewScreen()))),
                _AdminAction(icon: Icons.warning_amber_outlined, title: 'مراجعة المخاطر', subtitle: 'افحص إشارات الاحتيال أو سوء الاستخدام.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiskQueueScreen()))),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});
  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(icon, size: 32),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$value', style: Theme.of(context).textTheme.headlineMedium), Text(label)])),
              ],
            ),
          ),
        ),
      );
}

class _AdminAction extends StatelessWidget {
  const _AdminAction({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_left), onTap: onTap),
      );
}

class MatchingQueueScreen extends StatefulWidget {
  const MatchingQueueScreen({super.key});

  @override
  State<MatchingQueueScreen> createState() => _MatchingQueueScreenState();
}

class _MatchingQueueScreenState extends State<MatchingQueueScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminRepository(Supabase.instance.client).donationsQueue();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('طابور المطابقة')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return Center(child: Text('خطأ: ${s.error}'));
            final rows = s.data ?? [];
            if (rows.isEmpty) return const Center(child: Text('لا توجد تبرعات بانتظار المطابقة'));
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final d = rows[i];
                return Card(
                  child: ListTile(
                    title: Text('${d['item_type']}'),
                    subtitle: Text('${d['public_code']} • ${d['category']}'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchCandidatesScreen(donation: d))),
                  ),
                );
              },
            );
          },
        ),
      );
}

class MatchCandidatesScreen extends StatefulWidget {
  const MatchCandidatesScreen({super.key, required this.donation});
  final Map<String, dynamic> donation;

  @override
  State<MatchCandidatesScreen> createState() => _MatchCandidatesScreenState();
}

class _MatchCandidatesScreenState extends State<MatchCandidatesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminRepository(Supabase.instance.client).matchCandidates(widget.donation['id'] as String);
  }

  Future<void> _approve(Map<String, dynamic> candidate) async {
    try {
      final matchId = await AdminRepository(Supabase.instance.client).approveMatch(
        widget.donation['id'] as String,
        candidate['need_id'] as String,
      );
      if (!mounted) return;
      final assigned = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => DeliveryAssignmentScreen(matchId: matchId)),
      );
      if (!mounted) return;
      if (assigned == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اعتماد المطابقة وإسناد التوصيل.')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اعتماد المطابقة. يمكن إسناد التوصيل لاحقًا.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر اعتماد المطابقة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('مرشحو ${widget.donation['item_type']}')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) return Center(child: Text('خطأ: ${s.error}'));
            final rows = s.data ?? [];
            if (rows.isEmpty) return const Center(child: Text('لا يوجد تطابق مناسب حاليًا'));
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final n = rows[i];
                return Card(
                  child: ListTile(
                    title: Text('${n['item_type']}'),
                    subtitle: Text('النقاط ${n['score']} • المسافة ${n['distance_km'] ?? '-'} كم • طلبات مماثلة سابقة ${n['prior_same_category']}'),
                    trailing: FilledButton(onPressed: () => _approve(n), child: const Text('اعتماد')),
                  ),
                );
              },
            );
          },
        ),
      );
}

class ContributionReviewScreen extends StatefulWidget {
  const ContributionReviewScreen({super.key});

  @override
  State<ContributionReviewScreen> createState() => _ContributionReviewScreenState();
}

class _ContributionReviewScreenState extends State<ContributionReviewScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  void _load() => _future = AdminRepository(Supabase.instance.client).pendingContributions();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('مراجعة المساهمات')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            final rows = s.data ?? [];
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final c = rows[i];
                return Card(
                  child: ListTile(
                    title: Text('${c['amount_yer']} ريال'),
                    subtitle: Text('مرجع: ${c['payment_reference'] ?? 'غير مسجل'}'),
                    trailing: Wrap(
                      children: [
                        IconButton(icon: const Icon(Icons.check), onPressed: () async {await AdminRepository(Supabase.instance.client).verifyContribution(c['id'] as String, true); setState(_load);}),
                        IconButton(icon: const Icon(Icons.close), onPressed: () async {await AdminRepository(Supabase.instance.client).verifyContribution(c['id'] as String, false); setState(_load);}),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

class RiskQueueScreen extends StatefulWidget {
  const RiskQueueScreen({super.key});

  @override
  State<RiskQueueScreen> createState() => _RiskQueueScreenState();
}

class _RiskQueueScreenState extends State<RiskQueueScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminRepository(Supabase.instance.client).riskQueue();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('إشارات المخاطر')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            final rows = s.data ?? [];
            if (rows.isEmpty) return const Center(child: Text('لا توجد إشارات مفتوحة'));
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final r = rows[i];
                return Card(child: ListTile(leading: const Icon(Icons.warning_amber), title: Text('${r['rule_code']}'), subtitle: Text('الخطورة: ${r['severity']}\n${r['details']}')));
              },
            );
          },
        ),
      );
}
