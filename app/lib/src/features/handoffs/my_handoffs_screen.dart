import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/handoff_repository.dart';
import '../../theme/ruhamaa_theme.dart';

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
      handoff.kind == 'pickup' ? 'استلام العطاء منك' : 'تسليم العطاء إليك';

  String _statusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'يجري ترتيب الاستلام';
      case 'heading_to_pickup':
        return 'الموصل في طريقه للاستلام';
      case 'picked_up':
        return 'تم استلام العطاء';
      case 'heading_to_recipient':
        return 'العطاء في الطريق للتسليم';
      case 'delivered':
        return 'تم التسليم بنجاح';
      case 'rescheduled':
        return 'تمت إعادة جدولة الموعد';
      case 'failed':
        return 'تحتاج العملية إلى إعادة تنسيق';
      default:
        return 'العملية قيد المتابعة';
    }
  }

  int _progressRank(String status) {
    switch (status) {
      case 'assigned':
      case 'rescheduled':
        return 1;
      case 'heading_to_pickup':
        return 2;
      case 'picked_up':
        return 3;
      case 'heading_to_recipient':
        return 4;
      case 'delivered':
        return 5;
      default:
        return 1;
    }
  }

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
              const Text(
                'أعطِ هذا الرمز لموصل رحماء فقط عند وصوله إليك.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SelectableText(
                pin,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: RuhamaaColors.primaryDark,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                    ),
              ),
              const SizedBox(height: 12),
              const Text(
                'إن أعدت توليد الرمز، يصبح الرمز السابق غير صالح.',
                textAlign: TextAlign.center,
                style: TextStyle(color: RuhamaaColors.textMuted),
              ),
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
            return const _EmptyHandoffs();
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final handoff = rows[index];
                final progress = _progressRank(handoff.status);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                color: RuhamaaColors.softGreen,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                handoff.kind == 'pickup'
                                    ? Icons.inventory_2_outlined
                                    : Icons.local_shipping_outlined,
                                color: RuhamaaColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    handoff.itemType,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: RuhamaaColors.primaryDark,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(_kindLabel(handoff), style: const TextStyle(color: RuhamaaColors.textMuted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: RuhamaaColors.warmGoldSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timelapse_rounded, color: RuhamaaColors.warmGold, size: 21),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _statusLabel(handoff.status),
                                  style: const TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _JourneyTimeline(progress: progress),
                        const SizedBox(height: 14),
                        Text(
                          'رمز العملية: ${handoff.deliveryCode}',
                          style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 12),
                        ),
                        if (_pinAvailable(handoff)) ...[
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: () => _showPin(handoff),
                            icon: const Icon(Icons.pin_outlined),
                            label: Text(
                              handoff.kind == 'pickup'
                                  ? 'إظهار رمز الاستلام'
                                  : 'إظهار رمز التسليم',
                            ),
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

class _JourneyTimeline extends StatelessWidget {
  const _JourneyTimeline({required this.progress});

  final int progress;

  static const steps = [
    ('تم قبول المطابقة', Icons.check_circle_outline_rounded),
    ('يجري ترتيب الاستلام', Icons.schedule_rounded),
    ('استلم الموصل العطاء', Icons.inventory_2_outlined),
    ('في الطريق للتسليم', Icons.local_shipping_outlined),
    ('تم التسليم', Icons.favorite_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (index) {
        final done = index + 1 <= progress;
        final current = index + 1 == progress;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: done ? RuhamaaColors.primary : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done ? RuhamaaColors.primary : RuhamaaColors.border,
                      ),
                    ),
                    child: Icon(
                      steps[index].$2,
                      size: 16,
                      color: done ? Colors.white : RuhamaaColors.textMuted,
                    ),
                  ),
                  if (index < steps.length - 1)
                    Container(
                      width: 2,
                      height: 24,
                      color: done && index + 1 < progress
                          ? RuhamaaColors.primary
                          : RuhamaaColors.border,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 19),
                child: Text(
                  steps[index].$1,
                  style: TextStyle(
                    color: current || done ? RuhamaaColors.primaryDark : RuhamaaColors.textMuted,
                    fontWeight: current ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _EmptyHandoffs extends StatelessWidget {
  const _EmptyHandoffs();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 94,
              height: 94,
              decoration: const BoxDecoration(color: RuhamaaColors.softGreen, shape: BoxShape.circle),
              child: const Icon(Icons.local_shipping_outlined, size: 48, color: RuhamaaColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              'لا توجد عملية توصيل الآن',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: RuhamaaColors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'عند قبول مطابقة وترتيب الاستلام أو التسليم، ستظهر رحلتها هنا خطوة بخطوة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
