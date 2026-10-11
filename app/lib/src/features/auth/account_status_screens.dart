import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_error.dart';
import '../../data/handoff_repository.dart';
import '../../domain/account_state.dart';
import '../../theme/ruhamaa_theme.dart';

const String kSupportEmail = 'support@ruhamaa.com';

/// True when a sign-out that reported an error still removed the session on
/// this device. Offline, the server call fails after the local session is
/// already cleared: the person is signed out and must not see an error.
bool signedOutDespiteError() {
  try {
    return Supabase.instance.client.auth.currentSession == null;
  } catch (_) {
    return false;
  }
}

/// Signs out and reports a friendly message on failure. The router sends the
/// person to the login screen as soon as the session is gone.
class SignOutButton extends StatefulWidget {
  const SignOutButton({super.key, this.filled = false});

  final bool filled;

  @override
  State<SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<SignOutButton> {
  bool _busy = false;

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.signOut();
      HandoffRepository.clearIssuedPins();
    } catch (error) {
      if (signedOutDespiteError()) {
        HandoffRepository.clearIssuedPins();
      } else if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'لم يكتمل تسجيل الخروج. تحقق من اتصالك ثم حاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = Text(_busy ? 'جارٍ تسجيل الخروج...' : 'تسجيل الخروج');
    const icon = Icon(Icons.logout_rounded);
    if (widget.filled) {
      return FilledButton.icon(
        onPressed: _busy ? null : _signOut,
        icon: icon,
        label: label,
      );
    }
    return OutlinedButton.icon(
      onPressed: _busy ? null : _signOut,
      icon: icon,
      label: label,
    );
  }
}

/// Shown when the account state could not be loaded (for example offline).
/// Never claims the person lacks permission: the cause is unknown.
class AccountLoadErrorScreen extends StatelessWidget {
  const AccountLoadErrorScreen({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عطاء')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: ErrorRetry(error: error, onRetry: onRetry)),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(width: double.infinity, child: SignOutButton()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dedicated screen for an account that may not use the app: suspended, or
/// with an account deletion in progress / completed.
class AccountBlockedScreen extends StatelessWidget {
  const AccountBlockedScreen({super.key, required this.gate});

  final AccountGate gate;

  String get _title => switch (gate) {
        AccountGate.suspended => 'حسابك موقوف',
        AccountGate.deleted => 'تم حذف الحساب',
        _ => 'طلب حذف الحساب قيد التنفيذ',
      };

  String get _body => switch (gate) {
        AccountGate.suspended =>
          'أوقف فريق عطاء هذا الحساب مؤقتًا، لذلك لا يمكن استخدام التطبيق الآن. إذا كنت ترى أن ذلك حدث بالخطأ فتواصل معنا.',
        AccountGate.deleted =>
          'اكتمل حذف هذا الحساب وبياناته بناءً على طلبك. يمكنك تسجيل الخروج، وإن رغبت بالعودة فتواصل مع فريق عطاء.',
        _ =>
          'يعمل فريق عطاء على تنفيذ طلب حذف حسابك وبياناتك، ولا يمكن استخدام الحساب خلال هذه المرحلة. للاستفسار تواصل معنا.',
      };

  IconData get _icon => switch (gate) {
        AccountGate.suspended => Icons.block_rounded,
        AccountGate.deleted => Icons.person_off_outlined,
        _ => Icons.hourglass_top_rounded,
      };

  Future<void> _contact(BuildContext context) async {
    final uri = Uri(scheme: 'mailto', path: kSupportEmail);
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }
    if (opened) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('راسلنا على البريد: $kSupportEmail'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(28),
              children: [
                Icon(_icon, size: 64, color: RuhamaaColors.warmGold),
                const SizedBox(height: 18),
                Text(
                  _title,
                  key: const Key('account-blocked-title'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: RuhamaaColors.primaryDark,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  _body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: RuhamaaColors.textMuted,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  kSupportEmail,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: RuhamaaColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                OutlinedButton.icon(
                  onPressed: () => _contact(context),
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: const Text('تواصل مع فريق عطاء'),
                ),
                const SizedBox(height: 10),
                const SignOutButton(filled: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
