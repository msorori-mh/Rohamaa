import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/core/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('friendlyError', () {
    test('maps network failures to the offline message', () {
      expect(friendlyError(const SocketException('Failed host lookup')), kOfflineErrorMessage);
      expect(friendlyError(TimeoutException('slow')), kOfflineErrorMessage);
      expect(
        friendlyError(Exception('ClientException with SocketException: Connection refused')),
        kOfflineErrorMessage,
      );
      expect(isNetworkError(const SocketException('x')), isTrue);
      expect(isNetworkError(Exception('something else')), isFalse);
    });

    test('maps known database messages to Arabic copy', () {
      expect(
        friendlyError(const PostgrestException(message: 'need cannot be cancelled')),
        'لا يمكن إلغاء الطلب في هذه المرحلة.',
      );
      expect(
        friendlyError(const PostgrestException(message: 'donation cannot be cancelled')),
        'لا يمكن إلغاء التبرع في هذه المرحلة.',
      );
      expect(
        friendlyError(const PostgrestException(message: 'account suspended')),
        'حسابك موقوف مؤقتًا. تواصل مع فريق عطاء.',
      );
      expect(
        friendlyError(const PostgrestException(message: 'pickup PIN unavailable in this state')),
        'الرمز غير متاح في هذه المرحلة.',
      );
    });

    test('never leaks table or policy names', () {
      final message = friendlyError(
        const PostgrestException(
          message: 'new row violates row-level security policy for table "addresses"',
          code: '42501',
        ),
      );
      expect(message, 'لا تملك صلاحية تنفيذ هذا الإجراء.');
      expect(message.contains('addresses'), isFalse);
    });

    test('maps edge function error codes carried in the error text', () {
      expect(
        friendlyError(StateError('{error: current_password_invalid}')),
        'كلمة المرور الحالية غير صحيحة.',
      );
      expect(
        friendlyError(StateError('{error: current_password_required}')),
        'أدخل كلمة المرور الحالية.',
      );
      expect(
        friendlyError(StateError('{error: password_unchanged}')),
        'اختر كلمة مرور مختلفة عن الحالية.',
      );
    });

    test('unknown errors fall back to generic copy, never the raw text', () {
      final error = Exception('relation "public.secret_table" does not exist');
      expect(friendlyError(error), kGenericErrorMessage);
      expect(friendlyError(error, fallback: 'نص بديل'), 'نص بديل');
      expect(friendlyError(error).contains('secret_table'), isFalse);
    });

    test('network detection wins over the fallback', () {
      expect(
        friendlyError(const SocketException('x'), fallback: 'نص بديل'),
        kOfflineErrorMessage,
      );
    });
  });

  testWidgets('ErrorRetry shows friendly copy and calls onRetry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ErrorRetry(
              error: Exception('internal detail'),
              onRetry: () => retries += 1,
            ),
          ),
        ),
      ),
    );

    expect(find.text(kGenericErrorMessage), findsOneWidget);
    expect(find.textContaining('internal detail'), findsNothing);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    expect(retries, 1);
  });
}
