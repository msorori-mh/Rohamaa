import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../catalog/item_category_catalog.dart';
import '../../data/admin_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import '../items/item_form_components.dart';

class ItemMatchingV2Screen extends StatefulWidget {
  const ItemMatchingV2Screen({super.key});

  @override
  State<ItemMatchingV2Screen> createState() => _ItemMatchingV2ScreenState();
}

class _ItemMatchingV2ScreenState extends State<ItemMatchingV2Screen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = AdminRepository(Supabase.instance.client).donationsQueue();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مطابقة الأشياء V2')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('تعذر تحميل العطاءات: ${snapshot.error}'));
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) return const Center(child: Text('لا توجد عطاءات بانتظار المطابقة.'));
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final donation = rows[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: RuhamaaColors.softGreen,
                      foregroundColor: RuhamaaColors.primary,
                      child: Icon(itemCategoryByKey(_category(donation)).icon),
                    ),
                    title: Text('${donation['item_type']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${_path(donation)}\n${_attributes(donation)}', maxLines: 3, overflow: TextOverflow.ellipsis),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => _CandidateReviewScreen(donation: donation)),
                      );
                      if (mounted) setState(_reload);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CandidateReviewScreen extends StatefulWidget {
  const _CandidateReviewScreen({required this.donation});
  final Map<String, dynamic> donation;

  @override
  State<_CandidateReviewScreen> createState() => _CandidateReviewScreenState();
}

class _CandidateReviewScreenState extends State<_CandidateReviewScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminRepository(Supabase.instance.client).matchCandidates('${widget.donation['id']}');
  }

  Future<void> _approve(Map<String, dynamic> candidate) async {
    try {
      await AdminRepository(Supabase.instance.client).approveMatch(
        '${widget.donation['id']}',
        '${candidate['need_id']}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال عرض المطابقة الخاص للمستفيد.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال العرض: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('مرشحو ${widget.donation['item_type']}')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('تعذر تحميل المرشحين: ${snapshot.error}'));
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) return const Center(child: Text('لا يوجد تطابق مناسب حاليًا.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final candidate = rows[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${candidate['item_type']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                const SizedBox(height: 3),
                                Text(_path(candidate), style: const TextStyle(color: RuhamaaColors.textMuted)),
                              ],
                            ),
                          ),
                          Chip(label: Text('ملاءمة ${candidate['score']}')),
                        ],
                      ),
                      finalAttributes(candidate),
                      const SizedBox(height: 9),
                      Text(
                        'المسافة: ${candidate['distance_km'] ?? '-'} كم • انتظار: ${candidate['age_hours'] ?? '-'} ساعة • مرات إشباع سابقة لنفس الفئة: ${candidate['prior_same_category']}',
                        style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'النقاط المالية والمساهمات وما قدمه الشخص سابقًا من عطاء لا تدخل في أولوية هذه المطابقة.',
                        style: TextStyle(color: RuhamaaColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w700, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => _approve(candidate),
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('إرسال عرض المطابقة'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget finalAttributes(Map<String, dynamic> row) {
    final text = _attributes(row);
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text, style: const TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w700)),
    );
  }
}

String _category(Map<String, dynamic> row) {
  final raw = '${row['category']}';
  switch (raw) {
    case 'books': return 'education';
    case 'furniture':
    case 'home': return 'home_furniture';
    default: return itemCategoriesV2.any((c) => c.key == raw) ? raw : 'other';
  }
}

String _path(Map<String, dynamic> row) {
  final category = _category(row);
  return itemPathLabel(
    categoryKey: category,
    groupKey: row['category_group'] as String?,
    itemTypeKey: row['item_type_key'] as String?,
  );
}

String _attributes(Map<String, dynamic> row) {
  final raw = row['item_attributes'];
  if (raw is! Map || raw.isEmpty) return '';
  final category = itemCategoryByKey(_category(row));
  final parts = <String>[];
  for (final entry in raw.entries) {
    if ('${entry.value}'.trim().isEmpty || '${entry.key}' == 'size_flexible') continue;
    final specs = category.attributes.where((attribute) => attribute.key == '${entry.key}');
    if (specs.isEmpty) continue;
    final spec = specs.first;
    final value = spec.choices['${entry.value}'] ?? '${entry.value}';
    parts.add('${spec.label}: $value');
  }
  return parts.join(' • ');
}
