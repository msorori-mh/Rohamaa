import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/service_incident_repository.dart';
import '../../data/service_repository.dart';
import '../../domain/service_flow_rules.dart';
import '../../theme/ruhamaa_theme.dart';
import '../items/async_list_loader.dart';
import '../items/form_guards.dart';
import 'service_catalog.dart';

class MyServicesScreen extends StatelessWidget {
  const MyServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('وقتي ومهاراتي'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'ما أقدّمه', icon: Icon(Icons.handyman_outlined)),
              Tab(text: 'ما أحتاجه', icon: Icon(Icons.support_agent_outlined)),
              Tab(text: 'المتابعة', icon: Icon(Icons.history_rounded)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MyOffersList(),
            _MyRequestsList(),
            _ServiceHistoryList(),
          ],
        ),
      ),
    );
  }
}

class _MyOffersList extends StatefulWidget {
  const _MyOffersList();

  @override
  State<_MyOffersList> createState() => _MyOffersListState();
}

class _MyOffersListState extends State<_MyOffersList>
    with
        AutomaticKeepAliveClientMixin<_MyOffersList>,
        AsyncListLoader<_MyOffersList, Map<String, dynamic>> {
  final Set<String> _busy = <String>{};

  ServiceRepository get _repo => ServiceRepository(Supabase.instance.client);

  @override
  bool get wantKeepAlive => true;

  @override
  Future<List<Map<String, dynamic>>> fetchRows() => _repo.myServiceOffers();

  @override
  void initState() {
    super.initState();
    reloadRows();
  }

  Future<void> _withdraw(Map<String, dynamic> row) async {
    final id = '${row['id']}';
    if (_busy.contains(id)) return;
    final confirmed = await confirmAction(
      context,
      title: 'سحب هذه الخدمة؟',
      message: 'لن نعرض خدمتك «${row['title']}» على أي طلب بعد سحبها. يمكنك تسجيل خدمة جديدة في أي وقت.',
      confirmLabel: 'نعم، اسحبها',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy.add(id));
    try {
      await _repo.withdrawServiceOffer(id);
      if (mounted) showInfoSnack(context, 'تم سحب الخدمة.');
    } catch (error) {
      if (mounted) {
        showErrorSnack(context, error, fallback: 'لم نتمكن من سحب الخدمة. حاول مرة أخرى.');
      }
    }
    await reloadRows();
    if (mounted) setState(() => _busy.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return buildAsyncList(
      empty: const _EmptyState(
        icon: Icons.handyman_outlined,
        title: 'لم تسجّل خدمة بعد',
        subtitle: 'يمكنك التبرع بوقتك أو تقديم خدمة مجانًا.',
      ),
      builder: (rows) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final row = rows[index];
          final id = '${row['id']}';
          final status = row['status'] as String?;
          final category = serviceCategoryByKey('${row['category']}');
          final label = ServiceFlowRules.offerStatusLabel(
            status,
            row['verification_status'] as String?,
          );
          final busy = _busy.contains(id);
          return _ServiceRowCard(
            icon: category.icon,
            background: RuhamaaColors.softGreen,
            foreground: RuhamaaColors.primary,
            title: '${row['title']}',
            lines: [
              '${category.label} • ${row['service_type']}',
              '${_hoursText(row['available_hours'])} • $label',
            ],
            actionLabel: ServiceFlowRules.canWithdrawOffer(status)
                ? (busy ? 'جارٍ السحب...' : 'سحب الخدمة')
                : null,
            onAction: busy ? null : () => _withdraw(row),
          );
        },
      ),
    );
  }
}

class _MyRequestsList extends StatefulWidget {
  const _MyRequestsList();

  @override
  State<_MyRequestsList> createState() => _MyRequestsListState();
}

