import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/partner_repository.dart';
import '../../domain/staff_labels.dart';
import '../../theme/ruhamaa_theme.dart';
import '../partners/partner_hub_v2_screen.dart' show partnerKindsV2;
import 'staff_widgets.dart';

class PartnerManagementScreen extends StatefulWidget {
  const PartnerManagementScreen({super.key});

  @override
  State<PartnerManagementScreen> createState() =>
      _PartnerManagementScreenState();
}

class _PartnerManagementScreenState extends State<PartnerManagementScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _busyIds = <String>{};

  PartnerRepository get _repo => PartnerRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _repo.adminPartners();
  }

  Future<void> _refresh() async {
    final next = _repo.adminPartners();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  Future<void> _setStatus(Map<String, dynamic> row, String status) async {
    final id = '${row['id']}';
    if (_busyIds.contains(id)) return;
    String? note;
    if (status == 'verified') {
      final confirmed = await confirmAction(
        context,
        title: 'اعتماد الشريك؟',
        message:
            'سيظهر «${row['display_name']}» كشريك موثّق ويمكنه تقديم عروض خدمات باسم عطاء.',
        confirmLabel: 'اعتماد',
      );
      if (!confirmed) return;
    } else {
      final values = await TextFieldsDialog.show(
        context,
        title: status == 'suspended' ? 'إيقاف الشريك' : 'رفض طلب الشراكة',
        intro: status == 'suspended'
            ? 'ستتوقف عروض هذا الشريك حتى يُعاد تفعيله.'
            : null,
        fields: const [
          DialogField(
            id: 'note',
            label: 'ملاحظة داخلية (اختياري)',
            maxLines: 3,
            maxLength: 300,
          ),
        ],
      );
      if (values == null) return;
      final text = values['note'] ?? '';
      note = text.isEmpty ? null : text;
    }
    if (!mounted) return;
    setState(() => _busyIds.add(id));
    try {
      await _repo.setPartnerStatus(id, status, note: note);
      if (!mounted) return;
      showInfoSnack(
        context,
        status == 'verified' ? 'تم اعتماد شريك عطاء.' : 'تم تحديث حالة الشريك.',
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر تحديث الشريك. حدّث القائمة ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Widget _actions(Map<String, dynamic> row, String status, bool busy) {
    if (busy) return const Center(child: InlineSpinner());
    if (status == 'pending' || status == 'rejected') {
      return Row(
        children: [
          if (status == 'pending') ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => _setStatus(row, 'rejected'),
                child: const Text('رفض'),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () => _setStatus(row, 'verified'),
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('اعتماد كشريك'),
            ),
          ),
        ],
      );
    }
    if (status == 'verified') {
      return OutlinedButton.icon(
        onPressed: () => _setStatus(row, 'suspended'),
        icon: const Icon(Icons.pause_circle_outline_rounded),
        label: const Text('إيقاف الشريك وعروضه'),
      );
    }
    if (status == 'suspended') {
      return FilledButton.icon(
        onPressed: () => _setStatus(row, 'verified'),
        icon: const Icon(Icons.restart_alt_rounded),
        label: const Text('إعادة تفعيل الشريك'),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _card(Map<String, dynamic> row) {
    final id = '${row['id']}';
    final status = '${row['verification_status']}';
    final verified = status == 'verified';
    final kind = '${row['partner_kind']}';
    final adminNote = row['admin_note'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: verified
                      ? RuhamaaColors.softGreen
                      : RuhamaaColors.warmGoldSoft,
                  foregroundColor:
                      verified ? RuhamaaColors.primary : RuhamaaColors.warmGold,
                  child: Icon(
                    verified
                        ? Icons.verified_rounded
                        : Icons.storefront_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row['display_name']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        partnerKindsV2[kind] ?? 'نوع آخر',
                        style: const TextStyle(color: RuhamaaColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(StaffLabels.partnerStatusLabel(status))),
              ],
            ),
            const SizedBox(height: 10),
            if (row['description'] != null)
              Text('${row['description']}', style: const TextStyle(height: 1.45)),
            const SizedBox(height: 7),
            Text(
              'سعة تقريبية: ${row['monthly_case_capacity'] ?? 0} حالات/شهر',
              style: const TextStyle(color: RuhamaaColors.textMuted),
            ),
            if (row['contact_phone'] != null)
              Text(
                'تواصل خاص للتحقق: ${row['contact_phone']}',
                style: const TextStyle(color: RuhamaaColors.textMuted),
              ),
            if (adminNote is String && adminNote.trim().isNotEmpty)
              Text(
                'ملاحظة داخلية: $adminNote',
                style: const TextStyle(color: RuhamaaColors.textMuted),
              ),
            const SizedBox(height: 14),
            _actions(row, status, _busyIds.contains(id)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شركاء عطاء')),
      body: RefreshableFuture<List<Map<String, dynamic>>>(
        future: _future,
        onRefresh: _refresh,
        isEmpty: (rows) => rows.isEmpty,
        emptyText: 'لا توجد طلبات شراكة حتى الآن.',
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
