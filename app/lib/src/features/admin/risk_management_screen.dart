import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/admin_repository.dart';

class RiskManagementScreen extends StatefulWidget {
  const RiskManagementScreen({super.key});

  @override
  State<RiskManagementScreen> createState() => _RiskManagementScreenState();
}

class _RiskManagementScreenState extends State<RiskManagementScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = AdminRepository(Supabase.instance.client).riskQueue();
  }

  Future<void> _resolve(Map<String, dynamic> risk) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إغلاق إشارة الخطر'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'نتيجة المراجعة',
            hintText: 'مثال: تم التواصل وتبين أن الطلب مشروع، أو تم اتخاذ إجراء مناسب.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إغلاق وتوثيق')),
        ],
      ),
    );
    final resolution = controller.text.trim();
    controller.dispose();
    if (confirmed != true || resolution.length < 3) return;
    try {
      await AdminRepository(Supabase.instance.client).resolveRisk(risk['id'] as String, resolution);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إغلاق الإشارة وتوثيق القرار.')));
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إغلاق الإشارة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة المخاطر')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('تعذر تحميل المخاطر: ${snapshot.error}'));
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) return const Center(child: Text('لا توجد إشارات خطر مفتوحة.'));
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final risk = rows[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_outlined),
                            const SizedBox(width: 10),
                            Expanded(child: Text('${risk['rule_code']}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                            Text('${risk['severity']}'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('${risk['details']}'),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: () => _resolve(risk), child: const Text('تسجيل نتيجة المراجعة وإغلاق الإشارة')),
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
