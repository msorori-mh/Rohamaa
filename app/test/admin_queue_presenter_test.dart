import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/admin_queue_presenter.dart';
import 'package:ruhamaa/src/domain/paging_rules.dart';

void main() {
  final latin = RegExp(r'[A-Za-z_]');

  AdminQueueCopy present(String kind, String title, String subtitle) =>
      AdminQueuePresenter.present(kind: kind, title: title, subtitle: subtitle);

  group('AdminQueuePresenter', () {
    test('a risk row shows the rule and severity labels, never the codes', () {
      final copy = present('risk', 'إشارة مخاطر: ADDRESS_CHURN', 'الأولوية high');
      expect(copy.title, 'تغيير متكرر للعنوان');
      expect(copy.subtitle, 'الأولوية: عالية');

      final lower = present('risk', 'إشارة مخاطر: many_open_needs', 'الأولوية critical');
      expect(lower.title, 'عدد كبير من الطلبات المفتوحة');
      expect(lower.subtitle, 'الأولوية: حرجة');
    });

    test('an unknown rule or severity gets neutral copy without the raw key', () {
      final copy = present('risk', 'إشارة مخاطر: BRAND_NEW_RULE', 'الأولوية extreme');
      expect(latin.hasMatch(copy.title), isFalse);
      expect(latin.hasMatch(copy.subtitle), isFalse);
      expect(copy.title.trim(), isNotEmpty);
    });

    test('a service incident shows its type and status labels', () {
      final copy = present('service_incident', 'بلاغ خدمة: no_show', 'الحالة reviewing');
      expect(copy.title, 'بلاغ خدمة: عدم الحضور');
      expect(copy.subtitle, 'قيد المراجعة');

      final unknown = present('service_incident', 'بلاغ خدمة: new_type', 'الحالة new_status');
      expect(latin.hasMatch(unknown.title), isFalse);
      expect(latin.hasMatch(unknown.subtitle), isFalse);
    });

    test('a delivery row shows the admin status label', () {
      final copy = present('delivery', 'توصيل يحتاج إعادة تنسيق', 'الحالة rescheduled');
      expect(copy.subtitle, 'تحتاج إعادة إسناد');
      expect(latin.hasMatch(copy.title), isFalse);
      expect(latin.hasMatch(present('delivery', 'x', 'الحالة future_state').subtitle), isFalse);
    });

    test('a deletion request distinguishes pending from processing', () {
      final pending = present('account_deletion', 'طلب حذف حساب ينتظر المعالجة', 'الحالة pending');
      final processing = present('account_deletion', 'طلب حذف حساب ينتظر المعالجة', 'الحالة processing');
      expect(pending.subtitle, 'بانتظار القرار');
      expect(pending.title, isNot(processing.title));
      expect(processing.subtitle, contains('أعد المحاولة'));
      for (final copy in [pending, processing]) {
        expect(latin.hasMatch(copy.title), isFalse);
        expect(latin.hasMatch(copy.subtitle), isFalse);
      }
    });

    test('rows that carry typed text are shown unchanged', () {
      for (final kind in [
        'accepted_match',
        'contribution',
        'partner',
        'donation',
        'need',
        'service_offer',
        'service_request',
        'item_recovery',
        'future_kind',
      ]) {
        final copy = present(kind, 'عطاء ينتظر المعالجة', 'كرسي خشبي');
        expect(copy.title, 'عطاء ينتظر المعالجة', reason: kind);
        expect(copy.subtitle, 'كرسي خشبي', reason: kind);
      }
    });

    test('the key after a prefix is trimmed, and text without it is kept', () {
      expect(AdminQueuePresenter.keyAfter('الحالة  open ', 'الحالة'), 'open');
      expect(AdminQueuePresenter.keyAfter('open', 'الحالة'), 'open');
      expect(AdminQueuePresenter.keyAfter('', 'الحالة'), '');
    });
  });

  group('PagingRules', () {
    test('a reload keeps the rows on screen, in whole pages', () {
      expect(PagingRules.rowsToReload(shown: 0, pageSize: 50), 50);
      expect(PagingRules.rowsToReload(shown: 50, pageSize: 50), 50);
      expect(PagingRules.rowsToReload(shown: 51, pageSize: 50), 100);
      expect(PagingRules.rowsToReload(shown: 430, pageSize: 50), 450);
    });

    test('pages cover the wanted rows without overlap', () {
      expect(PagingRules.pages(wanted: 50, pageSize: 50), [
        const PageRequest(from: 0, limit: 50),
      ]);
      expect(PagingRules.pages(wanted: 120, pageSize: 50), [
        const PageRequest(from: 0, limit: 50),
        const PageRequest(from: 50, limit: 50),
        const PageRequest(from: 100, limit: 20),
      ]);
      expect(PagingRules.pages(wanted: 0, pageSize: 50), isEmpty);
    });

    test('no request is ever larger than 200 rows', () {
      final requests = PagingRules.pages(wanted: 1000, pageSize: 5000);
      expect(requests, hasLength(5));
      for (final request in requests) {
        expect(request.limit, lessThanOrEqualTo(PagingRules.maxRowsPerRequest));
      }
      expect(requests.last, const PageRequest(from: 800, limit: 200));
      expect(PagingRules.pages(wanted: 3, pageSize: 0), hasLength(3));
    });
  });
}
