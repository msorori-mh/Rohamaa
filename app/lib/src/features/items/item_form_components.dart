import 'package:flutter/material.dart';

import '../../catalog/item_category_catalog.dart';
import '../../theme/ruhamaa_theme.dart';

class ItemClassificationSelector extends StatelessWidget {
  const ItemClassificationSelector({
    super.key,
    required this.categoryKey,
    required this.groupKey,
    required this.itemTypeKey,
    required this.onCategoryChanged,
    required this.onGroupChanged,
    required this.onItemTypeChanged,
  });

  final String categoryKey;
  final String? groupKey;
  final String? itemTypeKey;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<String> onItemTypeChanged;

  @override
  Widget build(BuildContext context) {
    final category = itemCategoryByKey(categoryKey);
    final group = itemGroupByKey(category, groupKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'الفئة الرئيسية',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: RuhamaaColors.primaryDark,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.35,
          children: itemCategoriesV2.map((entry) {
            final selected = entry.key == categoryKey;
            return Material(
              color: selected ? RuhamaaColors.softGreen : Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onCategoryChanged(entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? RuhamaaColors.primary : RuhamaaColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(entry.icon, color: selected ? RuhamaaColors.primary : RuhamaaColors.textMuted, size: 22),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          entry.label,
                          style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Text(
          'اختر القسم',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: RuhamaaColors.primaryDark,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: category.groups.map((entry) => ChoiceChip(
                label: Text(entry.label),
                selected: entry.key == groupKey,
                onSelected: (_) => onGroupChanged(entry.key),
              )).toList(),
        ),
        if (group != null) ...[
          const SizedBox(height: 20),
          Text(
            'ما الشيء بالتحديد؟',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: RuhamaaColors.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.items.map((item) => ChoiceChip(
                  label: Text(item.label),
                  selected: item.key == itemTypeKey,
                  onSelected: (_) => onItemTypeChanged(item.key),
                )).toList(),
          ),
        ],
      ],
    );
  }
}

class ItemAttributesEditor extends StatelessWidget {
  const ItemAttributesEditor({
    super.key,
    required this.category,
    required this.values,
    required this.onChanged,
  });

  final ItemCategoryDefinition category;
  final Map<String, String> values;
  final void Function(String key, String value) onChanged;

  @override
  Widget build(BuildContext context) {
    if (category.attributes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'خصائص تساعد على المطابقة الدقيقة',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: RuhamaaColors.primaryDark,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        ...category.attributes.map((attribute) {
          if (attribute.isChoice) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                value: values[attribute.key]?.isEmpty ?? true ? null : values[attribute.key],
                decoration: InputDecoration(labelText: attribute.label),
                items: attribute.choices.entries
                    .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                    .toList(),
                onChanged: (value) => onChanged(attribute.key, value ?? ''),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              key: ValueKey('attr-${category.key}-${attribute.key}'),
              initialValue: values[attribute.key] ?? '',
              decoration: InputDecoration(
                labelText: attribute.label,
                hintText: attribute.hint,
              ),
              onChanged: (value) => onChanged(attribute.key, value.trim()),
            ),
          );
        }),
      ],
    );
  }
}

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
