import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/service_incident_repository.dart';
import '../../theme/ruhamaa_theme.dart';

class ServiceIncidentManagementScreen extends StatefulWidget {
  const ServiceIncidentManagementScreen({super.key});

  @override
  State<ServiceIncidentManagementScreen> createState() => _ServiceIncidentManagementScreenState();
}

class _ServiceIncidentManagementScreenState extends State<ServiceIncidentManagementScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  ServiceIncidentRepository get _repo => ServiceIncidentRepository(Supabase.instance.client);

  static const labels = <String, String>{
    'unexpected_charge': 'طلب مبلغ غير متفق عليه',
    'privacy': 'مشكلة خصوصية',
    'photo_marketing': 'تصوير أو تسويق',
    'no_show': 'عدم الحضور',
    'conduct': 'سلوك غير مناسب',
    'quality': 'مشكلة في التنفيذ',
    'other': 'أخرى',
  };

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() { _future = _repo.adminIncidents(); }

  Future<void> _resolve(Map<String, dynamic> row, {required bool dismissed}) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dismissed ? 'إغلاق البلاغ بدون إجراء' : 'تسجيل قرار المراجعة'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'قرار وملاحظات المراجعة',
            hintText: 'سجّل ما تم التحقق منه والإجراء المتخذ.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ القرار')),
        ],
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (ok != true) return;
    if (text.length < 3) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب قرار المراجعة.')));
      return;
    }
    try {
      await _repo.resolve('${row['id']}', dismissed: dismissed, resolution: text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ قرار مراجعة البلاغ.')));
      setState(_reload);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إغلاق البلاغ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بلاغات الخدمات')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('تعذر تحميل البلاغات. حاول مجددًا.'));
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text('لا توجد بلاغات خدمات مفتوحة الآن.', style: TextStyle(color: RuhamaaColors.textMuted)),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final row = rows[index];
                final type = '${row['incident_type']}';
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
                                labels[type] ?? type,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                            Chip(label: Text('${row['status']}')),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('${row['description']}', style: const TextStyle(height: 1.5)),
                        const SizedBox(height: 8),
                        Text(
                          'مرجع العملية: ${row['service_match_id']}',
                          style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 14),
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
              },
            ),
          );
        },
      ),
    );
  }
}
