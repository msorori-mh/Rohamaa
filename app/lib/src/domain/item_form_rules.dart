import '../catalog/item_category_catalog.dart';

/// Server-side text limits shared by the giving and requesting forms.
class ItemFormLimits {
  const ItemFormLimits._();

  static const int title = 160;
  static const int description = 2000;

  /// Shortest description the giving and requesting forms accept.
  static const int descriptionMin = 3;

  /// Longest short title derived from a description.
  static const int derivedTitle = 80;
}

/// Condition choices of the donation form: stored value -> Arabic label.
/// The values are the ones the server and the staff screens already know.
const Map<String, String> donationConditionChoices = <String, String>{
  'new': 'جديد',
  'good': 'جيد',
  'minor_repair': 'يحتاج إصلاحًا',
};

/// Short title stored as `item_type` for a free-text description: the first
/// line that has at least [ItemFormLimits.descriptionMin] characters (or the
/// whole text), with runs of whitespace collapsed, cut to
/// [ItemFormLimits.derivedTitle] characters. Empty when the text is empty.
String itemTitleFromDescription(String description) {
  String clean(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');
  var title = '';
  for (final line in description.split('\n')) {
    final candidate = clean(line);
    if (candidate.length >= ItemFormLimits.descriptionMin) {
      title = candidate;
      break;
    }
  }
  if (title.isEmpty) title = clean(description);
  final runes = title.runes;
  if (runes.length <= ItemFormLimits.derivedTitle) return title;
  return String.fromCharCodes(runes.take(ItemFormLimits.derivedTitle)).trim();
}

/// Inline validator message for the description of a donation or a request,
/// or null when valid.
String? validateItemDescription(String? value, {required String emptyMessage}) {
  return validateRequiredText(
    value,
    min: ItemFormLimits.descriptionMin,
    emptyMessage: emptyMessage,
  );
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
