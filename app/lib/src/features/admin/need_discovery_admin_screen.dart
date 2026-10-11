import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../catalog/item_category_catalog.dart';
import '../../core/app_error.dart';
import '../../data/need_discovery_repository.dart';
import '../../domain/staff_labels.dart';
import '../../theme/ruhamaa_theme.dart';
import 'staff_widgets.dart';

/// Arabic label for a V2 or legacy item category key.
String _categoryLabel(Object? raw) {
  final key = '${raw ?? ''}';
  final mapped = switch (key) {
    'books' => 'education',
    'furniture' || 'home' => 'home_furniture',
    _ => key,
  };
  return itemCategoryByKey(mapped).label;
}

class NeedDiscoveryAdminScreen extends StatelessWidget {
  const NeedDiscoveryAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _NeedDiscoveryAdminAppBar(),
        body: TabBarView(
          children: [
            _ReviewNeedsTab(),
            _PublishedCardsTab(),
          ],
        ),
      ),
    );
  }
}

class _NeedDiscoveryAdminAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _NeedDiscoveryAdminAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('احتياجات راجعها عطاء'),
      bottom: const TabBar(
        tabs: [
          Tab(text: 'للمراجعة', icon: Icon(Icons.fact_check_outlined)),
          Tab(text: 'المعروضة', icon: Icon(Icons.visibility_outlined)),
        ],
      ),
    );
  }

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);
}

class _ReviewData {
  const _ReviewData({required this.needs, required this.cards});

  final List<Map<String, dynamic>> needs;
  final List<Map<String, dynamic>> cards;
}

class _ReviewNeedsTab extends StatefulWidget {
  const _ReviewNeedsTab();

  @override
  State<_ReviewNeedsTab> createState() => _ReviewNeedsTabState();
}

class _ReviewNeedsTabState extends State<_ReviewNeedsTab> {
  late Future<_ReviewData> _future;
  final Set<String> _busyIds = <String>{};

