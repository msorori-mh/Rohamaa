import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/main_tab_signal.dart';
import '../../data/handoff_repository.dart';
import '../../data/match_offer_repository.dart';
import '../../data/service_repository.dart';
import '../../domain/operation_rules.dart';
import '../../theme/ruhamaa_theme.dart';
import '../services/service_home_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _PulseData _pulse = const _PulseData.none();
  bool _loadingPulse = false;

  @override
  void initState() {
    super.initState();
    MainTabs.active.addListener(_onTabChanged);
    _loadPulse();
  }

  @override
  void dispose() {
    MainTabs.active.removeListener(_onTabChanged);
    super.dispose();
  }

  /// The home tab stays alive while hidden, so refresh when it is shown again.
  void _onTabChanged() {
    if (MainTabs.active.value == MainTabs.home) _loadPulse();
  }

  /// Loads the "what needs you now" card. It is optional information, so a
  /// failure simply leaves the previous card (or none) in place.
  Future<void> _loadPulse() async {
    if (_loadingPulse) return;
    _loadingPulse = true;
    try {
      final client = Supabase.instance.client;
      final results = await Future.wait<dynamic>([
        MatchOfferRepository(client).pendingOffers(),
        ServiceRepository(client).pendingServiceMatches(),
        HandoffRepository(client).myHandoffs(),
      ]);
      final pulse = _PulseData.from(
        itemOffers: results[0] as List<MatchOffer>,
        serviceOffers: results[1] as List<ServiceMatchOffer>,
        handoffs: results[2] as List<UserHandoff>,
      );
      if (mounted) setState(() => _pulse = pulse);
    } catch (error) {
      debugPrint('Ataa home pulse load failed: ${error.runtimeType}');
    } finally {
      _loadingPulse = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: RuhamaaColors.pageGradient),
        child: RefreshIndicator(
          onRefresh: _loadPulse,
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _HomeHero(onLocation: () => context.push('/onboarding')),
            Transform.translate(
              offset: const Offset(0, -38),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PrimaryActionCard(
                      icon: Icons.volunteer_activism_rounded,
                      title: 'تبرّع بشيء',
                      subtitle: 'سنستلمه ونوصله لمن يحتاجه.',
                      foreground: RuhamaaColors.primaryBright,
                      onTap: () => context.push('/donate'),
                    ),
                    const SizedBox(height: 14),
                    _PrimaryActionCard(
                      icon: Icons.front_hand_rounded,
                      title: 'اطلب ما تحتاجه',
                      subtitle: 'أخبرنا بما تحتاجه وسنحافظ على خصوصيتك.',
                      foreground: RuhamaaColors.vividGold,
                      onTap: () => context.push('/need'),
                    ),
                    const SizedBox(height: 16),
                    _HomeActivityPulse(data: _pulse),
                    const SizedBox(height: 24),
                    const _SectionTitle(title: 'وصول سريع', subtitle: 'اختر ما تريد القيام به'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _QuickActionCard(icon: Icons.fact_check_outlined,title: 'طلبات للمساعدة',subtitle: 'طلبات راجعها فريقنا',accent: RuhamaaColors.primaryBright,tint: const Color(0xFFE8F8F4),onTap:()=>context.push('/verified-needs'))),
                      const SizedBox(width: 12),
                      Expanded(child: _QuickActionCard(icon: Icons.local_shipping_outlined,title: 'المتابعة',subtitle: 'تابع تبرعاتك وطلباتك',accent: RuhamaaColors.rose,tint: const Color(0xFFFFEDF3),onTap:()=>context.go('/handoffs'))),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _QuickActionCard(icon: Icons.mark_email_unread_outlined,title: 'عروض مناسبة',subtitle: 'راجع العروض المتاحة',accent: RuhamaaColors.vividGold,tint: const Color(0xFFFFF6E6),onTap:()=>context.go('/offers'))),
                      const SizedBox(width: 12),
                      Expanded(child: _QuickActionCard(icon: Icons.location_on_rounded,title: 'عناويني',subtitle: 'إدارة مواقع التوصيل',accent: RuhamaaColors.blue,tint: const Color(0xFFEAF7FB),onTap:()=>context.push('/onboarding'))),
                    ]),
                    const SizedBox(height: 26),
                    const ServiceHomeSection(),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92),borderRadius: BorderRadius.circular(24),boxShadow:[BoxShadow(color:RuhamaaColors.primaryDark.withValues(alpha:.07),blurRadius:22,offset:const Offset(0,8))]),
                      child: const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.shield_rounded,color:RuhamaaColors.primaryBright),SizedBox(width:12),Expanded(child:Text('بياناتك خاصة، ولا نشارك إلا ما يلزم لإتمام الاستلام أو التسليم.',style:TextStyle(color:RuhamaaColors.textMuted,height:1.5,fontWeight:FontWeight.w500)))]),
                    ),
                    const SizedBox(height: 26),
                    const Text('عطاء — مأرب • النسخة التجريبية',textAlign:TextAlign.center,style:TextStyle(color:RuhamaaColors.textMuted,fontSize:12,fontWeight:FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.onLocation});
  final VoidCallback onLocation;

  @override
  Widget build(BuildContext context) => Container(
    height: 310,
    padding: EdgeInsets.fromLTRB(22, MediaQuery.paddingOf(context).top + 22, 22, 56),
    decoration: const BoxDecoration(
      gradient: RuhamaaColors.heroGradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.elliptical(220, 48)),
    ),
    child: Stack(children:[
      Positioned(left:-40,bottom:-82,child:Container(width:230,height:150,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.07),shape:BoxShape.circle))),
      Positioned(right:-64,top:92,child:Container(width:210,height:210,decoration:BoxDecoration(color:RuhamaaColors.primaryGlow.withValues(alpha:.16),shape:BoxShape.circle))),
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(width:58,height:58,padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.94),shape:BoxShape.circle,boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.10),blurRadius:12,offset:const Offset(0,5))]),child:const RuhamaaBrandMark(size:44)),
          const Spacer(),
          _HeroButton(icon:Icons.location_on_outlined,tooltip:'بيانات التوصيل',onTap:onLocation),
          const SizedBox(width:10),
          const _HeroButton(icon:Icons.notifications_none_rounded,tooltip:'التنبيهات'),
        ]),
        const Spacer(),
        Text('${OperationRules.greetingForHour(DateTime.now().hour)} ✨',style:const TextStyle(color:Color(0xFFDDF6F1),fontSize:16,fontWeight:FontWeight.w500)),
        const SizedBox(height:4),
        Text('أهلًا بك في عطاء',style:Theme.of(context).textTheme.headlineMedium?.copyWith(color:Colors.white,fontWeight:FontWeight.w800,height:1.15)),
        const SizedBox(height:7),
        const Text('نحفظ النعمة ونصنع الأثر.',style:TextStyle(color:Color(0xFFD8EEEB),fontSize:16,fontWeight:FontWeight.w500)),
      ]),
    ]),
  );
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.icon,required this.tooltip,this.onTap});
  final IconData icon; final String tooltip; final VoidCallback? onTap;
  @override Widget build(BuildContext context)=>Material(color:Colors.white.withValues(alpha:.11),shape:const CircleBorder(),child:IconButton(tooltip:tooltip,onPressed:onTap??()=>context.go('/handoffs?tab=1&t=${DateTime.now().millisecondsSinceEpoch}'),icon:Icon(icon,color:Colors.white),iconSize:25));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title,required this.subtitle});
  final String title; final String subtitle;
  @override Widget build(BuildContext context)=>Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(context).textTheme.titleLarge?.copyWith(color:RuhamaaColors.primaryDark,fontWeight:FontWeight.w800)),const SizedBox(height:2),Text(subtitle,style:const TextStyle(color:RuhamaaColors.textMuted,fontSize:13,fontWeight:FontWeight.w500))]))]);
}

