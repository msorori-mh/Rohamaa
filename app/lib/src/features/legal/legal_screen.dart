import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_error.dart';
import '../../data/account_repository.dart';
import '../../theme/ruhamaa_theme.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  static final _privacy = Uri.parse('https://ruhamaa.com/privacy/');
  static final _terms = Uri.parse('https://ruhamaa.com/terms/');
  static final _deleteAccount = Uri.parse('https://ruhamaa.com/delete-account/');

  bool _busy = false;

  /// Latest deletion request status for the signed-in person, or null when
  /// there is none (or it could not be loaded).
  String? _deletionStatus;

  bool get _signedIn => Supabase.instance.client.auth.currentUser != null;
  bool get _hasOpenRequest =>
      _deletionStatus == 'pending' || _deletionStatus == 'processing';

  @override
  void initState() {
    super.initState();
    if (_signedIn) _loadStatus();
  }

  /// The status is extra information: when it cannot be loaded the screen
  /// still works, so a failure here stays silent.
  Future<void> _loadStatus() async {
    try {
      final state = await AccountRepository(Supabase.instance.client).myState();
      if (!mounted) return;
      setState(() => _deletionStatus = state.deletionStatus);
    } catch (error) {
      debugPrint('Ataa deletion status load failed: ${error.runtimeType}');
    }
  }

  Future<void> _open(Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Ataa link open failed: ${error.runtimeType}');
    }
    if (opened) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لم يُفتح الرابط. حاول مرة أخرى لاحقًا.')),
    );
  }

  Future<void> _requestDeletion() async {
    if (_busy) return;
    if (!_signedIn) {
      await _open(_deleteAccount);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طلب حذف الحساب'),
        content: const Text(
          'سيتم تسجيل طلب حذف حسابك وبياناتك الشخصية. إذا كانت لديك عملية استلام أو توصيل أو خدمة جارية، تُستكمل أو تُغلق تشغيليًا أولًا ثم يُنفذ الحذف. قد تُحفظ سجلات محدودة عند الضرورة لمعالجة بلاغ سلامة أو منع إساءة الاستخدام، وفق سياسة الخصوصية.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إرسال طلب الحذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    if (_busy) return;

    setState(() => _busy = true);
    try {
      await AccountRepository(Supabase.instance.client).requestDeletion();
      if (!mounted) return;
      setState(() => _deletionStatus = 'pending');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل طلب حذف الحساب.')),
      );
      await _loadStatus();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'لم يُرسل طلب الحذف. تحقق من اتصالك ثم حاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelDeletion() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء طلب الحذف؟'),
        content: const Text('سيبقى حسابك وبياناتك كما هي، ويمكنك طلب الحذف مجددًا في أي وقت.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
          FilledButton(
            key: const Key('confirm-cancel-deletion'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إلغاء طلب الحذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    if (_busy) return;

    setState(() => _busy = true);
    try {
      await AccountRepository(Supabase.instance.client).cancelDeletionRequest();
      if (!mounted) return;
      setState(() => _deletionStatus = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أُلغي طلب حذف الحساب.')),
      );
      await _loadStatus();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'لم يُلغَ طلب الحذف. حاول مرة أخرى أو تواصل مع فريق عطاء.',
        );
      }
      // The request may have moved on (e.g. to processing) in the meantime.
      await _loadStatus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget? _statusCard() {
    final status = _deletionStatus;
    if (status == null) return null;
    final (IconData icon, String title, String body) = switch (status) {
      'pending' => (
          Icons.hourglass_empty_rounded,
          'طلب حذف الحساب قيد الانتظار',
          'استلمنا طلبك وسيراجعه فريق عطاء. يمكنك إلغاء الطلب ما دام قيد الانتظار.',
        ),
      'processing' => (
          Icons.hourglass_top_rounded,
          'طلب حذف الحساب قيد التنفيذ',
          'بدأ فريق عطاء تنفيذ الحذف، ولم يعد إلغاء الطلب ممكنًا من التطبيق.',
        ),
      'rejected' => (
          Icons.info_outline_rounded,
          'لم يُنفَّذ طلب الحذف السابق',
          'يمكنك إرسال طلب جديد، أو التواصل مع فريق عطاء لمعرفة السبب.',
        ),
      'completed' => (
          Icons.check_circle_outline_rounded,
          'اكتمل حذف الحساب',
          'تم تنفيذ طلب حذف حسابك وبياناتك.',
        ),
      _ => (
          Icons.info_outline_rounded,
          'طلب حذف الحساب',
          'لديك طلب حذف مسجّل. تواصل مع فريق عطاء للاستفسار عن حالته.',
        ),
    };
    return Container(
      key: const Key('deletion-status-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RuhamaaColors.warmGoldSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: RuhamaaColors.warmGold),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: RuhamaaColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: const TextStyle(color: RuhamaaColors.primaryDark, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                key: const Key('cancel-deletion-request'),
                onPressed: _busy ? null : _cancelDeletion,
                icon: const Icon(Icons.undo_rounded),
                label: const Text('إلغاء طلب الحذف'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusCard = _statusCard();
    final deletionSubtitle = switch (_deletionStatus) {
      'pending' => 'لديك طلب حذف قيد الانتظار.',
      'processing' => 'طلب الحذف قيد التنفيذ.',
      _ => 'اطلب حذف حسابك والبيانات المرتبطة به.',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('الخصوصية والحساب')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'نحافظ على خصوصية بياناتك، ولا نشارك إلا ما يلزم لإتمام الاستلام أو التسليم أو الخدمة بعد الموافقة.',
          ),
          const SizedBox(height: 18),
          if (statusCard != null) ...[
            statusCard,
            const SizedBox(height: 18),
          ],
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('سياسة الخصوصية'),
                  subtitle: const Text('الحساب، الموقع، الصور، الاحتياجات، الخدمات، الشركاء، البلاغات والحذف.'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _open(_privacy),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('شروط الاستخدام'),
                  subtitle: const Text('قواعد الأشياء والمطابقة والتوصيل والوقت والمهارات وشركاء عطاء.'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _open(_terms),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('حذف الحساب والبيانات'),
                  subtitle: Text(deletionSubtitle),
                  trailing: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : _hasOpenRequest
                          ? null
                          : const Icon(Icons.chevron_right),
                  enabled: !_hasOpenRequest,
                  onTap: _busy || _hasOpenRequest ? null : _requestDeletion,
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
