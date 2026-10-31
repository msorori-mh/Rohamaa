import 'package:flutter/foundation.dart';

/// Message shown on the login screen after the web build signed out an
/// account that is not part of the Ataa team.
///
/// The browser build is the staff area only. A signed-in person without a
/// staff role is signed out and the router then lands on the login screen,
/// so the reason is handed over through this notifier.
abstract final class WebStaffNotice {
  static final ValueNotifier<String?> message = ValueNotifier<String?>(null);

  static const notStaffMessage =
      'هذه البوابة مخصصة لفريق عطاء فقط (الإدارة والمشرفين والموصلين). '
      'تم تسجيل خروجك. استخدم تطبيق عطاء على هاتفك للمشاركة في العطاء.';
}
