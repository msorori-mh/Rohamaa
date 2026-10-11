import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/admin_repository.dart';
import '../../domain/delivery_dispatch_rules.dart';
import 'delivery_assignment_screen.dart';
import 'staff_widgets.dart';

class DeliveryOperationsScreen extends StatefulWidget {
  const DeliveryOperationsScreen({super.key});

  @override
  State<DeliveryOperationsScreen> createState() =>
      _DeliveryOperationsScreenState();
}

class _DeliveryOperationsScreenState extends State<DeliveryOperationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _busyIds = <String>{};

  AdminRepository get _repo => AdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _repo.deliveryDispatchQueue();
  }

  Future<void> _refresh() async {
    final next = _repo.deliveryDispatchQueue();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  Future<void> _reassign(String deliveryId) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryAssignmentScreen(deliveryId: deliveryId),
      ),
    );
    if (changed == true && mounted) await _refresh();
  }

  Future<void> _cancel(Map<String, dynamic> row) async {
    final id = '${row['delivery_id']}';
    if (_busyIds.contains(id)) return;
    final values = await TextFieldsDialog.show(
      context,
      title: 'إلغاء مهمة التوصيل',
      intro:
          'سيُلغى توصيل ${row['public_code']} ولن يتمكن الموصل من متابعته. اكتب سبب الإلغاء ليُحفظ في السجل.',
      confirmLabel: 'تأكيد الإلغاء',
      cancelLabel: 'رجوع',
      fields: [
        DialogField(
          id: 'reason',
          label: 'سبب الإلغاء',
          maxLines: 3,
          maxLength: 300,
          validator: requiredText(message: 'اكتب سبب الإلغاء (3 أحرف على الأقل).'),
        ),
      ],
    );
    final reason = values?['reason'];
    if (reason == null || !mounted) return;
    setState(() => _busyIds.add(id));
    try {
      await _repo.cancelDelivery(deliveryId: id, reason: reason);
      if (!mounted) return;
      showInfoSnack(context, 'تم إلغاء مهمة التوصيل.');
      await _refresh();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر إلغاء المهمة. حدّث القائمة ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Widget _card(Map<String, dynamic> row) {
    final id = '${row['delivery_id']}';
    final status = '${row['status']}';
    final courier = row['courier_name'] as String?;
    final vehicle = row['vehicle_code'] as String?;
    final attempt = (row['dispatch_attempt'] as num?)?.toInt() ?? 1;
    final rejection = row['rejection_reason'] as String?;
    final canReassign = DeliveryDispatchRules.canAdminReassign(status);
    final canCancel = DeliveryDispatchRules.canAdminCancel(status);
    final busy = _busyIds.contains(id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row['public_code']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('الحالة: ${DeliveryDispatchRules.adminStatusLabel(status)}'),
            Text(
              courier == null || courier.trim().isEmpty
                  ? 'لا يوجد موصل حاليًا'
                  : 'الموصل: $courier',
            ),
            if (vehicle != null && vehicle.isNotEmpty) Text('الدراجة: $vehicle'),
            Text('محاولة الإسناد: $attempt'),
            if (rejection != null)
              Text(
                'سبب الاعتذار: ${DeliveryDispatchRules.rejectionReasonLabel(rejection)}',
              ),
            if (canReassign || canCancel) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (canReassign)
                    FilledButton.icon(
                      onPressed: busy ? null : () => _reassign(id),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: Text(
                        status == 'assigned'
                            ? 'تغيير الموصل'
                            : 'إعادة إسناد المهمة',
                      ),
                    ),
                  if (canCancel)
                    OutlinedButton.icon(
                      key: Key('cancel-delivery-$id'),
                      onPressed: busy ? null : () => _cancel(row),
                      icon: busy
                          ? const InlineSpinner()
                          : const Icon(Icons.cancel_outlined),
                      label: Text(busy ? 'جارٍ الإلغاء...' : 'إلغاء المهمة'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('متابعة التوصيل')),
      body: RefreshableFuture<List<Map<String, dynamic>>>(
        future: _future,
        onRefresh: _refresh,
        isEmpty: (rows) => rows.isEmpty,
        emptyText: 'لا توجد مهام توصيل جارية.',
        builder: (context, rows) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _card(rows[index]),
        ),
      ),
    );
  }
}
