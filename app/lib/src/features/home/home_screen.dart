import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/admin_repository.dart';
import '../../data/handoff_repository.dart';
import '../../data/match_offer_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import '../services/service_home_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('رحماء'),
        actions: [
          IconButton(
            tooltip: 'بيانات التوصيل',
            onPressed: () => context.push('/onboarding'),
            icon: const Icon(Icons.location_on_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [RuhamaaColors.softGreen, RuhamaaColors.warmSurface],
                ),
                border: Border.all(color: RuhamaaColors.border),
              ),
              child: Row(
                children: [
                  const RuhamaaBrandMark(size: 72),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ماذا تريد اليوم؟',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: RuhamaaColors.primaryDark,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'يمكنك أن تعطي شيئًا، تسجّل احتياجًا، أو تقدّم جزءًا من وقتك ومهارتك بخصوصية.',
                          style: TextStyle(color: RuhamaaColors.textMuted, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _HomeActivityPulse(),
            const SizedBox(height: 22),
            _PrimaryActionCard(
              icon: Icons.inventory_2_outlined,
              title: 'أعطي شيئًا',
              subtitle: 'شيء لم تعد تحتاجه قد يصنع فرقًا في حياة شخص آخر.',
              background: RuhamaaColors.softGreen,
              foreground: RuhamaaColors.primary,
              onTap: () => context.push('/donate'),
            ),
            const SizedBox(height: 14),
            _PrimaryActionCard(
              icon: Icons.favorite_outline_rounded,
              title: 'أحتاج شيئًا',
              subtitle: 'سجّل احتياجك بخصوصية، وسنبحث عن تطابق مناسب لك.',
              background: RuhamaaColors.warmGoldSoft,
              foreground: RuhamaaColors.warmGold,
              onTap: () => context.push('/need'),
            ),
            const SizedBox(height: 24),
            const ServiceHomeSection(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.mark_email_unread_outlined,
                    title: 'المطابقات',
                    subtitle: 'فرص مناسبة لك',
                    onTap: () => context.go('/offers'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.local_shipping_outlined,
                    title: 'عملياتي',
                    subtitle: 'تابع الاستلام والتسليم',
                    onTap: () => context.go('/handoffs'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: RuhamaaColors.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: RuhamaaColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'هويتك لا تُكشف للطرف الآخر إلا بالقدر الضروري عند تنفيذ خدمة تتطلب حضورًا مباشرًا، وموقعك الدقيق يستخدم للتشغيل فقط.',
                      style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FutureBuilder<String>(
              future: AdminRepository(Supabase.instance.client).myRole(),
              builder: (context, snapshot) {
                final role = snapshot.data;
                if (role == 'admin') {
                  return _OperationsCard(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'لوحة التشغيل',
                    subtitle: 'المطابقة، المساهمات، المخاطر ومتابعة العمليات.',
                    onTap: () => context.push('/admin'),
                  );
                }
                if (role == 'courier') {
                  return _OperationsCard(
                    icon: Icons.delivery_dining_outlined,
                    title: 'مهام التوصيل',
                    subtitle: 'الاستلام والتسليم المخصص لك فقط.',
                    onTap: () => context.push('/courier'),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 26),
            const Text(
              'رحماء — مأرب • النسخة التجريبية',
              textAlign: TextAlign.center,
              style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeActivityPulse extends StatefulWidget {
  const _HomeActivityPulse();

  @override
  State<_HomeActivityPulse> createState() => _HomeActivityPulseState();
}

class _HomeActivityPulseState extends State<_HomeActivityPulse> {
  late Future<_PulseData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PulseData> _load() async {
    final client = Supabase.instance.client;
    final results = await Future.wait<dynamic>([
      MatchOfferRepository(client).pendingOffers(),
      HandoffRepository(client).myHandoffs(),
    ]);
    final offers = results[0] as List<MatchOffer>;
    final handoffs = results[1] as List<UserHandoff>;
    final active = handoffs.where((row) => row.status != 'delivered').toList();
    if (offers.isNotEmpty) {
      return _PulseData(
        icon: Icons.auto_awesome_rounded,
        title: 'لديك تطابق ينتظر ردك',
        subtitle: 'وجد رحماء شيئًا مناسبًا لاحتياجك. راجعه الآن حتى نكمل الترتيب.',
        route: '/offers',
        warm: true,
      );
    }
    if (active.isNotEmpty) {
      return _PulseData(
        icon: Icons.local_shipping_rounded,
        title: 'هناك عملية تتحرك الآن',
        subtitle: 'تابع رحلة الاستلام أو التسليم خطوة بخطوة من «عملياتي».',
        route: '/handoffs',
      );
    }
    return const _PulseData.none();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PulseData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data ?? const _PulseData.none();
        if (data.route == null) return const SizedBox.shrink();
        final background = data.warm ? RuhamaaColors.warmGoldSoft : RuhamaaColors.softGreen;
        final accent = data.warm ? RuhamaaColors.warmGold : RuhamaaColors.primary;
        return Material(
          color: background,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.go(data.route!),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(data.icon, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'آخر تحديث',
                          style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data.title,
                          style: const TextStyle(
                            color: RuhamaaColors.primaryDark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data.subtitle,
                          style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.35, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left_rounded, color: accent),
                ],
              ),
            ),
          ),
        );
      },
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
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: foreground),
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
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.45),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_back_rounded, color: foreground),
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
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: RuhamaaColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: RuhamaaColors.primary, size: 32),
              const SizedBox(height: 9),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationsCard extends StatelessWidget {
  const _OperationsCard({
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
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Icon(icon, color: RuhamaaColors.primary, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: onTap,
      ),
    );
  }
}
