import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/ruhamaa_theme.dart';

class ServiceHomeSection extends StatelessWidget {
  const ServiceHomeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule_rounded, color: RuhamaaColors.primary),
            const SizedBox(width: 8),
            Text(
              'الوقت والمهارة',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: RuhamaaColors.primaryDark,
                            fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          'قد تحتاج شيئًا اليوم، وفي الوقت نفسه تستطيع تقديم جزء من وقتك أو مهارتك لشخص آخر.',
          style: TextStyle(color: RuhamaaColors.textMuted, height: 1.45),
        ),
        const SizedBox(height: 12),
        _ServiceActionCard(
          icon: Icons.handyman_outlined,
          title: 'أقدّم وقتي أو مهارتي كفرد',
          subtitle: 'سباكة، كهرباء، خياطة، صيانة أو مهارة أخرى من وقتك الشخصي.',
          background: RuhamaaColors.softGreen,
          accent: RuhamaaColors.primary,
          onTap: () => context.push('/offer-service'),
        ),
        const SizedBox(height: 10),
        _ServiceActionCard(
          icon: Icons.storefront_outlined,
          title: 'شركاء رحماء',
          subtitle: 'للمحلات والورش والصالونات والجهات التي تريد تقديم خدمات مجانية بعد التحقق.',
          background: RuhamaaColors.warmSurface,
          accent: RuhamaaColors.primary,
          onTap: () => context.push('/partners'),
        ),
        const SizedBox(height: 10),
        _ServiceActionCard(
          icon: Icons.support_agent_rounded,
          title: 'أحتاج خدمة',
          subtitle: 'سجّل احتياجك بخصوصية، وسيبحث رحماء عن فرد أو شريك موثّق مناسب.',
          background: RuhamaaColors.warmGoldSoft,
          accent: RuhamaaColors.warmGold,
          onTap: () => context.push('/request-service'),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RuhamaaColors.border),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.balance_outlined, size: 21, color: RuhamaaColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'العطاء والاحتياج مستقلان: لا تحتاج أن تقدّم خدمة حتى تحصل على مساعدة، وتقديمك للخدمة أو شراكتك مع رحماء لا يرفعان أولوية طلباتك.',
                  style: TextStyle(color: RuhamaaColors.textMuted, height: 1.45, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceActionCard extends StatelessWidget {
  const _ServiceActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color background;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      elevation:4,
      shadowColor:RuhamaaColors.primaryDark.withValues(alpha:.09),
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color:accent,shape:BoxShape.circle,boxShadow:[BoxShadow(color:accent.withValues(alpha:.23),blurRadius:12,offset:const Offset(0,5))]),
                child: Icon(icon, color: Colors.white, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.4, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
