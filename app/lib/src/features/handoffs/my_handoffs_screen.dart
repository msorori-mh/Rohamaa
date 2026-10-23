import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../core/main_tab_signal.dart';
import '../../data/handoff_repository.dart';
import '../../data/operations_repository.dart';
import '../../domain/handoff_pin_rules.dart';
import '../../domain/journey_rules.dart';
import '../../domain/operation_rules.dart';
import '../../domain/operation_status_presenter.dart';
import '../../theme/ruhamaa_theme.dart';

/// Routes that are bottom-navigation tabs. They are opened with `go` so the
/// tab switches, instead of stacking a second copy of the tab bar.
const _mainTabRoutes = <String>['/home', '/offers', '/handoffs', '/account'];

bool _isMainTabRoute(String route) {
  final path = route.split('?').first;
  return _mainTabRoutes.contains(path);
}

/// A repeated request for the same tab must still be seen as a new one.
String _withRequestId(String route) => OperationRules.withRequestId(
      route,
      DateTime.now().millisecondsSinceEpoch,
    );

class MyHandoffsScreen extends StatefulWidget {
  const MyHandoffsScreen({super.key, this.initialTab = 0, this.tabRequestId});

  /// 0 = status, 1 = notifications, 2 = handoffs.
  final int initialTab;

  /// Changes whenever a caller asks for [initialTab] again (the `t` query
  /// parameter), so the same tab can be requested twice in a row.
  final String? tabRequestId;

  @override
  State<MyHandoffsScreen> createState() => _MyHandoffsScreenState();
}

class _MyHandoffsScreenState extends State<MyHandoffsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  int get _requestedTab => widget.initialTab.clamp(0, 2).toInt();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this, initialIndex: _requestedTab);
  }

  @override
  void didUpdateWidget(covariant MyHandoffsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final requestChanged = oldWidget.initialTab != widget.initialTab ||
        oldWidget.tabRequestId != widget.tabRequestId;
    if (requestChanged && _tabs.index != _requestedTab) {
      _tabs.animateTo(_requestedTab);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _showStatusTab() {
    if (_tabs.index != 0) _tabs.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 20,
        title: const Text(
          'المتابعة',
          style: TextStyle(color: RuhamaaColors.text, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.track_changes_outlined), text: 'الحالة'),
            Tab(icon: Icon(Icons.notifications_none_rounded), text: 'التنبيهات'),
            Tab(icon: Icon(Icons.local_shipping_outlined), text: 'التسليم'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          const _OperationsList(),
          _NotificationsList(onOpenStatusTab: _showStatusTab),
          const _HandoffsList(),
        ],
      ),
    );
  }
}

/// Shared loading behaviour for the three lists: load once, keep showing the
/// last good data while refreshing, and reload when the follow-up tab becomes
/// visible again (the tab keeps its state while hidden).
abstract class _ListState<W extends StatefulWidget, T> extends State<W> {
  List<T>? rows;
  Object? error;
  bool _loading = false;

  Future<List<T>> fetch();

  @override
  void initState() {
    super.initState();
    MainTabs.active.addListener(_onMainTabChanged);
    reload();
  }

  @override
  void dispose() {
    MainTabs.active.removeListener(_onMainTabChanged);
    super.dispose();
  }

  void _onMainTabChanged() {
    if (MainTabs.active.value == MainTabs.followUp) reload();
  }

  /// Never throws, so it is safe as a RefreshIndicator callback.
  Future<void> reload() async {
    if (_loading) return;
    _loading = true;
    try {
      final data = await fetch();
      if (!mounted) return;
      setState(() {
        rows = data;
        error = null;
      });
    } catch (e) {
      debugPrint('Ataa follow-up list load failed: ${e.runtimeType}');
      if (!mounted) return;
      if (rows == null) {
        setState(() => error = e);
      } else {
        // Keep the list that is already on screen and explain the failure.
        showErrorSnack(context, e);
      }
    } finally {
      _loading = false;
    }
  }

  void retry() {
    setState(() {
      error = null;
      rows = null;
    });
    reload();
  }

