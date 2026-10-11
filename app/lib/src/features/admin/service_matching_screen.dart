import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/service_admin_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import '../services/service_catalog.dart';
import 'staff_widgets.dart';

class ServiceMatchingScreen extends StatelessWidget {
  const ServiceMatchingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: _ServiceAdminAppBar(),
        body: TabBarView(
          children: [
            _PendingOffersTab(),
            _OpenRequestsTab(),
            _AcceptedServicesTab(),
          ],
        ),
      ),
    );
  }
}

class _ServiceAdminAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _ServiceAdminAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('الوقت والمهارات'),
      bottom: const TabBar(
        tabs: [
          Tab(text: 'العروض', icon: Icon(Icons.verified_user_outlined)),
          Tab(text: 'الطلبات', icon: Icon(Icons.hub_outlined)),
          Tab(text: 'التنسيق', icon: Icon(Icons.event_available_outlined)),
        ],
      ),
    );
  }

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);
}

Widget _titleRow({
  required IconData icon,
  required String title,
  required String subtitle,
  Color background = RuhamaaColors.softGreen,
  Color foreground = RuhamaaColors.primary,
  Widget? trailing,
}) {
  return Row(
    children: [
      CircleAvatar(
        backgroundColor: background,
        foregroundColor: foreground,
        child: Icon(icon),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: RuhamaaColors.textMuted),
            ),
          ],
        ),
      ),
      if (trailing != null) trailing,
    ],
  );
}

class _PendingOffersTab extends StatefulWidget {
  const _PendingOffersTab();

  @override
  State<_PendingOffersTab> createState() => _PendingOffersTabState();
}

class _PendingOffersTabState extends State<_PendingOffersTab> {
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _busyIds = <String>{};

