import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/admin_repository.dart';
import 'delivery_assignment_screen.dart';

class AcceptedMatchesScreen extends StatefulWidget {
  const AcceptedMatchesScreen({super.key});

  @override
  State<AcceptedMatchesScreen> createState() => _AcceptedMatchesScreenState();
}

class _AcceptedMatchesScreenState extends State<AcceptedMatchesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = AdminRepository(Supabase.instance.client).acceptedMatchesAwaitingDelivery();
  }

  Future<void> _assign(String matchId) async {
    final assigned = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DeliveryAssignmentScreen(matchId: matchId)),
    );
    if (!mounted) return;
    if (assigned == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إسناد عملية التوصيل.')));
      setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مطابقات جاهزة للتوصيل')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('تعذر تحميل المطابقات. حاول مجددًا.'));
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) return const Center(child: Text('لا توجد مطابقات مقبولة بانتظار الإسناد.'));
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = rows[index];
                return Card(
                  child: ListTile(
                    title: Text('${row['item_type']}'),
                    subtitle: Text('${row['donation_code']} • ${row['need_code']}'),
                    trailing: FilledButton(
                      onPressed: () => _assign(row['match_id'] as String),
                      child: const Text('إسناد'),
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
