import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _authRedirectUrl,
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = 'تعذر تسجيل الدخول: ${e.message}');
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تسجيل الدخول بحساب Google. حاول مرة أخرى.');
      debugPrint('Google OAuth launch error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _staffLogin() async {
    final email = TextEditingController();
    final password = TextEditingController();
    bool busy = false;
    bool obscure = true;
    String? dialogError;

    await showDialog<void>(
      context: context,
      barrierDismissible: !busy,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('دخول فريق رحماء'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('للإدارة، مشرفي المدن/المناطق، والموصلين.'),
                const SizedBox(height: 16),
                TextField(
                  controller: email,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  enabled: !busy,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    suffixIcon: IconButton(
                      onPressed: busy ? null : () => setDialogState(() => obscure = !obscure),
                      icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(dialogError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (email.text.trim().isEmpty || password.text.isEmpty) return;
                      setDialogState(() {
                        busy = true;
                        dialogError = null;
                      });
                      try {
                        await Supabase.instance.client.auth.signInWithPassword(
                          email: email.text.trim(),
                          password: password.text,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } on AuthException catch (e) {
                        setDialogState(() {
                          busy = false;
                          dialogError = e.message;
                        });
                      } catch (_) {
                        setDialogState(() {
                          busy = false;
                          dialogError = 'تعذر تسجيل الدخول. تحقق من البيانات.';
                        });
                      }
                    },
              child: Text(busy ? 'جارٍ الدخول...' : 'دخول'),
            ),
          ],
        ),
      ),
    );
    email.dispose();
    password.dispose();
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
                  'رحماء',
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
                        'من الناس إلى الناس، بخصوصية وكرامة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: RuhamaaColors.primaryDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'رحماء يتولى المطابقة والتنسيق والتوصيل دون كشف هوية المتبرع والمستفيد لبعضهما.',
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
                  label: const Text('دخول فريق رحماء'),
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
                        'نستخدم بيانات Google الأساسية لتسجيل الدخول فقط؛ لا نطلب الوصول إلى Gmail أو Drive.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/legal'),
                  child: const Text('الخصوصية والشروط وحذف الحساب'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
