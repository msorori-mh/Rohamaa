import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/admin_repository.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('رحماء'),
        actions: [
          IconButton(tooltip: 'بيانات التوصيل', onPressed: () => context.push('/onboarding'), icon: const Icon(Icons.location_on_outlined)),
          IconButton(tooltip: 'تسجيل الخروج', onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('ماذا تريد اليوم؟', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('هويتك لا تُكشف للطرف الآخر. رحماء يتولى المطابقة والتوصيل.'),
            const SizedBox(height: 28),
            _ActionCard(icon: Icons.volunteer_activism_outlined, title: 'لدي شيء', subtitle: 'أضف شيئًا لم تعد تحتاجه ليستفيد منه شخص آخر.', onTap: () => context.push('/donate')),
            const SizedBox(height: 14),
            _ActionCard(icon: Icons.front_hand_outlined, title: 'أحتاج شيئًا', subtitle: 'سجّل احتياجك وسنبحث عن تطابق مناسب دون تصفح تبرعات الآخرين.', onTap: () => context.push('/need')),
            const SizedBox(height: 14),
            _ActionCard(icon: Icons.mark_email_unread_outlined, title: 'عروض المطابقة', subtitle: 'راجع أي شيء وجده رحماء مطابقًا لاحتياجك واقبله أو ارفضه.', onTap: () => context.push('/offers')),
            const SizedBox(height: 14),
            _ActionCard(icon: Icons.local_shipping_outlined, title: 'عملياتي', subtitle: 'تابع الاستلام والتسليم واعرض PIN عند وصول مندوب رحماء.', onTap: () => context.push('/handoffs')),
            const SizedBox(height: 18),
            FutureBuilder<String>(
              future: AdminRepository(Supabase.instance.client).myRole(),
              builder: (context, snapshot) {
                final role = snapshot.data;
                if (role == 'admin') {
                  return _ActionCard(icon: Icons.admin_panel_settings_outlined, title: 'لوحة التشغيل', subtitle: 'المطابقة، المساهمات، المخاطر ومتابعة العمليات.', onTap: () => context.push('/admin'));
                }
                if (role == 'courier') {
                  return _ActionCard(icon: Icons.delivery_dining_outlined, title: 'مهام التوصيل', subtitle: 'الاستلام والتسليم المخصص لك فقط.', onTap: () => context.push('/courier'));
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 28),
            const Text('رحماء — مأرب • النسخة التجريبية', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 42),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(subtitle)])),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}
