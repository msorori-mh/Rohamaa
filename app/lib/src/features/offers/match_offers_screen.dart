import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/match_offer_repository.dart';
import '../../theme/ruhamaa_theme.dart';

class MatchOffersScreen extends StatefulWidget {
  const MatchOffersScreen({super.key});

  @override
  State<MatchOffersScreen> createState() => _MatchOffersScreenState();
}

class _MatchOffersScreenState extends State<MatchOffersScreen> {
  late Future<List<MatchOffer>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = MatchOfferRepository(Supabase.instance.client).pendingOffers();
  }

  String _conditionLabel(String? value) {
    switch (value) {
      case 'new':
        return 'جديد';
      case 'excellent':
        return 'ممتاز';
      case 'good':
        return 'جيد';
      case 'minor_repair':
        return 'يحتاج إصلاحًا بسيطًا';
      default:
        return value == null || value.isEmpty ? 'غير محددة' : value;
    }
  }

  Future<void> _respond(MatchOffer offer, bool accept) async {
    try {
      await MatchOfferRepository(Supabase.instance.client).respond(
        offer.matchId,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'تم قبول المطابقة. سيبدأ رحماء ترتيب الاستلام والتوصيل.'
                : 'تم تحديث احتياجك وسيستمر البحث عن بديل مناسب.',
          ),
        ),
      );
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث العرض: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عروض المطابقة')),
      body: FutureBuilder<List<MatchOffer>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('تعذر تحميل العروض: ${snapshot.error}'));
          }
          final offers = snapshot.data ?? const [];
          if (offers.isEmpty) {
            return const _EmptyOffers();
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final offer = offers[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [RuhamaaColors.softGreen, RuhamaaColors.warmGoldSoft],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                          ),
                          child: const Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(right: 28, child: Icon(Icons.front_hand_rounded, size: 58, color: RuhamaaColors.primary)),
                              Positioned(left: 28, child: Icon(Icons.volunteer_activism_rounded, size: 58, color: RuhamaaColors.warmGold)),
                              Icon(Icons.favorite_rounded, size: 40, color: Colors.white),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'وجدنا شيئًا يناسب احتياجك ✨',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: RuhamaaColors.primaryDark,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: RuhamaaColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, color: RuhamaaColors.primary, size: 34),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(offer.itemType, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 3),
                                    Text(
                                      'الحالة: ${_conditionLabel(offer.condition)}',
                                      style: const TextStyle(color: RuhamaaColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: RuhamaaColors.softGreen,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lock_outline_rounded, color: RuhamaaColors.primary),
                              SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'هوية المتبرع تبقى خاصة، وهويتك لا تظهر له.',
                                  style: TextStyle(color: RuhamaaColors.primaryDark, height: 1.45, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => _respond(offer, true),
                          child: const Text('نعم، ما زلت أحتاجه'),
                        ),
                        const SizedBox(height: 9),
                        OutlinedButton(
                          onPressed: () => _respond(offer, false),
                          child: const Text('لم أعد أحتاجه'),
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

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers();

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
              child: const Icon(Icons.search_rounded, color: RuhamaaColors.primary, size: 48),
            ),
            const SizedBox(height: 18),
            Text(
              'لا يوجد عرض جديد الآن',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: RuhamaaColors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'إذا كان لديك احتياج مسجل، يستمر رحماء في البحث عن تطابق مناسب وسنظهره لك هنا عند توفره.',
              textAlign: TextAlign.center,
              style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
