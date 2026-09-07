import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/handoff_repository.dart';
import '../../data/operations_repository.dart';
import '../../domain/operation_status_presenter.dart';
import '../../theme/ruhamaa_theme.dart';

class MyHandoffsScreen extends StatelessWidget {
  const MyHandoffsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2).toInt(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('متابعة عملياتي'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.track_changes_outlined), text: 'الحالة'),
            Tab(icon: Icon(Icons.notifications_none_rounded), text: 'التنبيهات'),
            Tab(icon: Icon(Icons.local_shipping_outlined), text: 'التسليم'),
          ]),
        ),
        body: const TabBarView(children: [_OperationsList(), _NotificationsList(), _HandoffsList()]),
      ),
    );
  }
}

class _OperationsList extends StatefulWidget {
  const _OperationsList();
  @override State<_OperationsList> createState() => _OperationsListState();
}

class _OperationsListState extends State<_OperationsList> {
  late Future<List<OperationItem>> _future;
  OperationsRepository get _repo => OperationsRepository(Supabase.instance.client);
  @override void initState() { super.initState(); _reload(); }
  void _reload() => _future = _repo.myOperations();

  IconData _icon(String kind) => switch (kind) {
    'donation' => Icons.volunteer_activism_outlined,
    'need' => Icons.front_hand_outlined,
    'item_match' => Icons.compare_arrows_rounded,
    'delivery' => Icons.local_shipping_outlined,
    'service_offer' => Icons.handyman_outlined,
    'service_request' => Icons.support_agent_outlined,
    'service_match' => Icons.handshake_outlined,
    'item_processing' => Icons.warehouse_outlined,
    _ => Icons.receipt_long_outlined,
  };

  @override Widget build(BuildContext context) => FutureBuilder<List<OperationItem>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return _LoadError(message: 'تعذر تحميل الحالات', onRetry: () => setState(_reload));
      final rows = snapshot.data ?? const [];
      return RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          itemCount: rows.isEmpty ? 1 : rows.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (rows.isEmpty) return const _EmptyState(icon: Icons.track_changes_outlined, title: 'لا توجد عمليات بعد', subtitle: 'عند تسجيل عطاء أو احتياج أو خدمة ستجد حالتها والخطوة التالية هنا.');
            if (index == 0) return _SummaryBanner(total: rows.length, attention: rows.where((row) => row.requiresAction).length);
            final row = rows[index - 1];
            final copy = OperationStatusPresenter.present(row.kind, row.status);
            return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                CircleAvatar(backgroundColor: copy.attention ? RuhamaaColors.warmGoldSoft : RuhamaaColors.softGreen, foregroundColor: copy.attention ? RuhamaaColors.warmGold : RuhamaaColors.primary, child: Icon(_icon(row.kind))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(row.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text('${OperationStatusPresenter.kindLabel(row.kind)} • ${row.code}', style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 12)),
                ])),
                if (copy.attention) const Icon(Icons.priority_high_rounded, color: RuhamaaColors.warmGold),
              ]),
              const SizedBox(height: 12),
              Text(copy.label, style: const TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(copy.nextStep, style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.45)),
              if (row.requiresAction && row.actionRoute != '/handoffs') ...[
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: () => context.push(row.actionRoute), icon: const Icon(Icons.arrow_back_rounded), label: const Text('تنفيذ الخطوة الآن')),
              ],
            ])));
          },
        ),
      );
    },
  );
}

class _NotificationsList extends StatefulWidget {
  const _NotificationsList();
  @override State<_NotificationsList> createState() => _NotificationsListState();
}

class _NotificationsListState extends State<_NotificationsList> {
  late Future<List<UserNotificationItem>> _future;
  OperationsRepository get _repo => OperationsRepository(Supabase.instance.client);
  @override void initState() { super.initState(); _reload(); }
  void _reload() => _future = _repo.myNotifications();
  Future<void> _open(UserNotificationItem item) async {
    if (!item.isRead) await _repo.markRead(item.id);
    if (!mounted) return;
    if (item.actionRoute == '/handoffs') {
      context.go('/handoffs?tab=0');
      return;
    }
    await context.push(item.actionRoute);
    if (mounted) setState(_reload);
  }
  Future<void> _markAll() async { await _repo.markAllRead(); if (mounted) setState(_reload); }

  @override Widget build(BuildContext context) => FutureBuilder<List<UserNotificationItem>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return _LoadError(message: 'تعذر تحميل التنبيهات', onRetry: () => setState(_reload));
      final rows = snapshot.data ?? const [];
      final unread = rows.where((row) => !row.isRead).length;
      return RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          itemCount: rows.isEmpty ? 1 : rows.length + (unread > 0 ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (rows.isEmpty) return const _EmptyState(icon: Icons.notifications_none_rounded, title: 'لا توجد تنبيهات بعد', subtitle: 'ستظهر هنا التغييرات المهمة التي تحتاج معرفتها أو إجراءً منك.');
            if (unread > 0 && index == 0) return OutlinedButton.icon(onPressed: _markAll, icon: const Icon(Icons.done_all_rounded), label: Text('تحديد الكل كمقروء ($unread)'));
            final item = rows[index - (unread > 0 ? 1 : 0)];
            return Card(
              color: item.isRead ? RuhamaaColors.warmSurface : RuhamaaColors.warmGoldSoft,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Icon(item.isRead ? Icons.notifications_none_rounded : Icons.notifications_active_outlined, color: item.isRead ? RuhamaaColors.textMuted : RuhamaaColors.warmGold),
                title: Text(item.title, style: TextStyle(fontWeight: item.isRead ? FontWeight.w700 : FontWeight.w900)),
                subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(item.body)),
                trailing: const Icon(Icons.chevron_left_rounded), onTap: () => _open(item),
              ),
            );
          },
        ),
      );
    },
  );
}

