import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/main_tab_signal.dart';
import '../../data/account_repository.dart';
import '../../data/handoff_repository.dart';
import '../../data/match_offer_repository.dart';
import '../../data/operations_repository.dart';
import '../../data/service_repository.dart';
import '../../domain/journey_rules.dart';
import '../../domain/operation_rules.dart';
import '../../domain/operation_status_presenter.dart';
import '../../theme/ruhamaa_theme.dart';
import '../items/community_form_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _PulseData _pulse = const _PulseData.none();

  /// The donation or request shown in the «في الطريق» card, if any.
  OperationItem? _journey;
  String? _fullName;
  bool _hasUnread = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    MainTabs.active.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    MainTabs.active.removeListener(_onTabChanged);
    super.dispose();
  }

  /// The home tab stays alive while hidden, so refresh when it is shown again.
  void _onTabChanged() {
    if (MainTabs.active.value == MainTabs.home) _load();
  }

  /// Runs one optional load. A failure is logged and returns null, so one
  /// unavailable source never hides the others.
  Future<T?> _attempt<T>(String label, Future<T> Function() load) async {
    try {
      return await load();
    } catch (error) {
      debugPrint('Ataa home $label load failed: ${error.runtimeType}');
      return null;
    }
  }

  /// Loads the name, the bell marker, the journey card and the "decision
  /// waiting" row. Everything here is optional information: a source that
  /// fails keeps what is already on screen. Never throws, so it is safe as a
  /// RefreshIndicator callback.
  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final client = Supabase.instance.client;
      final operations = OperationsRepository(client);
      final results = await Future.wait<Object?>([
        _attempt('offers', () => MatchOfferRepository(client).pendingOffers()),
        _attempt('service matches', () => ServiceRepository(client).pendingServiceMatches()),
        _attempt('handoffs', () => HandoffRepository(client).myHandoffs()),
        _attempt('operations', operations.myOperations),
        _attempt('notifications', operations.myNotifications),
        _attempt('profile', () => AccountRepository(client).deliveryProfile()),
      ]);
      if (!mounted) return;
      final itemOffers = results[0] as List<MatchOffer>?;
      final serviceOffers = results[1] as List<ServiceMatchOffer>?;
      final handoffs = results[2] as List<UserHandoff>?;
      final rows = results[3] as List<OperationItem>?;
      final notifications = results[4] as List<UserNotificationItem>?;
      final profile = results[5] as DeliveryProfile?;
      setState(() {
        if (itemOffers != null && serviceOffers != null && handoffs != null) {
          _pulse = _PulseData.from(
            itemOffers: itemOffers,
            serviceOffers: serviceOffers,
            handoffs: handoffs,
          );
        }
        if (rows != null) _journey = _pickJourney(rows);
        if (notifications != null) {
          _hasUnread = notifications.any((item) => !item.isRead);
        }
        if (profile != null) _fullName = profile.fullName;
      });
    } finally {
      _loading = false;
    }
  }

  /// The donation or request still on its way that changed most recently.
  static OperationItem? _pickJourney(List<OperationItem> rows) {
    final open = rows
        .where((row) => JourneyRules.isInProgress(row.kind, row.status))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return open.isEmpty ? null : open.first;
  }

  void _goTab(String route) {
    context.go(OperationRules.withRequestId(route, DateTime.now().millisecondsSinceEpoch));
  }

  void _openServices() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: RuhamaaColors.background,
      builder: (sheetContext) {
        void open(String route) {
          Navigator.pop(sheetContext);
          context.push(route);
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'وقتي ومهارتي',
                  style: TextStyle(color: RuhamaaColors.text, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'قدّم ساعة من وقتك أو مهارتك مجانًا، أو اطلب خدمة تحتاجها.',
                  style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 14, height: 1.45),
                ),
                const SizedBox(height: 14),
                _SheetOption(
                  icon: Icons.handyman_outlined,
                  title: 'قدّم وقتك أو مهارتك',
                  subtitle: 'خدمة تستطيع تنفيذها مجانًا.',
                  onTap: () => open('/offer-service'),
                ),
                const SizedBox(height: 10),
                _SheetOption(
                  icon: Icons.support_agent_rounded,
                  title: 'اطلب خدمة',
                  subtitle: 'أخبرنا بالخدمة وسنبحث عن شخص مناسب.',
                  onTap: () => open('/request-service'),
                ),
                const SizedBox(height: 10),
                _SheetOption(
                  icon: Icons.storefront_outlined,
                  title: 'شارك من خلال نشاطك',
                  subtitle: 'للمحلات والورش والجهات التي تقدم خدمات مجانية.',
                  onTap: () => open('/partners'),
                ),
                const SizedBox(height: 10),
                _SheetOption(
                  icon: Icons.event_note_outlined,
                  title: 'خدماتي',
                  subtitle: 'تابع ما قدّمته أو طلبته من خدمات.',
                  onTap: () => open('/my-services'),
                ),
                const SizedBox(height: 12),
                const CommunityNote(
                  icon: Icons.balance_outlined,
                  text: 'طلب المساعدة لا يتطلب أن تتبرّع بشيء أو تقدم خدمة.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final journey = _journey;
    final pulse = _pulse;
    final showPulse = pulse.route != null && (pulse.warm || journey == null);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 20, 20, 28),
          children: [
            _Header(
              hasUnread: _hasUnread,
              onBell: () => _goTab('/handoffs?tab=1'),
            ),
            const SizedBox(height: 18),
            Text(
              OperationRules.greetingWithName(DateTime.now().hour, _fullName),
              style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'ماذا تحب أن تفعل اليوم؟',
              style: TextStyle(
                color: RuhamaaColors.text,
                fontSize: 28,
                height: 38 / 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _BigActionCard(
                    key: const ValueKey('home-donate'),
                    icon: Icons.card_giftcard_rounded,
                    title: 'تبرّع',
                    subtitle: 'شيء لم تعد تحتاجه',
                    background: RuhamaaColors.primary,
                    titleColor: Colors.white,
                    subtitleColor: const Color(0xFFD9EEE8),
                    iconColor: Colors.white,
                    iconBackground: Colors.white.withValues(alpha: .16),
                    onTap: () => context.push('/donate'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigActionCard(
                    key: const ValueKey('home-need'),
                    icon: Icons.volunteer_activism_outlined,
                    title: 'ما أحتاجه',
                    subtitle: 'اطلب بسرية وكرامة',
                    background: RuhamaaColors.warmGoldSoft,
                    titleColor: RuhamaaColors.goldInk,
                    subtitleColor: const Color(0xFF6B4E1A),
                    iconColor: RuhamaaColors.goldDeep,
                    iconBackground: Colors.white.withValues(alpha: .6),
                    onTap: () => context.push('/need'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ServicesRow(onTap: _openServices),
            if (showPulse) ...[
              const SizedBox(height: 12),
              _PulseRow(data: pulse, onTap: () => _goTab(pulse.route!)),
            ],
            if (journey != null) ...[
              const SizedBox(height: 22),
              _JourneyCard(
                operation: journey,
                onTap: () => _goTab('/handoffs?tab=0'),
              ),
            ],
            const SizedBox(height: 16),
            const CommunityNote(
              icon: Icons.lock_outline_rounded,
              text: 'لا يعرف المتبرّع ولا المحتاج هوية الآخر.',
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _LinkChip(
                  icon: Icons.fact_check_outlined,
                  label: 'طلبات راجعها الفريق',
                  onTap: () => context.push('/verified-needs'),
                ),
                _LinkChip(
                  icon: Icons.storefront_outlined,
                  label: 'شركاء عطاء',
                  onTap: () => context.push('/partners'),
                ),
                _LinkChip(
                  icon: Icons.location_on_outlined,
                  label: 'عناويني',
                  onTap: () => context.push('/onboarding'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'عطاء — مأرب • النسخة التجريبية',
              textAlign: TextAlign.center,
              style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo, name and the bell (with a dot while notifications are unread).
class _Header extends StatelessWidget {
  const _Header({required this.hasUnread, required this.onBell});

  final bool hasUnread;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const RuhamaaBrandMark(size: 40),
        ),
        const SizedBox(width: 10),
        const Text(
          'عطاء',
          style: TextStyle(color: RuhamaaColors.primaryDark, fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        Semantics(
          button: true,
          label: hasUnread ? 'التنبيهات، توجد تنبيهات جديدة' : 'التنبيهات',
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(side: BorderSide(color: RuhamaaColors.border)),
            child: InkWell(
              key: const ValueKey('home-bell'),
              customBorder: const CircleBorder(),
              onTap: onBell,
              child: SizedBox.square(
                dimension: 44,
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.notifications_none_rounded, color: RuhamaaColors.text, size: 22),
                    ),
                    if (hasUnread)
                      Positioned(
                        top: 9,
                        left: 10,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: RuhamaaColors.alert,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One of the two big home actions (196 high, 28 radius).
class _BigActionCard extends StatelessWidget {
  const _BigActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.titleColor,
    required this.subtitleColor,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color background;
  final Color titleColor;
  final Color subtitleColor;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: SizedBox(
          height: 196,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: titleColor, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: subtitleColor, fontSize: 15, height: 21 / 15),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «وقتي ومهارتي» row.
class _ServicesRow extends StatelessWidget {
  const _ServicesRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: RuhamaaColors.cardBorder),
    );
    return Material(
      color: Colors.white,
      shape: shape,
      child: InkWell(
        key: const ValueKey('home-services'),
        customBorder: shape,
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _CircleIcon(
                icon: Icons.schedule_rounded,
                background: RuhamaaColors.skyTint,
                color: RuhamaaColors.sky,
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'وقتي ومهارتي',
                      style: TextStyle(color: RuhamaaColors.text, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'قدّم ساعة من وقتك، أو اطلب خدمة',
                      style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Color(0xFF7B8B8E), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.background, required this.color});

  final IconData icon;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

/// A decision waiting for the person (an offer to answer), or a handoff in
/// progress when there is no journey card.
class _PulseRow extends StatelessWidget {
  const _PulseRow({required this.data, required this.onTap});

  final _PulseData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final warm = data.warm;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: warm ? BorderSide.none : const BorderSide(color: RuhamaaColors.cardBorder),
    );
    return Material(
      color: warm ? RuhamaaColors.warmGoldSoft : Colors.white,
      shape: shape,
      child: InkWell(
        key: const ValueKey('home-pulse'),
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _CircleIcon(
                icon: data.icon,
                background: warm ? Colors.white.withValues(alpha: .6) : RuhamaaColors.softGreen,
                color: warm ? RuhamaaColors.goldDeep : RuhamaaColors.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: TextStyle(
                        color: warm ? RuhamaaColors.goldInk : RuhamaaColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle,
                      style: TextStyle(
                        color: warm ? const Color(0xFF6B4E1A) : RuhamaaColors.textMuted,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: warm ? RuhamaaColors.goldDeep : const Color(0xFF7B8B8E),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «تبرّعك في الطريق» / «طلبك في الطريق»: the operation, a five-segment
/// progress bar and the next step.
class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.operation, required this.onTap});

  final OperationItem operation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final need = operation.kind == 'need';
    final accent = need ? RuhamaaColors.goldDark : RuhamaaColors.primary;
    final step = JourneyRules.currentStep(operation.kind, operation.status) ?? 0;
    final filled = JourneyRules.filledSegments(operation.kind, operation.status);
    final stepLabel = JourneyRules.stepsFor(operation.kind)[step];
    final nextStep = OperationStatusPresenter.present(operation.kind, operation.status).nextStep;
    final cleanNext = nextStep.endsWith('.') ? nextStep.substring(0, nextStep.length - 1) : nextStep;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: RuhamaaColors.cardBorder),
    );
    final segments = <Widget>[];
    for (var index = 0; index < JourneyRules.stepCount; index++) {
      if (index > 0) segments.add(const SizedBox(width: 6));
      segments.add(
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: index < filled ? accent : RuhamaaColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                need ? 'طلبك في الطريق' : 'تبرّعك في الطريق',
                style: const TextStyle(color: RuhamaaColors.text, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(foregroundColor: need ? RuhamaaColors.goldDeep : RuhamaaColors.primary),
              child: const Text('التفاصيل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.white,
          shape: shape,
          child: InkWell(
            key: const ValueKey('home-journey'),
            customBorder: shape,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: need ? RuhamaaColors.goldTint : RuhamaaColors.softGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          need ? Icons.volunteer_activism_outlined : Icons.card_giftcard_rounded,
                          color: need ? RuhamaaColors.goldDeep : RuhamaaColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              operation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: RuhamaaColors.text, fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              stepLabel,
                              style: TextStyle(
                                color: need ? RuhamaaColors.goldDeep : RuhamaaColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(children: segments),
                  const SizedBox(height: 14),
                  Text(
                    'الخطوة التالية: $cleanNext',
                    style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small secondary link (reviewed needs, partners, addresses).
class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const shape = StadiumBorder(side: BorderSide(color: RuhamaaColors.cardBorder));
    return Material(
      color: Colors.white,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: RuhamaaColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: RuhamaaColors.text, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One choice of the «وقتي ومهارتي» sheet.
class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: RuhamaaColors.cardBorder),
    );
    return Material(
      color: Colors.white,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _CircleIcon(icon: icon, background: RuhamaaColors.skyTint, color: RuhamaaColors.sky),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: RuhamaaColors.text, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF7B8B8E), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseData {
  const _PulseData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.warm = false,
  });

  const _PulseData.none()
      : icon = Icons.info_outline_rounded,
        title = '',
        subtitle = '',
        route = null,
        warm = false;

  /// Picks the single most useful thing to show: a decision waiting for the
  /// person first, then a handoff in progress.
  factory _PulseData.from({
    required List<MatchOffer> itemOffers,
    required List<ServiceMatchOffer> serviceOffers,
    required List<UserHandoff> handoffs,
  }) {
    final activeHandoffs = handoffs.where((row) => !OperationRules.isDeliveryClosed(row.status)).toList();
    final waitingServiceResponse = serviceOffers.where((row) => row.myResponse == 'pending').toList();

    if (waitingServiceResponse.isNotEmpty) {
      final match = waitingServiceResponse.first;
      return _PulseData(
        icon: Icons.handyman_rounded,
        title: match.mySide == 'provider'
            ? 'هناك احتياج يناسب مهارتك'
            : 'هناك مهارة تناسب احتياجك',
        subtitle: 'راجع العرض وأخبرنا بقرارك.',
        route: '/offers?tab=1',
        warm: true,
      );
    }
    if (itemOffers.isNotEmpty) {
      return const _PulseData(
        icon: Icons.auto_awesome_rounded,
        title: 'لديك عرض مناسب',
        subtitle: 'راجع العرض وأخبرنا إن كنت ما زلت تحتاجه.',
        route: '/offers',
        warm: true,
      );
    }
    if (activeHandoffs.isNotEmpty) {
      return const _PulseData(
        icon: Icons.local_shipping_rounded,
        title: 'لديك تسليم قيد التنفيذ',
        subtitle: 'تابع حالة الاستلام أو التسليم.',
        route: '/handoffs?tab=2',
      );
    }
    return const _PulseData.none();
  }

  final IconData icon;
  final String title;
  final String subtitle;
  final String? route;
  final bool warm;
}
