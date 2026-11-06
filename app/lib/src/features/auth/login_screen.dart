import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../core/auth_callback_error.dart';
import '../../core/web_staff_notice.dart';
import '../../theme/ruhamaa_theme.dart';

const _authRedirectUrl = String.fromEnvironment(
  'AUTH_REDIRECT_URL',
  defaultValue: 'com.ruhamaa.app://login-callback',
);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.staffOnly = kIsWeb});

  /// Browser build: only the team sign-in is offered (no Google, no
  /// community wording).
  final bool staffOnly;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    _authSubscription = auth.onAuthStateChange.listen((data) {
      debugPrint('Login auth event: ${data.event}; session=${data.session != null}');
      if (data.session != null) _openApp();
    }, onError: (Object error) {
      debugPrint('Login auth callback failed: ${error.runtimeType}');
      _showCallbackError(error);
    });
    AuthCallbackError.last.addListener(_onCallbackError);
    WebStaffNotice.message.addListener(_onWebStaffNotice);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (auth.currentSession != null) {
        _openApp();
        return;
      }
      // A callback that failed before this screen was built.
      _onCallbackError();
      _onWebStaffNotice();
    });
  }

  void _onWebStaffNotice() {
    final message = WebStaffNotice.message.value;
    if (message == null) return;
    WebStaffNotice.message.value = null;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  void _onCallbackError() {
    final error = AuthCallbackError.last.value;
    if (error == null) return;
    AuthCallbackError.last.value = null;
    _showCallbackError(error);
  }

  void _showCallbackError(Object error) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = friendlyError(
        error,
        fallback: AuthCallbackError.fallbackMessage,
      );
    });
  }

  void _openApp() {
    if (!mounted) return;
    // While the email screen is open on top, it finishes its own steps
    // (password, name) before entering the app.
    if (ModalRoute.of(context)?.isCurrent == false) return;
    context.go('/');
  }

  @override
  void dispose() {
    AuthCallbackError.last.removeListener(_onCallbackError);
    WebStaffNotice.message.removeListener(_onWebStaffNotice);
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _authRedirectUrl,
      );
    } catch (error) {
      debugPrint('Google sign-in failed: ${error.runtimeType}');
      if (mounted) {
        setState(
          () => _error = friendlyError(
            error,
            fallback: 'لم يكتمل تسجيل الدخول بحساب Google. حاول مرة أخرى أو استخدم حسابًا آخر.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _emailAuth() => context.push('/email-auth');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              children: [
                const Center(child: RuhamaaBrandMark(size: 96)),
                const SizedBox(height: 8),
                Text(
                  'عطاء',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: RuhamaaColors.primaryDark,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ما لديك قد يصنع فرقًا',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: RuhamaaColors.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                if (widget.staffOnly) ...[
                  const Text(
                    'بوابة فريق عطاء',
                    key: Key('login-staff-only-heading'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: RuhamaaColors.primaryDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'للإدارة، مشرفي المدن/المناطق، والموصلين.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('login-staff-button'),
                    onPressed: _loading ? null : _emailAuth,
                    icon: const Icon(Icons.mail_outline_rounded),
                    label: const Text('تسجيل الدخول بالبريد الإلكتروني'),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: RuhamaaColors.softGreen,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.handshake_rounded, color: RuhamaaColors.primary, size: 46),
                        SizedBox(height: 10),
                        Text(
                          'تبرّع أو اطلب المساعدة بخصوصية',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: RuhamaaColors.primaryDark,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'يراجع عطاء الطلبات وينسّق الاستلام والتسليم دون عرض بياناتك للآخرين.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _loading ? null : _googleSignIn,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(_loading ? 'جارٍ تسجيل الدخول...' : 'المتابعة بحساب Google'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('login-email-button'),
                    onPressed: _loading ? null : _emailAuth,
                    icon: const Icon(Icons.mail_outline_rounded),
                    label: const Text('التسجيل أو الدخول بالبريد الإلكتروني'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                    ),
                  ),
                ],
                if (!widget.staffOnly) ...[
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 17, color: RuhamaaColors.primary),
                      SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'نستخدم بيانات حساب Google لتسجيل الدخول فقط، ولا نصل إلى Gmail أو Drive.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/legal'),
                  child: const Text('الخصوصية والشروط'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
