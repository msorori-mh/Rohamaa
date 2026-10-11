import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../theme/ruhamaa_theme.dart';

const _authRedirectUrl = String.fromEnvironment(
  'AUTH_REDIRECT_URL',
  defaultValue: 'com.ruhamaa.app://login-callback',
);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (auth.currentSession != null) _openApp();
    });
  }

  void _openApp() {
    if (!mounted) return;
    context.go('/');
  }

  @override
  void dispose() {
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

  Future<void> _staffLogin() async {
    await showDialog<void>(
      context: context,
      // The dialog owns its busy state; it is closed only by its own buttons
      // so a sign-in in progress is never interrupted by a stray tap.
      barrierDismissible: false,
      builder: (_) => const _StaffLoginDialog(),
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
                  onPressed: _loading ? null : _staffLogin,
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('دخول فريق عطاء'),
                ),
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

class _StaffLoginDialog extends StatefulWidget {
  const _StaffLoginDialog();

  @override
  State<_StaffLoginDialog> createState() => _StaffLoginDialogState();
}

class _StaffLoginDialogState extends State<_StaffLoginDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'أدخل البريد الإلكتروني وكلمة المرور.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // A successful sign-in may already have replaced the login page (and
      // this dialog with it) through the router redirect.
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      debugPrint('Staff sign-in failed: ${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(
          error,
          fallback: 'لم يكتمل تسجيل الدخول. تحقق من البيانات ثم حاول مرة أخرى.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('دخول فريق عطاء'),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('للإدارة، مشرفي المدن/المناطق، والموصلين.'),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('staff-login-email'),
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('staff-login-password'),
                  controller: _password,
                  enabled: !_busy,
                  obscureText: _obscure,
                  textDirection: TextDirection.ltr,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    suffixIcon: IconButton(
                      onPressed: _busy ? null : () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const Key('staff-login-submit'),
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'جارٍ الدخول...' : 'دخول'),
          ),
        ],
      ),
    );
  }
}
