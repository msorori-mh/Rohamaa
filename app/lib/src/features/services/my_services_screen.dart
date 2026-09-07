import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/service_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import 'service_catalog.dart';

class MyServicesScreen extends StatelessWidget {
  const MyServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('وقتي ومهاراتي'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'ما أقدّمه', icon: Icon(Icons.handyman_outlined)),
              Tab(text: 'ما أحتاجه', icon: Icon(Icons.support_agent_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MyOffersList(),
            _MyRequestsList(),
          ],
        ),
      ),
    );
  }
}

class _MyOffersList extends StatefulWidget {
  const _MyOffersList();

  @override
  State<_MyOffersList> createState() => _MyOffersListState();
}

class _MyOffersListState extends State<_MyOffersList> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ServiceRepository(Supabase.instance.client).myServiceOffers();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('تعذر تحميل ما تقدمه: ${snapshot.error}'));
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) {
          return const _EmptyState(
            icon: Icons.handyman_outlined,
            title: 'لم تسجل وقتًا أو مهارة بعد',
            subtitle: 'يمكنك تقديم ساعات من وقتك أو خدمة مجانية عندما تكون قادرًا على ذلك.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final row = rows[index];
              final category = serviceCategoryByKey('${row['category']}');
              final status = _offerStatus('${row['status']}', '${row['verification_status']}');
              final hours = row['available_hours'];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  leading: CircleAvatar(
                    backgroundColor: RuhamaaColors.softGreen,
                    foregroundColor: RuhamaaColors.primary,
                    child: Icon(category.icon),
                  ),
                  title: Text('${row['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text('${category.label} • ${row['service_type']}\n$hours ساعة • $status'),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MyRequestsList extends StatefulWidget {
  const _MyRequestsList();

  @override
  State<_MyRequestsList> createState() => _MyRequestsListState();
}

class _MyRequestsListState extends State<_MyRequestsList> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ServiceRepository(Supabase.instance.client).myServiceRequests();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('تعذر تحميل احتياجات الخدمة: ${snapshot.error}'));
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) {
          return const _EmptyState(
            icon: Icons.support_agent_outlined,
            title: 'لا يوجد طلب خدمة مسجل',
            subtitle: 'إذا احتجت سباكة أو كهرباء أو صيانة أو أي مهارة أخرى، سجّلها من الرئيسية.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final row = rows[index];
              final category = serviceCategoryByKey('${row['category']}');
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  leading: CircleAvatar(
                    backgroundColor: RuhamaaColors.warmGoldSoft,
                    foregroundColor: RuhamaaColors.warmGold,
                    child: Icon(category.icon),
                  ),
                  title: Text('${row['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text('${category.label} • ${row['service_type']}\n${_requestStatus('${row['status']}')}'),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

String _offerStatus(String status, String verification) {
  if (verification == 'pending') return 'قيد مراجعة رحماء';
  if (verification == 'rejected') return 'يحتاج مراجعة أو تعديل';
  switch (status) {
    case 'approved':
      return 'متاح للمطابقة';
    case 'matched':
      return 'تم العثور على احتياج مناسب';
    case 'completed':
      return 'اكتملت الخدمة';
    case 'paused':
      return 'متوقف مؤقتًا';
    case 'cancelled':
      return 'ملغي';
    default:
      return 'قيد المراجعة';
  }
}

String _requestStatus(String status) {
  switch (status) {
    case 'reviewing':
      return 'يراجع رحماء الاحتياج';
    case 'matched':
      return 'تم العثور على مهارة مناسبة';
    case 'scheduled':
      return 'تم ترتيب الموعد';
    case 'completed':
      return 'اكتملت الخدمة';
    case 'rejected':
      return 'يحتاج الطلب إلى مراجعة';
    case 'cancelled':
      return 'ملغي';
    default:
      return 'تم التسجيل ويجري البحث';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(color: RuhamaaColors.softGreen, shape: BoxShape.circle),
              child: Icon(icon, size: 45, color: RuhamaaColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: RuhamaaColors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
