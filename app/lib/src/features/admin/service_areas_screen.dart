import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/staff_repository.dart';
import '../../domain/staff_labels.dart';
import 'staff_widgets.dart';

class ServiceAreasScreen extends StatefulWidget {
  const ServiceAreasScreen({super.key});

  @override
  State<ServiceAreasScreen> createState() => _ServiceAreasScreenState();
}

class _ServiceAreasScreenState extends State<ServiceAreasScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _creating = false;

  StaffRepository get _repo => StaffRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _repo.serviceAreas();
  }

  Future<void> _refresh() async {
    final next = _repo.serviceAreas();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  Future<void> _create() async {
    if (_creating) return;
    List<Map<String, dynamic>> current;
    try {
      current = await _future;
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'لم تُحمَّل النطاقات بعد. حدّث الصفحة ثم حاول مجددًا.',
        );
      }
      return;
    }
    if (!mounted) return;

    var kind = 'area';
    String? parentId;
    final values = await TextFieldsDialog.show(
      context,
      title: 'إضافة مدينة / منطقة',
      confirmLabel: 'إضافة',
      headerBuilder: (context, setDialogState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'area', label: Text('منطقة')),
              ButtonSegment(value: 'city', label: Text('مدينة')),
            ],
            selected: {kind},
            onSelectionChanged: (selection) => setDialogState(() {
              kind = selection.first;
              if (kind == 'city') parentId = null;
            }),
          ),
          if (kind == 'area') ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: parentId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'تتبع'),
              items: current
                  .map(
                    (area) => DropdownMenuItem(
                      value: area['id'] as String,
                      child: Text('${area['name_ar']}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setDialogState(() => parentId = value),
              validator: (value) => value == null
                  ? 'اختر المدينة أو المنطقة التي يتبعها هذا النطاق.'
                  : null,
            ),
          ],
        ],
      ),
      fields: [
        DialogField(
          id: 'name',
          label: 'الاسم بالعربية',
          hint: 'مثال: الروضة',
          maxLength: 60,
          validator: requiredText(
            min: 2,
            message: 'أدخل اسمًا من حرفين على الأقل.',
          ),
        ),
        const DialogField(
          id: 'code',
          label: 'الكود',
          hint: 'مثال: MARIB_RAWDA',
          maxLength: 30,
          textCapitalization: TextCapitalization.characters,
          validator: StaffLabels.areaCodeError,
        ),
      ],
    );
    if (values == null || !mounted) return;
    setState(() => _creating = true);
    try {
      await _repo.createServiceArea(
        code: values['code'] ?? '',
        nameAr: values['name'] ?? '',
        kind: kind,
        parentId: kind == 'area' ? parentId : null,
      );
      if (!mounted) return;
      showInfoSnack(context, 'تم إنشاء نطاق الخدمة.');
      await _refresh();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر إنشاء النطاق. تأكد أن الكود غير مستخدم ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  String _parentName(List<Map<String, dynamic>> rows, String? id) {
    if (id == null) return 'نطاق رئيسي';
    for (final row in rows) {
      if (row['id'] == id) return 'تتبع ${row['name_ar']}';
    }
    return 'تتبع نطاقًا آخر';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المدن والمناطق'),
        actions: [
          IconButton(
            tooltip: 'إضافة نطاق',
            onPressed: _creating ? null : _create,
            icon: const Icon(Icons.add_location_alt_outlined),
          ),
        ],
      ),
      body: RefreshableFuture<List<Map<String, dynamic>>>(
        future: _future,
        onRefresh: _refresh,
        isEmpty: (rows) => rows.isEmpty,
        emptyText: 'لا توجد نطاقات خدمة.',
        builder: (context, rows) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final area = rows[i];
            final isCity = area['kind'] == 'city';
            final parent = _parentName(rows, area['parent_id'] as String?);
            return Card(
              child: ListTile(
                leading: Icon(
                  isCity ? Icons.location_city_outlined : Icons.place_outlined,
                ),
                title: Text('${area['name_ar']}'),
                subtitle: Text(
                  '${area['code']} • ${isCity ? 'مدينة' : 'منطقة'} • $parent',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
