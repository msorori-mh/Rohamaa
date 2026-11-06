import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../theme/ruhamaa_theme.dart';

enum _Step { signIn, registerEmail, registerCode, registerPassword, registerName, resetEmail, resetCode, resetPassword }

/// Email sign-in and registration. Registration: email -> code -> password
/// (+ confirmation) -> name. Team members sign in here like everyone else; the
/// session landing screen routes them by role.
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key, this.allowRegister = true});

  final bool allowRegister;

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _name = TextEditingController();
  _Step _step = _Step.signIn;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    _name.dispose();
    super.dispose();
  }

  void _go(_Step step) => setState(() {
        _step = step;
        _error = null;
      });

  Future<void> _run(Future<void> Function() action, String fallback) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      debugPrint('Email auth failed: ${error.runtimeType}');
      if (mounted) setState(() => _error = friendlyError(error, fallback: fallback));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _emailValid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  bool _passwordOk() {
    if (_password.text.length < 8) {
      setState(() => _error = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.');
      return false;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين.');
      return false;
    }
    return true;
  }

  Future<void> _signIn() => _run(() async {
        if (!_emailValid || _password.text.isEmpty) {
          setState(() => _error = 'أدخل البريد الإلكتروني وكلمة المرور.');
          return;
        }
        await _auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
        if (mounted) context.go('/');
      }, 'لم يكتمل تسجيل الدخول. تحقق من البيانات ثم حاول مرة أخرى.');

  Future<void> _sendCode({required bool reset}) => _run(() async {
        if (!_emailValid) {
          setState(() => _error = 'أدخل بريدًا إلكترونيًا صحيحًا.');
          return;
        }
        await _auth.signInWithOtp(email: _email.text.trim(), shouldCreateUser: !reset);
        _code.clear();
        _go(reset ? _Step.resetCode : _Step.registerCode);
      }, 'تعذّر إرسال الرمز. تحقق من البريد وحاول مرة أخرى.');

  Future<void> _verifyCode({required bool reset}) => _run(() async {
        final code = _code.text.trim();
        if (code.length < 6) {
          setState(() => _error = 'أدخل الرمز المكوّن من 6 أرقام.');
          return;
        }
        await _auth.verifyOTP(email: _email.text.trim(), token: code, type: OtpType.email);
        _go(reset ? _Step.resetPassword : _Step.registerPassword);
      }, 'الرمز غير صحيح أو انتهت صلاحيته.');

  Future<void> _savePassword({required bool reset}) => _run(() async {
        if (!_passwordOk()) return;
        await _auth.updateUser(UserAttributes(password: _password.text));
        if (reset) {
          if (mounted) context.go('/');
        } else {
          _go(_Step.registerName);
        }
      }, 'تعذّر حفظ كلمة المرور. حاول مرة أخرى.');

  Future<void> _saveName() => _run(() async {
        final name = _name.text.trim();
        if (name.isEmpty) {
          setState(() => _error = 'أدخل اسمك.');
          return;
        }
        await _auth.updateUser(UserAttributes(data: {'full_name': name}));
        if (mounted) context.go('/');
      }, 'تعذّر حفظ البيانات. حاول مرة أخرى.');

  InputDecoration _dec(String label, {Widget? suffix}) =>
      InputDecoration(labelText: label, suffixIcon: suffix);

  Widget _emailField() => TextField(
        key: const Key('auth-email'),
        controller: _email,
        enabled: !_busy,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textDirection: TextDirection.ltr,
        decoration: _dec('البريد الإلكتروني'),
      );

  Widget _codeField() => TextField(
        key: const Key('auth-code'),
        controller: _code,
        enabled: !_busy,
        keyboardType: TextInputType.number,
        textDirection: TextDirection.ltr,
        maxLength: 6,
        decoration: _dec('رمز التحقق (6 أرقام)'),
      );

  Widget _passwordFields({bool confirm = false}) => Column(children: [
        TextField(
          key: const Key('auth-password'),
          controller: _password,
          enabled: !_busy,
          obscureText: _obscure,
          textDirection: TextDirection.ltr,
          onSubmitted: confirm ? null : (_) => _signIn(),
          decoration: _dec(
            'كلمة المرور',
            suffix: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
          ),
        ),
        if (confirm) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('auth-password-confirm'),
            controller: _confirm,
            enabled: !_busy,
            obscureText: _obscure,
            textDirection: TextDirection.ltr,
            decoration: _dec('تأكيد كلمة المرور'),
          ),
        ],
      ]);

  Widget _primary(String label, VoidCallback onPressed, {Key? key}) => FilledButton(
        key: key,
        onPressed: _busy ? null : onPressed,
        child: Text(_busy ? 'لحظة...' : label),
      );

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _Step.signIn => 'تسجيل الدخول',
      _Step.registerEmail => 'إنشاء حساب',
      _Step.registerCode || _Step.resetCode => 'أدخل رمز التحقق',
      _Step.registerPassword || _Step.resetPassword => 'اختر كلمة مرور',
      _Step.registerName => 'بقي خطوة واحدة',
      _Step.resetEmail => 'استعادة كلمة المرور',
    };
    final reset = _step == _Step.resetEmail || _step == _Step.resetCode || _step == _Step.resetPassword;
    final children = <Widget>[
      Text(title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: RuhamaaColors.primaryDark, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 20),
      switch (_step) {
        _Step.signIn => Column(children: [
            _emailField(),
            const SizedBox(height: 12),
            _passwordFields(),
            const SizedBox(height: 18),
            _primary('دخول', _signIn, key: const Key('auth-signin-submit')),
            TextButton(onPressed: _busy ? null : () => _go(_Step.resetEmail), child: const Text('نسيت كلمة المرور؟')),
            if (widget.allowRegister)
              TextButton(
                  onPressed: _busy ? null : () => _go(_Step.registerEmail),
                  child: const Text('ليس لديك حساب؟ أنشئ حسابًا')),
          ]),
        _Step.registerEmail || _Step.resetEmail => Column(children: [
            _emailField(),
            const SizedBox(height: 18),
            _primary('إرسال رمز التحقق', () => _sendCode(reset: reset), key: const Key('auth-send-code')),
            TextButton(onPressed: _busy ? null : () => _go(_Step.signIn), child: const Text('لدي حساب، تسجيل الدخول')),
          ]),
        _Step.registerCode || _Step.resetCode => Column(children: [
            Text('أرسلنا رمزًا إلى ${_email.text.trim()}', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            _codeField(),
            const SizedBox(height: 10),
            _primary('تأكيد', () => _verifyCode(reset: reset), key: const Key('auth-verify-code')),
            TextButton(onPressed: _busy ? null : () => _sendCode(reset: reset), child: const Text('إعادة إرسال الرمز')),
          ]),
        _Step.registerPassword || _Step.resetPassword => Column(children: [
            _passwordFields(confirm: true),
            const SizedBox(height: 18),
            _primary('متابعة', () => _savePassword(reset: reset), key: const Key('auth-save-password')),
          ]),
        _Step.registerName => Column(children: [
            TextField(
              key: const Key('auth-name'),
              controller: _name,
              enabled: !_busy,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveName(),
              decoration: _dec('الاسم'),
            ),
            const SizedBox(height: 18),
            _primary('إنهاء التسجيل', _saveName, key: const Key('auth-save-name')),
          ]),
      },
      if (_error != null) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
        ),
      ],
    ];
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(padding: const EdgeInsets.all(24), children: children),
          ),
        ),
      ),
    );
  }
}
