import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/item_recovery_rules.dart';

void main(){
  group('ItemRecoveryRules',(){
    test('keeps the A-D operational meanings explicit',(){
      expect(ItemRecoveryRules.gradeLabels['A'],contains('مباشرة'));
      expect(ItemRecoveryRules.gradeLabels['B'],contains('تنظيف'));
      expect(ItemRecoveryRules.gradeLabels['C'],contains('إصلاح'));
      expect(ItemRecoveryRules.gradeLabels['D'],contains('تدوير'));
    });
    test('only active processing states expose an action',(){
      expect(ItemRecoveryRules.status('inspection_pending').nextAction,'inspect');
      expect(ItemRecoveryRules.status('repairing').nextAction,'complete_work');
      expect(ItemRecoveryRules.status('ready_for_distribution').nextAction,isNull);
      expect(ItemRecoveryRules.status('recycled').nextAction,isNull);
    });
  });
}