  NeedDiscoveryRepository get _repo =>
      NeedDiscoveryRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReviewData> _load() async {
    final results = await Future.wait([
      _repo.adminOpenNeeds(),
      _repo.adminCards(),
    ]);
    return _ReviewData(needs: results[0], cards: results[1]);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  Future<void> _publish(
    Map<String, dynamic> need,
    Map<String, dynamic>? existing,
  ) async {
    final id = '${need['id']}';
    if (_busyIds.contains(id)) return;
    final values = await TextFieldsDialog.show(
      context,
      title: 'صياغة البطاقة للمتبرعين',
      intro:
          'اكتب ما يحتاجه الشخص فقط. لا تنقل السبب الشخصي أو أي بيانات قد تكشف هويته.',
      confirmLabel: 'حفظ وعرض البطاقة',
      fields: [
        DialogField(
          id: 'title',
          label: 'عنوان محايد',
          hint: 'مثال: شمزان رجالي مقاس 52',
          initialValue: existing?['display_title'] as String? ??
              '${need['item_type'] ?? ''}',
          maxLength: 80,
          validator: requiredText(message: 'اكتب عنوانًا من 3 أحرف على الأقل.'),
        ),
        DialogField(
          id: 'detail',
          label: 'تفاصيل مفيدة للمتبرع (اختياري)',
          hint: 'مثال: يقبل المستعمل بحالة جيدة، واللون غير مهم',
          initialValue: existing?['display_detail'] as String? ?? '',
          maxLines: 3,
          maxLength: 300,
        ),
        DialogField(
          id: 'city',
          label: 'المدينة فقط',
          initialValue: existing?['city_label'] as String? ?? 'مأرب',
          maxLength: 40,
        ),
      ],
    );
    if (values == null || !mounted) return;
    final city = values['city'] ?? '';
    setState(() => _busyIds.add(id));
    try {
      await _repo.publish(
        needId: id,
        title: values['title'] ?? '',
        detail: values['detail'] ?? '',
        cityLabel: city.isEmpty ? 'مأرب' : city,
      );
      if (!mounted) return;
      showInfoSnack(
        context,
        'تم عرض بطاقة احتياج محجوبة الهوية بعد المراجعة.',
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر عرض البطاقة. حدّث القائمة ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Widget _card(Map<String, dynamic> need, Map<String, dynamic>? existing) {
    final id = '${need['id']}';
    final status = need['status'] as String?;
    final active = existing?['is_active'] == true;
    final canPublish = StaffLabels.canPublishNeed(status);
    final busy = _busyIds.contains(id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: RuhamaaColors.softGreen,
                  foregroundColor: RuhamaaColors.primary,
                  child: Icon(Icons.front_hand_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${need['item_type']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${_categoryLabel(need['category'])} • '
                        '${StaffLabels.needStatusLabel(status)} • '
                        '${need['public_code']}',
                        style: const TextStyle(
                          color: RuhamaaColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(active ? 'معروض' : 'غير معروض'),
                  avatar: Icon(
                    active
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_outlined,
                    size: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RuhamaaColors.warmGoldSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'خاص بفريق عطاء — لا تنسخه تلقائيًا إلى البطاقة المعروضة',
                    style: TextStyle(
                      color: RuhamaaColors.primaryDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  if (need['reason'] != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'تفاصيل خاصة: ${need['reason']}',
                      style: const TextStyle(height: 1.45),
                    ),
                  ],
                  if (need['description'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'وصف: ${need['description']}',
                      style: const TextStyle(height: 1.45),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (canPublish) ...[
              const Text(
                'عند العرض اكتب وصفًا محايدًا للشيء نفسه فقط. لا تعرض اسمًا أو رقمًا أو عنوانًا أو قصة شخصية أو سببًا حساسًا.',
                style: TextStyle(
                  color: RuhamaaColors.textMuted,
                  height: 1.45,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: busy ? null : () => _publish(need, existing),
                icon: busy
                    ? const InlineSpinner()
                    : Icon(
                        active
                            ? Icons.edit_outlined
                            : Icons.visibility_outlined,
                      ),
                label: Text(
                  busy
                      ? 'جارٍ الحفظ...'
                      : active
                          ? 'راجع أو عدّل البطاقة المعروضة'
                          : 'راجع ثم اعرض للمتبرعين',
                ),
              ),
            ] else
              const Text(
                'وُجد تبرع مرشح لهذا الطلب، لذلك لا يمكن عرضه للمتبرعين أو تعديل بطاقته الآن.',
                style: TextStyle(
                  color: RuhamaaColors.primaryDark,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshableFuture<_ReviewData>(
      future: _future,
      onRefresh: _refresh,
      isEmpty: (data) => data.needs.isEmpty,
      emptyText: 'لا توجد احتياجات مفتوحة للمراجعة الآن.',
      builder: (context, data) {
        final byNeed = <String, Map<String, dynamic>>{
          for (final card in data.cards) '${card['need_id']}': card,
        };
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: data.needs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final need = data.needs[index];
            return _card(need, byNeed['${need['id']}']);
          },
        );
      },
    );
  }
}

class _PublishedCardsTab extends StatefulWidget {
  const _PublishedCardsTab();

  @override
  State<_PublishedCardsTab> createState() => _PublishedCardsTabState();
}

class _PublishedCardsTabState extends State<_PublishedCardsTab> {
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _busyIds = <String>{};

  NeedDiscoveryRepository get _repo =>
      NeedDiscoveryRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _loadActive();
  }

  Future<List<Map<String, dynamic>>> _loadActive() async {
    final cards = await _repo.adminCards();
    return cards.where((card) => card['is_active'] == true).toList();
  }

  Future<void> _refresh() async {
    final next = _loadActive();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  Future<void> _unpublish(String id) async {
    if (_busyIds.contains(id)) return;
    final confirmed = await confirmAction(
      context,
      title: 'إيقاف عرض البطاقة؟',
      message:
          'ستختفي البطاقة من واجهة المتبرعين، وسيبقى الطلب محفوظًا ويمكن عرضه مرة أخرى لاحقًا.',
      confirmLabel: 'إيقاف العرض',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyIds.add(id));
    try {
      await _repo.unpublish(id);
      if (!mounted) return;
      showInfoSnack(
        context,
        'توقف عرض البطاقة. يمكنك إعادة عرضها من تبويب «للمراجعة».',
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر إيقاف عرض البطاقة. حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshableFuture<List<Map<String, dynamic>>>(
      future: _future,
      onRefresh: _refresh,
      isEmpty: (cards) => cards.isEmpty,
      emptyText: 'لا توجد بطاقات احتياج معروضة الآن.',
      builder: (context, cards) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final card = cards[index];
          final id = '${card['id']}';
          final busy = _busyIds.contains(id);
          return Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  leading: const Icon(
                    Icons.fact_check_outlined,
                    color: RuhamaaColors.primary,
                  ),
                  title: Text(
                    '${card['display_title']}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${_categoryLabel(card['category'])} • ${card['city_label']}\n'
                    '${card['display_detail'] ?? ''}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: OutlinedButton.icon(
                    key: Key('unpublish-need-card-$id'),
                    onPressed: busy ? null : () => _unpublish(id),
                    icon: busy
                        ? const InlineSpinner()
                        : const Icon(Icons.visibility_off_outlined),
                    label: Text(
                      busy ? 'جارٍ إيقاف العرض...' : 'إيقاف عرض البطاقة',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
