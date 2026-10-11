import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/staff_labels.dart';

void main() {
  final latin = RegExp(r'[A-Za-z_]');

  group('StaffLabels statuses', () {
    test('need discovery publish is offered only for RPC-accepted statuses',
        () {
      expect(StaffLabels.canPublishNeed('submitted'), isTrue);
      expect(StaffLabels.canPublishNeed('waiting'), isTrue);
      expect(StaffLabels.canPublishNeed('candidate_found'), isFalse);
      expect(StaffLabels.canPublishNeed('matched'), isFalse);
      expect(StaffLabels.canPublishNeed('fulfilled'), isFalse);
      expect(StaffLabels.canPublishNeed(null), isFalse);
    });

    test('status labels never show raw keys', () {
      const needStatuses = [
        'submitted',
        'waiting',
        'candidate_found',
        'confirmed',
        'matched',
        'delivery_scheduled',
        'fulfilled',
        'cancelled',
        'expired',
        'brand_new',
      ];
      for (final status in needStatuses) {
        final label = StaffLabels.needStatusLabel(status);
        expect(label, isNotEmpty);
        expect(latin.hasMatch(label), isFalse, reason: status);
      }
      for (final status in ['open', 'reviewing', 'resolved', 'dismissed', 'x']) {
        final label = StaffLabels.incidentStatusLabel(status);
        expect(latin.hasMatch(label), isFalse, reason: status);
      }
      for (final status in ['pending', 'processing', 'completed', 'rejected']) {
        final label = StaffLabels.deletionStatusLabel(status);
        expect(latin.hasMatch(label), isFalse, reason: status);
      }
      for (final status in ['submitted', 'under_review', 'available', 'zzz']) {
        final label = StaffLabels.donationStatusLabel(status);
        expect(latin.hasMatch(label), isFalse, reason: status);
      }
      expect(StaffLabels.incidentTypeLabel('no_show'), 'عدم الحضور');
      expect(StaffLabels.incidentTypeLabel('whatever'), 'نوع آخر');
      expect(StaffLabels.partnerStatusLabel('suspended'), 'موقوف');
      expect(StaffLabels.partnerStatusLabel(null), 'بانتظار المراجعة');
    });

    test('roles: only user, courier and supervisor can be assigned', () {
      expect(StaffLabels.assignableRoles, ['user', 'courier', 'supervisor']);
      expect(StaffLabels.roleLabel('courier'), 'موصل');
      expect(StaffLabels.roleLabel('supervisor'), 'مشرف');
      expect(StaffLabels.roleLabel('admin'), 'مدير');
      expect(latin.hasMatch(StaffLabels.roleLabel('root')), isFalse);
    });

    test('account deletion can be decided while pending or processing', () {
      expect(StaffLabels.canDecideDeletion('pending'), isTrue);
      expect(StaffLabels.canDecideDeletion('processing'), isTrue);
      expect(StaffLabels.canDecideDeletion('completed'), isFalse);
      expect(StaffLabels.canDecideDeletion('rejected'), isFalse);
      expect(StaffLabels.canDecideDeletion(null), isFalse);
    });

    test('a request being processed can only be retried, not rejected', () {
      expect(StaffLabels.canRejectDeletion('pending'), isTrue);
      expect(StaffLabels.canRejectDeletion('processing'), isFalse);
      expect(StaffLabels.canRejectDeletion('completed'), isFalse);
      expect(StaffLabels.canRejectDeletion(null), isFalse);
      expect(StaffLabels.deletionApproveLabel('pending'), 'حذف الحساب');
      expect(StaffLabels.deletionApproveLabel('processing'), 'إعادة محاولة الحذف');
    });

    test('courier receipt label covers the three states', () {
      final labels = {
        StaffLabels.courierReceiptLabel(true),
        StaffLabels.courierReceiptLabel(false),
        StaffLabels.courierReceiptLabel(null),
      };
      expect(labels.length, 3);
    });

    test('donation condition falls back to the stored text', () {
      expect(StaffLabels.donationConditionLabel('good'), 'جيد');
      expect(StaffLabels.donationConditionLabel(null), '');
      expect(StaffLabels.donationConditionLabel(''), '');
      expect(StaffLabels.donationConditionLabel('حالة ممتازة'), 'حالة ممتازة');
    });
  });

  group('StaffLabels Edge Function errors', () {
    test('extracts the code from a decoded JSON payload', () {
      expect(
        StaffLabels.functionErrorCode({'error': 'password_too_short'}),
        'password_too_short',
      );
      expect(
        StaffLabels.functionErrorCode({
          'error': 'create_user_failed',
          'message': 'A user with this email address has already been registered',
        }),
        'create_user_failed',
      );
    });

    test('extracts the code from a raw JSON string', () {
      expect(
        StaffLabels.functionErrorCode('{"error":"admin_required"}'),
        'admin_required',
      );
      expect(
        StaffLabels.functionErrorCode('{ "error" : "invalid_area" }'),
        'invalid_area',
      );
    });

    test('returns null when there is no code', () {
      expect(StaffLabels.functionErrorCode(null), isNull);
      expect(StaffLabels.functionErrorCode('Internal Server Error'), isNull);
      expect(StaffLabels.functionErrorCode({'message': 'x'}), isNull);
      expect(StaffLabels.functionErrorCode({'error': ''}), isNull);
      expect(StaffLabels.functionErrorCode(500), isNull);
    });

    test('every known code maps to Arabic copy', () {
      const codes = [
        'admin_required',
        'staff_required',
        'invalid_email',
        'reserved_email',
        'full_name_required',
        'invalid_role',
        'area_required',
        'invalid_area',
        'create_user_failed',
        'staff_setup_failed',
        'password_too_short',
        'password_not_complex',
        'password_unchanged',
        'current_password_required',
        'current_password_invalid',
        'profile_update_failed',
        'password_too_long',
        'temp_password_expired',
        'too_many_attempts',
        'verification_failed',
        'invalid_body',
        'invalid_user',
        'not_staff',
      ];
      for (final code in codes) {
        final label = StaffLabels.functionErrorLabel(code);
        expect(label, isNotNull, reason: code);
        expect(latin.hasMatch(label!), isFalse, reason: code);
      }
      expect(StaffLabels.functionErrorLabel('never_seen'), isNull);
      expect(StaffLabels.functionErrorLabel(null), isNull);
    });
  });

  group('StaffLabels password rules', () {
    test('profile_update_failed means the password did change', () {
      expect(StaffLabels.passwordChangedDespite('profile_update_failed'), isTrue);
      expect(StaffLabels.passwordChangedDespite('password_update_failed'), isFalse);
      expect(StaffLabels.passwordChangedDespite('too_many_attempts'), isFalse);
      expect(StaffLabels.passwordChangedDespite(null), isFalse);
      expect(
        StaffLabels.functionErrorLabel('profile_update_failed'),
        StaffLabels.passwordChangedMessage,
      );
    });

    test('an expired temporary password points to a reset, not a new account', () {
      final label = StaffLabels.functionErrorLabel('temp_password_expired')!;
      expect(label, contains('إعادة تعيين كلمة المرور'));
      expect(label, isNot(contains('حساب جديد')));
    });

    test('a half-finished reset tells the admin to repeat it', () {
      final label = StaffLabels.resetPasswordErrorLabel('profile_update_failed');
      expect(label, isNotNull);
      expect(label, isNot(StaffLabels.passwordChangedMessage));
      expect(StaffLabels.resetPasswordErrorLabel('not_staff'), isNull);
      expect(StaffLabels.resetPasswordErrorLabel(null), isNull);
    });

    test('only couriers and supervisors can have their password reset', () {
      expect(StaffLabels.canResetStaffPassword('courier'), isTrue);
      expect(StaffLabels.canResetStaffPassword('supervisor'), isTrue);
      expect(StaffLabels.canResetStaffPassword('admin'), isFalse);
      expect(StaffLabels.canResetStaffPassword('user'), isFalse);
      expect(StaffLabels.canResetStaffPassword(null), isFalse);
    });
  });

  group('StaffLabels validation', () {
    test('staff password follows the server complexity rules', () {
      expect(StaffLabels.staffPasswordError('Aa1!aaaa'), isNull);
      expect(StaffLabels.staffPasswordError('Aa1!'), isNotNull);
      expect(StaffLabels.staffPasswordError('aaaaaaaa'), isNotNull);
      expect(StaffLabels.staffPasswordError('AAAAAAA1!'), isNotNull);
      expect(StaffLabels.staffPasswordError('Aaaaaaaa1'), isNotNull);
      expect(StaffLabels.staffPasswordError(null), isNotNull);
    });

    test('area code follows the server pattern', () {
      expect(StaffLabels.areaCodeError('MARIB_RAWDA'), isNull);
      expect(StaffLabels.areaCodeError('marib-01'), isNull);
      expect(StaffLabels.areaCodeError(' mr '), isNull);
      expect(StaffLabels.areaCodeError('M'), isNotNull);
      expect(StaffLabels.areaCodeError(''), isNotNull);
      expect(StaffLabels.areaCodeError(null), isNotNull);
      expect(StaffLabels.areaCodeError('مأرب'), isNotNull);
      expect(StaffLabels.areaCodeError('MARIB RAWDA'), isNotNull);
      expect(StaffLabels.areaCodeError('A' * 31), isNotNull);
    });
  });
}
