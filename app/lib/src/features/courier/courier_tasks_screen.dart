import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_error.dart';
import '../../data/delivery_repository.dart';
import '../../domain/courier_task_rules.dart';
import '../../domain/delivery_dispatch_rules.dart';
import '../admin/staff_widgets.dart';
import '../auth/change_password_screen.dart';

String _clock(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class CourierTasksScreen extends StatefulWidget {
  const CourierTasksScreen({super.key});

  @override
  State<CourierTasksScreen> createState() => _CourierTasksScreenState();
}

class _CourierTasksScreenState extends State<CourierTasksScreen> {
  late Future<List<DeliveryTask>> _future;
  RealtimeChannel? _channel;
  bool _signingOut = false;

  DeliveryRepository get _repo => DeliveryRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _repo.myTasks();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _channel = Supabase.instance.client
          .channel('courier-deliveries-$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'deliveries',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'courier_id',
              value: userId,
            ),
            callback: (_) {
              if (mounted) _refresh();
            },
          )
          .subscribe();
    }
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) Supabase.instance.client.removeChannel(channel);
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = _repo.myTasks();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  Future<void> _openTask(DeliveryTask task) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => CourierTaskScreen(task: task)),
    );
    if (mounted) await _refresh();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final confirmed = await confirmAction(
      context,
      title: 'تسجيل الخروج؟',
      message: 'سيتم إنهاء جلسة الموصل على هذا الجهاز.',
      confirmLabel: 'تسجيل الخروج',
    );
    if (!confirmed || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  String _subtitle(DeliveryTask task) {
    final label = DeliveryDispatchRules.statusLabel(task.status);
    final expires = task.offerExpiresAt;
    if (!DeliveryDispatchRules.canRespond(task.status) || expires == null) {
      return label;
    }
    if (expires.isBefore(DateTime.now())) {
      return '$label • انتهت مهلة القبول';
    }
    return '$label • مهلة القبول حتى ${_clock(expires)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مهام التوصيل'),
        actions: [
          IconButton(
            tooltip: 'تغيير كلمة المرور',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ChangePasswordScreen(
                  role: 'courier',
                  requiredChange: false,
                ),
              ),
            ),
            icon: const Icon(Icons.password_outlined),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: _signingOut ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshableFuture<List<DeliveryTask>>(
        future: _future,
        onRefresh: _refresh,
        isEmpty: (tasks) => tasks.isEmpty,
        emptyText: 'لا توجد مهام حاليًا.\nاسحب للأسفل للتحديث.',
        builder: (context, tasks) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final task = tasks[index];
            final pending = DeliveryDispatchRules.canRespond(task.status);
            final waiting = DeliveryDispatchRules.waitsForAdmin(task.status);
            return Card(
              child: ListTile(
                leading: Icon(
                  pending
                      ? Icons.notification_important_outlined
                      : waiting
                          ? Icons.hourglass_bottom_rounded
                          : Icons.delivery_dining_outlined,
                ),
                title: Text(task.publicCode),
                subtitle: Text(_subtitle(task)),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => _openTask(task),
              ),
            );
          },
        ),
      ),
    );
  }
}

class CourierTaskScreen extends StatefulWidget {
  const CourierTaskScreen({super.key, required this.task});

  final DeliveryTask task;

  @override
  State<CourierTaskScreen> createState() => _CourierTaskScreenState();
}

class _CourierTaskScreenState extends State<CourierTaskScreen> {
  /// Resolves to null when the task is no longer assigned to this courier.
  late Future<CourierTaskDetails?> _details;
  bool _busy = false;

  /// null until the pledges of the current phase have been loaded.
  List<CashPledge>? _pledges;
  bool _pledgesFailed = false;
  final Set<String> _pledgeBusyIds = <String>{};

