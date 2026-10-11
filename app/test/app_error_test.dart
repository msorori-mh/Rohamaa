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

    test('every known key maps to its own non-empty Arabic copy', () {
      final arabic = RegExp(r'[\u0600-\u06FF]');
      expect(kServerErrorMessages, isNotEmpty);
      for (final entry in kServerErrorMessages.entries) {
        expect(entry.key, entry.key.toLowerCase(), reason: 'keys are lower-case');
        expect(entry.key.trim(), isNotEmpty);
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
        expect(arabic.hasMatch(entry.value), isTrue, reason: entry.key);
        // No earlier, more generic key may shadow this one.
        expect(
          friendlyError(PostgrestException(message: entry.key)),
          entry.value,
          reason: 'shadowed key: ${entry.key}',
        );
      }
    });

    test('specific messages win over the generic ones they contain', () {
      String copy(String message) => friendlyError(PostgrestException(message: message));
      expect(copy('need cannot be cancelled'), isNot(copy('service request cannot be cancelled')));
      expect(
        copy('donation unavailable for intake'),
        'هذا التبرع غير متاح للاستلام في المستودع.',
      );
      expect(copy('donation unavailable'), 'لم يعد هذا التبرع متاحًا للمطابقة.');
      expect(
        copy('need is not eligible for discovery while a match offer or fulfillment is active'),
        'لا يمكن نشر الطلب ما دام له عرض أو تسليم جارٍ.',
      );
      expect(copy('need is not eligible for discovery'), 'هذا الطلب غير مؤهل للنشر الآن.');
      expect(
        copy('donation already has an active offer/match'),
        'لهذا التبرع عرض أو مطابقة جارية بالفعل.',
      );
      expect(copy('donation already matched'), 'تمت المطابقة مسبقًا.');
      expect(
        copy('cancellation reason too long'),
        isNot(copy('value too long for full_name')),
      );
      expect(copy('value too long for area description'), 'النص المدخل أطول من المسموح.');
      expect(
        copy('account deletion in progress'),
        isNot(copy('delivery in progress')),
      );
    });

    test('password change answers never claim what did not happen', () {
      expect(
        friendlyError(StateError('{error: profile_update_failed}')),
        'تم تغيير كلمة المرور. سجّل الدخول بها من جديد.',
      );
      final revoke = friendlyError(StateError('{error: session_revoke_failed}'));
      expect(revoke.contains('تغيّرت'), isFalse);
      expect(revoke.contains('تم تغيير'), isFalse);
      expect(
        friendlyError(StateError('{error: temp_password_expired}')),
        contains('إعادة تعيين كلمة المرور'),
      );
      expect(
        friendlyError(StateError('{error: too_many_attempts}')),
        'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.',
      );
      expect(friendlyError(StateError('{error: verification_failed}')), isNot(kGenericErrorMessage));
    });

    test('the new dispatch and pledge messages have their own copy', () {
      for (final message in [
        'pause reason required',
        'delivery cannot be paused',
        'collected item cannot change courier',
        'vehicle inactive',
        'pledge already answered',
        'courier reported cash not received',
        'account deletion in progress',
        'invalid party for this phase',
        'account is not active',
      ]) {
        expect(
          friendlyError(PostgrestException(message: message)),
          isNot(kGenericErrorMessage),
          reason: message,
        );
      }
    });

    test('the dead deletion key is gone', () {
      expect(kServerErrorMessages.containsKey('deletion request already'), isFalse);
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
