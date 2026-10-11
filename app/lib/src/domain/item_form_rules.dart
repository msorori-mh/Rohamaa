import '../catalog/item_category_catalog.dart';

/// Server-side text limits shared by the giving and requesting forms.
class ItemFormLimits {
  const ItemFormLimits._();

  static const int title = 160;
  static const int description = 2000;
  static const int attributeValue = 120;
}

/// The V2 catalog key for a stored category, including the legacy names
/// (`books`, `furniture`, `home`). Unknown or missing values map to `other`.
String canonicalItemCategoryKey(String? value) {
  switch (value) {
    case 'books':
      return 'education';
    case 'furniture':
    case 'home':
      return 'home_furniture';
  }
  final raw = value ?? '';
  return itemCategoriesV2.any((category) => category.key == raw) ? raw : 'other';
}

/// Attribute keys that are stored for matching but never shown as text.
const Set<String> hiddenItemAttributeKeys = <String>{'size_flexible'};

/// Arabic `label: value` pairs for the attributes of an item, in the order the
/// catalog defines them. Raw keys such as `season` or `winter` are never
/// returned: an attribute or choice the catalog does not know is skipped.
List<String> itemAttributeLabels(
  String categoryKey,
  Map<String, String> attributes,
) {
  final category = itemCategoryByKey(canonicalItemCategoryKey(categoryKey));
  final parts = <String>[];
  for (final definition in category.attributes) {
    if (hiddenItemAttributeKeys.contains(definition.key)) continue;
    final raw = attributes[definition.key]?.trim() ?? '';
    if (raw.isEmpty) continue;
    if (definition.isChoice) {
      final label = definition.choices[raw];
      if (label == null) continue;
      parts.add('${definition.label}: $label');
    } else {
      parts.add('${definition.label}: $raw');
    }
  }
  return parts;
}

/// [itemAttributeLabels] joined for a single review line.
String describeItemAttributes(
  String categoryKey,
  Map<String, String> attributes,
) {
  return itemAttributeLabels(categoryKey, attributes).join(' • ');
}

/// Title to show after the person picks another item type.
///
/// A title the person typed is kept. A title that is empty, or that was filled
/// automatically from the previously selected item ([previousAutoTitle]),
/// follows the new selection.
String titleAfterItemChange({
  required String currentTitle,
  required String? previousAutoTitle,
  required String newItemLabel,
}) {
  final current = currentTitle.trim();
  if (current.isEmpty) return newItemLabel;
  if (previousAutoTitle != null && current == previousAutoTitle.trim()) {
    return newItemLabel;
  }
  return currentTitle;
}

/// True when [title] was written by the person rather than filled from the
/// selected item ([autoTitle]).
bool isCustomItemTitle({required String title, required String? autoTitle}) {
  final current = title.trim();
  if (current.isEmpty) return false;
  return autoTitle == null || current != autoTitle.trim();
}

/// Inline validator message for an item title, or null when valid.
String? validateItemTitle(String? value, {required String emptyMessage}) {
  final text = value?.trim() ?? '';
  if (text.length < 3) return emptyMessage;
  if (text.length > ItemFormLimits.title) {
    return 'الاسم طويل جدًا (الحد ${ItemFormLimits.title} حرفًا).';
  }
  return null;
}

/// Inline validator message for optional free text, or null when valid.
String? validateOptionalText(
  String? value, {
  int max = ItemFormLimits.description,
}) {
  final text = value?.trim() ?? '';
  if (text.length > max) return 'النص طويل جدًا (الحد $max حرفًا).';
  return null;
}

/// Inline validator message for required free text, or null when valid.
String? validateRequiredText(
  String? value, {
  required int min,
  required String emptyMessage,
  int max = ItemFormLimits.description,
}) {
  final text = value?.trim() ?? '';
  if (text.length < min) return emptyMessage;
  if (text.length > max) return 'النص طويل جدًا (الحد $max حرفًا).';
  return null;
}

/// Postgres error code for a unique or primary-key violation.
const String uniqueViolationCode = '23505';

/// True when an insert failed because the row already exists. Forms send a
/// row id generated once per form instance, so after a lost response a retry
/// hits the primary key and the first row is read back instead of creating a
/// duplicate.
bool isUniqueViolationCode(String? code) => code == uniqueViolationCode;
