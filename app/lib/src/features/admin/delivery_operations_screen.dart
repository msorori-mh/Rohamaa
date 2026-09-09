import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/admin_repository.dart';
import '../../domain/delivery_dispatch_rules.dart';
import 'delivery_assignment_screen.dart';

class DeliveryOperationsScreen extends StatefulWidget {
  const DeliveryOperationsScreen({super.key});

  @override
  State<DeliveryOperationsScreen> createState() => _DeliveryOperationsScreenState();
}

class _DeliveryOperationsScreenState extends State<DeliveryOperationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = AdminRepository(Supabase.instance.client).deliveryDispatchQueue();

  Future<void> _reassign(String deliveryId) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DeliveryAssignmentScreen(deliveryId: deliveryId)),
    );
    if (changed == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('متابعة التوصيل')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return const Center(child: Text('تعذر تحميل مهام التوصيل. تحقق من اتصالك وحاول مجددًا.'));
            final rows = snapshot.data ?? const [];
            if (rows.isEmpty) return const Center(child: Text('لا توجد مهام توصيل جارية.'));
            return RefreshIndicator(
              onRefresh: () async => setState(_reload),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final status = '${row['status']}';
                  final courier = row['courier_name'] as String?;
                  final attempt = row['dispatch_attempt'] as int? ?? 1;
                  final canReassign = const {'assigned', 'failed', 'rescheduled'}.contains(status);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${row['public_code']}', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text('الحالة: ${DeliveryDispatchRules.statusLabel(status)}'),
                          Text(courier == null ? 'لا يوجد موصل حاليًا' : 'الموصل: $courier'),
                          Text('محاولة الإسناد: $attempt'),
                          if (row['rejection_reason'] != null) Text('سبب الاعتذار: ${_reasonLabel('${row['rejection_reason']}')}'),
                          if (canReassign) ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => _reassign('${row['delivery_id']}'),
                              icon: const Icon(Icons.swap_horiz_rounded),
                              label: Text(status == 'assigned' ? 'تغيير الموصل' : 'إعادة إسناد المهمة'),
                            ),
                          ],
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

  static String _reasonLabel(String reason) => switch (reason) {
        'unavailable' => 'غير متاح الآن',
        'too_far' => 'الموقع بعيد',
        'vehicle_issue' => 'مشكلة في وسيلة النقل',
        'schedule_conflict' => 'تعارض في الوقت',
        _ => 'سبب آخر',
      };
}