  /// Wraps every state (loading, error, empty, data) in a RefreshIndicator so
  /// pull-to-refresh always works.
  Widget buildList({
    required Widget empty,
    required Widget Function(List<T> rows) builder,
  }) {
    final data = rows;
    final Widget child;
    if (data == null) {
      final failure = error;
      child = failure == null
          ? const Center(child: CircularProgressIndicator())
          : ErrorRetry(error: failure, onRetry: retry);
    } else if (data.isEmpty) {
      child = ScrollableEmpty(child: empty);
    } else {
      child = builder(data);
    }
    return RefreshIndicator(onRefresh: reload, child: child);
  }
}

class _OperationsList extends StatefulWidget {
  const _OperationsList();

  @override
  State<_OperationsList> createState() => _OperationsListState();
}

class _OperationsListState extends _ListState<_OperationsList, OperationItem> {
  String? _cancellingId;

  OperationsRepository get _repo => OperationsRepository(Supabase.instance.client);

  @override
  Future<List<OperationItem>> fetch() => _repo.myOperations();

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

  Future<void> _openAction(OperationItem row) async {
    final route = OperationRules.actionRoute(
      kind: row.kind,
      status: row.status,
      serverRoute: row.actionRoute,
    );
    if (!route.startsWith('/')) return;
    if (_isMainTabRoute(route)) {
      context.go(_withRequestId(route));
      return;
    }
    await context.push(route);
    if (mounted) await reload();
  }

  bool _showsAction(OperationItem row) => OperationRules.showsAction(
        kind: row.kind,
        status: row.status,
        requiresAction: row.requiresAction,
        serverRoute: row.actionRoute,
      );

  Future<void> _cancel(OperationItem row) async {
    if (_cancellingId != null) return;
    final isDonation = row.kind == 'donation';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isDonation ? 'إلغاء التبرّع؟' : 'إلغاء الطلب؟'),
        content: Text(
          isDonation
              ? 'سيُلغى تبرّعك «${row.title}» ولن يُعرض على أي طلب. لا يمكن التراجع عن الإلغاء، لكن يمكنك تسجيل تبرّع جديد في أي وقت.'
              : 'سيُلغى طلبك «${row.title}» ولن نبحث له عن تبرّع. لا يمكن التراجع عن الإلغاء، لكن يمكنك إرسال طلب جديد في أي وقت.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            key: const Key('confirm-cancel-operation'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isDonation ? 'إلغاء التبرّع' : 'إلغاء الطلب'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    if (_cancellingId != null) return;

    setState(() => _cancellingId = row.id);
    try {
      if (isDonation) {
        await _repo.cancelDonation(row.id);
      } else {
        await _repo.cancelNeed(row.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isDonation ? 'أُلغي التبرّع.' : 'أُلغي الطلب.')),
      );
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
    // Refresh in both cases: after a failure the status has usually moved on.
    if (mounted) await reload();
  }

  Widget _card(OperationItem row) {
    final copy = OperationStatusPresenter.present(row.kind, row.status);
    final showAction = _showsAction(row);
    final canCancel = OperationRules.canCancel(kind: row.kind, status: row.status);
    final cancelling = _cancellingId == row.id;
    final step = JourneyRules.currentStep(row.kind, row.status);
    final gold = copy.attention || row.kind == 'need';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: copy.attention
                        ? RuhamaaColors.warmGoldSoft
                        : gold
                            ? RuhamaaColors.goldTint
                            : RuhamaaColors.softGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _icon(row.kind),
                    color: gold ? RuhamaaColors.goldDeep : RuhamaaColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        style: const TextStyle(color: RuhamaaColors.text, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${OperationStatusPresenter.kindLabel(row.kind)} • ${row.code}',
                        style: const TextStyle(color: RuhamaaColors.iconMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (copy.attention) const Icon(Icons.priority_high_rounded, color: RuhamaaColors.warmGold),
              ],
            ),
            const SizedBox(height: 16),
            if (step != null)
              _JourneyTimeline(
                steps: JourneyRules.stepsFor(row.kind),
                current: step,
                complete: JourneyRules.isComplete(row.kind, row.status),
                note: copy.nextStep,
              )
            else ...[
              Text(
                copy.label,
                style: const TextStyle(color: RuhamaaColors.text, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(copy.nextStep, style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.45)),
            ],
            if (showAction) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _openAction(row),
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('أكمل الآن'),
              ),
            ],
            if (canCancel) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: _cancellingId != null ? null : () => _cancel(row),
                  style: TextButton.styleFrom(foregroundColor: RuhamaaColors.textMuted),
                  icon: cancelling
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: Text(
                    cancelling
                        ? 'جارٍ الإلغاء...'
                        : row.kind == 'donation'
                            ? 'إلغاء التبرّع'
                            : 'إلغاء الطلب',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildList(
      empty: const _EmptyState(
        icon: Icons.track_changes_outlined,
        title: 'لا يوجد ما تتابعه الآن',
        subtitle: 'ستظهر هنا حالة تبرّعاتك وطلباتك والخطوة التالية.',
      ),
      builder: (rows) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        itemCount: rows.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _SummaryBanner(
              total: rows.length,
              // Only rows that really offer a button count as "needs you".
              attention: rows.where(_showsAction).length,
            );
          }
          return _card(rows[index - 1]);
        },
      ),
    );
  }
}

