import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/service_admin_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import '../services/service_catalog.dart';

class ServiceMatchingScreen extends StatelessWidget {
  const ServiceMatchingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: _ServiceAdminAppBar(),
        body: TabBarView(
          children: [
            _PendingOffersTab(),
            _OpenRequestsTab(),
            _AcceptedServicesTab(),
          ],
        ),
      ),
    );
  }
}

class _ServiceAdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ServiceAdminAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('الوقت والمهارات'),
      bottom: const TabBar(
        tabs: [
          Tab(text: 'العروض', icon: Icon(Icons.verified_user_outlined)),
          Tab(text: 'الطلبات', icon: Icon(Icons.hub_outlined)),
          Tab(text: 'التنسيق', icon: Icon(Icons.event_available_outlined)),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);
}

class _PendingOffersTab extends StatefulWidget {
  const _PendingOffersTab();

  @override
  State<_PendingOffersTab> createState() => _PendingOffersTabState();
}

class _PendingOffersTabState extends State<_PendingOffersTab> {
  late Future<List<Map<String, dynamic>>> _future;

  ServiceAdminRepository get _repo => ServiceAdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() { _future = _repo.pendingOffers(); }

  Future<void> _decide(String id, bool approve) async {
    try {
      if (approve) {
        await _repo.approveOffer(id);
      } else {
        await _repo.rejectOffer(id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'تم اعتماد عرض الوقت أو المهارة.' : 'تم رفض العرض.')),
      );
      setState(_reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث العرض: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل عروض المهارات. حاول مجددًا.'));
        }
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) {
          return const _AdminEmpty('لا توجد عروض وقت أو مهارة تنتظر المراجعة.');
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final row = rows[index];
              final category = serviceCategoryByKey('${row['category']}');
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: RuhamaaColors.softGreen,
                            foregroundColor: RuhamaaColors.primary,
                            child: Icon(category.icon),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${row['title']}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                                Text(
                                  '${category.label} • ${row['service_type']}',
                                  style: const TextStyle(color: RuhamaaColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Chip(label: Text(row['provider_kind'] == 'business' ? 'محل/جهة' : 'شخص')),
                        ],
                      ),
                      if (row['description'] != null) ...[
                        const SizedBox(height: 10),
                        Text('${row['description']}', style: const TextStyle(height: 1.45)),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        '${row['available_hours']} ساعة • ${row['pricing_mode'] == 'free' ? 'مجاني' : 'العمل مجاني والمواد فقط'}',
                        style: const TextStyle(
                          color: RuhamaaColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (row['availability_note'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'التوفر: ${row['availability_note']}',
                          style: const TextStyle(color: RuhamaaColors.textMuted),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _decide('${row['id']}', false),
                              child: const Text('رفض'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: () => _decide('${row['id']}', true),
                              icon: const Icon(Icons.verified_outlined),
                              label: const Text('اعتماد العرض'),
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
    );
  }
}

class _OpenRequestsTab extends StatefulWidget {
  const _OpenRequestsTab();

  @override
  State<_OpenRequestsTab> createState() => _OpenRequestsTabState();
}

class _OpenRequestsTabState extends State<_OpenRequestsTab> {
  late Future<List<Map<String, dynamic>>> _future;
  ServiceAdminRepository get _repo => ServiceAdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() { _future = _repo.openRequests(); }

  Future<void> _openCandidates(Map<String, dynamic> request) async {
    try {
      await _repo.markRequestReviewing('${request['id']}');
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => _CandidateSheet(request: request),
      );
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح المرشحين: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل طلبات الخدمات. حاول مجددًا.'));
        }
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) {
          return const _AdminEmpty('لا توجد طلبات خدمات مفتوحة الآن.');
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final row = rows[index];
              final category = serviceCategoryByKey('${row['category']}');
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: RuhamaaColors.warmGoldSoft,
                            foregroundColor: RuhamaaColors.warmGold,
                            child: Icon(category.icon),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${row['title']}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                                Text(
                                  '${category.label} • ${row['service_type']}',
                                  style: const TextStyle(color: RuhamaaColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('${row['details']}', style: const TextStyle(height: 1.45)),
                      const SizedBox(height: 8),
                      Text(
                        'الوقت المتوقع: ${row['estimated_hours'] ?? 'غير محدد'} • المواد: ${row['materials_available'] == true ? 'متوفرة' : 'تحتاج مراجعة'}',
                        style: const TextStyle(color: RuhamaaColors.textMuted),
                      ),
                      if (row['preferred_time_note'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'الوقت المناسب: ${row['preferred_time_note']}',
                          style: const TextStyle(color: RuhamaaColors.textMuted),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => _openCandidates(row),
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('ابحث عن مهارة مناسبة'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AcceptedServicesTab extends StatefulWidget {
  const _AcceptedServicesTab();

  @override
  State<_AcceptedServicesTab> createState() => _AcceptedServicesTabState();
}

class _AcceptedServicesTabState extends State<_AcceptedServicesTab> {
  late Future<List<Map<String, dynamic>>> _future;
  ServiceAdminRepository get _repo => ServiceAdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() { _future = _repo.acceptedMatches(); }

  Future<void> _schedule(Map<String, dynamic> row) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 180)),
      initialDate: row['scheduled_at'] == null
          ? now.add(const Duration(days: 1))
          : DateTime.tryParse('${row['scheduled_at']}')?.toLocal() ?? now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 16, minute: 0),
    );
    if (time == null || !mounted) return;
    final scheduled = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    try {
      await _repo.scheduleMatch(matchId: '${row['id']}', scheduledAt: scheduled);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ موعد الخدمة بعد موافقة الطرفين.')),
      );
      setState(_reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديد الموعد: $e')));
      }
    }
  }

  Future<void> _complete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد اكتمال الخدمة'),
        content: const Text('استخدم هذا الخيار بعد التأكد أن الخدمة نُفذت بالفعل.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تمت الخدمة')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.completeMatch(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إغلاق الخدمة كمكتملة.')),
      );
      setState(_reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إغلاق الخدمة: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل الخدمات المقبولة. حاول مجددًا.'));
        }
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) {
          return const _AdminEmpty('لا توجد خدمات وافق عليها الطرفان وتنتظر التنسيق.');
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final row = rows[index];
              final offer = Map<String, dynamic>.from(row['service_offers'] as Map);
              final request = Map<String, dynamic>.from(row['service_requests'] as Map);
              final category = serviceCategoryByKey('${request['category']}');
              final scheduledAt = row['scheduled_at'] == null
                  ? null
                  : DateTime.tryParse('${row['scheduled_at']}')?.toLocal();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: RuhamaaColors.softGreen,
                            foregroundColor: RuhamaaColors.primary,
                            child: Icon(category.icon),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${request['title']}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                                Text(
                                  '${offer['title']} • ${request['service_type']}',
                                  style: const TextStyle(color: RuhamaaColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          Icon(Icons.task_alt_rounded, color: RuhamaaColors.primary, size: 20),
                          SizedBox(width: 7),
                          Text('وافق مقدم الخدمة وصاحب الاحتياج', style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      if (scheduledAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'الموعد: ${MaterialLocalizations.of(context).formatMediumDate(scheduledAt)} • ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(scheduledAt))}',
                          style: const TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w800),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => _schedule(row),
                        icon: const Icon(Icons.event_outlined),
                        label: Text(scheduledAt == null ? 'تحديد موعد الخدمة' : 'تعديل الموعد'),
                      ),
                      if (scheduledAt != null) ...[
                        const SizedBox(height: 9),
                        OutlinedButton.icon(
                          onPressed: () => _complete('${row['id']}'),
                          icon: const Icon(Icons.done_all_rounded),
                          label: const Text('تأكيد اكتمال الخدمة'),
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
    );
  }
}

class _CandidateSheet extends StatefulWidget {
  const _CandidateSheet({required this.request});
  final Map<String, dynamic> request;

  @override
  State<_CandidateSheet> createState() => _CandidateSheetState();
}

class _CandidateSheetState extends State<_CandidateSheet> {
  late Future<List<Map<String, dynamic>>> _future;
  ServiceAdminRepository get _repo => ServiceAdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _repo.candidates('${widget.request['id']}');
  }

  Future<void> _match(Map<String, dynamic> candidate) async {
    try {
      await _repo.createMatch(
        requestId: '${widget.request['id']}',
        offerId: '${candidate['offer_id']}',
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال مطابقة خدمة خاصة للطرفين. لن يُحدد موعد حتى يوافق كلاهما.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء المطابقة: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, controller) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('تعذر تحميل المرشحين. حاول مجددًا.'));
          }
          final candidates = snapshot.data ?? const [];
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: RuhamaaColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'مرشحون لـ «${widget.request['title']}»',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'الترتيب يعتمد على تطابق نوع الخدمة والمنطقة والوقت المتاح، ولا يستخدم المساهمات المالية أو سجل ما قدمه الشخص من عطاء.',
                style: TextStyle(color: RuhamaaColors.textMuted, height: 1.45),
              ),
              const SizedBox(height: 16),
              if (candidates.isEmpty)
                const _AdminEmpty('لا يوجد مقدم خدمة معتمد مناسب حاليًا. يبقى الطلب مفتوحًا للمراجعة.')
              else
                ...candidates.map((candidate) {
                  final category = serviceCategoryByKey('${candidate['category']}');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(category.icon, color: RuhamaaColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${candidate['title']}',
                                    style: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                Chip(label: Text('ملاءمة ${candidate['score']}')),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${candidate['service_type']} • ${candidate['available_hours']} ساعة',
                              style: const TextStyle(color: RuhamaaColors.textMuted),
                            ),
                            const SizedBox(height: 10),
                            FilledButton(
                              onPressed: () => _match(candidate),
                              child: const Text('إرسال المطابقة للطرفين'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _AdminEmpty extends StatelessWidget {
  const _AdminEmpty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
          ),
        ),
      );
}
