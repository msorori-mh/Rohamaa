import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../core/main_tab_signal.dart';
import '../../data/match_offer_repository.dart';
import '../../data/service_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import '../items/async_list_loader.dart';
import '../items/form_guards.dart';
import '../services/service_catalog.dart';

class MatchOffersScreen extends StatefulWidget {
  /// [initialTab]: 0 opens the items tab, 1 opens the services tab.
  const MatchOffersScreen({super.key, this.initialTab = 0, this.tabRequestId});

  final int initialTab;

  /// Changes whenever a caller asks for [initialTab] again (the `t` query
  /// parameter), so the same tab can be requested twice in a row.
  final String? tabRequestId;

  @override
  State<MatchOffersScreen> createState() => _MatchOffersScreenState();
}

class _MatchOffersScreenState extends State<MatchOffersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  int get _requestedTab => widget.initialTab.clamp(0, 1).toInt();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: _requestedTab);
  }

  @override
  void didUpdateWidget(covariant MatchOffersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final requestChanged = oldWidget.initialTab != widget.initialTab ||
        oldWidget.tabRequestId != widget.tabRequestId;
    if (requestChanged && _tabs.index != _requestedTab) {
      _tabs.animateTo(_requestedTab);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العروض المناسبة'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'الأشياء', icon: Icon(Icons.inventory_2_outlined)),
            Tab(text: 'الخدمات', icon: Icon(Icons.handyman_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ItemOffersTab(),
          _ServiceOffersTab(),
        ],
      ),
    );
  }
}

class _ItemOffersTab extends StatefulWidget {
  const _ItemOffersTab();

  @override
  State<_ItemOffersTab> createState() => _ItemOffersTabState();
}

