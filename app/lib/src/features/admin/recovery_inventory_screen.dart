import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/recovery_repository.dart';
import '../../domain/item_recovery_rules.dart';
import '../../domain/staff_labels.dart';
import '../../theme/ruhamaa_theme.dart';
import 'staff_widgets.dart';

class RecoveryInventoryScreen extends StatefulWidget {
  const RecoveryInventoryScreen({super.key});

  @override
  State<RecoveryInventoryScreen> createState() =>
      _RecoveryInventoryScreenState();
}

class _RecoveryData {
  const _RecoveryData(this.summary, this.warehouses, this.incoming, this.queue);

  final RecoverySummary summary;
  final List<WarehouseItem> warehouses;
  final List<IntakeCandidate> incoming;
  final List<InventoryQueueItem> queue;
}

String? _optionalWeight(String value) {
  if (value.isEmpty) return null;
  final parsed = double.tryParse(value);
  if (parsed == null || parsed < 0) return 'أدخل وزنًا صحيحًا بالكيلو.';
  return null;
}

class _RecoveryInventoryScreenState extends State<RecoveryInventoryScreen> {
  static const _warehouseBusyKey = 'new-warehouse';

  late Future<_RecoveryData> _future;

  /// Ids of rows with a mutation in flight, so a step cannot be sent twice.
  final Set<String> _busyKeys = <String>{};

