import 'package:flutter_test/flutter_test.dart';
import 'package:ruhamaa/src/domain/item_form_rules.dart';

void main() {
  test('only the unique-violation code means the row already exists', () {
    expect(isUniqueViolationCode('23505'), isTrue);
    expect(isUniqueViolationCode('23503'), isFalse);
    expect(isUniqueViolationCode('42501'), isFalse);
    expect(isUniqueViolationCode(''), isFalse);
    expect(isUniqueViolationCode(null), isFalse);
  });

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

  group('short title derived from a description', () {
    test('takes the first line, trimmed and with single spaces', () {
      expect(
        itemTitleFromDescription('  ثوب رجالي   مقاس 52 \nنظيف وبحالة جيدة'),
        'ثوب رجالي مقاس 52',
      );
    });

    test('skips leading empty or too short lines', () {
      expect(itemTitleFromDescription('\n\n  \nحذاء رياضي'), 'حذاء رياضي');
      expect(itemTitleFromDescription('١\nكتب الصف السادس'), 'كتب الصف السادس');
    });

    test('falls back to the whole text when no line is long enough', () {
      expect(itemTitleFromDescription('اب\nج'), 'اب ج');
      expect(itemTitleFromDescription('   '), '');
    });

    test('is cut to 80 characters', () {
      final long = 'ا' * 120;
      expect(itemTitleFromDescription(long).length, ItemFormLimits.derivedTitle);
      expect(itemTitleFromDescription('ب' * 80), 'ب' * 80);
      expect(itemTitleFromDescription('${'ج' * 79} د'), 'ج' * 79);
    });

    test('never splits a character outside the basic plane', () {
      final title = itemTitleFromDescription('\u{1F600}' * 100);
      expect(title.runes.length, ItemFormLimits.derivedTitle);
      expect(title, '\u{1F600}' * 80);
    });
  });

  test('donation conditions keep the values the server already stores', () {
    expect(donationConditionChoices.keys, ['new', 'good', 'minor_repair']);
    expect(donationConditionChoices.values, ['جديد', 'جيد', 'يحتاج إصلاحًا']);
  });

  group('item form validators', () {
    test('a description needs 3 to 2000 characters', () {
      expect(validateItemDescription(null, emptyMessage: 'مطلوب'), 'مطلوب');
      expect(validateItemDescription(' اب ', emptyMessage: 'مطلوب'), 'مطلوب');
      expect(validateItemDescription('ثوب', emptyMessage: 'مطلوب'), isNull);
      expect(validateItemDescription('ا' * 2000, emptyMessage: 'مطلوب'), isNull);
      expect(validateItemDescription('ا' * 2001, emptyMessage: 'مطلوب'), isNotNull);
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
