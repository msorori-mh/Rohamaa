import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/data/operations_repository.dart';

void main() {
  UserNotificationItem notification(String title, String body) => UserNotificationItem.fromJson({
    'id': 'test', 'title': title, 'body': body, 'action_route': '/offers',
    'created_at': '2026-09-15T00:00:00Z', 'read_at': null,
  });
  const formerName = '\u0631\u062d\u0645\u0627\u0621';
  test('old generated notifications display the current identity', () {
    final item = notification('تحديث حالة شريك $formerName',
      'وجد فريق $formerName عطاءً مناسبًا لاحتياجك. راجع العرض واتخذ قرارك.');
    expect(item.title, 'تحديث حالة شريك عطاء');
    expect(item.body, 'وجد فريق عطاء شيئًا مناسبًا لاحتياجك. راجع العرض واتخذ قرارك.');
  });
  test('notification display does not rewrite free-form names or content', () {
    final item = notification('رسالة من $formerName', 'نص مستخدم: $formerName');
    expect(item.title, 'رسالة من $formerName');
    expect(item.body, 'نص مستخدم: $formerName');
  });
}
