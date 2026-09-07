import 'package:flutter/material.dart';

class ItemAttributeDefinition {
  const ItemAttributeDefinition({
    required this.key,
    required this.label,
    this.hint,
    this.choices = const {},
  });

  final String key;
  final String label;
  final String? hint;
  final Map<String, String> choices;

  bool get isChoice => choices.isNotEmpty;
}

class ItemTypeDefinition {
  const ItemTypeDefinition({required this.key, required this.label});
  final String key;
  final String label;
}

class ItemGroupDefinition {
  const ItemGroupDefinition({
    required this.key,
    required this.label,
    required this.items,
  });

  final String key;
  final String label;
  final List<ItemTypeDefinition> items;
}

class ItemCategoryDefinition {
  const ItemCategoryDefinition({
    required this.key,
    required this.label,
    required this.icon,
    required this.groups,
    this.attributes = const [],
  });

  final String key;
  final String label;
  final IconData icon;
  final List<ItemGroupDefinition> groups;
  final List<ItemAttributeDefinition> attributes;
}

const _quantity = ItemAttributeDefinition(
  key: 'quantity',
  label: 'الكمية',
  hint: 'مثال: 1 أو 3 قطع',
);

const itemCategoriesV2 = <ItemCategoryDefinition>[
  ItemCategoryDefinition(
    key: 'clothes',
    label: 'ملابس وأحذية',
    icon: Icons.checkroom_rounded,
    attributes: [
      ItemAttributeDefinition(key: 'size', label: 'المقاس', hint: 'مثال: 52 أو XL أو 38'),
      ItemAttributeDefinition(
        key: 'season',
        label: 'الموسم',
        choices: {'any': 'لا يهم', 'summer': 'صيفي', 'winter': 'شتوي'},
      ),
      _quantity,
    ],
    groups: [
      ItemGroupDefinition(
        key: 'mens',
        label: 'رجالي',
        items: [
          ItemTypeDefinition(key: 'mens_thobe', label: 'ثوب / شمزان'),
          ItemTypeDefinition(key: 'mens_shirt', label: 'قميص'),
          ItemTypeDefinition(key: 'mens_pants', label: 'بنطلون'),
          ItemTypeDefinition(key: 'mens_jacket', label: 'جاكيت / كوت'),
          ItemTypeDefinition(key: 'mens_suit', label: 'بدلة'),
        ],
      ),
      ItemGroupDefinition(
        key: 'womens',
        label: 'نسائي',
        items: [
          ItemTypeDefinition(key: 'womens_abaya', label: 'عباءة'),
          ItemTypeDefinition(key: 'womens_dress', label: 'فستان'),
          ItemTypeDefinition(key: 'womens_daily', label: 'ملابس يومية'),
          ItemTypeDefinition(key: 'womens_hijab', label: 'حجاب / طرحة'),
        ],
      ),
      ItemGroupDefinition(
        key: 'kids_clothes',
        label: 'أطفال',
        items: [
          ItemTypeDefinition(key: 'baby_clothes', label: 'ملابس مواليد'),
          ItemTypeDefinition(key: 'boys_clothes', label: 'ملابس أولاد'),
          ItemTypeDefinition(key: 'girls_clothes', label: 'ملابس بنات'),
          ItemTypeDefinition(key: 'school_uniform', label: 'زي مدرسي'),
        ],
      ),
      ItemGroupDefinition(
        key: 'shoes',
        label: 'أحذية',
        items: [
          ItemTypeDefinition(key: 'mens_shoes', label: 'أحذية رجالية'),
          ItemTypeDefinition(key: 'womens_shoes', label: 'أحذية نسائية'),
          ItemTypeDefinition(key: 'kids_shoes', label: 'أحذية أطفال'),
        ],
      ),
    ],
  ),
  ItemCategoryDefinition(
    key: 'children',
    label: 'أطفال وأمومة',
    icon: Icons.toys_rounded,
    attributes: [
      ItemAttributeDefinition(key: 'age_range', label: 'العمر المناسب', hint: 'مثال: 0–6 أشهر أو 3–5 سنوات'),
      _quantity,
    ],
    groups: [
      ItemGroupDefinition(
        key: 'sleep_transport',
        label: 'نوم وتنقل',
        items: [
          ItemTypeDefinition(key: 'baby_stroller', label: 'عربة طفل'),
          ItemTypeDefinition(key: 'baby_crib', label: 'مهد / سرير طفل'),
          ItemTypeDefinition(key: 'car_seat', label: 'مقعد سيارة للأطفال'),
        ],
      ),
      ItemGroupDefinition(
        key: 'feeding',
        label: 'إطعام وعناية',
        items: [
          ItemTypeDefinition(key: 'high_chair', label: 'كرسي طعام'),
          ItemTypeDefinition(key: 'feeding_supplies', label: 'مستلزمات إطعام'),
          ItemTypeDefinition(key: 'mother_baby_supplies', label: 'مستلزمات أم ورضيع'),
        ],
      ),
      ItemGroupDefinition(
        key: 'play',
        label: 'لعب وتعلم',
        items: [
          ItemTypeDefinition(key: 'toys', label: 'ألعاب'),
          ItemTypeDefinition(key: 'baby_activity', label: 'أدوات نشاط للطفل'),
        ],
      ),
    ],
  ),
  ItemCategoryDefinition(
    key: 'education',
    label: 'تعليم ومدرسة',
    icon: Icons.school_rounded,
    attributes: [
      ItemAttributeDefinition(key: 'grade_level', label: 'الصف / المستوى', hint: 'مثال: الصف السادس أو سنة أولى جامعة'),
      ItemAttributeDefinition(key: 'subject', label: 'المادة / التخصص', hint: 'إن كان مهمًا'),
      _quantity,
    ],
    groups: [
      ItemGroupDefinition(
        key: 'books',
        label: 'كتب',
        items: [
          ItemTypeDefinition(key: 'school_books', label: 'كتب مدرسية'),
          ItemTypeDefinition(key: 'university_books', label: 'كتب جامعية'),
          ItemTypeDefinition(key: 'reading_books', label: 'كتب قراءة'),
        ],
      ),
      ItemGroupDefinition(
        key: 'school_supplies',
        label: 'مستلزمات مدرسية',
        items: [
          ItemTypeDefinition(key: 'stationery', label: 'دفاتر وقرطاسية'),
          ItemTypeDefinition(key: 'school_bag', label: 'حقيبة مدرسية'),
          ItemTypeDefinition(key: 'geometry_tools', label: 'أدوات هندسية'),
          ItemTypeDefinition(key: 'calculator', label: 'آلة حاسبة'),
        ],
      ),
    ],
  ),
  ItemCategoryDefinition(
    key: 'home_furniture',
    label: 'منزل وأثاث',
    icon: Icons.chair_alt_rounded,
    attributes: [
      ItemAttributeDefinition(key: 'dimensions', label: 'الأبعاد التقريبية', hint: 'خصوصًا للأثاث الكبير'),
      ItemAttributeDefinition(key: 'carry_note', label: 'ملاحظة النقل', hint: 'مثال: يحتاج شخصين للحمل'),
      _quantity,
    ],
    groups: [
      ItemGroupDefinition(
        key: 'furniture',
        label: 'أثاث',
        items: [
          ItemTypeDefinition(key: 'bed', label: 'سرير / هيكل سرير'),
          ItemTypeDefinition(key: 'wardrobe', label: 'دولاب'),
          ItemTypeDefinition(key: 'table', label: 'طاولة'),
          ItemTypeDefinition(key: 'chair', label: 'كرسي'),
          ItemTypeDefinition(key: 'sofa', label: 'كنبة'),
          ItemTypeDefinition(key: 'desk', label: 'مكتب'),
          ItemTypeDefinition(key: 'shelves', label: 'رفوف / تخزين'),
        ],
      ),
      ItemGroupDefinition(
        key: 'household',
        label: 'أدوات منزلية',
        items: [
          ItemTypeDefinition(key: 'cookware', label: 'أواني طبخ'),
          ItemTypeDefinition(key: 'dishes', label: 'أطباق وكاسات'),
          ItemTypeDefinition(key: 'bedding', label: 'مفارش وبطانيات'),
          ItemTypeDefinition(key: 'cleaning_tools', label: 'أدوات تنظيف'),
          ItemTypeDefinition(key: 'storage_items', label: 'أدوات تخزين'),
        ],
      ),
    ],
  ),
  ItemCategoryDefinition(
    key: 'electronics',
    label: 'أجهزة وإلكترونيات',
    icon: Icons.devices_other_rounded,
    attributes: [
      ItemAttributeDefinition(
        key: 'working_state',
        label: 'حالة التشغيل',
        choices: {
          'working': 'يعمل طبيعيًا',
          'minor_issue': 'يعمل مع ملاحظة',
          'needs_repair': 'يحتاج إصلاحًا',
          'unknown': 'غير معروف',
        },
      ),
      _quantity,
    ],
    groups: [
      ItemGroupDefinition(
        key: 'personal_devices',
        label: 'أجهزة شخصية',
        items: [
          ItemTypeDefinition(key: 'phone', label: 'هاتف'),
          ItemTypeDefinition(key: 'tablet', label: 'تابلت'),
          ItemTypeDefinition(key: 'laptop', label: 'لابتوب / كمبيوتر'),
          ItemTypeDefinition(key: 'television', label: 'تلفزيون'),
        ],
      ),
      ItemGroupDefinition(
        key: 'home_appliances',
        label: 'أجهزة منزلية',
        items: [
          ItemTypeDefinition(key: 'fan', label: 'مروحة'),
          ItemTypeDefinition(key: 'refrigerator', label: 'ثلاجة'),
          ItemTypeDefinition(key: 'washing_machine', label: 'غسالة'),
          ItemTypeDefinition(key: 'blender', label: 'خلاط'),
          ItemTypeDefinition(key: 'heater', label: 'سخان'),
        ],
      ),
    ],
  ),
  ItemCategoryDefinition(
    key: 'tools_trades',
    label: 'أدوات ومهن',
    icon: Icons.handyman_rounded,
    attributes: [
      ItemAttributeDefinition(
        key: 'working_state',
        label: 'الحالة',
        choices: {
          'working': 'جاهز للاستخدام',
          'minor_issue': 'يحتاج صيانة بسيطة',
          'needs_repair': 'يحتاج إصلاحًا',
          'unknown': 'غير معروف',
        },
      ),
      _quantity,
    ],
    groups: [
      ItemGroupDefinition(
        key: 'tailoring_tools',
        label: 'خياطة',
        items: [ItemTypeDefinition(key: 'sewing_machine', label: 'ماكينة خياطة')],
      ),
      ItemGroupDefinition(
        key: 'hand_power_tools',
        label: 'عدة وأدوات',
        items: [
          ItemTypeDefinition(key: 'hand_tools', label: 'عدة يدوية'),
          ItemTypeDefinition(key: 'drill', label: 'دريل'),
          ItemTypeDefinition(key: 'electrical_tools', label: 'أدوات كهرباء'),
          ItemTypeDefinition(key: 'carpentry_tools', label: 'أدوات نجارة'),
          ItemTypeDefinition(key: 'agriculture_tools', label: 'أدوات زراعية بسيطة'),
        ],
      ),
    ],
  ),
  ItemCategoryDefinition(
    key: 'events',
    label: 'مناسبات وزواج',
    icon: Icons.celebration_rounded,
    attributes: [
      ItemAttributeDefinition(key: 'size', label: 'المقاس', hint: 'إن كان الشيء ملبوسًا'),
      _quantity,
    ],
    groups: [
      ItemGroupDefinition(
        key: 'occasion_clothes',
        label: 'ملابس مناسبة',
        items: [
          ItemTypeDefinition(key: 'wedding_dress', label: 'فستان زفاف'),
          ItemTypeDefinition(key: 'groom_suit', label: 'بدلة عريس'),
          ItemTypeDefinition(key: 'occasion_dress', label: 'فستان مناسبة'),
          ItemTypeDefinition(key: 'occasion_accessories', label: 'إكسسوارات مناسبة'),
        ],
      ),
      ItemGroupDefinition(
        key: 'event_items',
        label: 'مستلزمات مناسبة',
        items: [
          ItemTypeDefinition(key: 'event_decor_items', label: 'زينة وتجهيزات'),
          ItemTypeDefinition(key: 'event_lighting_items', label: 'إضاءة بسيطة'),
        ],
      ),
    ],
  ),
  ItemCategoryDefinition(
    key: 'other',
    label: 'أخرى',
    icon: Icons.more_horiz_rounded,
    groups: [
      ItemGroupDefinition(
        key: 'other',
        label: 'أخرى',
        items: [ItemTypeDefinition(key: 'other_item', label: 'شيء آخر')],
      ),
    ],
  ),
];

ItemCategoryDefinition itemCategoryByKey(String key) {
  return itemCategoriesV2.firstWhere(
    (category) => category.key == key,
    orElse: () => itemCategoriesV2.last,
  );
}

ItemGroupDefinition? itemGroupByKey(ItemCategoryDefinition category, String? key) {
  if (key == null) return null;
  for (final group in category.groups) {
    if (group.key == key) return group;
  }
  return null;
}

ItemTypeDefinition? itemTypeByKey(ItemCategoryDefinition category, String? key) {
  if (key == null) return null;
  for (final group in category.groups) {
    for (final item in group.items) {
      if (item.key == key) return item;
    }
  }
  return null;
}

String legacyCategoryForV2(String category) {
  switch (category) {
    case 'education':
      return 'books';
    case 'home_furniture':
      return 'furniture';
    case 'tools_trades':
      return 'other';
    default:
      return category;
  }
}