class _MyRequestsListState extends State<_MyRequestsList>
    with
        AutomaticKeepAliveClientMixin<_MyRequestsList>,
        AsyncListLoader<_MyRequestsList, Map<String, dynamic>> {
  final Set<String> _busy = <String>{};

  ServiceRepository get _repo => ServiceRepository(Supabase.instance.client);

  @override
  bool get wantKeepAlive => true;

  @override
  Future<List<Map<String, dynamic>>> fetchRows() => _repo.myServiceRequests();

  @override
  void initState() {
    super.initState();
    reloadRows();
  }

  Future<void> _cancel(Map<String, dynamic> row) async {
    final id = '${row['id']}';
    if (_busy.contains(id)) return;
    final confirmed = await confirmAction(
      context,
      title: 'إلغاء طلب الخدمة؟',
      message: 'سنوقف البحث عن خدمة لطلبك «${row['title']}». يمكنك تسجيل طلب جديد في أي وقت.',
      confirmLabel: 'نعم، ألغِ الطلب',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy.add(id));
    try {
      await _repo.cancelServiceRequest(id);
      if (mounted) showInfoSnack(context, 'تم إلغاء طلب الخدمة.');
    } catch (error) {
      if (mounted) {
        showErrorSnack(context, error, fallback: 'لم نتمكن من إلغاء الطلب. حاول مرة أخرى.');
      }
    }
    await reloadRows();
    if (mounted) setState(() => _busy.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return buildAsyncList(
      empty: const _EmptyState(
        icon: Icons.support_agent_outlined,
        title: 'لا يوجد طلب خدمة',
        subtitle: 'اطلب الخدمة التي تحتاجها من الصفحة الرئيسية.',
      ),
      builder: (rows) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final row = rows[index];
          final id = '${row['id']}';
          final status = row['status'] as String?;
          final category = serviceCategoryByKey('${row['category']}');
          final busy = _busy.contains(id);
          return _ServiceRowCard(
            icon: category.icon,
            background: RuhamaaColors.warmGoldSoft,
            foreground: RuhamaaColors.warmGold,
            title: '${row['title']}',
            lines: [
              '${category.label} • ${row['service_type']}',
              ServiceFlowRules.requestStatusLabel(status),
            ],
            actionLabel: ServiceFlowRules.canCancelRequest(status)
                ? (busy ? 'جارٍ الإلغاء...' : 'إلغاء الطلب')
                : null,
            onAction: busy ? null : () => _cancel(row),
          );
        },
      ),
    );
  }
}

String _hoursText(Object? hours) {
  final value = hours is num ? hours : num.tryParse('$hours');
  if (value == null) return 'ساعات غير محددة';
  final text = value % 1 == 0 ? value.toInt().toString() : value.toString();
  return '$text ساعة';
}