class _HandoffsList extends StatefulWidget {
  const _HandoffsList();
  @override State<_HandoffsList> createState() => _HandoffsListState();
}

class _HandoffsListState extends State<_HandoffsList> {
  late Future<List<UserHandoff>> _future;
  HandoffRepository get _repo => HandoffRepository(Supabase.instance.client);
  @override void initState() { super.initState(); _reload(); }
  void _reload() => _future = _repo.myHandoffs();
  bool _pinAvailable(UserHandoff row) => row.kind == 'pickup' ? ['assigned','heading_to_pickup','rescheduled'].contains(row.status) : ['picked_up','heading_to_recipient','rescheduled'].contains(row.status);
  Future<void> _showPin(UserHandoff row) async {
    try {
      final pin = await _repo.issuePin(deliveryId: row.deliveryId, kind: row.kind);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: Text(row.kind == 'pickup' ? 'رمز الاستلام' : 'رمز التسليم'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('أعطِ هذا الرمز لموصل رحماء فقط عند وصوله إليك.', textAlign: TextAlign.center), const SizedBox(height: 18),
          SelectableText(pin, style: Theme.of(context).textTheme.displayMedium?.copyWith(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w900, letterSpacing: 10)),
          const SizedBox(height: 10), const Text('عند توليد رمز جديد يصبح السابق غير صالح.', textAlign: TextAlign.center, style: TextStyle(color: RuhamaaColors.textMuted)),
        ]), actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم'))],
      ));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء الرمز: $error')));
    }
  }

  @override Widget build(BuildContext context) => FutureBuilder<List<UserHandoff>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return _LoadError(message: 'تعذر تحميل عمليات التسليم', onRetry: () => setState(_reload));
      final rows = snapshot.data ?? const [];
      return RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          itemCount: rows.isEmpty ? 1 : rows.length, separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (rows.isEmpty) return const _EmptyState(icon: Icons.local_shipping_outlined, title: 'لا توجد عملية تسليم الآن', subtitle: 'بعد قبول المطابقة وترتيب الموصل ستظهر الرحلة ورمز التسليم هنا.');
            final row = rows[index];
            final copy = OperationStatusPresenter.present('delivery', row.status);
            return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [const CircleAvatar(backgroundColor: RuhamaaColors.softGreen, foregroundColor: RuhamaaColors.primary, child: Icon(Icons.local_shipping_outlined)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(row.itemType, style: const TextStyle(fontWeight: FontWeight.w900)), Text(row.kind == 'pickup' ? 'استلام العطاء منك' : 'تسليم العطاء إليك', style: const TextStyle(color: RuhamaaColors.textMuted))]))]),
              const SizedBox(height: 12), Text(copy.label, style: const TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w900)), Text(copy.nextStep, style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.45)),
              const SizedBox(height: 8), Text('رمز العملية: ${row.deliveryCode}', style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 12)),
              if (_pinAvailable(row)) ...[const SizedBox(height: 12), FilledButton.icon(onPressed: () => _showPin(row), icon: const Icon(Icons.pin_outlined), label: Text(row.kind == 'pickup' ? 'إظهار رمز الاستلام' : 'إظهار رمز التسليم'))],
            ])));
          },
        ),
      );
    },
  );
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.total, required this.attention});
  final int total; final int attention;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: attention > 0 ? RuhamaaColors.warmGoldSoft : RuhamaaColors.softGreen, borderRadius: BorderRadius.circular(18)), child: Row(children: [Icon(attention > 0 ? Icons.pending_actions_rounded : Icons.check_circle_outline_rounded, color: attention > 0 ? RuhamaaColors.warmGold : RuhamaaColors.primary), const SizedBox(width: 10), Expanded(child: Text(attention > 0 ? 'لديك $attention إجراء مهم من أصل $total عملية.' : 'كل عملياتك تحت المتابعة، ولا يوجد إجراء مطلوب الآن.', style: const TextStyle(fontWeight: FontWeight.w800)))]));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
  final IconData icon; final String title; final String subtitle;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 28), child: Column(children: [Icon(icon, size: 58, color: RuhamaaColors.primary), const SizedBox(height: 14), Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900), textAlign: TextAlign.center), const SizedBox(height: 8), Text(subtitle, style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.5), textAlign: TextAlign.center)]));
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message; final VoidCallback onRetry;
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message), const SizedBox(height: 12), FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة'))])));
}
