import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/match_offer_repository.dart';

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

  Future<void> _respond(MatchOffer offer, bool accept) async {
    try {
      await MatchOfferRepository(Supabase.instance.client).respond(
        offer.matchId,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'تم قبول المطابقة وسيتم ترتيب التوصيل.' : 'تم رفض المطابقة وسيستمر البحث عن بديل.')),
      );
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث العرض: $e')));
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
          if (snapshot.hasError) return Center(child: Text('تعذر تحميل العروض: ${snapshot.error}'));
          final offers = snapshot.data ?? const [];
          if (offers.isEmpty) return const Center(child: Text('لا توجد عروض مطابقة بانتظار ردك.'));
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final offer = offers[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('وجد سند شيئًا مطابقًا لاحتياجك', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(offer.itemType),
                        Text('الحالة: ${offer.condition ?? 'غير محددة'}'),
                        const SizedBox(height: 8),
                        const Text('لن تظهر لك هوية المتبرع، ولن تظهر هويتك له.'),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: () => _respond(offer, false), child: const Text('لم أعد أحتاجه'))),
                            const SizedBox(width: 10),
                            Expanded(child: FilledButton(onPressed: () => _respond(offer, true), child: const Text('ما زلت أحتاجه'))),
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
      ),
    );
  }
}