  RecoveryRepository get _repo => RecoveryRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_RecoveryData> _load() async {
    final values = await Future.wait<dynamic>([
      _repo.summary(),
      _repo.warehouses(),
      _repo.intakeCandidates(),
      _repo.queue(),
    ]);
    return _RecoveryData(
      values[0] as RecoverySummary,
      values[1] as List<WarehouseItem>,
      values[2] as List<IntakeCandidate>,
      values[3] as List<InventoryQueueItem>,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  Future<void> _run(String busyKey, Future<void> Function() action) async {
    if (!mounted || _busyKeys.contains(busyKey)) return;
    setState(() => _busyKeys.add(busyKey));
    try {
      await action();
      if (!mounted) return;
      showInfoSnack(context, 'تم حفظ الخطوة التشغيلية.');
      await _refresh();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر تنفيذ الخطوة. حدّث القائمة ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyKeys.remove(busyKey));
    }
  }

  Future<void> _createWarehouse() async {
    if (_busyKeys.contains(_warehouseBusyKey)) return;
    final values = await TextFieldsDialog.show(
      context,
      title: 'إضافة مستودع',
      confirmLabel: 'حفظ',
      fields: [
        DialogField(
          id: 'code',
          label: 'الرمز مثل MRB-01',
          maxLength: 30,
          textCapitalization: TextCapitalization.characters,
          validator: requiredText(
            min: 2,
            message: 'أدخل رمزًا من حرفين على الأقل.',
          ),
        ),
        DialogField(
          id: 'name',
          label: 'اسم المستودع',
          maxLength: 80,
          validator: requiredText(message: 'أدخل اسمًا من 3 أحرف على الأقل.'),
        ),
        const DialogField(
          id: 'address',
          label: 'وصف الموقع — اختياري',
          maxLines: 2,
          maxLength: 200,
        ),
      ],
    );
    if (values == null) return;
    await _run(
      _warehouseBusyKey,
      () => _repo.createWarehouse(
        code: values['code'] ?? '',
        name: values['name'] ?? '',
        addressNote: values['address'],
      ),
    );
  }

  Future<void> _receive(
    IntakeCandidate item,
    List<WarehouseItem> warehouses,
  ) async {
    if (_busyKeys.contains(item.id)) return;
    if (warehouses.isEmpty) {
      showInfoSnack(context, 'أنشئ مستودعًا نشطًا أولًا.');
      return;
    }
    var warehouse = warehouses.first.id;
    final values = await TextFieldsDialog.show(
      context,
      title: 'استلام ${item.itemType}',
      confirmLabel: 'تأكيد الاستلام',
      headerBuilder: (context, setDialogState) =>
          DropdownButtonFormField<String>(
        initialValue: warehouse,
        decoration: const InputDecoration(labelText: 'المستودع'),
        items: warehouses
            .map(
              (w) => DropdownMenuItem(
                value: w.id,
                child: Text('${w.name} (${w.code})'),
              ),
            )
            .toList(),
        onChanged: (value) =>
            setDialogState(() => warehouse = value ?? warehouse),
      ),
      fields: const [
        DialogField(
          id: 'bin',
          label: 'الرف/الموقع الداخلي — اختياري',
          maxLength: 60,
        ),
      ],
    );
    if (values == null) return;
    await _run(
      item.id,
      () => _repo.receive(
        donationId: item.id,
        warehouseId: warehouse,
        binLocation: values['bin'],
      ),
    );
  }

  Future<void> _inspect(InventoryQueueItem item) async {
    if (_busyKeys.contains(item.id)) return;
    var grade = 'A';
    final values = await TextFieldsDialog.show(
      context,
      title: 'نتيجة الفحص A–D',
      confirmLabel: 'اعتماد التصنيف',
      headerBuilder: (context, setDialogState) =>
          DropdownButtonFormField<String>(
        initialValue: grade,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'درجة الفحص'),
        items: ItemRecoveryRules.gradeLabels.entries
            .map(
              (entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (value) => setDialogState(() => grade = value ?? grade),
      ),
      fields: [
        const DialogField(
          id: 'note',
          label: 'ملاحظة الفحص — اختيارية',
          maxLines: 3,
          maxLength: 300,
        ),
        DialogField(
          id: 'cost',
          label: 'التكلفة التقديرية (ر.ي) — اختيارية',
          keyboardType: TextInputType.number,
          digitsOnly: true,
          maxLength: 9,
          validator: optionalAmount,
          visible: () => grade == 'B' || grade == 'C',
        ),
      ],
    );
    if (values == null) return;
    final needsCost = grade == 'B' || grade == 'C';
    await _run(
      item.id,
      () => _repo.inspect(
        inventoryId: item.id,
        grade: grade,
        note: values['note'],
        estimatedCostYer: needsCost ? int.tryParse(values['cost'] ?? '') : null,
      ),
    );
  }

  Future<void> _advanceWork(InventoryQueueItem item, String action) async {
    final workOrderId = item.workOrderId;
    if (_busyKeys.contains(item.id)) return;
    if (workOrderId == null) {
      showInfoSnack(context, 'لا يوجد أمر عمل لهذا العنصر. حدّث القائمة.');
      return;
    }
    final completing = action == 'complete';
    final values = await TextFieldsDialog.show(
      context,
      title: completing ? 'إكمال المعالجة' : 'بدء المعالجة',
      confirmLabel: completing ? 'إكمال وإتاحة العطاء' : 'بدء العمل',
      fields: [
        if (completing)
          const DialogField(
            id: 'cost',
            label: 'التكلفة الفعلية (ر.ي) — اختيارية',
            keyboardType: TextInputType.number,
            digitsOnly: true,
            maxLength: 9,
            validator: optionalAmount,
          ),
        const DialogField(
          id: 'note',
          label: 'ملاحظة تشغيلية — اختيارية',
          maxLines: 3,
          maxLength: 300,
        ),
      ],
    );
    if (values == null) return;
    await _run(
      item.id,
      () => _repo.advanceWork(
        workOrderId: workOrderId,
        action: action,
        actualCostYer: completing ? int.tryParse(values['cost'] ?? '') : null,
        note: values['note'],
      ),
    );
  }

  Future<void> _confirmRecycling(InventoryQueueItem item) async {
    final recyclingId = item.recyclingId;
    if (_busyKeys.contains(item.id)) return;
    if (recyclingId == null) {
      showInfoSnack(context, 'لا يوجد سجل تدوير لهذا العنصر. حدّث القائمة.');
      return;
    }
    final values = await TextFieldsDialog.show(
      context,
      title: 'تأكيد إعادة التدوير',
      intro: 'هذا تأكيد نهائي: يخرج العنصر من المخزون ولا يعود للتوزيع.',
      confirmLabel: 'تأكيد نهائي',
      fields: const [
        DialogField(
          id: 'material',
          label: 'نوع المادة — اختياري',
          maxLength: 60,
        ),
        DialogField(
          id: 'weight',
          label: 'الوزن بالكيلو — اختياري',
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          maxLength: 9,
          validator: _optionalWeight,
        ),
        DialogField(
          id: 'proceeds',
          label: 'العائد (ر.ي) — اختياري',
          keyboardType: TextInputType.number,
          digitsOnly: true,
          maxLength: 9,
          validator: optionalAmount,
        ),
        DialogField(
          id: 'note',
          label: 'ملاحظة — اختيارية',
          maxLines: 2,
          maxLength: 300,
        ),
      ],
    );
    if (values == null) return;
    await _run(
      item.id,
      () => _repo.confirmRecycling(
        recyclingId: recyclingId,
        materialType: values['material'],
        weightKg: double.tryParse(values['weight'] ?? ''),
        proceedsYer: int.tryParse(values['proceeds'] ?? ''),
        note: values['note'],
      ),
    );
  }

  Widget _content(_RecoveryData data) {
    final activeWarehouses = data.warehouses.where((w) => w.active).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        const _Intro(),
        const SizedBox(height: 16),
        _Summary(summary: data.summary),
        const SizedBox(height: 22),
        _Header(
          title: 'المستودعات',
          actionLabel: 'إضافة مستودع',
          onAction:
              _busyKeys.contains(_warehouseBusyKey) ? null : _createWarehouse,
        ),
        const SizedBox(height: 8),
        if (data.warehouses.isEmpty)
          const _Empty('لا يوجد مستودع بعد. أنشئ موقعًا قبل استلام الأشياء.')
        else
          for (final w in data.warehouses)
            Card(
              child: ListTile(
                leading: const Icon(Icons.warehouse_outlined),
                title: Text(w.name),
                subtitle: Text(w.active ? w.code : '${w.code} • متوقف'),
                trailing: Icon(
                  w.active ? Icons.check_circle : Icons.pause_circle,
                  color:
                      w.active ? RuhamaaColors.success : RuhamaaColors.textMuted,
                ),
              ),
            ),
        const SizedBox(height: 22),
        const _Header(title: 'وارد ينتظر الاستلام'),
        const SizedBox(height: 8),
        if (data.incoming.isEmpty)
          const _Empty('لا توجد عطاءات جديدة تنتظر إدخال المخزون.')
        else
          for (final item in data.incoming)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.move_to_inbox_outlined),
                  ),
                  title: Text(
                    item.itemType,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    [
                      item.code,
                      StaffLabels.donationConditionLabel(item.condition),
                    ].where((part) => part.isNotEmpty).join(' • '),
                  ),
                  trailing: FilledButton(
                    onPressed: _busyKeys.contains(item.id)
                        ? null
                        : () => _receive(item, activeWarehouses),
                    child: Text(
                      _busyKeys.contains(item.id) ? 'جارٍ...' : 'استلام',
                    ),
                  ),
                ),
              ),
            ),
        const SizedBox(height: 22),
        const _Header(title: 'طابور الفحص والمعالجة'),
        const SizedBox(height: 8),
        if (data.queue.isEmpty)
          const _Empty('لا توجد أشياء داخل دورة التأهيل بعد.')
        else
          for (final item in data.queue)
            _InventoryCard(
              item: item,
              busy: _busyKeys.contains(item.id),
              onInspect: () => _inspect(item),
              onStart: () => _advanceWork(item, 'start'),
              onComplete: () => _advanceWork(item, 'complete'),
              onRecycle: () => _confirmRecycling(item),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التأهيل والمخزون'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: RefreshableFuture<_RecoveryData>(
        future: _future,
        onRefresh: _refresh,
        builder: (context, data) => _content(data),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RuhamaaColors.softGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'كل عطاء يُفحص قبل إعادة توزيعه: A جاهز، B تنظيف، C إصلاح، D تدوير. الغذاء والدواء خارج هذه المرحلة.',
        style: TextStyle(height: 1.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final RecoverySummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip('فحص', summary.awaitingInspection),
        _Chip('تنظيف', summary.cleaning),
        _Chip('إصلاح', summary.repairing),
        _Chip('جاهز', summary.ready),
        _Chip('مُدوّر', summary.recycled),
        _Chip('تكلفة التأهيل', summary.repairCostYer, suffix: ' ر.ي'),
        _Chip('عائد التدوير', summary.recyclingProceedsYer, suffix: ' ر.ي'),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value, {this.suffix = ''});

  final String label;
  final int value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        '$label: $value$suffix',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ),
        if (label != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add),
            label: Text(label),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          text,
          style: const TextStyle(color: RuhamaaColors.textMuted),
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.item,
    required this.busy,
    required this.onInspect,
    required this.onStart,
    required this.onComplete,
    required this.onRecycle,
  });

  final InventoryQueueItem item;
  final bool busy;
  final VoidCallback onInspect;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onRecycle;

  @override
  Widget build(BuildContext context) {
    final copy = ItemRecoveryRules.status(item.status);
    final (VoidCallback? action, String actionLabel) = switch (copy.nextAction) {
      'inspect' => (onInspect, 'تسجيل الفحص'),
      'start_work' => (onStart, 'بدء المعالجة'),
      'complete_work' => (onComplete, 'إكمال المعالجة'),
      'confirm_recycling' => (onRecycle, 'تأكيد التدوير'),
      _ => (null, ''),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.itemType,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                [item.code, item.warehouseName, item.binLocation]
                    .where((part) => part.isNotEmpty)
                    .join(' • '),
                style: const TextStyle(color: RuhamaaColors.textMuted),
              ),
              const SizedBox(height: 10),
              Text(
                copy.label,
                style: const TextStyle(
                  color: RuhamaaColors.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (item.grade.isNotEmpty)
                Text(
                  ItemRecoveryRules.gradeLabels[item.grade] ?? item.grade,
                  style: const TextStyle(color: RuhamaaColors.textMuted),
                ),
              if (action != null) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy ? null : action,
                  child: Text(busy ? 'جارٍ الحفظ...' : actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
