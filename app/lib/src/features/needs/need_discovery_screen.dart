import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../catalog/item_category_catalog.dart';
import '../../data/need_discovery_repository.dart';
import '../../theme/ruhamaa_theme.dart';

class NeedDiscoveryScreen extends StatefulWidget {
  const NeedDiscoveryScreen({super.key});

  @override
  State<NeedDiscoveryScreen> createState() => _NeedDiscoveryScreenState();
}

class _NeedDiscoveryScreenState extends State<NeedDiscoveryScreen> {
  String? _category;
  late Future<List<NeedDiscoveryCard>> _future;

  NeedDiscoveryRepository get _repo => NeedDiscoveryRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _repo.cards(category: _category);
  }

  void _selectCategory(String? value) {
    setState(() {
      _category = value;
      _reload();
    });
  }

  void _offerFor(NeedDiscoveryCard card) {
    context.push('/donate', extra: {
      'category': card.category,
      'categoryGroup': card.categoryGroup,
      'itemTypeKey': card.itemTypeKey,
      'attributes': card.attributes,
      'title': card.title,
      'discoveryCardId': card.id,
    });
  }

  String _waitLabel(int days) {
    if (days <= 0) return 'طلب حديث';
    if (days == 1) return 'ينتظر منذ يوم';
    if (days == 2) return 'ينتظر منذ يومين';
    if (days >= 3 && days <= 10) return 'ينتظر منذ $days أيام';
    return 'ينتظر منذ $days يومًا';
  }

  String _structuredDetail(NeedDiscoveryCard card) {
    if (card.attributes.isEmpty) return '';
    final category = itemCategoryByKey(card.category);
    final parts = <String>[];
    for (final entry in card.attributes.entries) {
      if (entry.key == 'size_flexible' || entry.value.trim().isEmpty) continue;
      final spec = category.attributes.where((attribute) => attribute.key == entry.key).firstOrNull;
      if (spec == null) continue;
      final value = spec.choices[entry.value] ?? entry.value;
      parts.add('${spec.label}: $value');
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات للمساعدة')),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: RuhamaaColors.softGreen,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: RuhamaaColors.primary),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'قد تجد طلبًا تستطيع المساعدة في تلبيته',
                          style: TextStyle(
                            color: RuhamaaColors.primaryDark,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'راجع فريقنا هذه الطلبات وأخفى بيانات أصحابها. إذا تبرعت، سنوجّه الشيء إلى الطلب الأنسب والأعلى أولوية.',
                    style: TextStyle(color: RuhamaaColors.textMuted, height: 1.55),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: ChoiceChip(
                      label: const Text('الكل'),
                      selected: _category == null,
                      onSelected: (_) => _selectCategory(null),
                    ),
                  ),
                  ...itemCategoriesV2.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: ChoiceChip(
                        avatar: Icon(category.icon, size: 18),
                        label: Text(category.label),
                        selected: _category == category.key,
                        onSelected: (_) => _selectCategory(category.key),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<NeedDiscoveryCard>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'تعذر تحميل الطلبات. تحقق من اتصالك وحاول مجددًا.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final cards = snapshot.data ?? const [];
                if (cards.isEmpty) return const _EmptyDiscovery();
                return Column(
                  children: cards.map((card) {
                    final category = itemCategoryByKey(card.category);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _NeedCard(
                        card: card,
                        label: category.label,
                        icon: category.icon,
                        structuredDetail: _structuredDetail(card),
                        waitLabel: _waitLabel(card.waitDays),
                        onOffer: () => _offerFor(card),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NeedCard extends StatelessWidget {
  const _NeedCard({
    required this.card,
    required this.label,
    required this.icon,
    required this.structuredDetail,
    required this.waitLabel,
    required this.onOffer,
  });

  final NeedDiscoveryCard card;
  final String label;
  final IconData icon;
  final String structuredDetail;
  final String waitLabel;
  final VoidCallback onOffer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: RuhamaaColors.softGreen,
                  foregroundColor: RuhamaaColors.primary,
                  child: Icon(icon),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        style: const TextStyle(
                          color: RuhamaaColors.primaryDark,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$label • ${card.cityLabel} • $waitLabel',
                        style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Tooltip(
                  message: 'راجع فريقنا هذا الطلب قبل عرضه',
                  child: Icon(Icons.verified_rounded, color: RuhamaaColors.primary),
                ),
              ],
            ),
            if (structuredDetail.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                structuredDetail,
                style: const TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w700, height: 1.45),
              ),
            ],
            if (card.detail != null && card.detail!.trim().isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(card.detail!, style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.5)),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RuhamaaColors.warmGoldSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text(
                'تبقى بيانات صاحب الطلب خاصة، وسنوجّه تبرعك حسب الملاءمة والأولوية.',
                style: TextStyle(color: RuhamaaColors.primaryDark, height: 1.45, fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onOffer,
              icon: const Icon(Icons.volunteer_activism_outlined),
              label: const Text('أستطيع التبرع بهذا'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDiscovery extends StatelessWidget {
  const _EmptyDiscovery();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(color: RuhamaaColors.softGreen, shape: BoxShape.circle),
            child: const Icon(Icons.fact_check_outlined, color: RuhamaaColors.primary, size: 44),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد طلبات في هذا القسم الآن',
            textAlign: TextAlign.center,
            style: TextStyle(color: RuhamaaColors.primaryDark, fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          const Text(
            'نعرض هنا فقط الطلبات التي راجعها فريقنا ويمكن مشاركتها دون بيانات شخصية.',
            textAlign: TextAlign.center,
            style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
