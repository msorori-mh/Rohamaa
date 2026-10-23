import '../../catalog/item_category_catalog.dart';

/// «القسم ← المجموعة ← النوع» for a stored item. Older rows carry a group
/// and an item type; rows from the simplified community forms carry only
/// the category, so the path is just the category label.
String itemPathLabel({
  required String categoryKey,
  String? groupKey,
  String? itemTypeKey,
}) {
  final category = itemCategoryByKey(categoryKey);
  final group = itemGroupByKey(category, groupKey);
  final item = itemTypeByKey(category, itemTypeKey);
  return [category.label, if (group != null) group.label, if (item != null) item.label].join(' ← ');
}