  DeliveryRepository get _repo => DeliveryRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _details = _loadDetails();
  }

  Future<CourierTaskDetails?> _loadDetails() async {
    CourierTaskDetails details;
    try {
      details = await _repo.details(widget.task.id);
    } on TaskUnavailableException {
      return null;
    }
    if (DeliveryDispatchRules.showsCashPledges(details.status)) {
      _loadPledges();
    } else if (mounted) {
      setState(() {
        _pledges = null;
        _pledgesFailed = false;
      });
    }
    return details;
  }

  /// Cash pledges are secondary information: a failure here never blocks the
  /// handoff actions, it only shows a retry line.
  Future<void> _loadPledges() async {
    try {
      final pledges = await _repo.cashPledges(widget.task.id);
      if (!mounted) return;
      setState(() {
        _pledges = pledges;
        _pledgesFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _pledgesFailed = true);
    }
  }

  Future<void> _refresh() async {
    final next = _loadDetails();
    setState(() => _details = next);
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  /// Best-effort location evidence. Any failure (GPS off, permission denied,
  /// timeout, plugin error) yields null so the handoff is never blocked.
  Future<Position?> _position() async {
    try {
      return await _locate().timeout(const Duration(seconds: 20));
    } catch (_) {
      return null;
    }
  }

  Future<Position?> _locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    ).timeout(const Duration(seconds: 8));
  }

  Future<void> _run(
    Future<Object?> Function() action, {
    required String success,
    bool closeAfter = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showInfoSnack(context, success);
      if (closeAfter) {
        Navigator.pop(context);
      } else {
        await _refresh();
      }
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر تنفيذ الإجراء. حدّث المهمة وحاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(CourierTaskDetails details) => _run(
        () => _repo.respond(deliveryId: details.deliveryId, accept: true),
        success: 'تم قبول المهمة. يمكنك الآن التوجه إلى موقع الاستلام.',
      );

  Future<void> _reject(CourierTaskDetails details) async {
    if (_busy) return;
    var reason = 'unavailable';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('الاعتذار عن المهمة؟'),
          content: DropdownButtonFormField<String>(
            initialValue: reason,
            decoration: const InputDecoration(labelText: 'سبب الاعتذار'),
            items: [
              for (final entry in DeliveryDispatchRules.rejectionReasons.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) =>
                setDialogState(() => reason = value ?? reason),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تأكيد الاعتذار'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => _repo.respond(
        deliveryId: details.deliveryId,
        accept: false,
        reason: reason,
      ),
      success: 'تم إرسال اعتذارك، وستعود المهمة إلى فريق عطاء لإسنادها.',
      closeAfter: true,
    );
  }

  Future<void> _verifyPin(
    CourierTaskDetails details, {
    required bool pickup,
  }) async {
    if (_busy) return;
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => _PinDialog(pickup: pickup),
    );
    if (pin == null || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final position = await _position();
      final valid = await _repo.verifyPin(
        deliveryId: details.deliveryId,
        pin: pin,
        kind: pickup ? 'pickup' : 'delivery',
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
      if (!mounted) return;
      if (!valid) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('لم يُقبل الرمز'),
            content: const Text(
              CourierTaskRules.pinRejectedMessage,
              style: TextStyle(height: 1.5),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('حسنًا'),
              ),
            ],
          ),
        );
        return;
      }
      showInfoSnack(
        context,
        pickup ? 'تم تأكيد الاستلام.' : 'تم تأكيد التسليم واكتملت المهمة.',
      );
      if (pickup) {
        await _refresh();
      } else {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر التحقق من الرمز. حاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startDropoff(CourierTaskDetails details) => _run(
        () => _repo.startDropoff(details.deliveryId),
        success: 'تم بدء مرحلة التسليم.',
      );

  Future<void> _reportProblem(CourierTaskDetails details) async {
    if (_busy) return;
    final report = await showDialog<_FailureReport>(
      context: context,
      builder: (_) => const _FailureReportDialog(),
    );
    if (report == null || !mounted) return;
    await _run(
      () async {
        final position = await _position();
        await _repo.reportFailure(
          deliveryId: details.deliveryId,
          party: report.party,
          reasonCode: report.reason,
          note: report.note,
          latitude: position?.latitude,
          longitude: position?.longitude,
        );
      },
      success: 'وصل البلاغ إلى الفريق لإعادة التنسيق.',
      closeAfter: true,
    );
  }

  Future<void> _answerPledge(CashPledge pledge, bool received) async {
    final id = pledge.contributionId;
    if (_pledgeBusyIds.contains(id)) return;
    final confirmed = await confirmAction(
      context,
      title: received ? 'تأكيد استلام المبلغ' : 'تسجيل عدم الاستلام',
      message: received
          ? 'هل استلمت ${pledge.amountYer} ريال نقدًا فعلًا؟ ستراجع الإدارة هذا التأكيد.'
          : 'هل تؤكد أنك لم تستلم مبلغ ${pledge.amountYer} ريال؟',
      confirmLabel: received ? 'نعم، استلمته' : 'لم أستلمه',
    );
    if (!confirmed || !mounted) return;
    setState(() => _pledgeBusyIds.add(id));
    try {
      await _repo.confirmCashPledge(contributionId: id, received: received);
      if (!mounted) return;
      showInfoSnack(context, 'تم تسجيل إجابتك.');
      await _loadPledges();
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _pledgeBusyIds.remove(id));
    }
  }

  Future<void> _launch(Uri uri, String failureMessage) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) showInfoSnack(context, failureMessage);
  }

  Widget _locationCard({
    required String title,
    String? area,
    String? description,
    String? phone,
    double? latitude,
    double? longitude,
  }) {
    final tel = CourierTaskRules.telUri(phone);
    final map = CourierTaskRules.mapsUri(latitude, longitude);
    return _LocationCard(
      title: title,
      area: area,
      description: description,
      phone: phone,
      onCall: tel == null
          ? null
          : () => _launch(
                tel,
                'لم نتمكن من فتح تطبيق الاتصال. اتصل بالرقم يدويًا.',
              ),
      onMap: map == null
          ? null
          : () => _launch(map, 'لم نتمكن من فتح تطبيق الخرائط.'),
    );
  }

  List<Widget> _pledgeSection() {
    if (_pledgesFailed) {
      return [
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('لم تُحمَّل المساهمات النقدية'),
            subtitle: const Text('يمكنك متابعة المهمة والمحاولة لاحقًا.'),
            trailing: TextButton(
              onPressed: _loadPledges,
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ),
      ];
    }
    final pledges = _pledges;
    if (pledges == null || pledges.isEmpty) return const <Widget>[];
    return [
      const SizedBox(height: 16),
      _PledgesCard(
        pledges: pledges,
        busyIds: _pledgeBusyIds,
        onAnswer: _answerPledge,
      ),
    ];
  }

  List<Widget> _phaseWidgets(CourierTaskDetails details) {
    final status = details.status;
    if (DeliveryDispatchRules.canRespond(status)) {
      final expires = widget.task.offerExpiresAt;
      return [
        _locationCard(title: 'منطقة الاستلام', area: details.pickupArea),
        if (expires != null) ...[
          const SizedBox(height: 8),
          Text(
            expires.isBefore(DateTime.now())
                ? 'انتهت مهلة القبول. يمكنك الاعتذار، أو انتظار إعادة الإسناد من الإدارة.'
                : 'مهلة القبول حتى ${_clock(expires)}.',
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('courier-accept-assignment'),
          onPressed: _busy ? null : () => _accept(details),
          icon: const Icon(Icons.check_rounded),
          label: const Text('قبول المهمة'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('courier-reject-assignment'),
          onPressed: _busy ? null : () => _reject(details),
          icon: const Icon(Icons.close_rounded),
          label: const Text('الاعتذار عن المهمة'),
        ),
      ];
    }
    if (DeliveryDispatchRules.canVerifyPickup(status)) {
      return [
        _locationCard(
          title: 'موقع الاستلام',
          area: details.pickupArea,
          description: details.pickupDescription,
          phone: details.pickupPhone,
          latitude: details.pickupLatitude,
          longitude: details.pickupLongitude,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : () => _verifyPin(details, pickup: true),
          icon: const Icon(Icons.pin_outlined),
          label: Text(_busy ? 'جارٍ التنفيذ...' : 'تأكيد الاستلام بالرمز'),
        ),
        _ProblemButton(busy: _busy, onPressed: () => _reportProblem(details)),
        ..._pledgeSection(),
      ];
    }
    if (DeliveryDispatchRules.canStartDropoff(status)) {
      return [
        _locationCard(
          title: 'موقع التسليم',
          area: details.dropoffArea,
          description: details.dropoffDescription,
          phone: details.dropoffPhone,
          latitude: details.dropoffLatitude,
          longitude: details.dropoffLongitude,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : () => _startDropoff(details),
          icon: const Icon(Icons.route_outlined),
          label: const Text('بدء التوجه للتسليم'),
        ),
        _ProblemButton(busy: _busy, onPressed: () => _reportProblem(details)),
        ..._pledgeSection(),
      ];
    }
    if (DeliveryDispatchRules.canVerifyDropoff(status)) {
      return [
        _locationCard(
          title: 'موقع التسليم',
          area: details.dropoffArea,
          description: details.dropoffDescription,
          phone: details.dropoffPhone,
          latitude: details.dropoffLatitude,
          longitude: details.dropoffLongitude,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : () => _verifyPin(details, pickup: false),
          icon: const Icon(Icons.pin_outlined),
          label: Text(_busy ? 'جارٍ التنفيذ...' : 'تأكيد التسليم بالرمز'),
        ),
        _ProblemButton(busy: _busy, onPressed: () => _reportProblem(details)),
        ..._pledgeSection(),
      ];
    }
    if (DeliveryDispatchRules.waitsForAdmin(status)) {
      return const [
        _NoticeCard(
          icon: Icons.hourglass_bottom_rounded,
          title: DeliveryDispatchRules.waitingForAdminMessage,
          body:
              'وصل البلاغ إلى فريق عطاء. لا يوجد إجراء مطلوب منك الآن، وستصلك المهمة من جديد إذا أُسندت إليك.',
        ),
      ];
    }
    return const [
      _NoticeCard(
        icon: Icons.task_alt_rounded,
        title: 'هذه المهمة مغلقة',
        body: 'لا يوجد إجراء مطلوب منك على هذه المهمة.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task.publicCode),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshableFuture<CourierTaskDetails?>(
        future: _details,
        onRefresh: _refresh,
        builder: (context, details) {
          if (details == null) {
            return ScrollableEmpty(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.assignment_late_outlined, size: 44),
                    const SizedBox(height: 12),
                    const Text(
                      'لم تعد هذه المهمة مسندة إليك.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('العودة إلى المهام'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                DeliveryDispatchRules.statusLabel(details.status),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('تظهر لك البيانات الضرورية لكل مرحلة فقط.'),
              const SizedBox(height: 20),
              ..._phaseWidgets(details),
            ],
          );
        },
      ),
    );
  }
}

class _ProblemButton extends StatelessWidget {
  const _ProblemButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton.icon(
        onPressed: busy ? null : onPressed,
        icon: const Icon(Icons.report_problem_outlined),
        label: const Text('تعذر إكمال المهمة'),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(body, style: const TextStyle(height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.title,
    this.area,
    this.description,
    this.phone,
    this.onCall,
    this.onMap,
  });

  final String title;
  final String? area;
  final String? description;
  final String? phone;
  final VoidCallback? onCall;
  final VoidCallback? onMap;

  @override
  Widget build(BuildContext context) {
    final details = description;
    final contact = phone;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(area ?? 'المنطقة غير محددة'),
            if (details != null && details.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(details),
              ),
            if (contact != null && contact.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SelectableText('للتواصل عند الحاجة: $contact'),
              ),
            if (onCall != null || onMap != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (onCall != null)
                      OutlinedButton.icon(
                        onPressed: onCall,
                        icon: const Icon(Icons.call_outlined),
                        label: const Text('اتصال'),
                      ),
                    if (onMap != null)
                      OutlinedButton.icon(
                        onPressed: onMap,
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('فتح الخريطة'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PledgesCard extends StatelessWidget {
  const _PledgesCard({
    required this.pledges,
    required this.busyIds,
    required this.onAnswer,
  });

  final List<CashPledge> pledges;
  final Set<String> busyIds;
  final void Function(CashPledge pledge, bool received) onAnswer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'مساهمات نقدية مرتبطة بالمهمة',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'سجّل لكل مساهمة هل استلمت المبلغ نقدًا أم لا. تعتمد الإدارة المساهمة بعد تأكيدك.',
              style: TextStyle(height: 1.45),
            ),
            for (final pledge in pledges) ...[
              const Divider(height: 24),
              Text(
                '${pledge.amountYer} ريال',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              if (pledge.publicCode.isNotEmpty) Text(pledge.publicCode),
              const SizedBox(height: 4),
              Text(CourierTaskRules.pledgeAnswerLabel(pledge.courierReceived)),
              const SizedBox(height: 8),
              if (busyIds.contains(pledge.contributionId))
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: InlineSpinner(),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: pledge.courierReceived == true
                          ? null
                          : () => onAnswer(pledge, true),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('استلمت المبلغ'),
                    ),
                    OutlinedButton.icon(
                      onPressed: pledge.courierReceived == false
                          ? null
                          : () => onAnswer(pledge, false),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('لم أستلم'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.pickup});

  final bool pickup;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    Navigator.pop(context, CourierTaskRules.normalizedPin(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.pickup ? 'رمز الاستلام' : 'رمز التسليم'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: CourierTaskRules.pinLength,
          inputFormatters: [
            FilteringTextInputFormatter.allow(CourierTaskRules.pinInputPattern),
          ],
          decoration: InputDecoration(
            labelText: 'أدخل الرمز المكوّن من 4 أرقام',
            helperText: widget.pickup
                ? 'يظهر الرمز للمتبرع في تطبيقه.'
                : 'يظهر الرمز لصاحب الطلب في تطبيقه.',
            errorMaxLines: 2,
          ),
          validator: CourierTaskRules.pinError,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('تحقق')),
      ],
    );
  }
}

class _FailureReport {
  const _FailureReport({
    required this.party,
    required this.reason,
    this.note,
  });

  final String party;
  final String reason;
  final String? note;
}

class _FailureReportDialog extends StatefulWidget {
  const _FailureReportDialog();

  @override
  State<_FailureReportDialog> createState() => _FailureReportDialogState();
}

class _FailureReportDialogState extends State<_FailureReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  String _party = 'other';
  String _reason = 'other';

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    Navigator.pop(
      context,
      _FailureReport(
        party: _party,
        reason: _reason,
        note: CourierTaskRules.normalizedNote(_note.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعذر إكمال المهمة'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _party,
                decoration: const InputDecoration(labelText: 'الطرف المرتبط'),
                items: [
                  for (final entry in CourierTaskRules.failureParties.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _party = value ?? _party),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                decoration: const InputDecoration(labelText: 'ما الذي حدث؟'),
                items: [
                  for (final entry in CourierTaskRules.failureReasons.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _reason = value ?? _reason),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLines: 3,
                maxLength: CourierTaskRules.failureNoteMaxLength,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة مختصرة — اختيارية',
                ),
                validator: CourierTaskRules.failureNoteError,
              ),
              const SizedBox(height: 4),
              const Text(
                'بعد الإرسال تتوقف المهمة لديك حتى تعيد الإدارة إسنادها.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('إرسال للفريق'),
        ),
      ],
    );
  }
}
