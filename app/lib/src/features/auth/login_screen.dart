import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
                  onSubmitted: (_) {},
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
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.handshake_outlined, size: 72),
                const SizedBox(height: 20),
                Text(
                  'رحماء',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text('ما لديك قد يصنع فرقًا.', textAlign: TextAlign.center),
                const SizedBox(height: 36),
                FilledButton.icon(
                  onPressed: _loading ? null : _googleSignIn,
                  icon: const Icon(Icons.login),
                  label: Text(_loading ? 'جارٍ تسجيل الدخول...' : 'المتابعة بحساب Google'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _staffLogin,
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('دخول فريق رحماء'),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => context.push('/legal'),
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: const Text('الخصوصية والشروط وحذف الحساب'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'نستخدم بيانات حساب Google الأساسية لتسجيل الدخول فقط. لا نطلب صلاحيات Gmail أو Drive. رقم الهاتف والموقع يُستخدمان عند الحاجة التشغيلية للاستلام والتوصيل.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                const Text(
                  'عند تهيئة حساب الإدارة الرئيسي لأول مرة، استخدم Google بالبريد المعتمد، ثم سيطلب رحماء تعيين كلمة مرور خاصة بفريق التشغيل.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
