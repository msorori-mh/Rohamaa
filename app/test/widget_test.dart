import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/features/profile/account_screen.dart';
import 'package:ruhamaa/src/theme/ruhamaa_theme.dart';

void main() {
  testWidgets('renders Ruhamaa Arabic RTL smoke widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Center(child: Text('رحماء'))),
        ),
      ),
    );

    expect(find.text('رحماء'), findsOneWidget);
  });

  testWidgets('account sign-out action stays visible on a compact phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        theme: RuhamaaTheme.light(),
        home: AccountScreen(
          email: 'user@example.com',
          onSignOut: () async {},
        ),
      ),
    );

    final signOut = find.byKey(const Key('account-sign-out'));
    expect(signOut, findsOneWidget);
    expect(tester.getTopLeft(signOut).dy, greaterThanOrEqualTo(0));
    expect(tester.getBottomRight(signOut).dy, lessThanOrEqualTo(640));
  });

  testWidgets('account sign-out requires confirmation and invokes handler', (tester) async {
    var signOutCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        theme: RuhamaaTheme.light(),
        home: AccountScreen(
          email: 'user@example.com',
          onSignOut: () async {
            signOutCalls += 1;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('account-sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الخروج؟'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-sign-out')));
    await tester.pumpAndSettle();
    expect(signOutCalls, 1);
  });
}
