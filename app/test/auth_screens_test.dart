import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/account_state.dart';
import 'package:ruhamaa/src/features/auth/account_status_screens.dart';
import 'package:ruhamaa/src/features/auth/change_password_screen.dart';
import 'package:ruhamaa/src/theme/ruhamaa_theme.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: RuhamaaTheme.light(),
    home: Directionality(textDirection: TextDirection.rtl, child: child),
  );
}

void main() {
  group('ChangePasswordScreen', () {
    testWidgets('a voluntary change asks for the current password', (tester) async {
      await tester.pumpWidget(
        _host(const ChangePasswordScreen(role: 'admin', requiredChange: false)),
      );

      expect(find.byKey(const Key('current-password-field')), findsOneWidget);

      final save = find.text('حفظ');
      await tester.ensureVisible(save);
      await tester.pump();
      await tester.tap(save);
      await tester.pump();

      expect(find.text('أدخل كلمة المرور الحالية'), findsOneWidget);
      expect(find.text('استخدم 8 أحرف على الأقل'), findsOneWidget);
    });

    testWidgets('a forced change hides the current password field', (tester) async {
      await tester.pumpWidget(_host(const ChangePasswordScreen(role: 'courier')));

      expect(find.byKey(const Key('current-password-field')), findsNothing);
      expect(find.byKey(const Key('new-password-field')), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
    });

    testWidgets('mismatched confirmation is reported inline', (tester) async {
      await tester.pumpWidget(_host(const ChangePasswordScreen(role: 'courier')));

      await tester.enterText(find.byKey(const Key('new-password-field')), 'Strong#Pass1');
      await tester.enterText(find.byKey(const Key('confirm-password-field')), 'Strong#Pass2');
      final save = find.text('حفظ');
      await tester.ensureVisible(save);
      await tester.pump();
      await tester.tap(save);
      await tester.pump();

      expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
    });
  });

  group('AccountBlockedScreen', () {
    testWidgets('a suspended account gets a dedicated screen with sign-out', (tester) async {
      await tester.pumpWidget(_host(const AccountBlockedScreen(gate: AccountGate.suspended)));

      expect(find.text('حسابك موقوف'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
      expect(find.text(kSupportEmail), findsOneWidget);
    });

    testWidgets('a deletion in progress is explained', (tester) async {
      await tester.pumpWidget(
        _host(const AccountBlockedScreen(gate: AccountGate.deletionProcessing)),
      );

      expect(find.text('طلب حذف الحساب قيد التنفيذ'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
    });
  });
}
