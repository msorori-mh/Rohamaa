import 'package:flutter/foundation.dart';

/// Last sign-in callback failure reported by the auth stream.
///
/// A failed OAuth callback (cancelled consent, expired or reused code) is
/// delivered as a stream error, often before the login screen exists again.
/// The app-wide auth listener stores it here and the login screen shows it
/// once, so the person never lands on a silent login page.
abstract final class AuthCallbackError {
  static final ValueNotifier<Object?> last = ValueNotifier<Object?>(null);

  static const fallbackMessage =
      'لم يكتمل تسجيل الدخول. حاول مرة أخرى أو استخدم حسابًا آخر.';
}
