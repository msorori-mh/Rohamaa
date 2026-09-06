import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/handoff_repository.dart';

class MyHandoffsScreen extends StatefulWidget {
  const MyHandoffsScreen({super.key});

  @override
  State<MyHandoffsScreen> createState() => _MyHandoffsScreenState();
}

class _MyHandoffsScreenState extends State<MyHandoffsScreen> {
  late Future<List<UserHandoff>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = HandoffRepository(Supabase.instance.client).myHandoffs();
  }

  bool _pinAvailable(UserHandoff handoff) {
    if (handoff.kind == 'pickup') {
      return ['assigned', 'heading_to_pickup', 'rescheduled'].contains(handoff.status);
    }
    return ['picked_up', 'heading_to_recipient', 'rescheduled'].contains(handoff.status);
  }

  String _kindLabel(UserHandoff handoff) =>
      handoff.kind == 'pickup' ? 'استلام التبرع منك' : 'تسليم التبرع لك';

  Future<void> _showPin(UserHandoff handoff) async {
    try {
      final pin = await HandoffRepository(Supabase.instance.client).issuePin(
        deliveryId: handoff.deliveryId,
        kind: handoff.kind,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(handoff.kind == 'pickup' ? 'رمز الاستلام' : 'رمز التسليم'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('أعطِ هذا الرمز لمندوب سند فقط عند وصوله إليك.'),
              const SizedBox(height: 18),
              SelectableText(
                pin,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 10,
                    ),
              ),
              const SizedBox(height: 12),
              const Text('إن أعدت توليد الرمز، يصبح الرمز السابق غير صالح.'),
            ],
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء الرمز: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عملياتي')),
      body: FutureBuilder<List<UserHandoff>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('تعذر تحميل العمليات: ${snapshot.error}'));
          }
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) {
            return const Center(child: Text('لا توجد لديك عمليات استلام أو تسليم حتى الآن.'));
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final handoff = rows[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(handoff.itemType, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(_kindLabel(handoff)),
                        Text('الحالة: ${handoff.status}'),
                        Text('العملية: ${handoff.deliveryCode}', style: Theme.of(context).textTheme.bodySmall),
                        if (_pinAvailable(handoff)) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => _showPin(handoff),
                            icon: const Icon(Icons.pin_outlined),
                            label: Text(handoff.kind == 'pickup' ? 'إظهار رمز الاستلام' : 'إظهار رمز التسليم'),
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
  }
}