class _ItemOffersTabState extends State<_ItemOffersTab>
    with
        AutomaticKeepAliveClientMixin<_ItemOffersTab>,
        AsyncListLoader<_ItemOffersTab, MatchOffer> {
  final Set<String> _busy = <String>{};

  MatchOfferRepository get _repo => MatchOfferRepository(Supabase.instance.client);

  @override
  bool get wantKeepAlive => true;

  @override
  Future<List<MatchOffer>> fetchRows() => _repo.pendingOffers();

  @override
  void initState() {
    super.initState();
    MainTabs.active.addListener(_onMainTabChanged);
    reloadRows();
  }

  @override
  void dispose() {
    MainTabs.active.removeListener(_onMainTabChanged);
    super.dispose();
  }

  /// The offers tab keeps its state while hidden, so reload when it is shown
  /// again. Skipped while the first load is still running.
  void _onMainTabChanged() {
    if (MainTabs.active.value != MainTabs.offers) return;
    if (loadedRows == null && loadError == null) return;
    reloadRows();
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
        return 'غير محددة';
    }
  }

  Future<void> _respond(MatchOffer offer, bool accept) async {
    if (_busy.contains(offer.matchId)) return;
    if (!accept) {
      final confirmed = await confirmAction(
        context,
        title: 'رفض هذا العرض؟',
        message: 'لن يُحجز لك هذا الشيء بعد الرفض، وسنواصل البحث عن بديل مناسب.',
        confirmLabel: 'نعم، لم أعد أحتاجه',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _busy.add(offer.matchId));
    try {
      await _repo.respond(offer.matchId, accept: accept);
      if (mounted) {
        showInfoSnack(
          context,
          accept
              ? 'تم قبول العرض. سنرتب الاستلام والتسليم.'
              : 'تم رفض العرض، وسنواصل البحث عن بديل.',
        );
      }
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    }
    await reloadRows();
    if (mounted) setState(() => _busy.remove(offer.matchId));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return buildAsyncList(
      empty: const _EmptyOffers(
        icon: Icons.inventory_2_outlined,
        title: 'لا توجد عروض جديدة',
        subtitle: 'سنخبرك هنا عندما نجد شيئًا مناسبًا لطلبك.',
      ),
      builder: (offers) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: offers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final offer = offers[index];
          final busy = _busy.contains(offer.matchId);
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
                    onPressed: busy ? null : () => _respond(offer, true),
                    child: Text(busy ? 'جارٍ الإرسال...' : 'نعم، ما زلت أحتاجه'),
                  ),
                  const SizedBox(height: 9),
                  OutlinedButton(
                    onPressed: busy ? null : () => _respond(offer, false),
                    child: const Text('لم أعد أحتاجه'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ServiceOffersTab extends StatefulWidget {
  const _ServiceOffersTab();

  @override
  State<_ServiceOffersTab> createState() => _ServiceOffersTabState();
}

class _ServiceOffersTabState extends State<_ServiceOffersTab>
    with
        AutomaticKeepAliveClientMixin<_ServiceOffersTab>,
        AsyncListLoader<_ServiceOffersTab, ServiceMatchOffer> {
  final Set<String> _busy = <String>{};

  ServiceRepository get _repo => ServiceRepository(Supabase.instance.client);

  @override
  bool get wantKeepAlive => true;

  @override
  Future<List<ServiceMatchOffer>> fetchRows() => _repo.pendingServiceMatches();

  @override
  void initState() {
    super.initState();
    MainTabs.active.addListener(_onMainTabChanged);
    reloadRows();
  }

  @override
  void dispose() {
    MainTabs.active.removeListener(_onMainTabChanged);
    super.dispose();
  }

  /// The offers tab keeps its state while hidden, so reload when it is shown
  /// again. Skipped while the first load is still running.
  void _onMainTabChanged() {
    if (MainTabs.active.value != MainTabs.offers) return;
    if (loadedRows == null && loadError == null) return;
    reloadRows();
  }

  Future<void> _respond(ServiceMatchOffer offer, bool accept) async {
    if (_busy.contains(offer.matchId)) return;
    if (!accept) {
      final provider = offer.mySide == 'provider';
      final confirmed = await confirmAction(
        context,
        title: 'رفض هذه المطابقة؟',
        message: provider
            ? 'سنبحث عن شخص آخر لهذا الاحتياج، وتبقى خدمتك متاحة لمطابقات أخرى.'
            : 'سنلغي هذه المطابقة ونواصل البحث عن بديل لطلبك.',
        confirmLabel: 'نعم، أرفض',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _busy.add(offer.matchId));
    try {
      final state = await _repo.respondServiceMatch(offer.matchId, accept: accept);
      if (mounted) {
        final message = !accept
            ? 'تم رفض العرض، وسنواصل البحث عن بديل.'
            : state == 'accepted'
                ? 'وافق الطرفان. سنرتب الموعد ونشارك المعلومات الضرورية فقط.'
                : 'تم تسجيل موافقتك، وننتظر رد الطرف الآخر.';
        showInfoSnack(context, message);
      }
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    }
    await reloadRows();
    if (mounted) setState(() => _busy.remove(offer.matchId));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return buildAsyncList(
      empty: const _EmptyOffers(
        icon: Icons.handyman_outlined,
        title: 'لا توجد عروض خدمات جديدة',
        subtitle: 'سنخبرك هنا عندما نجد خدمة أو طلبًا مناسبًا.',
      ),
      builder: (offers) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: offers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _ServiceMatchCard(
          offer: offers[index],
          busy: _busy.contains(offers[index].matchId),
          onRespond: _respond,
        ),
      ),
    );
  }
}

class _ServiceMatchCard extends StatelessWidget {
  const _ServiceMatchCard({
    required this.offer,
    required this.busy,
    required this.onRespond,
  });

  final ServiceMatchOffer offer;
  final bool busy;
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
                              ? 'وجد عطاء احتياجًا يناسب مهارتك'
                              : 'وجد عطاء وقتًا أو مهارة تناسب احتياجك',
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
                    : 'وافق الطرفان. سيكمل عطاء تنسيق الموعد.',
              )
            else if (awaitingMe) ...[
              FilledButton(
                onPressed: busy ? null : () => onRespond(offer, true),
                child: Text(
                  busy
                      ? 'جارٍ الإرسال...'
                      : provider
                          ? 'نعم، ما زلت أستطيع تقديمها'
                          : 'نعم، ما زلت أحتاجها',
                ),
              ),
              const SizedBox(height: 9),
              OutlinedButton(
                onPressed: busy ? null : () => onRespond(offer, false),
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
    return Padding(
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
    );
  }
}
