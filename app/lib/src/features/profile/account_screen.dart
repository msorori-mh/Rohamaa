import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/ruhamaa_theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    this.email,
    this.onSignOut,
  });

  final String? email;
  final Future<void> Function()? onSignOut;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج؟'),
        content: const Text(
          'سيتم إنهاء جلسة رحماء على هذا الجهاز، ويمكنك بعد ذلك الدخول بحساب Google آخر.',
        ),
        actions: [
          TextButton(
            key: const Key('cancel-sign-out'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const Key('confirm-sign-out'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _signingOut = true);
    try {
      final handler = widget.onSignOut;
      if (handler != null) {
        await handler();
      } else {
        await Supabase.instance.client.auth.signOut();
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تسجيل الخروج: ${error.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تسجيل الخروج. تحقق من اتصالك ثم حاول مرة أخرى.')),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email ?? Supabase.instance.client.auth.currentUser?.email;

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
                  leading: const Icon(Icons.handyman_outlined, color: RuhamaaColors.primary),
                  title: const Text('وقتي ومهاراتي', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('شاهد ما تقدمه من وقت أو مهارة وما سجلته من احتياجات للخدمات.'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => context.push('/my-services'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: RuhamaaColors.primary),
                  title: const Text('كيف يعمل رحماء؟', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('راجع بطاقات التعريف والخصوصية والمساهمة في التوصيل.'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => context.push('/intro'),
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
                    'في رحماء لا توجد هوية ثابتة باسم «متبرع» أو «محتاج». يمكنك تسجيل احتياجك، وفي الوقت نفسه تقديم شيء أو وقت أو مهارة عندما تستطيع.',
                    style: TextStyle(color: RuhamaaColors.primaryDark, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: RuhamaaColors.background,
            border: Border(top: BorderSide(color: RuhamaaColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: OutlinedButton.icon(
              key: const Key('account-sign-out'),
              onPressed: _signingOut ? null : _signOut,
              icon: _signingOut
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout_rounded),
              label: Text(_signingOut ? 'جارٍ تسجيل الخروج...' : 'تسجيل الخروج'),
            ),
          ),
        ),
      ),
    );
  }
}
