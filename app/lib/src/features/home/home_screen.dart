import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/admin_repository.dart';
import '../../theme/ruhamaa_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openNav(BuildContext context, int index) {
    switch (index) {
      case 0:
        return;
      case 1:
        context.push('/offers');
      case 2:
        context.push('/handoffs');
      case 3:
        context.push('/account');
    }
  }

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
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout_rounded),
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
                          'كل خطوة هنا تتم بخصوصية، ورحماء يتولى المطابقة والتوصيل.',
                          style: TextStyle(color: RuhamaaColors.textMuted, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.mark_email_unread_outlined,
                    title: 'المطابقات',
                    subtitle: 'فرص مناسبة لك',
                    onTap: () => context.push('/offers'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.local_shipping_outlined,
                    title: 'عملياتي',
                    subtitle: 'تابع الاستلام والتسليم',
                    onTap: () => context.push('/handoffs'),
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
                      'هويتك لا تُكشف للطرف الآخر، وموقعك الدقيق يستخدم فقط للتشغيل والتوصيل.',
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) => _openNav(context, index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), label: 'المطابقات'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'عملياتي'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'حسابي'),
        ],
      ),
    );
  }
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
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.82), shape: BoxShape.circle),
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
                    Text(subtitle, style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.45)),
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
  const _QuickActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

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
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationsCard extends StatelessWidget {
  const _OperationsCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

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
