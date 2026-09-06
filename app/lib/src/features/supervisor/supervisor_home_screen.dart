import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../reports/reports_screen.dart';

class SupervisorHomeScreen extends StatelessWidget {
  const SupervisorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إشراف سند'),
        actions: [IconButton(tooltip: 'تسجيل الخروج', onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('لوحة مشرف المنطقة', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('تظهر لك التقارير ضمن المدينة أو المناطق المسندة إلى حسابك فقط.'),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: const Text('التقارير الأساسية'),
              subtitle: const Text('الأثر، التوصيل، المساهمات والمصروفات ضمن نطاقك.'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
            ),
          ),
        ],
      ),
    );
  }
}
