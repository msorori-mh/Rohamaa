import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/admin_repository.dart';
import '../../domain/staff_labels.dart';
import '../../theme/ruhamaa_theme.dart';
import 'staff_widgets.dart';

/// Review queue for pending cash contributions. The admin approves a
/// contribution only after the money was really received; the courier's own
/// confirmation is shown on each row as supporting evidence.
class ContributionReviewScreen extends StatefulWidget {
  const ContributionReviewScreen({super.key});

  @override
  State<ContributionReviewScreen> createState() =>
      _ContributionReviewScreenState();
}

class _ContributionReviewScreenState extends State<ContributionReviewScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _busyIds = <String>{};

  AdminRepository get _repo => AdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _repo.pendingContributions();
  }

  Future<void> _refresh() async {
    final next = _repo.pendingContributions();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  Future<void> _verify(Map<String, dynamic> contribution, bool verified) async {
    final id = '${contribution['id']}';
    if (_busyIds.contains(id)) return;
    final amount = '${contribution['amount_yer']} ريال';
    final courierReceived = contribution['courier_received'];

    final String message;
    if (verified) {
      message = courierReceived == true
          ? 'أكد الموصل استلام $amount. هل تعتمد المساهمة؟'
          : courierReceived == false
              ? 'أفاد الموصل بأن مبلغ $amount لم يُستلم. لا تعتمد المساهمة إلا إذا تأكدت بنفسك من استلام المبلغ.'
              : 'لم يؤكد الموصل استلام $amount بعد. لا تعتمد المساهمة إلا إذا تأكدت بنفسك من استلام المبلغ.';
    } else {
      message = 'هل تأكدت أن مبلغ $amount لم يُستلم؟ سيُرفض سجل المساهمة.';
    }
    final confirmed = await confirmAction(
      context,
      title: verified ? 'اعتماد المساهمة' : 'تأكيد عدم الاستلام',
      message: message,
      confirmLabel: verified ? 'اعتماد' : 'تأكيد الرفض',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyIds.add(id));
    try {
      await _repo.verifyContribution(id, verified);
      if (!mounted) return;
      showInfoSnack(
        context,
        verified ? 'تم اعتماد المساهمة.' : 'تم تسجيل عدم استلام المبلغ.',
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر تحديث المساهمة. حدّث القائمة ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  String _details(Map<String, dynamic> contribution) {
    final method = contribution['payment_method'];
    final code = contribution['public_code'] ?? '';
    if (method == 'cash_to_courier') {
      return 'نقدًا للمندوب • $code';
    }
    final reference = contribution['payment_reference'] ?? 'غير مسجل';
    return 'سجل تحويل قديم • $code\nالمرجع: $reference';
  }

  Widget _courierLine(Map<String, dynamic> contribution) {
    final received = contribution['courier_received'];
    final color = received == true
        ? RuhamaaColors.success
        : received == false
            ? RuhamaaColors.rose
            : RuhamaaColors.textMuted;
    final icon = received == true
        ? Icons.check_circle_outline_rounded
        : received == false
            ? Icons.error_outline_rounded
            : Icons.hourglass_empty_rounded;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            StaffLabels.courierReceiptLabel(received),
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _card(Map<String, dynamic> c) {
    final id = '${c['id']}';
    final busy = _busyIds.contains(id);
    final isCash = c['payment_method'] == 'cash_to_courier';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c['amount_yer']} ريال',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(_details(c)),
                  if (isCash) ...[
                    const SizedBox(height: 6),
                    _courierLine(c),
                  ],
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Wrap(
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة المساهمات النقدية')),
      body: RefreshableFuture<List<Map<String, dynamic>>>(
        future: _future,
        onRefresh: _refresh,
        isEmpty: (rows) => rows.isEmpty,
        emptyText: 'لا توجد مساهمات بانتظار التحقق.',
        builder: (context, rows) => ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: rows.length + 1,
          itemBuilder: (context, index) {
            if (index == rows.length) {
              return rows.length >= AdminRepository.queueLimit
                  ? const QueueLimitNote(limit: AdminRepository.queueLimit)
                  : const SizedBox(height: 8);
            }
            return _card(rows[index]);
          },
        ),
      ),
    );
  }
}
