import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  static final _privacy = Uri.parse('https://ruhamaa.com/privacy/');
  static final _terms = Uri.parse('https://ruhamaa.com/terms/');
  static final _deleteAccount = Uri.parse('https://ruhamaa.com/delete-account/');

  bool _requestingDeletion = false;

  Future<void> _open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الرابط. حاول مرة أخرى لاحقًا.')),
      );
    }
  }

  Future<void> _requestDeletion() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await _open(_deleteAccount);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طلب حذف الحساب'),
        content: const Text(
          'سيتم تسجيل طلب حذف حسابك وبياناتك الشخصية. إذا كانت لديك عملية استلام أو توصيل جارية، تُستكمل أو تُغلق تشغيليًا أولًا ثم يُنفذ الحذف. لا يؤثر تقديم الطلب على أي حق لك في الخصوصية.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إرسال طلب الحذف')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _requestingDeletion = true);
    try {
      await Supabase.instance.client.rpc('request_account_deletion');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل طلب حذف الحساب.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تسجيل طلب الحذف: $e')),
      );
    } finally {
      if (mounted) setState(() => _requestingDeletion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الخصوصية والحساب')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'رحماء يحافظ على خصوصية المتبرع والمستفيد، ويستخدم البيانات الشخصية فقط لتسجيل الحساب والمطابقة والتشغيل والتوصيل والسلامة.',
          ),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('سياسة الخصوصية'),
                  subtitle: const Text('ما نجمعه، لماذا نستخدمه، وكيف نحميه ونحذفه.'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _open(_privacy),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('شروط الاستخدام'),
                  subtitle: const Text('قواعد الاستخدام والمطابقة والتوصيل والمساهمات التشغيلية.'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _open(_terms),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('حذف الحساب والبيانات'),
                  subtitle: const Text('اطلب حذف حسابك والبيانات المرتبطة به.'),
                  trailing: _requestingDeletion
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_left),
                  onTap: _requestingDeletion ? null : _requestDeletion,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _open(_deleteAccount),
            icon: const Icon(Icons.language_outlined),
            label: const Text('صفحة حذف الحساب على ruhamaa.com'),
          ),
        ],
      ),
    );
  }
}
