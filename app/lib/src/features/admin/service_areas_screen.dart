import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/staff_repository.dart';
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
    setState(() {
      _future = next;
    });
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

    final governorates = current
        .where((area) => area['kind'] == 'city' && area['active'] == true)
        .toList();
    if (governorates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد محافظات متاحة. تواصل مع المشرف الأعلى.')),
      );
      return;
    }

    String? governorateId;
    final values = await TextFieldsDialog.show(
      context,
      title: 'إضافة منطقة',
      confirmLabel: 'إضافة',
      headerBuilder: (context, setDialogState) => DropdownButtonFormField<String>(
        initialValue: governorateId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'المحافظة'),
        items: governorates
            .map(
              (area) => DropdownMenuItem(
                value: area['id'] as String,
                child: Text('${area['name_ar']}'),
              ),
            )
            .toList(),
        onChanged: (value) => setDialogState(() => governorateId = value),
        validator: (value) => value == null ? 'اختر المحافظة التي تتبعها المنطقة.' : null,
      ),
      fields: [
        DialogField(
          id: 'name',
          label: 'اسم المنطقة بالعربية',
          hint: 'مثال: الروضة',
          maxLength: 60,
          validator: requiredText(
            min: 2,
            message: 'أدخل اسمًا من حرفين على الأقل.',
          ),
        ),
      ],
    );
    if (values == null || governorateId == null || !mounted) return;
    setState(() => _creating = true);
    try {
      await _repo.createArea(
        nameAr: values['name'] ?? '',
        governorateId: governorateId!,
      );
      if (!mounted) return;
      showInfoSnack(context, 'تم إنشاء المنطقة وتوليد كودها تلقائياً.');
      await _refresh();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر إنشاء المنطقة. تحقق من اختيار المحافظة ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _activateGovernorate() async {
    if (_creating) return;
    List<Map<String, dynamic>> inactive;
    try {
      inactive = await _repo.inactiveGovernorates();
    } catch (error) {
      if (mounted) {
        showErrorSnack(context, error, fallback: 'تعذر تحميل المحافظات. حاول مجددًا.');
      }
      return;
    }
    if (!mounted) return;
    if (inactive.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كل المحافظات مفعّلة بالفعل.')),
      );
      return;
    }

    final governorateId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? selected;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('تفعيل محافظة'),
            content: DropdownButtonFormField<String>(
              initialValue: selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'المحافظة'),
              items: inactive
                  .map(
                    (area) => DropdownMenuItem(
                      value: area['id'] as String,
                      child: Text('${area['name_ar']}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setDialogState(() => selected = value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: selected == null ? null : () => Navigator.pop(dialogContext, selected),
                child: const Text('تفعيل'),
              ),
            ],
          ),
        );
      },
    );
    if (governorateId == null || !mounted) return;
    setState(() => _creating = true);
    try {
      await _repo.setServiceAreaActive(governorateId, true);
      if (!mounted) return;
      showInfoSnack(context, 'تم تفعيل المحافظة وأصبحت متاحة للتشغيل.');
      await _refresh();
    } catch (error) {
      if (mounted) {
        showErrorSnack(context, error, fallback: 'تعذر تفعيل المحافظة. حاول مجددًا.');
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
            tooltip: 'تفعيل محافظة',
            onPressed: _creating ? null : _activateGovernorate,
            icon: const Icon(Icons.toggle_on_outlined),
          ),
          IconButton(
            tooltip: 'إضافة منطقة',
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