class _ServiceRowCard extends StatelessWidget {
  const _ServiceRowCard({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.title,
    required this.lines,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String title;
  final List<String> lines;

  /// Null hides the action: the row is no longer eligible for it.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: background,
                  foregroundColor: foreground,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      for (final line in lines)
                        Text(line, style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.45)),
                    ],
                  ),
                ),
              ],
            ),
            if (label != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: Text(label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceHistoryList extends StatefulWidget {
  const _ServiceHistoryList();

  @override
  State<_ServiceHistoryList> createState() => _ServiceHistoryListState();
}

class _ServiceHistoryListState extends State<_ServiceHistoryList>
    with
        AutomaticKeepAliveClientMixin<_ServiceHistoryList>,
        AsyncListLoader<_ServiceHistoryList, Map<String, dynamic>> {
  final Set<String> _reporting = <String>{};

  ServiceIncidentRepository get _repo => ServiceIncidentRepository(Supabase.instance.client);

  @override
  bool get wantKeepAlive => true;

  @override
  Future<List<Map<String, dynamic>>> fetchRows() => _repo.serviceHistory();

  @override
  void initState() {
    super.initState();
    reloadRows();
  }

  Future<void> _report(Map<String, dynamic> row) async {
    final matchId = '${row['match_id']}';
    if (_reporting.contains(matchId)) return;
    final draft = await showDialog<_IncidentDraft>(
      context: context,
      builder: (_) => const _IncidentDialog(),
    );
    if (draft == null || !mounted) return;
    setState(() => _reporting.add(matchId));
    try {
      await _repo.report(
        serviceMatchId: matchId,
        incidentType: draft.type,
        description: draft.details,
      );
      if (mounted) showInfoSnack(context, 'تم إرسال البلاغ لفريق عطاء للمراجعة.');
    } catch (error) {
      if (mounted) {
        showErrorSnack(context, error, fallback: 'لم نتمكن من إرسال البلاغ. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _reporting.remove(matchId));
    }
  }

  String _dateText(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return buildAsyncList(
      empty: const _EmptyState(
        icon: Icons.history_rounded,
        title: 'لا توجد خدمات قيد المتابعة',
        subtitle: 'بعد موافقة الطرفين ستظهر تفاصيل الخدمة هنا.',
      ),
      builder: (rows) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final row = rows[index];
          final matchId = '${row['match_id']}';
          final status = row['status'] as String?;
          final category = serviceCategoryByKey('${row['category']}');
          final scheduledRaw = row['scheduled_at'];
          final scheduled = scheduledRaw == null ? null : DateTime.tryParse('$scheduledRaw')?.toLocal();
          final reporting = _reporting.contains(matchId);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: RuhamaaColors.softGreen,
                        foregroundColor: RuhamaaColors.primary,
                        child: Icon(category.icon),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${row['service_title']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                            Text('${category.label} • ${row['service_type']}', style: const TextStyle(color: RuhamaaColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    ServiceFlowRules.matchStatusLabel(status),
                    style: const TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w700),
                  ),
                  if (scheduled != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'الموعد: ${_dateText(scheduled)}',
                      style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 12),
                    ),
                  ],
                  if (status != 'cancelled') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: reporting ? null : () => _report(row),
                      icon: const Icon(Icons.report_outlined),
                      label: Text(reporting ? 'جارٍ الإرسال...' : 'إبلاغ عطاء عن مشكلة'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IncidentDraft {
  const _IncidentDraft({required this.type, required this.details});

  final String type;
  final String details;
}

/// Owns its text controller so it is disposed with the dialog route, not
/// while the dialog is still animating out.
class _IncidentDialog extends StatefulWidget {
  const _IncidentDialog();

  @override
  State<_IncidentDialog> createState() => _IncidentDialogState();
}

class _IncidentDialogState extends State<_IncidentDialog> {
  static const incidentTypes = <String, String>{
    'unexpected_charge': 'طلب مبلغ غير متفق عليه',
    'privacy': 'مشكلة خصوصية',
    'photo_marketing': 'تصوير أو استخدام للتسويق',
    'no_show': 'عدم الحضور',
    'conduct': 'سلوك غير مناسب',
    'quality': 'مشكلة في تنفيذ الخدمة',
    'other': 'أخرى',
  };

  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();
  String _type = 'unexpected_charge';

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  void _send() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _IncidentDraft(type: _type, details: _details.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إبلاغ عطاء عن مشكلة'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'البلاغ خاص بفريق عطاء ولا ينشر كتقييم أو تعليق عام. استخدمه إذا حدثت مشكلة أثناء الخدمة أو بعدها.',
                style: TextStyle(color: RuhamaaColors.textMuted, height: 1.45),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'نوع المشكلة'),
                items: incidentTypes.entries
                    .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                    .toList(),
                onChanged: (value) => setState(() => _type = value ?? 'other'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _details,
                maxLines: 4,
                maxLength: ServiceFlowRules.detailsMax,
                decoration: const InputDecoration(
                  labelText: 'اشرح ما حدث',
                  hintText: 'اذكر الوقائع التي تساعد فريق عطاء على المراجعة.',
                ),
                validator: (value) => ServiceFlowRules.validateDetails(
                  value,
                  emptyMessage: 'أضف وصفًا مختصرًا لما حدث.',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _send, child: const Text('إرسال البلاغ')),
      ],
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
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(color: RuhamaaColors.softGreen, shape: BoxShape.circle),
            child: Icon(icon, size: 45, color: RuhamaaColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: RuhamaaColors.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
