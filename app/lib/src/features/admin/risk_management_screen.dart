import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/admin_repository.dart';
import '../../domain/risk_flag_presenter.dart';
import '../../theme/ruhamaa_theme.dart';
import 'staff_widgets.dart';

class RiskManagementScreen extends StatefulWidget {
  const RiskManagementScreen({super.key});

  @override
  State<RiskManagementScreen> createState() => _RiskManagementScreenState();
}

class _RiskManagementScreenState extends State<RiskManagementScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _busyIds = <String>{};

  AdminRepository get _repo => AdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _repo.riskQueue();
  }

  Future<void> _refresh() async {
    final next = _repo.riskQueue();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  Future<void> _resolve(Map<String, dynamic> risk) async {
    final id = '${risk['id']}';
    if (_busyIds.contains(id)) return;
    final values = await TextFieldsDialog.show(
      context,
      title: 'إغلاق إشارة الخطر',
      confirmLabel: 'إغلاق وتوثيق',
      fields: [
        DialogField(
          id: 'resolution',
          label: 'نتيجة المراجعة',
          hint: 'مثال: تم التواصل وتبين أن الطلب مشروع، أو تم اتخاذ إجراء مناسب.',
          maxLines: 3,
          maxLength: 500,
          validator: requiredText(
            message: 'اكتب نتيجة المراجعة (3 أحرف على الأقل).',
          ),
        ),
      ],
    );
    final resolution = values?['resolution'];
    if (resolution == null || !mounted) return;
    setState(() => _busyIds.add(id));
    try {
      await _repo.resolveRisk(id, resolution);
      if (!mounted) return;
      showInfoSnack(context, 'تم إغلاق الإشارة وتوثيق القرار.');
      await _refresh();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر إغلاق الإشارة. حدّث القائمة ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  String _subject(Map<String, dynamic> risk) {
    if (risk['delivery_id'] != null) return 'مرتبطة بعملية توصيل';
    if (risk['need_id'] != null) return 'مرتبطة بطلب احتياج';
    if (risk['donation_id'] != null) return 'مرتبطة بتبرع';
    return 'مرتبطة بحساب مستخدم';
  }

  Widget _card(Map<String, dynamic> risk) {
    final id = '${risk['id']}';
    final severity = risk['severity'] as String?;
    final urgent = RiskFlagPresenter.isUrgent(severity);
    final lines = RiskFlagPresenter.detailLines(risk['details']);
    final created = DateTime.tryParse('${risk['created_at']}')?.toLocal();
    final busy = _busyIds.contains(id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  color: urgent ? RuhamaaColors.rose : RuhamaaColors.warmGold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    RiskFlagPresenter.ruleLabel(risk['rule_code'] as String?),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(
                    'الخطورة: ${RiskFlagPresenter.severityLabel(severity)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              created == null
                  ? _subject(risk)
                  : '${_subject(risk)} • ${MaterialLocalizations.of(context).formatMediumDate(created)}',
              style: const TextStyle(color: RuhamaaColors.textMuted),
            ),
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(line, style: const TextStyle(height: 1.4)),
                ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : () => _resolve(risk),
              icon: busy
                  ? const InlineSpinner()
                  : const Icon(Icons.fact_check_outlined),
              label: Text(
                busy ? 'جارٍ الحفظ...' : 'تسجيل نتيجة المراجعة وإغلاق الإشارة',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة المخاطر')),
      body: RefreshableFuture<List<Map<String, dynamic>>>(
        future: _future,
        onRefresh: _refresh,
        isEmpty: (rows) => rows.isEmpty,
        emptyText: 'لا توجد إشارات خطر مفتوحة.',
        builder: (context, rows) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: rows.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == rows.length) {
              return rows.length >= AdminRepository.queueLimit
                  ? const QueueLimitNote(limit: AdminRepository.queueLimit)
                  : const SizedBox.shrink();
            }
            return _card(rows[index]);
          },
        ),
      ),
    );
  }
}
