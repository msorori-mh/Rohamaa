import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/admin_repository.dart';
import 'delivery_assignment_screen.dart';
import 'staff_widgets.dart';

class AcceptedMatchesScreen extends StatefulWidget {
  const AcceptedMatchesScreen({super.key});

  @override
  State<AcceptedMatchesScreen> createState() => _AcceptedMatchesScreenState();
}

class _AcceptedMatchesScreenState extends State<AcceptedMatchesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  AdminRepository get _repo => AdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _repo.acceptedMatchesAwaitingDelivery();
  }

  Future<void> _refresh() async {
    final next = _repo.acceptedMatchesAwaitingDelivery();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  Future<void> _assign(String matchId) async {
    final assigned = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryAssignmentScreen(matchId: matchId),
      ),
    );
    if (!mounted) return;
    if (assigned == true) {
      showInfoSnack(context, 'تم إسناد عملية التوصيل.');
    }
    // Refresh either way: the match may have been assigned by someone else.
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مطابقات جاهزة للتوصيل')),
      body: RefreshableFuture<List<Map<String, dynamic>>>(
        future: _future,
        onRefresh: _refresh,
        isEmpty: (rows) => rows.isEmpty,
        emptyText: 'لا توجد مطابقات مقبولة بانتظار الإسناد.',
        builder: (context, rows) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final row = rows[index];
            return Card(
              child: ListTile(
                title: Text('${row['item_type']}'),
                subtitle: Text(
                  'تبرع ${row['donation_code']} • طلب ${row['need_code']}',
                ),
                trailing: FilledButton(
                  onPressed: () => _assign('${row['match_id']}'),
                  child: const Text('إسناد'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
