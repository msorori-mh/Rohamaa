import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/core/web_staff_notice.dart';
import 'package:ruhamaa/src/domain/account_state.dart';
import 'package:ruhamaa/src/features/auth/web_staff_only_screen.dart';
import 'package:ruhamaa/src/theme/ruhamaa_theme.dart';

void main() {
  group('browser build is staff only', () {
    test('staff roles may use the web build', () {
      for (final role in AccountState.staffRoles) {
        expect(AccountState(role: role).isAllowedOnPlatform(isWeb: true), isTrue);
      }
    });

    test('community accounts are refused on web but allowed on phones', () {
      expect(AccountState.community.isAllowedOnPlatform(isWeb: true), isFalse);
      expect(const AccountState(role: 'partner').isAllowedOnPlatform(isWeb: true), isFalse);
      expect(AccountState.community.isAllowedOnPlatform(isWeb: false), isTrue);
    });

    testWidgets('refusal screen explains the rule and offers sign-out', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RuhamaaTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: WebStaffOnlyScreen(autoSignOut: false),
          ),
        ),
      );

      expect(find.byKey(const Key('web-staff-only-title')), findsOneWidget);
      expect(find.text(WebStaffNotice.notStaffMessage), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
    });
  });

  test('only the dart:io adapter imports dart:io in lib (web builds must compile)', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('socket_error_io.dart')) continue;
      if (entity.readAsStringSync().contains("'dart:io'")) offenders.add(entity.path);
    }
    expect(offenders, isEmpty);
  });
}
