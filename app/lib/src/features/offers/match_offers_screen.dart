import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/match_offer_repository.dart';
import '../../data/service_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import '../services/service_catalog.dart';

class MatchOffersScreen extends StatelessWidget {
  const MatchOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _MatchAppBar(),
        body: TabBarView(
          children: [
            _ItemOffersTab(),
            _ServiceOffersTab(),
          ],
        ),
      ),
    );
  }
}

class _MatchAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _MatchAppBar();

  @override
  Widget build(BuildContext context) => AppBar(
        title: const Text('العروض المناسبة'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'الأشياء', icon: Icon(Icons.inventory_2_outlined)),
            Tab(text: 'الخدمات', icon: Icon(Icons.handyman_outlined)),
          ],
        ),
      );

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);
}

class _ItemOffersTab extends StatefulWidget {
  const _ItemOffersTab();

  @override
  State<_ItemOffersTab> createState() => _ItemOffersTabState();
}

class _ItemOffersTabState extends State<_ItemOffersTab> {
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
                ? 'تم قبول العرض. سنرتب الاستلام والتسليم.'
                : 'تم رفض العرض، وسنواصل البحث عن بديل.',
          ),
        ),
      );
      setState(_reload);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث العرض. تحقق من اتصالك وحاول مرة أخرى.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MatchOffer>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل العروض. تحقق من اتصالك وحاول مجددًا.'));
        }
        final offers = snapshot.data ?? const [];
        if (offers.isEmpty) {
          return const _EmptyOffers(
            icon: Icons.inventory_2_outlined,
            title: 'لا توجد عروض جديدة',
            subtitle: 'سنخبرك هنا عندما نجد شيئًا مناسبًا لطلبك.',
          );
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
                      const _PrivacyBox(
                        text: 'بياناتك وبيانات المتبرع خاصة.',
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
    );
  }
}

class _ServiceOffersTab extends StatefulWidget {
  const _ServiceOffersTab();

  @override
  State<_ServiceOffersTab> createState() => _ServiceOffersTabState();
}

class _ServiceOffersTabState extends State<_ServiceOffersTab> {
  late Future<List<ServiceMatchOffer>> _future;

  ServiceRepository get _repo => ServiceRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _repo.pendingServiceMatches();
  }

  Future<void> _respond(ServiceMatchOffer offer, bool accept) async {
    try {
      final state = await _repo.respondServiceMatch(offer.matchId, accept: accept);
      if (!mounted) return;
      final message = !accept
          ? 'تم رفض العرض، وسنواصل البحث عن بديل.'
          : state == 'accepted'
              ? 'وافق الطرفان. سنرتب الموعد ونشارك المعلومات الضرورية فقط.'
              : 'تم تسجيل موافقتك، وننتظر رد الطرف الآخر.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      setState(_reload);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديث العرض. تحقق من اتصالك وحاول مرة أخرى.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceMatchOffer>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل عروض الخدمات. تحقق من اتصالك وحاول مجددًا.'));
        }
        final offers = snapshot.data ?? const [];
        if (offers.isEmpty) {
          return const _EmptyOffers(
            icon: Icons.handyman_outlined,
            title: 'لا توجد عروض خدمات جديدة',
            subtitle: 'سنخبرك هنا عندما نجد خدمة أو طلبًا مناسبًا.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: offers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) => _ServiceMatchCard(
              offer: offers[index],
              onRespond: _respond,
            ),
          ),
        );
      },
    );
  }
}

class _ServiceMatchCard extends StatelessWidget {
  const _ServiceMatchCard({required this.offer, required this.onRespond});

  final ServiceMatchOffer offer;
  final Future<void> Function(ServiceMatchOffer offer, bool accept) onRespond;

  @override
  Widget build(BuildContext context) {
    final category = serviceCategoryByKey(offer.category);
    final provider = offer.mySide == 'provider';
    final awaitingMe = offer.myResponse == 'pending' && offer.status == 'proposed';
    final bothAccepted = offer.status == 'accepted' || offer.status == 'scheduled';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: provider ? RuhamaaColors.softGreen : RuhamaaColors.warmGoldSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    foregroundColor: provider ? RuhamaaColors.primary : RuhamaaColors.warmGold,
                    child: Icon(category.icon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider
                              ? 'وجد رحماء احتياجًا يناسب مهارتك'
                              : 'وجد رحماء وقتًا أو مهارة تناسب احتياجك',
                          style: const TextStyle(
                            color: RuhamaaColors.primaryDark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${category.label} • ${offer.serviceType}',
                          style: const TextStyle(color: RuhamaaColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              offer.serviceTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: RuhamaaColors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            _PrivacyBox(
              text: provider
                  ? 'بعد موافقة الطرفين، نشارك المعلومات الضرورية لتنفيذ الخدمة فقط.'
                  : 'بعد موافقة الطرفين، نشارك المعلومات الضرورية لترتيب الموعد فقط.',
            ),
            const SizedBox(height: 14),
            if (bothAccepted)
              _StatusBox(
                icon: Icons.task_alt_rounded,
                text: offer.status == 'scheduled'
                    ? 'وافق الطرفان وتم ترتيب الموعد.'
                    : 'وافق الطرفان. سيكمل رحماء تنسيق الموعد.',
              )
            else if (awaitingMe) ...[
              FilledButton(
                onPressed: () => onRespond(offer, true),
                child: Text(provider ? 'نعم، ما زلت أستطيع تقديمها' : 'نعم، ما زلت أحتاجها'),
              ),
              const SizedBox(height: 9),
              OutlinedButton(
                onPressed: () => onRespond(offer, false),
                child: Text(provider ? 'لست متاحًا لهذه المطابقة' : 'لم أعد أحتاج هذه الخدمة'),
              ),
            ] else
              const _StatusBox(
                icon: Icons.hourglass_top_rounded,
                text: 'وافقت على العرض، وننتظر رد الطرف الآخر.',
              ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyBox extends StatelessWidget {
  const _PrivacyBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RuhamaaColors.softGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline_rounded, color: RuhamaaColors.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: RuhamaaColors.primaryDark,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RuhamaaColors.warmGoldSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: RuhamaaColors.warmGold),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: RuhamaaColors.primaryDark,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
}

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers({required this.icon, required this.title, required this.subtitle});

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
              width: 94,
              height: 94,
              decoration: const BoxDecoration(color: RuhamaaColors.softGreen, shape: BoxShape.circle),
              child: Icon(icon, color: RuhamaaColors.primary, size: 48),
            ),
            const SizedBox(height: 18),
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