  ServiceAdminRepository get _repo =>
      ServiceAdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _repo.pendingOffers();
  }

  Future<void> _refresh() async {
    final next = _repo.pendingOffers();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  Future<void> _decide(String id, bool approve) async {
    if (_busyIds.contains(id)) return;
    final confirmed = await confirmAction(
      context,
      title: approve ? 'اعتماد العرض؟' : 'رفض العرض؟',
      message: approve
          ? 'سيصبح العرض متاحًا للمطابقة مع طلبات الخدمات.'
          : 'لن يُستخدم هذا العرض في المطابقة.',
      confirmLabel: approve ? 'اعتماد' : 'رفض',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyIds.add(id));
    try {
      if (approve) {
        await _repo.approveOffer(id);
      } else {
        await _repo.rejectOffer(id);
      }
      if (!mounted) return;
      showInfoSnack(
        context,
        approve ? 'تم اعتماد عرض الوقت أو المهارة.' : 'تم رفض العرض.',
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر تحديث العرض. حدّث القائمة ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Widget _card(Map<String, dynamic> row) {
    final id = '${row['id']}';
    final busy = _busyIds.contains(id);
    final rejected = row['verification_status'] == 'rejected';
    final category = serviceCategoryByKey('${row['category']}');
    final pricing =
        row['pricing_mode'] == 'free' ? 'مجاني' : 'العمل مجاني والمواد فقط';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _titleRow(
              icon: category.icon,
              title: '${row['title']}',
              subtitle: '${category.label} • ${row['service_type']}',
              trailing: Chip(
                label: Text(
                  row['provider_kind'] == 'business' ? 'محل/جهة' : 'شخص',
                ),
              ),
            ),
            if (rejected) ...const [
              SizedBox(height: 8),
              Text(
                'مرفوض سابقًا — يمكن اعتماده بعد إعادة المراجعة.',
                style: TextStyle(
                  color: RuhamaaColors.rose,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
            if (row['description'] != null) ...[
              const SizedBox(height: 10),
              Text('${row['description']}', style: const TextStyle(height: 1.45)),
            ],
            const SizedBox(height: 10),
            Text(
              '${row['available_hours'] ?? 0} ساعة • $pricing',
              style: const TextStyle(
                color: RuhamaaColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (row['availability_note'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'التوفر: ${row['availability_note']}',
                style: const TextStyle(color: RuhamaaColors.textMuted),
              ),
            ],
            const SizedBox(height: 14),
            if (busy)
              const Center(child: InlineSpinner())
            else
              Row(
                children: [
                  if (!rejected) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _decide(id, false),
                        child: const Text('رفض'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => _decide(id, true),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('اعتماد العرض'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshableFuture<List<Map<String, dynamic>>>(
      future: _future,
      onRefresh: _refresh,
      isEmpty: (rows) => rows.isEmpty,
      emptyText: 'لا توجد عروض وقت أو مهارة تنتظر المراجعة.',
      builder: (context, rows) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _card(rows[index]),
      ),
    );
  }
}

class _OpenRequestsTab extends StatefulWidget {
  const _OpenRequestsTab();

  @override
  State<_OpenRequestsTab> createState() => _OpenRequestsTabState();
}

class _OpenRequestsTabState extends State<_OpenRequestsTab> {
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _busyIds = <String>{};

  ServiceAdminRepository get _repo =>
      ServiceAdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _repo.openRequests();
  }

  Future<void> _refresh() async {
    final next = _repo.openRequests();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  Future<void> _openCandidates(Map<String, dynamic> request) async {
    final id = '${request['id']}';
    if (_busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      if (request['status'] != 'reviewing') {
        await _repo.markRequestReviewing(id);
      }
      if (!mounted) return;
      final matched = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _CandidateSheet(request: request),
      );
      if (!mounted) return;
      if (matched == true) {
        showInfoSnack(
          context,
          'تم إرسال مطابقة خدمة خاصة للطرفين. لن يُحدد موعد حتى يوافق كلاهما.',
        );
      }
      await _refresh();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر فتح المرشحين. حدّث القائمة ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Widget _card(Map<String, dynamic> row) {
    final busy = _busyIds.contains('${row['id']}');
    final category = serviceCategoryByKey('${row['category']}');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _titleRow(
              icon: category.icon,
              title: '${row['title']}',
              subtitle: '${category.label} • ${row['service_type']}',
              background: RuhamaaColors.warmGoldSoft,
              foreground: RuhamaaColors.warmGold,
              trailing: row['status'] == 'reviewing'
                  ? const Chip(label: Text('قيد المراجعة'))
                  : null,
            ),
            const SizedBox(height: 10),
            Text('${row['details'] ?? ''}', style: const TextStyle(height: 1.45)),
            const SizedBox(height: 8),
            Text(
              'الوقت المتوقع: ${row['estimated_hours'] == null ? 'غير محدد' : '${row['estimated_hours']} ساعة'}'
              ' • المواد: ${row['materials_available'] == true ? 'متوفرة' : 'تحتاج مراجعة'}',
              style: const TextStyle(color: RuhamaaColors.textMuted),
            ),
            if (row['preferred_time_note'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'الوقت المناسب: ${row['preferred_time_note']}',
                style: const TextStyle(color: RuhamaaColors.textMuted),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: busy ? null : () => _openCandidates(row),
              icon: busy
                  ? const InlineSpinner()
                  : const Icon(Icons.search_rounded),
              label: const Text('ابحث عن مهارة مناسبة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshableFuture<List<Map<String, dynamic>>>(
      future: _future,
      onRefresh: _refresh,
      isEmpty: (rows) => rows.isEmpty,
      emptyText: 'لا توجد طلبات خدمات مفتوحة الآن.',
      builder: (context, rows) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _card(rows[index]),
      ),
    );
  }
}

class _AcceptedServicesTab extends StatefulWidget {
  const _AcceptedServicesTab();

  @override
  State<_AcceptedServicesTab> createState() => _AcceptedServicesTabState();
}

class _AcceptedServicesTabState extends State<_AcceptedServicesTab> {
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _busyIds = <String>{};

  ServiceAdminRepository get _repo =>
      ServiceAdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _repo.acceptedMatches();
  }

  Future<void> _refresh() async {
    final next = _repo.acceptedMatches();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  Future<void> _mutate(
    String id,
    Future<void> Function() action, {
    required String success,
    required String failure,
  }) async {
    if (!mounted || _busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await action();
      if (!mounted) return;
      showInfoSnack(context, success);
      await _refresh();
    } catch (error) {
      if (mounted) showErrorSnack(context, error, fallback: failure);
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _schedule(Map<String, dynamic> row) async {
    final id = '${row['id']}';
    if (_busyIds.contains(id)) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final existing = row['scheduled_at'] == null
        ? null
        : DateTime.tryParse('${row['scheduled_at']}')?.toLocal();
    final lastDate = today.add(const Duration(days: 180));
    final date = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: lastDate,
      initialDate: existing == null ||
              existing.isBefore(today) ||
              existing.isAfter(lastDate)
          ? tomorrow
          : existing,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: existing == null
          ? const TimeOfDay(hour: 16, minute: 0)
          : TimeOfDay.fromDateTime(existing),
    );
    if (time == null || !mounted) return;
    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(DateTime.now())) {
      showInfoSnack(context, 'اختر موعدًا في المستقبل.');
      return;
    }
    await _mutate(
      id,
      () => _repo.scheduleMatch(matchId: id, scheduledAt: scheduled),
      success: 'تم حفظ موعد الخدمة بعد موافقة الطرفين.',
      failure: 'تعذر تحديد الموعد. حدّث القائمة ثم حاول مجددًا.',
    );
  }

  Future<void> _complete(String id) async {
    if (_busyIds.contains(id)) return;
    final confirmed = await confirmAction(
      context,
      title: 'تأكيد اكتمال الخدمة',
      message: 'استخدم هذا الخيار بعد التأكد أن الخدمة نُفذت بالفعل.',
      confirmLabel: 'تمت الخدمة',
    );
    if (!confirmed) return;
    await _mutate(
      id,
      () => _repo.completeMatch(id),
      success: 'تم إغلاق الخدمة كمكتملة.',
      failure: 'تعذر إغلاق الخدمة. حدّث القائمة ثم حاول مجددًا.',
    );
  }

  Widget _card(Map<String, dynamic> row) {
    final id = '${row['id']}';
    final busy = _busyIds.contains(id);
    final offer = Map<String, dynamic>.from(row['service_offers'] as Map);
    final request = Map<String, dynamic>.from(row['service_requests'] as Map);
    final category = serviceCategoryByKey('${request['category']}');
    final scheduledAt = row['scheduled_at'] == null
        ? null
        : DateTime.tryParse('${row['scheduled_at']}')?.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final scheduledTime = scheduledAt == null
        ? ''
        : localizations.formatTimeOfDay(TimeOfDay.fromDateTime(scheduledAt));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _titleRow(
              icon: category.icon,
              title: '${request['title']}',
              subtitle: '${offer['title']} • ${request['service_type']}',
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(
                  Icons.task_alt_rounded,
                  color: RuhamaaColors.primary,
                  size: 20,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'وافق مقدم الخدمة وصاحب الاحتياج',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (scheduledAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'الموعد: ${localizations.formatMediumDate(scheduledAt)} • $scheduledTime',
                style: const TextStyle(
                  color: RuhamaaColors.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (busy)
              const Center(child: InlineSpinner())
            else ...[
              FilledButton.icon(
                onPressed: () => _schedule(row),
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  scheduledAt == null ? 'تحديد موعد الخدمة' : 'تعديل الموعد',
                ),
              ),
              if (scheduledAt != null) ...[
                const SizedBox(height: 9),
                OutlinedButton.icon(
                  onPressed: () => _complete(id),
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('تأكيد اكتمال الخدمة'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshableFuture<List<Map<String, dynamic>>>(
      future: _future,
      onRefresh: _refresh,
      isEmpty: (rows) => rows.isEmpty,
      emptyText: 'لا توجد خدمات وافق عليها الطرفان وتنتظر التنسيق.',
      builder: (context, rows) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _card(rows[index]),
      ),
    );
  }
}

class _CandidateSheet extends StatefulWidget {
  const _CandidateSheet({required this.request});

  final Map<String, dynamic> request;

  @override
  State<_CandidateSheet> createState() => _CandidateSheetState();
}

class _CandidateSheetState extends State<_CandidateSheet> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;

  /// Shown inside the sheet: a snackbar would be hidden behind it.
  String? _matchError;

  ServiceAdminRepository get _repo =>
      ServiceAdminRepository(Supabase.instance.client);

  String get _requestId => '${widget.request['id']}';

  @override
  void initState() {
    super.initState();
    _future = _repo.candidates(_requestId);
  }

  void _retry() {
    setState(() {
      _future = _repo.candidates(_requestId);
    });
  }

  Future<void> _match(Map<String, dynamic> candidate) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _matchError = null;
    });
    try {
      await _repo.createMatch(
        requestId: _requestId,
        offerId: '${candidate['offer_id']}',
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _matchError = friendlyError(
          error,
          fallback: 'تعذر إنشاء المطابقة. أغلق القائمة وحدّثها ثم حاول مجددًا.',
        );
      });
    }
  }

  Widget _candidateCard(Map<String, dynamic> candidate) {
    final category = serviceCategoryByKey('${candidate['category']}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(category.icon, color: RuhamaaColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${candidate['title']}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Chip(label: Text('ملاءمة ${candidate['score']}')),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${candidate['service_type']} • ${candidate['available_hours'] ?? 0} ساعة',
                style: const TextStyle(color: RuhamaaColors.textMuted),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _busy ? null : () => _match(candidate),
                child: Text(
                  _busy ? 'جارٍ الإرسال...' : 'إرسال المطابقة للطرفين',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matchError = _matchError;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, controller) =>
          FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = snapshot.error;
          if (error != null) {
            return ErrorRetry(error: error, onRetry: _retry);
          }
          final candidates = snapshot.data ?? const [];
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: RuhamaaColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'مرشحون لـ «${widget.request['title']}»',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'الترتيب يعتمد على تطابق نوع الخدمة والمنطقة والوقت المتاح، ولا يستخدم المساهمات المالية أو سجل ما قدمه الشخص من عطاء.',
                style: TextStyle(color: RuhamaaColors.textMuted, height: 1.45),
              ),
              if (matchError != null) ...[
                const SizedBox(height: 12),
                Text(
                  matchError,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (candidates.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'لا يوجد مقدم خدمة معتمد مناسب حاليًا. يبقى الطلب مفتوحًا للمراجعة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: RuhamaaColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                )
              else
                for (final candidate in candidates) _candidateCard(candidate),
            ],
          );
        },
      ),
    );
  }
}