class _NotificationsList extends StatefulWidget {
  const _NotificationsList({required this.onOpenStatusTab});

  final VoidCallback onOpenStatusTab;

  @override
  State<_NotificationsList> createState() => _NotificationsListState();
}

class _NotificationsListState extends _ListState<_NotificationsList, UserNotificationItem> {
  bool _markingAll = false;

  OperationsRepository get _repo => OperationsRepository(Supabase.instance.client);

  @override
  Future<List<UserNotificationItem>> fetch() => _repo.myNotifications();

  Future<void> _open(UserNotificationItem item) async {
    if (!item.isRead) {
      try {
        await _repo.markRead(item.id);
      } catch (error) {
        // Opening the notification matters more than the read marker.
        debugPrint('Ataa notification read marker failed: ${error.runtimeType}');
      }
      if (!mounted) return;
      await reload();
    }
    if (!mounted) return;
    final route = OperationRules.notificationRoute(
      entityType: item.entityType,
      dedupeKey: item.dedupeKey,
      serverRoute: item.actionRoute,
    );
    if (route == '/handoffs') {
      // Already on this screen: just show the status tab.
      widget.onOpenStatusTab();
      return;
    }
    if (!route.startsWith('/')) return;
    if (_isMainTabRoute(route)) {
      context.go(_withRequestId(route));
      return;
    }
    await context.push(route);
    if (mounted) await reload();
  }

  Future<void> _markAll() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await _repo.markAllRead();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'لم تُحدَّث التنبيهات. حاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
    if (mounted) await reload();
  }

  @override
  Widget build(BuildContext context) {
    return buildList(
      empty: const _EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'لا توجد تنبيهات',
        subtitle: 'ستظهر هنا التحديثات المهمة وما يحتاج إلى إجراء منك.',
      ),
      builder: (rows) {
        final unread = rows.where((row) => !row.isRead).length;
        final offset = unread > 0 ? 1 : 0;
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          itemCount: rows.length + offset,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (unread > 0 && index == 0) {
              return OutlinedButton.icon(
                onPressed: _markingAll ? null : _markAll,
                icon: const Icon(Icons.done_all_rounded),
                label: Text(_markingAll ? 'جارٍ التحديث...' : 'تحديد الكل كمقروء ($unread)'),
              );
            }
            final item = rows[index - offset];
            return Card(
              color: item.isRead ? Colors.white : RuhamaaColors.goldTint,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Icon(
                  item.isRead ? Icons.notifications_none_rounded : Icons.notifications_active_outlined,
                  color: item.isRead ? RuhamaaColors.textMuted : RuhamaaColors.warmGold,
                ),
                title: Text(item.title, style: TextStyle(fontWeight: item.isRead ? FontWeight.w700 : FontWeight.w900)),
                subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(item.body)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _open(item),
              ),
            );
          },
        );
      },
    );
  }
}

class _HandoffsList extends StatefulWidget {
  const _HandoffsList();

  @override
  State<_HandoffsList> createState() => _HandoffsListState();
}

class _HandoffsListState extends _ListState<_HandoffsList, UserHandoff> {
  String? _issuingKey;

  HandoffRepository get _repo => HandoffRepository(Supabase.instance.client);

  @override
  Future<List<UserHandoff>> fetch() => _repo.myHandoffs();

  String _key(UserHandoff row) => '${row.deliveryId}:${row.kind}';

