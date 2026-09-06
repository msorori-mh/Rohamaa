import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/staff_repository.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.role});
  final String role;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final v = value ?? '';
    if (v.length < 8) return 'استخدم 8 أحرف على الأقل';
    if (!RegExp(r'[a-z]').hasMatch(v) || !RegExp(r'[A-Z]').hasMatch(v) || !RegExp(r'[0-9]').hasMatch(v) || !RegExp(r'[^A-Za-z0-9]').hasMatch(v)) {
      return 'يجب أن تحتوي على حرف كبير وصغير ورقم ورمز';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمتا المرور غير متطابقتين')));
      return;
    }
    setState(() => _busy = true);
    try {
      await StaffRepository(Supabase.instance.client).changePassword(_password.text);
      if (!mounted) return;
      final route = switch (widget.role) {
        'admin' => '/admin',
        'supervisor' => '/supervisor',
        'courier' => '/courier',
        _ => '/home',
      };
      context.go(route);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعيين كلمة مرور جديدة')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.lock_reset_outlined, size: 64),
                const SizedBox(height: 18),
                Text('حماية حساب فريق سند', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('هذه أول مرة تستخدم فيها حساب الفريق أو أن كلمة المرور الحالية مؤقتة. عيّن كلمة مرور خاصة بك قبل المتابعة.', textAlign: TextAlign.center),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  validator: _validate,
                  decoration: InputDecoration(labelText: 'كلمة المرور الجديدة', suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
                ),
                const SizedBox(height: 14),
                TextFormField(controller: _confirm, obscureText: _obscure, validator: (v) => (v ?? '').isEmpty ? 'أعد إدخال كلمة المرور' : null, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور')),
                const SizedBox(height: 24),
                FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'جارٍ الحفظ...' : 'حفظ والمتابعة')),
                const SizedBox(height: 10),
                TextButton(onPressed: _busy ? null : () => Supabase.instance.client.auth.signOut(), child: const Text('تسجيل الخروج')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
