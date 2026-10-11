import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../catalog/item_category_catalog.dart';
import '../../core/app_error.dart';
import '../../data/admin_repository.dart';
import '../../domain/staff_labels.dart';
import '../../theme/ruhamaa_theme.dart';
import '../items/item_form_components.dart';
import 'staff_widgets.dart';

class ItemMatchingV2Screen extends StatefulWidget {
  const ItemMatchingV2Screen({super.key});

  @override
  State<ItemMatchingV2Screen> createState() => _ItemMatchingV2ScreenState();
}

class _ItemMatchingV2ScreenState extends State<ItemMatchingV2Screen> {
  late Future<List<Map<String, dynamic>>> _future;

  AdminRepository get _repo => AdminRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _future = _repo.donationsQueue();
  }

  Future<void> _refresh() async {
    final next = _repo.donationsQueue();
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  Future<void> _openDonation(Map<String, dynamic> donation) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _CandidateReviewScreen(donation: donation),
      ),
    );
    if (mounted) await _refresh();
  }

  String _subtitle(Map<String, dynamic> donation) {
    final lines = <String>[
      _path(donation),
      _attributes(donation),
      [
        StaffLabels.donationStatusLabel(donation['status'] as String?),
        StaffLabels.donationConditionLabel(donation['condition'] as String?),
      ].where((part) => part.isNotEmpty).join(' • '),
    ];
    return lines.where((line) => line.isNotEmpty).join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مطابقة الأشياء')),
      body: RefreshableFuture<List<Map<String, dynamic>>>(
        future: _future,
        onRefresh: _refresh,
        isEmpty: (rows) => rows.isEmpty,
        emptyText: 'لا توجد عطاءات بانتظار المطابقة.',
        builder: (context, rows) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: rows.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == rows.length) {
              return rows.length >= AdminRepository.queueLimit
                  ? const QueueLimitNote(limit: AdminRepository.queueLimit)
                  : const SizedBox.shrink();
            }
            final donation = rows[index];
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                leading: CircleAvatar(
                  backgroundColor: RuhamaaColors.softGreen,
                  foregroundColor: RuhamaaColors.primary,
                  child: Icon(itemCategoryByKey(_category(donation)).icon),
                ),
                title: Text(
                  '${donation['item_type']}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  _subtitle(donation),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => _openDonation(donation),
              ),
            );
          },
        ),
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

  /// Resolves to null when the photos could not be loaded. Photos are only a
  /// reviewing aid, so a failure here never blocks matching.
  late Future<List<String>?> _photos;
  bool _busy = false;

  AdminRepository get _repo => AdminRepository(Supabase.instance.client);

  String get _donationId => '${widget.donation['id']}';

  @override
  void initState() {
    super.initState();
    _future = _repo.matchCandidates(_donationId);
    _photos = _loadPhotos();
  }

  Future<List<String>?> _loadPhotos() async {
    try {
      return await _repo.donationImageUrls(_donationId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    final next = _repo.matchCandidates(_donationId);
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // Rendered by the FutureBuilder as a retryable error state.
    }
  }

  void _reloadPhotos() {
    setState(() {
      _photos = _loadPhotos();
    });
  }

  Future<void> _approve(Map<String, dynamic> candidate) async {
    if (_busy) return;
    final confirmed = await confirmAction(
      context,
      title: 'إرسال عرض المطابقة؟',
      message:
          'سيصل عرض خاص لصاحب هذا الطلب ليقبله أو يعتذر عنه. لا يُنشأ التوصيل قبل موافقته.',
      confirmLabel: 'إرسال العرض',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.approveMatch(_donationId, '${candidate['need_id']}');
      if (!mounted) return;
      showInfoSnack(context, 'تم إرسال عرض المطابقة الخاص للمستفيد.');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر إرسال العرض. حدّث القائمة ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _attributesLine(Map<String, dynamic> row) {
    final text = _attributes(row);
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: RuhamaaColors.primaryDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _donationHeader() {
    final donation = widget.donation;
    final condition =
        StaffLabels.donationConditionLabel(donation['condition'] as String?);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'التبرع: ${donation['item_type']}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 3),
            Text(
              [
                _path(donation),
                if (condition.isNotEmpty) 'الحالة: $condition',
                '${donation['public_code'] ?? ''}',
              ].where((part) => part.isNotEmpty).join(' • '),
              style: const TextStyle(color: RuhamaaColors.textMuted),
            ),
            _attributesLine(donation),
            const SizedBox(height: 12),
            _DonationPhotos(photos: _photos, onRetry: _reloadPhotos),
          ],
        ),
      ),
    );
  }

  Widget _candidateCard(Map<String, dynamic> candidate) {
    final distance = candidate['distance_km'];
    final age = candidate['age_hours'];
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
                      Text(
                        '${candidate['item_type']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _path(candidate),
                        style: const TextStyle(color: RuhamaaColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Chip(label: Text('ملاءمة ${candidate['score']}')),
              ],
            ),
            _attributesLine(candidate),
            const SizedBox(height: 9),
            Text(
              'المسافة: ${distance == null ? 'غير معروفة' : '$distance كم'}'
              ' • الانتظار: ${age == null ? 'غير معروف' : '$age ساعة'}'
              ' • مرات تلبية سابقة لنفس الفئة: ${candidate['prior_same_category'] ?? 0}',
              style: const TextStyle(
                color: RuhamaaColors.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (candidate['accepts_used'] == false) ...const [
              SizedBox(height: 6),
              Text(
                'صاحب الطلب يفضّل شيئًا جديدًا.',
                style: TextStyle(
                  color: RuhamaaColors.rose,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'النقاط المالية والمساهمات وما قدمه الشخص سابقًا من عطاء لا تدخل في أولوية هذه المطابقة.',
              style: TextStyle(
                color: RuhamaaColors.primaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : () => _approve(candidate),
              icon: const Icon(Icons.send_outlined),
              label: Text(_busy ? 'جارٍ الإرسال...' : 'إرسال عرض المطابقة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('مرشحو ${widget.donation['item_type']}')),
      body: RefreshableFuture<List<Map<String, dynamic>>>(
        future: _future,
        onRefresh: _refresh,
        builder: (context, rows) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _donationHeader(),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا يوجد تطابق مناسب حاليًا.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: RuhamaaColors.textMuted),
                ),
              )
            else
              for (final candidate in rows) ...[
                _candidateCard(candidate),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _DonationPhotos extends StatelessWidget {
  const _DonationPhotos({required this.photos, required this.onRetry});

  final Future<List<String>?> photos;
  final VoidCallback onRetry;

  static const double _size = 96;

  void _enlarge(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const SizedBox(
                        height: 240,
                        child: Center(child: Text('جارٍ تحميل الصورة...')),
                      ),
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 240,
                  child: Center(
                    child: Text('لم تُحمَّل الصورة. أغلق ثم حاول مجددًا.'),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 4,
              end: 4,
              child: IconButton.filledTonal(
                tooltip: 'إغلاق',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(IconData icon) {
    return Container(
      width: _size,
      height: _size,
      color: RuhamaaColors.softGreen,
      alignment: Alignment.center,
      child: Icon(icon, color: RuhamaaColors.textMuted),
    );
  }

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(color: RuhamaaColors.textMuted, fontSize: 12);
    return FutureBuilder<List<String>?>(
      future: photos,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Text('جارٍ تحميل صور التبرع...', style: muted);
        }
        final urls = snapshot.data;
        if (snapshot.hasError || urls == null) {
          return Row(
            children: [
              const Expanded(
                child: Text(
                  'لم تُحمَّل صور التبرع. يمكنك متابعة المطابقة بدونها.',
                  style: muted,
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          );
        }
        if (urls.isEmpty) {
          return const Text('لا توجد صور مرفقة بهذا التبرع.', style: muted);
        }
        return SizedBox(
          height: _size,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final url = urls[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _enlarge(context, url),
                  child: Image.network(
                    url,
                    width: _size,
                    height: _size,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : _placeholder(Icons.image_outlined),
                    errorBuilder: (context, error, stackTrace) =>
                        _placeholder(Icons.broken_image_outlined),
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

String _category(Map<String, dynamic> row) {
  final raw = '${row['category']}';
  switch (raw) {
    case 'books':
      return 'education';
    case 'furniture':
    case 'home':
      return 'home_furniture';
    default:
      return itemCategoriesV2.any((c) => c.key == raw) ? raw : 'other';
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
    if ('${entry.value}'.trim().isEmpty || '${entry.key}' == 'size_flexible') {
      continue;
    }
    final specs = category.attributes
        .where((attribute) => attribute.key == '${entry.key}');
    if (specs.isEmpty) continue;
    final spec = specs.first;
    final value = spec.choices['${entry.value}'] ?? '${entry.value}';
    parts.add('${spec.label}: $value');
  }
  return parts.join(' • ');
}
