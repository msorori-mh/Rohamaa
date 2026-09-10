import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/need_discovery_repository.dart';
import '../../theme/ruhamaa_theme.dart';

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

class _NeedDiscoveryAdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _NeedDiscoveryAdminAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('احتياجات راجعها رحماء'),
      bottom: const TabBar(
        tabs: [
          Tab(text: 'للمراجعة', icon: Icon(Icons.fact_check_outlined)),
          Tab(text: 'المعروضة', icon: Icon(Icons.visibility_outlined)),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);
}

class _ReviewNeedsTab extends StatefulWidget {
  const _ReviewNeedsTab();

  @override
  State<_ReviewNeedsTab> createState() => _ReviewNeedsTabState();
}

class _ReviewNeedsTabState extends State<_ReviewNeedsTab> {
  late Future<_ReviewData> _future;

  NeedDiscoveryRepository get _repo => NeedDiscoveryRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _load();
  }

  Future<_ReviewData> _load() async {
    final results = await Future.wait<dynamic>([
      _repo.adminOpenNeeds(),
      _repo.adminCards(),
    ]);
    final needs = results[0] as List<Map<String, dynamic>>;
    final cards = results[1] as List<Map<String, dynamic>>;
    return _ReviewData(needs: needs, cards: cards);
  }

  Future<void> _publish(Map<String, dynamic> need, Map<String, dynamic>? existing) async {
    final result = await showDialog<_PublishDraft>(
      context: context,
      builder: (context) => _PublishNeedDialog(need: need, existing: existing),
    );
    if (result == null) return;
    try {
      await _repo.publish(
        needId: '${need['id']}',
        title: result.title,
        detail: result.detail,
        cityLabel: result.city,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم عرض بطاقة احتياج محجوبة الهوية بعد المراجعة.')),
      );
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر عرض البطاقة: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReviewData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل الاحتياجات. حاول مجددًا.'));
        }
        final data = snapshot.data!;
        if (data.needs.isEmpty) {
          return const _AdminEmpty('لا توجد احتياجات مفتوحة للمراجعة الآن.');
        }
        final byNeed = <String, Map<String, dynamic>>{
          for (final card in data.cards) '${card['need_id']}': card,
        };
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.needs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final need = data.needs[index];
              final existing = byNeed['${need['id']}'];
              final active = existing?['is_active'] == true;
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
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  '${need['category']} • ${need['status']} • ${need['public_code']}',
                                  style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(active ? 'معروض' : 'غير معروض'),
                            avatar: Icon(
                              active ? Icons.visibility_rounded : Icons.visibility_off_outlined,
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
                              'خاص بفريق رحماء — لا تنسخه تلقائيًا إلى البطاقة المعروضة',
                              style: TextStyle(
                                color: RuhamaaColors.primaryDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            if (need['reason'] != null) ...[
                              const SizedBox(height: 6),
                              Text('تفاصيل خاصة: ${need['reason']}', style: const TextStyle(height: 1.45)),
                            ],
                            if (need['description'] != null) ...[
                              const SizedBox(height: 4),
                              Text('وصف: ${need['description']}', style: const TextStyle(height: 1.45)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'عند العرض اكتب وصفًا محايدًا للشيء نفسه فقط. لا تعرض اسمًا أو رقمًا أو عنوانًا أو قصة شخصية أو سببًا حساسًا.',
                        style: TextStyle(color: RuhamaaColors.textMuted, height: 1.45, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => _publish(need, existing),
                        icon: Icon(active ? Icons.edit_outlined : Icons.visibility_outlined),
                        label: Text(active ? 'راجع أو عدّل البطاقة المعروضة' : 'راجع ثم اعرض للمتبرعين'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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

  NeedDiscoveryRepository get _repo => NeedDiscoveryRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _repo.adminCards();
  }

  Future<void> _unpublish(String id) async {
    if (_busyIds.contains(id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إيقاف عرض البطاقة؟'),
        content: const Text(
          'ستختفي البطاقة من واجهة المتبرعين، وسيبقى الطلب محفوظًا ويمكن عرضه مرة أخرى لاحقًا.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إيقاف العرض')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyIds.add(id));
    try {
      await _repo.unpublish(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('توقف عرض البطاقة. يمكنك إعادة عرضها من تبويب «للمراجعة».')),
      );
      setState(() {
        _busyIds.remove(id);
        _reload();
      });
    } catch (error) {
      debugPrint('Need discovery unpublish failed: $error');
      if (!mounted) return;
      setState(() => _busyIds.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إيقاف عرض البطاقة. حاول مجددًا.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل البطاقات. حاول مجددًا.'));
        }
        final cards = (snapshot.data ?? const [])
            .where((card) => card['is_active'] == true)
            .toList();
        if (cards.isEmpty) {
          return const _AdminEmpty('لا توجد بطاقات احتياج معروضة الآن.');
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.separated(
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      leading: const Icon(Icons.fact_check_outlined, color: RuhamaaColors.primary),
                      title: Text('${card['display_title']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(
                        '${card['category']} • ${card['city_label']}\n${card['display_detail'] ?? ''}',
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
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.visibility_off_outlined),
                        label: Text(busy ? 'جارٍ إيقاف العرض...' : 'إيقاف عرض البطاقة'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PublishNeedDialog extends StatefulWidget {
  const _PublishNeedDialog({required this.need, required this.existing});

  final Map<String, dynamic> need;
  final Map<String, dynamic>? existing;

  @override
  State<_PublishNeedDialog> createState() => _PublishNeedDialogState();
}

class _PublishNeedDialogState extends State<_PublishNeedDialog> {
  late final TextEditingController _title;
  late final TextEditingController _detail;
  late final TextEditingController _city;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: widget.existing?['display_title'] as String? ?? '${widget.need['item_type']}',
    );
    _detail = TextEditingController(
      text: widget.existing?['display_detail'] as String? ?? '',
    );
    _city = TextEditingController(
      text: widget.existing?['city_label'] as String? ?? 'مأرب',
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('صياغة البطاقة للمتبرعين'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اكتب ما يحتاجه الشخص فقط. لا تنقل السبب الشخصي أو أي بيانات قد تكشف هويته.',
              style: TextStyle(color: RuhamaaColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'عنوان محايد',
                hintText: 'مثال: شمزان رجالي مقاس 52',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detail,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'تفاصيل مفيدة للمتبرع (اختياري)',
                hintText: 'مثال: يقبل المستعمل بحالة جيدة، واللون غير مهم',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'المدينة فقط'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.length < 3) return;
            Navigator.pop(
              context,
              _PublishDraft(
                title: title,
                detail: _detail.text.trim(),
                city: _city.text.trim().isEmpty ? 'مأرب' : _city.text.trim(),
              ),
            );
          },
          child: const Text('حفظ وعرض البطاقة'),
        ),
      ],
    );
  }
}

class _ReviewData {
  const _ReviewData({required this.needs, required this.cards});
  final List<Map<String, dynamic>> needs;
  final List<Map<String, dynamic>> cards;
}

class _PublishDraft {
  const _PublishDraft({required this.title, required this.detail, required this.city});
  final String title;
  final String detail;
  final String city;
}

class _AdminEmpty extends StatelessWidget {
  const _AdminEmpty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
        ),
      ),
    );
  }
}
