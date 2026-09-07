import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/catalog/item_category_catalog.dart';

void main() {
  test('Category V2 root keys are unique and populated', () {
    final keys = itemCategoriesV2.map((category) => category.key).toList();
    expect(keys.toSet().length, keys.length);
    expect(itemCategoriesV2.length, 8);
    for (final category in itemCategoriesV2) {
      expect(category.label.trim(), isNotEmpty);
      expect(category.groups, isNotEmpty);
    }
  });

  test('Category V2 group and item keys are unique inside taxonomy', () {
    final groupKeys = <String>{};
    final itemKeys = <String>{};
    for (final category in itemCategoriesV2) {
      for (final group in category.groups) {
        expect(groupKeys.add('${category.key}/${group.key}'), isTrue);
        expect(group.items, isNotEmpty);
        for (final item in group.items) {
          expect(item.label.trim(), isNotEmpty);
          expect(itemKeys.add(item.key), isTrue, reason: 'Duplicate item key: ${item.key}');
        }
      }
    }
  });

  test('legacy categories map to V2 roots', () {
    expect(itemCategoryByKey('education').label, 'تعليم ومدرسة');
    expect(itemCategoryByKey('home_furniture').label, 'منزل وأثاث');
    expect(legacyCategoryForV2('education'), 'books');
    expect(legacyCategoryForV2('home_furniture'), 'furniture');
    expect(legacyCategoryForV2('tools_trades'), 'other');
  });

  test('key pilot examples are represented', () {
    final clothes = itemCategoryByKey('clothes');
    expect(itemTypeByKey(clothes, 'mens_thobe')?.label, 'ثوب / شمزان');
    expect(itemTypeByKey(clothes, 'womens_abaya')?.label, 'عباءة');

    final education = itemCategoryByKey('education');
    expect(itemTypeByKey(education, 'school_bag')?.label, 'حقيبة مدرسية');

    final tools = itemCategoryByKey('tools_trades');
    expect(itemTypeByKey(tools, 'sewing_machine')?.label, 'ماكينة خياطة');
  });
}
