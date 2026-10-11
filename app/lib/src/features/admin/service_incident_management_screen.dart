import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/service_incident_repository.dart';
import '../../domain/staff_labels.dart';
import '../../theme/ruhamaa_theme.dart';
import 'staff_widgets.dart';

class ServiceIncidentManagementScreen extends StatefulWidget {
  const ServiceIncidentManagementScreen({super.key});

  @override
  State<ServiceIncidentManagementScreen> createState() =>
      _ServiceIncidentManagementScreenState();
}

class _ServiceIncidentManagementScreenState
    extends State<ServiceIncidentManagementScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _busyIds = <String>{};

  ServiceIncidentRepository get _repo =>
      ServiceIncidentRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _repo.adminIncidents();
  }

  Future<void> _refresh() async {
    final next = _repo.adminIncidents();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  Future<void> _resolve(
    Map<String, dynamic> row, {
    required bool dismissed,
  }) async {
    final id = '${row['id']}';
    if (_busyIds.contains(id)) return;
    final values = await TextFieldsDialog.show(
      context,
      title: dismissed ? 'إغلاق البلاغ بدون إجراء' : 'تسجيل قرار المراجعة',
      confirmLabel: 'حفظ القرار',
      fields: [
        DialogField(
          id: 'resolution',
          label: 'قرار وملاحظات المراجعة',
          hint: 'سجّل ما تم التحقق منه والإجراء المتخذ.',
          maxLines: 4,
          maxLength: 500,
          validator: requiredText(
            message: 'اكتب قرار المراجعة (3 أحرف على الأقل).',
          ),
        ),
      ],
    );
    final resolution = values?['resolution'];
    if (resolution == null || !mounted) return;
    setState(() => _busyIds.add(id));
    try {
      await _repo.resolve(id, dismissed: dismissed, resolution: resolution);
      if (!mounted) return;
      showInfoSnack(context, 'تم حفظ قرار مراجعة البلاغ.');
      await _refresh();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر إغلاق البلاغ. حدّث القائمة ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Widget _card(Map<String, dynamic> row) {
    final id = '${row['id']}';
    final busy = _busyIds.contains(id);
    final created = DateTime.tryParse('${row['created_at']}')?.toLocal();
    final matchRef = '${row['service_match_id'] ?? ''}';
    final shortRef = matchRef.length > 8 ? matchRef.substring(0, 8) : matchRef;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: RuhamaaColors.warmGoldSoft,
                  foregroundColor: RuhamaaColors.warmGold,
                  child: Icon(Icons.report_problem_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    StaffLabels.incidentTypeLabel(
                      row['incident_type'] as String?,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    StaffLabels.incidentStatusLabel(row['status'] as String?),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('${row['description'] ?? ''}', style: const TextStyle(height: 1.5)),
            const SizedBox(height: 8),
            Text(
              [
                if (created != null)
                  'تاريخ البلاغ: ${MaterialLocalizations.of(context).formatMediumDate(created)}',
                if (shortRef.isNotEmpty) 'مرجع الخدمة: $shortRef',
              ].join(' • '),
              style: const TextStyle(
                color: RuhamaaColors.textMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 14),
            if (busy)
              const Center(child: InlineSpinner())
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _resolve(row, dismissed: true),
                      child: const Text('إغلاق دون إجراء'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => _resolve(row, dismissed: false),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('تسجيل قرار المراجعة'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('بلاغات الخدمات')),
      body: RefreshableFuture<List<Map<String, dynamic>>>(
        future: _future,
        onRefresh: _refresh,
        isEmpty: (rows) => rows.isEmpty,
        emptyText: 'لا توجد بلاغات خدمات مفتوحة الآن.',
        builder: (context, rows) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _card(rows[index]),
        ),
      ),
    );
  }
}