class _HomeActivityPulse extends StatelessWidget {
  const _HomeActivityPulse({required this.data});

  final _PulseData data;

  @override
  Widget build(BuildContext context) {
    final route = data.route;
    if (route == null) return const SizedBox.shrink();
    final accent = data.warm ? RuhamaaColors.warmGold : RuhamaaColors.primary;
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: RuhamaaColors.primaryDark.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(29),
      child: InkWell(
        borderRadius: BorderRadius.circular(29),
        onTap: () => context.go(route),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(29), border: Border(top: BorderSide(color: accent, width: 5))),
          child: Row(children: [
            Container(width: 58, height: 58, decoration: BoxDecoration(color: accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: accent.withValues(alpha: .25), blurRadius: 14, offset: const Offset(0, 6))]), child: Icon(data.icon, color: Colors.white, size: 29)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('تحديث جديد', style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(data.title, style: const TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 3),
              Text(data.subtitle, style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.35, fontSize: 12, fontWeight: FontWeight.w500)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: accent.withValues(alpha: .11), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text('راجع', style: TextStyle(color: accent, fontWeight: FontWeight.w800)), const SizedBox(width: 4), Icon(Icons.arrow_forward_rounded, color: accent, size: 17)])),
          ]),
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
    final activeHandoffs = handoffs.where((row) => row.status != 'delivered').toList();
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
        title: 'لديك طلب قيد التنفيذ',
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

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 7,
      shadowColor: RuhamaaColors.primaryDark.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20,vertical: 18),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin:Alignment.topRight,end:Alignment.bottomLeft,colors:[foreground.withValues(alpha:.76),foreground]),
                  borderRadius: BorderRadius.circular(23),
                  boxShadow:[BoxShadow(color:foreground.withValues(alpha:.28),blurRadius:16,offset:const Offset(0,7))],
                ),
                child: Icon(icon, size: 34, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: RuhamaaColors.primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(color: RuhamaaColors.textMuted,height:1.45,fontWeight:FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(width:42,height:42,decoration:BoxDecoration(color:foreground.withValues(alpha:.1),shape:BoxShape.circle),child:Icon(Icons.arrow_forward_ios_rounded,color:foreground,size:19)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint,
      elevation: 4,
      shadowColor: RuhamaaColors.primaryDark.withValues(alpha:.10),
      borderRadius: BorderRadius.circular(27),
      child: InkWell(
        borderRadius: BorderRadius.circular(27),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14,18,14,17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            gradient:LinearGradient(begin:Alignment.topRight,end:Alignment.bottomLeft,colors:[Colors.white.withValues(alpha:.86),tint]),
          ),
          child: Column(
            crossAxisAlignment:CrossAxisAlignment.start,
            children: [
              Align(alignment:Alignment.centerRight,child:Container(width:54,height:54,decoration:BoxDecoration(color:accent,shape:BoxShape.circle,boxShadow:[BoxShadow(color:accent.withValues(alpha:.28),blurRadius:14,offset:const Offset(0,6))]),child:Icon(icon,color:Colors.white,size:28))),
              const SizedBox(height: 15),
              Text(title,style:const TextStyle(color:RuhamaaColors.primaryDark,fontWeight:FontWeight.w800,fontSize:16)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color:RuhamaaColors.textMuted,fontSize:12,fontWeight:FontWeight.w500,height:1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
