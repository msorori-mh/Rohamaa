import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/ruhamaa_theme.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: RuhamaaColors.softGreen,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person_outline_rounded, color: RuhamaaColors.primary, size: 31),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'حساب رحماء',
                        style: TextStyle(
                          color: RuhamaaColors.primaryDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      if (email != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          email,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on_outlined, color: RuhamaaColors.primary),
                  title: const Text('بيانات التوصيل', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('رقم الهاتف، نطاق الخدمة، العنوان والموقع الخاص.'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => context.push('/onboarding'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: RuhamaaColors.primary),
                  title: const Text('الخصوصية والحساب', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('سياسة الخصوصية، الشروط وطلب حذف الحساب.'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => context.push('/legal'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: RuhamaaColors.warmGoldSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: RuhamaaColors.warmGold),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'بيانات حسابك التشغيلية لا تظهر للمتبرع أو المستفيد الآخر، ويستخدمها رحماء عند الحاجة للمطابقة والتوصيل فقط.',
                    style: TextStyle(color: RuhamaaColors.primaryDark, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}