  Future<void> _showPin(UserHandoff row) async {
    if (_issuingKey != null) return;
    setState(() => _issuingKey = _key(row));
    IssuedHandoffPin? pin;
    try {
      // Reuses the PIN already issued while it is still valid.
      pin = await _repo.currentOrNewPin(deliveryId: row.deliveryId, kind: row.kind);
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'لم يتم إنشاء الرمز. حاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _issuingKey = null);
    }
    if (!mounted) return;
    final issued = pin;
    if (issued != null) {
      await showDialog<void>(
        context: context,
        builder: (_) => _PinDialog(repo: _repo, handoff: row, initialPin: issued),
      );
    }
    // The courier may have confirmed the PIN while the dialog was open, or
    // the handoff may have moved to a phase where no PIN is available.
    if (mounted) await reload();
  }

  Widget _card(UserHandoff row) {
    final copy = OperationStatusPresenter.presentHandoff(row.kind, row.status);
    final pickup = row.kind == 'pickup';
    final canShowPin = HandoffPinRules.canIssue(kind: row.kind, status: row.status);
    final issuing = _issuingKey == _key(row);
    final closed = OperationRules.isDeliveryClosed(row.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: closed ? RuhamaaColors.sand : RuhamaaColors.softGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    color: closed ? RuhamaaColors.textMuted : RuhamaaColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.itemType,
                        style: const TextStyle(color: RuhamaaColors.text, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pickup ? 'استلام التبرّع منك' : 'تسليم ما طلبته إليك',
                        style: const TextStyle(color: RuhamaaColors.iconMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              copy.label,
              style: TextStyle(
                color: copy.attention ? RuhamaaColors.goldDeep : RuhamaaColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(copy.nextStep, style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.45)),
            const SizedBox(height: 8),
            Text(
              'رمز العملية: ${row.deliveryCode}',
              style: const TextStyle(color: RuhamaaColors.iconMuted, fontSize: 12),
            ),
            if (canShowPin) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _issuingKey != null ? null : () => _showPin(row),
                style: FilledButton.styleFrom(
                  backgroundColor: RuhamaaColors.primaryDark,
                  shape: const StadiumBorder(),
                ),
                icon: issuing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.pin_outlined),
                label: Text(
                  issuing
                      ? 'جارٍ تجهيز الرمز...'
                      : pickup
                          ? 'إظهار رمز الاستلام'
                          : 'إظهار رمز التسليم',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildList(
      empty: const _EmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'لا يوجد تسليم الآن',
        subtitle: 'بعد قبول عرض وترتيب الموصل ستظهر التفاصيل والرمز هنا.',
      ),
      builder: (rows) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _card(rows[index]),
      ),
    );
  }
}

/// Shows the handoff PIN with a live countdown. The same PIN stays on screen
/// until it expires; a new one is requested only on purpose, because issuing
/// a PIN invalidates the previous one for the courier.
class _PinDialog extends StatefulWidget {
  const _PinDialog({
    required this.repo,
    required this.handoff,
    required this.initialPin,
  });

