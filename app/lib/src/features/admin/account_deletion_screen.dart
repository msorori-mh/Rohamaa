import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/admin_repository.dart';
import '../../data/staff_repository.dart' show staffFunctionErrorMessage;
import '../../domain/staff_labels.dart';
import '../../theme/ruhamaa_theme.dart';
import 'staff_widgets.dart';

/// Admin queue of account deletion requests. Approving runs the
/// `admin-delete-account` Edge Function, which deletes the account for good.
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _busyIds = <String>{};

  AdminRepository get _repo => AdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _repo.accountDeletionQueue();
  }

  Future<void> _refresh() async {
    final next = _repo.accountDeletionQueue();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  String _name(Map<String, dynamic> row) {
    final name = row['full_name'];
    return name is String && name.trim().isNotEmpty ? name : 'مستخدم بدون اسم';
  }

  int _openOperations(Map<String, dynamic> row) =>
      (row['open_operations'] as num?)?.toInt() ?? 0;

  Future<void> _decide(
    Map<String, dynamic> row, {
    required bool approve,
    String? note,
  }) async {
    final id = '${row['request_id']}';
    setState(() => _busyIds.add(id));
    try {
      await _repo.decideAccountDeletion(
        requestId: id,
        approve: approve,
        note: note,
      );
      if (!mounted) return;
      showInfoSnack(
        context,
        approve ? 'تم حذف الحساب نهائيًا.' : 'تم رفض طلب الحذف وتوثيق السبب.',
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: staffFunctionErrorMessage(error) ??
              'تعذر تنفيذ القرار. حدّث القائمة ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _approve(Map<String, dynamic> row) async {
    if (_busyIds.contains('${row['request_id']}')) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ApproveDeletionDialog(
        name: _name(row),
        openOperations: _openOperations(row),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _decide(row, approve: true);
  }

  Future<void> _reject(Map<String, dynamic> row) async {
    if (_busyIds.contains('${row['request_id']}')) return;
    final values = await TextFieldsDialog.show(
      context,
      title: 'رفض طلب الحذف',
      intro:
          'يبقى الحساب كما هو. اكتب سبب الرفض ليُحفظ مع الطلب (مثال: عملية توصيل جارية يجب إغلاقها أولًا).',
      confirmLabel: 'رفض الطلب',
      fields: [
        DialogField(
          id: 'note',
          label: 'سبب الرفض',
          maxLines: 3,
          maxLength: 300,
          validator: requiredText(message: 'اكتب سبب الرفض (3 أحرف على الأقل).'),
        ),
      ],
    );
    final note = values?['note'];
    if (note == null || !mounted) return;
    await _decide(row, approve: false, note: note);
  }

  Widget _card(Map<String, dynamic> row) {
    final id = '${row['request_id']}';
    final status = row['status'] as String?;
    final open = _openOperations(row);
    final busy = _busyIds.contains(id);
    final requestedAt = DateTime.tryParse('${row['requested_at']}')?.toLocal();
    final canDecide = StaffLabels.canDecideDeletion(status);
    final canReject = StaffLabels.canRejectDeletion(status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.person_remove_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _name(row),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Chip(label: Text(StaffLabels.deletionStatusLabel(status))),
              ],
            ),
            if (requestedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'تاريخ الطلب: ${MaterialLocalizations.of(context).formatMediumDate(requestedAt)}',
                style: const TextStyle(color: RuhamaaColors.textMuted),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              open == 0
                  ? 'لا توجد عمليات جارية على هذا الحساب.'
                  : 'عمليات جارية على الحساب: $open — أغلقها أولًا قبل الموافقة.',
              style: TextStyle(
                color: open == 0 ? RuhamaaColors.success : RuhamaaColors.rose,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (status == 'processing') ...const [
              SizedBox(height: 6),
              Text(
                'بدأ تنفيذ الحذف ولم يكتمل. لا يمكن رفض الطلب في هذه المرحلة؛ أعد المحاولة لإكماله.',
                style: TextStyle(color: RuhamaaColors.textMuted, height: 1.4),
              ),
            ],
            if (canDecide) ...[
              const SizedBox(height: 14),
              if (busy)
                const Center(child: InlineSpinner())
              else
                Row(
                  children: [
                    if (canReject) ...[
                      Expanded(
                        child: OutlinedButton(
                          key: Key('reject-deletion-$id'),
                          onPressed: () => _reject(row),
                          child: const Text('رفض الطلب'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton(
                        key: Key('approve-deletion-$id'),
                        style: FilledButton.styleFrom(
                          backgroundColor: RuhamaaColors.rose,
                        ),
                        onPressed: () => _approve(row),
                        child: Text(StaffLabels.deletionApproveLabel(status)),
                      ),
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
      appBar: AppBar(title: const Text('طلبات حذف الحسابات')),
      body: RefreshableFuture<List<Map<String, dynamic>>>(
        future: _future,
        onRefresh: _refresh,
        isEmpty: (rows) => rows.isEmpty,
        emptyText: 'لا توجد طلبات حذف حسابات الآن.',
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

class _ApproveDeletionDialog extends StatefulWidget {
  const _ApproveDeletionDialog({
    required this.name,
    required this.openOperations,
  });

  final String name;
  final int openOperations;

  @override
  State<_ApproveDeletionDialog> createState() => _ApproveDeletionDialogState();
}

class _ApproveDeletionDialogState extends State<_ApproveDeletionDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('حذف الحساب نهائيًا؟'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'سيُحذف حساب «${widget.name}» وبياناته الشخصية نهائيًا. '
              'لا يمكن التراجع عن هذا الإجراء ولا استعادة الحساب بعده.',
              style: const TextStyle(height: 1.5),
            ),
            if (widget.openOperations > 0) ...[
              const SizedBox(height: 10),
              Text(
                'تنبيه: على هذا الحساب ${widget.openOperations} عملية جارية. '
                'الأفضل إغلاقها قبل الحذف.',
                style: const TextStyle(
                  color: RuhamaaColors.rose,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _understood,
              onChanged: (value) =>
                  setState(() => _understood = value ?? false),
              title: const Text('أفهم أن الحذف نهائي ولا يمكن التراجع عنه'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: RuhamaaColors.rose),
          onPressed: _understood ? () => Navigator.pop(context, true) : null,
          child: const Text('حذف نهائي'),
        ),
      ],
    );
  }
}
