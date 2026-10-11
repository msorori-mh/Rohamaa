import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/item_form_rules.dart';

void main() {
  group('item attribute labels', () {
    test('choice attributes show Arabic labels, never raw keys', () {
      final text = describeItemAttributes('clothes', {
        'season': 'winter',
        'size': '52',
        'quantity': '2',
      });
      expect(text, 'المقاس: 52 • الموسم: شتوي • الكمية: 2');
      expect(text.contains('season'), isFalse);
      expect(text.contains('winter'), isFalse);
    });

    test('follows catalog order and skips empty values', () {
      expect(
        itemAttributeLabels('clothes', {'quantity': '1', 'size': '  ', 'season': 'any'}),
        ['الموسم: لا يهم', 'الكمية: 1'],
      );
    });

    test('skips internal, unknown and invalid entries', () {
      expect(
        itemAttributeLabels('clothes', {
          'size_flexible': 'true',
          'made_up_key': 'value',
          'season': 'monsoon',
        }),
        isEmpty,
      );
      expect(describeItemAttributes('other', {'size': '40'}), '');
    });

    test('uses the label of the right category for a shared key', () {
      expect(
        describeItemAttributes('electronics', {'working_state': 'needs_repair'}),
        'حالة التشغيل: يحتاج إصلاحًا',
      );
      expect(
        describeItemAttributes('tools_trades', {'working_state': 'working'}),
        'الحالة: جاهز للاستخدام',
      );
    });

    test('legacy category names resolve to the V2 catalog', () {
      expect(canonicalItemCategoryKey('books'), 'education');
      expect(canonicalItemCategoryKey('furniture'), 'home_furniture');
      expect(canonicalItemCategoryKey('home'), 'home_furniture');
      expect(canonicalItemCategoryKey('clothes'), 'clothes');
      expect(canonicalItemCategoryKey('nonsense'), 'other');
      expect(canonicalItemCategoryKey(null), 'other');
      expect(
        describeItemAttributes('books', {'grade_level': 'الصف السادس'}),
        'الصف / المستوى: الصف السادس',
      );
    });
  });

  group('item title after changing the selected item', () {
    test('an empty title takes the new item label', () {
      expect(
        titleAfterItemChange(currentTitle: '  ', previousAutoTitle: null, newItemLabel: 'قميص'),
        'قميص',
      );
    });

    test('an auto-filled title follows the selected item', () {
      expect(
        titleAfterItemChange(currentTitle: 'قميص', previousAutoTitle: 'قميص', newItemLabel: 'بنطلون'),
        'بنطلون',
      );
    });

    test('a title typed by the person is preserved', () {
      expect(
        titleAfterItemChange(
          currentTitle: 'قميص أزرق مقاس كبير',
          previousAutoTitle: 'قميص',
          newItemLabel: 'بنطلون',
        ),
        'قميص أزرق مقاس كبير',
      );
      expect(
        titleAfterItemChange(currentTitle: 'عنوان من الطلب', previousAutoTitle: null, newItemLabel: 'بنطلون'),
        'عنوان من الطلب',
      );
    });

    test('custom title detection', () {
      expect(isCustomItemTitle(title: '', autoTitle: 'قميص'), isFalse);
      expect(isCustomItemTitle(title: 'قميص', autoTitle: 'قميص'), isFalse);
      expect(isCustomItemTitle(title: 'قميص أزرق', autoTitle: 'قميص'), isTrue);
      expect(isCustomItemTitle(title: 'قميص', autoTitle: null), isTrue);
    });
  });

  group('item form validators', () {
    test('title needs 3 to 160 characters', () {
      expect(validateItemTitle(null, emptyMessage: 'مطلوب'), 'مطلوب');
      expect(validateItemTitle(' اب ', emptyMessage: 'مطلوب'), 'مطلوب');
      expect(validateItemTitle('ثوب', emptyMessage: 'مطلوب'), isNull);
      expect(validateItemTitle('ا' * 160, emptyMessage: 'مطلوب'), isNull);
      expect(validateItemTitle('ا' * 161, emptyMessage: 'مطلوب'), isNotNull);
    });

    test('optional and required text respect the 2000 character limit', () {
      expect(validateOptionalText(null), isNull);
      expect(validateOptionalText('ا' * 2000), isNull);
      expect(validateOptionalText('ا' * 2001), isNotNull);
      expect(validateOptionalText('ا' * 121, max: 120), isNotNull);
      expect(validateRequiredText('قصير', min: 8, emptyMessage: 'مطلوب'), 'مطلوب');
      expect(validateRequiredText('تفاصيل كافية للبحث', min: 8, emptyMessage: 'مطلوب'), isNull);
      expect(validateRequiredText('ا' * 2001, min: 8, emptyMessage: 'مطلوب'), isNotNull);
    });
  });
}
