import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.sanad.app://login-callback',
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تسجيل الدخول. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.handshake_outlined, size: 72),
              const SizedBox(height: 20),
              Text('سند', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('ما لا تحتاجه قد يصنع فرقًا لشخص آخر.', textAlign: TextAlign.center),
              const SizedBox(height: 36),
              FilledButton.icon(
                onPressed: _loading ? null : _signIn,
                icon: const Icon(Icons.login),
                label: Text(_loading ? 'جارٍ تسجيل الدخول...' : 'المتابعة بحساب Google'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              const Text(
                'لا نستخدم رسائل SMS لتسجيل الدخول. رقم الهاتف يُستخدم فقط عند الحاجة التشغيلية للتوصيل.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
