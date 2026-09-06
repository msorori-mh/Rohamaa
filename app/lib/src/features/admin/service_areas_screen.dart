import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/staff_repository.dart';

class ServiceAreasScreen extends StatefulWidget {
  const ServiceAreasScreen({super.key});
  @override State<ServiceAreasScreen> createState() => _ServiceAreasScreenState();
}

class _ServiceAreasScreenState extends State<ServiceAreasScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  @override void initState() { super.initState(); _reload(); }
  void _reload() { _future = StaffRepository(Supabase.instance.client).serviceAreas(); }

  Future<void> _create() async {
    final code = TextEditingController();
    final name = TextEditingController();
    var kind = 'area';
    String? parentId;
    final current = await _future;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('إضافة مدينة / منطقة'),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<String>(segments: const [ButtonSegment(value: 'area', label: Text('منطقة')), ButtonSegment(value: 'city', label: Text('مدينة'))], selected: {kind}, onSelectionChanged: (v) => setDialogState(() { kind = v.first; if (kind == 'city') parentId = null; })),
          const SizedBox(height: 14),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم بالعربية', hintText: 'مثال: الروضة')),
          const SizedBox(height: 14),
          TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'الكود', hintText: 'مثال: MARIB_RAWDA')),
          if (kind == 'area') ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: parentId,
              decoration: const InputDecoration(labelText: 'تتبع'),
              items: current.map((a) => DropdownMenuItem(value: a['id'] as String, child: Text('${a['name_ar']}'))).toList(),
              onChanged: (v) => setDialogState(() => parentId = v),
            ),
          ],
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة'))],
      )),
    );
    if (ok == true) {
      if (name.text.trim().length < 2 || code.text.trim().length < 2 || (kind == 'area' && parentId == null)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل بيانات المنطقة.')));
      } else {
        try {
          await StaffRepository(Supabase.instance.client).createServiceArea(code: code.text, nameAr: name.text, kind: kind, parentId: parentId);
          if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء نطاق الخدمة.'))); setState(_reload); }
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء النطاق: $e')));
        }
      }
    }
    code.dispose(); name.dispose();
  }

  String _parentName(List<Map<String, dynamic>> rows, String? id) {
    if (id == null) return 'نطاق رئيسي';
    for (final row in rows) { if (row['id'] == id) return '${row['name_ar']}'; }
    return 'نطاق آخر';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المدن والمناطق'), actions: [IconButton(tooltip: 'إضافة نطاق', onPressed: _create, icon: const Icon(Icons.add_location_alt_outlined))]),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('تعذر تحميل المناطق: ${snapshot.error}'));
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) return const Center(child: Text('لا توجد نطاقات خدمة.'));
        return RefreshIndicator(onRefresh: () async => setState(_reload), child: ListView.separated(
          padding: const EdgeInsets.all(16), itemCount: rows.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) { final a = rows[i]; return Card(child: ListTile(
            leading: Icon(a['kind'] == 'city' ? Icons.location_city_outlined : Icons.place_outlined),
            title: Text('${a['name_ar']}'),
            subtitle: Text('${a['code']} • ${a['kind'] == 'city' ? 'مدينة' : 'منطقة'} • ${_parentName(rows, a['parent_id'] as String?)}'),
          )); },
        ));
      },
    ),
  );
}