  final HandoffRepository repo;
  final UserHandoff handoff;
  final IssuedHandoffPin initialPin;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  late IssuedHandoffPin _pin;
  Timer? _ticker;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pin = widget.initialPin;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _issueNew({required bool expired}) async {
    if (_busy) return;
    if (!expired) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إنشاء رمز جديد؟'),
          content: const Text(
            'سيتوقف الرمز الحالي عن العمل فورًا. استخدم هذا الخيار فقط إذا أخبرك الموصل أن الرمز لا يعمل.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إنشاء رمز جديد')),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;
      if (_busy) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pin = await widget.repo.issueNewPin(
        deliveryId: widget.handoff.deliveryId,
        kind: widget.handoff.kind,
      );
      if (!mounted) return;
      setState(() {
        _pin = pin;
        _busy = false;
      });
    } catch (error) {
      debugPrint('Ataa handoff PIN issue failed: ${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(error, fallback: 'لم يتم إنشاء رمز جديد. حاول مرة أخرى.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = HandoffPinRules.remaining(_pin, DateTime.now());
    final expired = remaining == Duration.zero;
    final pickup = widget.handoff.kind == 'pickup';
    final error = _error;
    final digits = _pin.pin.split('');
    final boxes = <Widget>[];
    for (var index = 0; index < digits.length; index++) {
      if (index > 0) boxes.add(const SizedBox(width: 6));
      boxes.add(
        Container(
          width: 44,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            digits[index],
            style: TextStyle(
              color: expired ? Colors.white54 : Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              decoration: expired ? TextDecoration.lineThrough : null,
              decorationColor: Colors.white54,
            ),
          ),
        ),
      );
    }
    return Dialog(
      backgroundColor: RuhamaaColors.primaryDark,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              pickup ? 'رمز الاستلام' : 'رمز التسليم',
              style: const TextStyle(color: RuhamaaColors.warmGoldSoft, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'عند وصول الموصل',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              pickup
                  ? 'أعطه رمز الاستلام. لا تسلّم الشيء قبل أن يُدخل الرمز.'
                  : 'أعطه رمز التسليم بعد أن تستلم ما طلبته منه.',
              style: const TextStyle(color: Color(0xFFCFE6DF), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Semantics(
                        label: 'الرمز ${digits.join(' ')}',
                        excludeSemantics: true,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            key: const Key('handoff-pin-value'),
                            mainAxisSize: MainAxisSize.min,
                            children: boxes,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  expired ? 'انتهت\nالصلاحية' : 'صالح\n${HandoffPinRules.clock(remaining)}',
                  key: const Key('handoff-pin-countdown'),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: expired ? const Color(0xFFFFC9C2) : RuhamaaColors.warmGoldSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              expired
                  ? HandoffPinRules.countdownLabel(remaining)
                  : 'الرمز صالح لمدة 10 دقائق ولخمس محاولات، وسيظهر لك الرمز نفسه حتى تنتهي صلاحيته.',
              style: TextStyle(
                color: expired ? const Color(0xFFFFC9C2) : const Color(0xFFCFE6DF),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error,
                style: const TextStyle(color: Color(0xFFFFC9C2), fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _busy ? null : () => _issueNew(expired: expired),
                    style: TextButton.styleFrom(foregroundColor: RuhamaaColors.warmGoldSoft),
                    child: Text(
                      _busy
                          ? 'جارٍ الإنشاء...'
                          : expired
                              ? 'إنشاء رمز جديد'
                              : 'الرمز لا يعمل؟',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: RuhamaaColors.warmGold,
                    foregroundColor: RuhamaaColors.goldInk,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('تم'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Five steps of a donation or a request: reached steps in green with a
/// check, the current one in gold with the next step, the rest outlined.
class _JourneyTimeline extends StatelessWidget {
  const _JourneyTimeline({
    required this.steps,
    required this.current,
    required this.complete,
    required this.note,
  });

  final List<String> steps;
  final int current;

  /// The last step was reached: every step is shown as done.
  final bool complete;

  /// Shown under the current step.
  final String note;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var index = 0; index < steps.length; index++) {
      final done = complete || index < current;
      final now = !complete && index == current;
      final last = index == steps.length - 1;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    _StepDot(done: done, now: now),
                    if (!last)
                      Expanded(
                        child: Container(
                          width: 3,
                          color: done ? RuhamaaColors.primary : RuhamaaColors.border,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 3, bottom: last ? 0 : 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[index],
                        style: TextStyle(
                          color: now
                              ? RuhamaaColors.goldDeep
                              : done
                                  ? RuhamaaColors.text
                                  : RuhamaaColors.iconMuted,
                          fontSize: 16,
                          fontWeight: now
                              ? FontWeight.w800
                              : done
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                        ),
                      ),
                      if (now) ...[
                        const SizedBox(height: 2),
                        Text(
                          'الآن · $note',
                          style: const TextStyle(color: RuhamaaColors.iconMuted, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.done, required this.now});

  final bool done;
  final bool now;

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(color: RuhamaaColors.primary, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
      );
    }
    if (now) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: RuhamaaColors.warmGold,
          shape: BoxShape.circle,
          border: Border.all(color: RuhamaaColors.warmGoldSoft, width: 4),
        ),
      );
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: RuhamaaColors.stepIdle, width: 2),
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.total, required this.attention});

  final int total;
  final int attention;

  @override
  Widget build(BuildContext context) {
    final needsAttention = attention > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: needsAttention ? RuhamaaColors.goldTint : RuhamaaColors.softGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            needsAttention ? Icons.pending_actions_rounded : Icons.check_circle_outline_rounded,
            color: needsAttention ? RuhamaaColors.warmGold : RuhamaaColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              needsAttention
                  ? 'لديك $attention إجراء يحتاج إلى انتباهك من أصل $total.'
                  : 'لا يوجد إجراء مطلوب منك الآن.',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 58, color: RuhamaaColors.primary),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
