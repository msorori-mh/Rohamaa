import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سند'),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ماذا تريد اليوم؟', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('هويتك لا تُكشف للطرف الآخر. سند يتولى المطابقة والتوصيل.'),
              const SizedBox(height: 28),
              _ActionCard(
                icon: Icons.volunteer_activism_outlined,
                title: 'لدي شيء',
                subtitle: 'أضف شيئًا لم تعد تحتاجه ليستفيد منه شخص آخر.',
                onTap: () => context.push('/donate'),
              ),
              const SizedBox(height: 14),
              _ActionCard(
                icon: Icons.front_hand_outlined,
                title: 'أحتاج شيئًا',
                subtitle: 'سجّل احتياجك وسنبحث عن تطابق مناسب دون تصفح تبرعات الآخرين.',
                onTap: () => context.push('/need'),
              ),
              const Spacer(),
              const Text('سند — مأرب • النسخة التجريبية', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            ],
          ),
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
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(subtitle),
                ]),
              ),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}
