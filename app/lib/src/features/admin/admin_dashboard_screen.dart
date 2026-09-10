import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/admin_repository.dart';
import 'accepted_matches_screen.dart';

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
      appBar: AppBar(title: const Text('لوحة تشغيل رحماء')),
      body: FutureBuilder<AdminStats>(
        future: _stats,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('تعذر تحميل لوحة الإدارة. حاول مجددًا.'));
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
                    _StatCard(label: 'مساهمات نقدية بانتظار التحقق', value: s.pendingContributions, icon: Icons.payments_outlined),
                    _StatCard(label: 'إشارات خطر مفتوحة', value: s.openRiskFlags, icon: Icons.shield_outlined),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('التشغيل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _AdminAction(icon: Icons.hub_outlined, title: 'المطابقة', subtitle: 'راجع التبرعات وأرسل عرض مطابقة خاصًا للمستفيد.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MatchingQueueScreen()))),
                _AdminAction(icon: Icons.delivery_dining_outlined, title: 'مطابقات جاهزة للتوصيل', subtitle: 'المستفيد وافق؛ أسند المندوب والدراجة.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AcceptedMatchesScreen()))),
                _AdminAction(icon: Icons.verified_outlined, title: 'التحقق من المساهمات', subtitle: 'اعتمد المساهمة بعد تأكيد استلام المبلغ نقدًا من المندوب. لا توجد حوالات جديدة داخل التطبيق.', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContributionReviewScreen()))),
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
      await AdminRepository(Supabase.instance.client).approveMatch(
        widget.donation['id'] as String,
        candidate['need_id'] as String,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال عرض المطابقة للمستفيد. لن يتم إنشاء التوصيل قبل موافقته.')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال عرض المطابقة: $e')));
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
                    trailing: FilledButton(onPressed: () => _approve(n), child: const Text('إرسال عرض')),
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
  final Set<String> _busyIds = <String>{};

  AdminRepository get _repo => AdminRepository(Supabase.instance.client);

  void _load() => _future = _repo.pendingContributions();

  Future<void> _verify(Map<String, dynamic> contribution, bool verified) async {
    final id = '${contribution['id']}';
    if (_busyIds.contains(id)) return;

    if (!verified) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد عدم الاستلام'),
          content: const Text('هل تأكدت أن المبلغ لم يُستلم؟ سيُرفض سجل المساهمة.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد الرفض')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _busyIds.add(id));
    try {
      await _repo.verifyContribution(id, verified);
      if (!mounted) return;
      setState(() {
        _busyIds.remove(id);
        _load();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(verified ? 'تم اعتماد المساهمة.' : 'تم تسجيل عدم استلام المبلغ.')),
      );
    } catch (error) {
      debugPrint('Contribution verification failed: $error');
      if (!mounted) return;
      setState(() => _busyIds.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث المساهمة. حدّث القائمة ثم حاول مجددًا.')),
      );
    }
  }

  String _details(Map<String, dynamic> contribution) {
    final method = contribution['payment_method'];
    final code = contribution['public_code'] ?? '';
    if (method == 'cash_to_courier') {
      return 'نقدًا للمندوب • $code\nاعتمدها فقط بعد تأكيد استلام المبلغ فعليًا.';
    }
    final reference = contribution['payment_reference'] ?? 'غير مسجل';
    return 'سجل تحويل قديم • $code\nالمرجع: $reference';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('مراجعة المساهمات النقدية')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (s.hasError) {
              return Center(
                child: FilledButton.icon(
                  onPressed: () => setState(_load),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة تحميل المساهمات'),
                ),
              );
            }
            final rows = s.data ?? [];
            if (rows.isEmpty) return const Center(child: Text('لا توجد مساهمات بانتظار التحقق'));
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final c = rows[i];
                final id = '${c['id']}';
                final busy = _busyIds.contains(id);
                return Card(
                  child: ListTile(
                    title: Text('${c['amount_yer']} ريال'),
                    subtitle: Text(_details(c)),
                    trailing: busy
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Wrap(
                            children: [
                              IconButton(
                                key: Key('verify-contribution-$id'),
                                tooltip: 'اعتماد المبلغ المستلم',
                                icon: const Icon(Icons.check_circle_outline_rounded),
                                onPressed: () => _verify(c, true),
                              ),
                              IconButton(
                                key: Key('reject-contribution-$id'),
                                tooltip: 'رفض: لم يُستلم المبلغ',
                                icon: const Icon(Icons.cancel_outlined),
                                onPressed: () => _verify(c, false),
                              ),
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
