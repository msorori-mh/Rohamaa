import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/delivery_repository.dart';

class CourierTasksScreen extends StatefulWidget {
  const CourierTasksScreen({super.key});

  @override
  State<CourierTasksScreen> createState() => _CourierTasksScreenState();
}

class _CourierTasksScreenState extends State<CourierTasksScreen> {
  late Future<List<DeliveryTask>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = DeliveryRepository(Supabase.instance.client).myTasks();
  }

  Future<void> _openPin(DeliveryTask task) async {
    final isPickup = task.status == 'assigned' || task.status == 'heading_to_pickup';
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPickup ? 'رمز الاستلام' : 'رمز التسليم'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(labelText: 'PIN من 4 أرقام'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final ok = await DeliveryRepository(Supabase.instance.client).verifyPin(
                deliveryId: task.id,
                pin: controller.text.trim(),
                kind: isPickup ? 'pickup' : 'delivery',
              );
              if (!context.mounted) return;
              Navigator.pop(context, ok);
            },
            child: const Text('تحقق'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isPickup ? 'تم تأكيد الاستلام' : 'تم تأكيد التسليم')),
      );
      setState(_reload);
    } else if (result == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرمز غير صحيح أو تعذر التحقق')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مهام التوصيل')),
      body: FutureBuilder<List<DeliveryTask>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('تعذر تحميل المهام: ${snapshot.error}'));
          }
          final tasks = snapshot.data ?? const [];
          if (tasks.isEmpty) return const Center(child: Text('لا توجد مهام حالياً'));
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Card(
                  child: ListTile(
                    title: Text(task.publicCode),
                    subtitle: Text(task.status),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => _openPin(task),
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
