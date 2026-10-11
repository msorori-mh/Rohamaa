import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/account_repository.dart';
import '../../data/handoff_repository.dart';
import '../../domain/staff_labels.dart';
import 'account_status_screens.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.role, this.requiredChange = true, this.onChanged});
  final String role;

  /// Called after a successful forced change so the host can reload the
  /// account state. When null the screen navigates to the role's home route.
  final VoidCallback? onChanged;

  /// True when the server forces a new password (temporary password or first
  /// setup). The current password is not asked for in that case.
  final bool requiredChange;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _obscureCurrent = true;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validateCurrent(String? value) {
    if (widget.requiredChange) return null;
    if ((value ?? '').isEmpty) return 'أدخل كلمة المرور الحالية';
    return null;
  }

  String? _validate(String? value) {
    final v = value ?? '';
    if (v.length < 8) return 'استخدم 8 أحرف على الأقل';
    if (!RegExp(r'[a-z]').hasMatch(v) || !RegExp(r'[A-Z]').hasMatch(v) || !RegExp(r'[0-9]').hasMatch(v) || !RegExp(r'[^A-Za-z0-9]').hasMatch(v)) {
      return 'يجب أن تحتوي على حرف كبير وصغير ورقم ورمز';
    }
    if (!widget.requiredChange && v == _current.text) {
      return 'اختر كلمة مرور مختلفة عن الحالية';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if ((value ?? '').isEmpty) return 'أعد إدخال كلمة المرور';
    if (value != _password.text) return 'كلمتا المرور غير متطابقتين';
    return null;
  }

  Future<void> _save() async {
    if (_busy) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _busy = true);
    try {
      await AccountRepository(Supabase.instance.client).changeStaffPassword(
        password: _password.text,
        currentPassword: widget.requiredChange ? null : _current.text,
      );
      if (!mounted) return;
      // The repository drops the local session after a successful change:
      // the server may already have ended it.
      final signedOut = signedOutDespiteError();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              signedOut
                  ? StaffLabels.passwordChangedMessage
                  : 'تم تغيير كلمة المرور.',
            ),
          ),
        );
      if (signedOut) {
        HandoffRepository.clearIssuedPins();
        context.go('/login');
        return;
      }
      if (!widget.requiredChange && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
        return;
      }
      final onChanged = widget.onChanged;
      if (onChanged != null) {
        onChanged();
        return;
      }
      final route = switch (widget.role) {
        'admin' => '/admin',
        'supervisor' => '/supervisor',
        'courier' => '/courier',
        _ => '/home',
      };
      context.go(route);
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'لم يتم تغيير كلمة المرور. تحقق من البيانات ثم حاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.requiredChange ? 'تعيين كلمة مرور جديدة' : 'تغيير كلمة المرور')),
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
                Text('حماية حساب فريق عطاء', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  widget.requiredChange
                      ? 'كلمة المرور الحالية مؤقتة أو أن هذه أول تهيئة لحساب الفريق. عيّن كلمة مرور خاصة بك قبل المتابعة.'
                      : 'يمكنك تغيير كلمة مرور حساب فريق عطاء في أي وقت. استخدم كلمة قوية لا تستخدمها في خدمات أخرى.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                if (!widget.requiredChange) ...[
                  TextFormField(
                    key: const Key('current-password-field'),
                    controller: _current,
                    enabled: !_busy,
                    obscureText: _obscureCurrent,
                    validator: _validateCurrent,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الحالية',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        icon: Icon(_obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  key: const Key('new-password-field'),
                  controller: _password,
                  enabled: !_busy,
                  obscureText: _obscure,
                  validator: _validate,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: 'كلمة المرور الجديدة', suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('confirm-password-field'),
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: _obscure,
                  validator: _validateConfirm,
                  decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'جارٍ الحفظ...' : 'حفظ')),
                if (widget.requiredChange) ...[
                  const SizedBox(height: 10),
                  const SignOutButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
