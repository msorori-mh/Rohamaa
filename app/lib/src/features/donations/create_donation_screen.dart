import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/donation_image_repository.dart';
import '../../data/ruhamaa_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import '../contributions/contribution_screen.dart';

class CreateDonationScreen extends StatefulWidget {
  const CreateDonationScreen({
    super.key,
    this.prefillCategory,
    this.prefillTitle,
    this.inspiredByDiscoveryCardId,
  });

  final String? prefillCategory;
  final String? prefillTitle;
  final String? inspiredByDiscoveryCardId;

  @override
  State<CreateDonationScreen> createState() => _CreateDonationScreenState();
}

class _CreateDonationScreenState extends State<CreateDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = [];

  String _condition = 'good';
  String _category = 'clothes';
  bool _saving = false;
  int _step = 0;

  static const categories = <String, (String, IconData)>{
    'clothes': ('ملابس', Icons.checkroom_rounded),
    'books': ('كتب وتعليم', Icons.menu_book_rounded),
    'furniture': ('أثاث', Icons.chair_alt_rounded),
    'children': ('أطفال', Icons.toys_rounded),
    'home': ('أدوات منزلية', Icons.home_repair_service_rounded),
    'electronics': ('أجهزة', Icons.devices_other_rounded),
    'events': ('مناسبات', Icons.card_giftcard_rounded),
    'other': ('أخرى', Icons.more_horiz_rounded),
  };

  static const conditions = <String, String>{
    'new': 'جديد',
    'excellent': 'ممتاز',
    'good': 'جيد',
    'minor_repair': 'يحتاج إصلاحًا بسيطًا',
  };

  bool get _inspired => widget.inspiredByDiscoveryCardId != null;

  @override
  void initState() {
    super.initState();
    final category = widget.prefillCategory;
    if (category != null && categories.containsKey(category)) {
      _category = category;
    }
    final title = widget.prefillTitle?.trim();
    if (title != null && title.isNotEmpty) {
      _title.text = title;
    }
    if (_inspired) _step = 1;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(
      maxWidth: 1440,
      maxHeight: 1440,
      imageQuality: 72,
      limit: 4,
    );
    if (!mounted) return;
    setState(() {
      _images
        ..clear()
        ..addAll(picked.take(4));
    });
  }

  Future<bool> _ensureProfile() async {
    final repo = RuhamaaRepository(Supabase.instance.client);
    if (await repo.hasOperationalProfile()) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('أكمل رقم الهاتف وعنوان التوصيل أولًا.')),
    );
    await context.push('/onboarding');
    return repo.hasOperationalProfile();
  }

  void _nextFromCategory() => setState(() => _step = 1);

  void _nextFromDetails() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _step = 2);
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step -= 1);
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      if (!await _ensureProfile()) return;
      final repo = RuhamaaRepository(Supabase.instance.client);
      final donationId = await repo.createDonation(
        title: _title.text.trim(),
        description: _description.text.trim(),
        condition: _condition,
        category: _category,
        addressId: await repo.defaultAddressId(),
        inspiredByDiscoveryCardId: widget.inspiredByDiscoveryCardId,
      );

      final imageRepo = DonationImageRepository(Supabase.instance.client);
      for (var i = 0; i < _images.length; i++) {
        final x = _images[i];
        final Uint8List bytes = await x.readAsBytes();
        final ext = x.name.contains('.') ? x.name.split('.').last : 'jpg';
        await imageRepo.upload(
          donationId: donationId,
          bytes: bytes,
          extension: ext,
          sortOrder: i,
        );
      }

      if (!mounted) return;
      final contribute = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تم تسجيل عطائك'),
          content: const Text(
            'تبرعك بالشيء هو الأهم وقد يصنع فرقًا حقيقيًا. وإذا استطعت، يمكنك أيضًا المساهمة في تكلفة استلامه وتوصيله؛ ومساهمتك تساعد رحماء على إيصال تبرعات أخرى لأشخاص لا يستطيعون تحمل تكلفة التوصيل. لا يوجد دفع داخل التطبيق، والمبلغ يُسلَّم نقدًا للموصل عند الاستلام.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('أكتفي بالتبرع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('أساهم في التوصيل'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (contribute == true) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ContributionScreen(donationId: donationId)),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ التبرع: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أعطي شيئًا')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _ProgressHeader(current: _step + 1),
            const SizedBox(height: 18),
            if (_inspired) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: RuhamaaColors.warmGoldSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: RuhamaaColors.warmGold),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'هذه الحاجة ألهمت عطائك، لذلك ملأنا بعض البيانات لك. لا يعني ذلك أن الشيء محجوز لنفس الحالة؛ رحماء يوجّه العطاء للحاجة الأعلى أولوية من الحالات المتوافقة.',
                        style: TextStyle(color: RuhamaaColors.primaryDark, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_step) {
                0 => _categoryStep(),
                1 => _detailsStep(),
                _ => _reviewStep(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryStep() {
    return Column(
      key: const ValueKey('donation-category'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RuhamaaColors.softGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.favorite_outline_rounded, color: RuhamaaColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ابدأ باختيار نوع الشيء الذي تريد أن يستفيد منه غيرك. هويتك لا تظهر للمستفيد.',
                  style: TextStyle(
                    color: RuhamaaColors.primaryDark,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SectionTitle('اختر التصنيف المناسب'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: categories.entries.map((entry) {
            final selected = _category == entry.key;
            return _CategoryTile(
              label: entry.value.$1,
              icon: entry.value.$2,
              selected: selected,
              onTap: () => setState(() => _category = entry.key),
            );
          }).toList(),
        ),
        const SizedBox(height: 26),
        FilledButton.icon(
          onPressed: _nextFromCategory,
          icon: const Icon(Icons.chevron_left_rounded),
          label: const Text('التالي: التفاصيل'),
        ),
      ],
    );
  }

  Widget _detailsStep() {
    return Column(
      key: const ValueKey('donation-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('أخبرنا عن عطائك'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'ما هو الشيء؟',
            hintText: 'مثال: جاكيت شتوي رجالي',
          ),
          validator: (v) => v == null || v.trim().length < 3
              ? 'اكتب اسمًا واضحًا للشيء'
              : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _description,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'تفاصيل إضافية (اختياري)',
            hintText: 'المقاس، العمر التقريبي، أي ملاحظات مهمة',
          ),
        ),
        const SizedBox(height: 18),
        const _SectionTitle('حالة الشيء'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: conditions.entries.map((entry) {
            return ChoiceChip(
              label: Text(entry.value),
              selected: _condition == entry.key,
              onSelected: (_) => setState(() => _condition = entry.key),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('أضف صورًا للعطاء'),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _saving ? null : _pickImages,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(
            _images.isEmpty
                ? 'إضافة صور (حتى 4)'
                : 'تم اختيار ${_images.length} صورة — تغيير',
          ),
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: RuhamaaColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.photo_library_outlined, color: RuhamaaColors.primary),
                const SizedBox(width: 10),
                Text('جاهز لرفع ${_images.length} صورة'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _back,
                child: const Text('السابق'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _nextFromDetails,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('التالي: المراجعة'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _reviewStep() {
    final category = categories[_category]!.$1;
    final condition = conditions[_condition] ?? _condition;
    return Column(
      key: const ValueKey('donation-review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: RuhamaaColors.warmSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: RuhamaaColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.fact_check_outlined, color: RuhamaaColors.primary),
                  SizedBox(width: 9),
                  Text(
                    'راجع عطائك قبل الإرسال',
                    style: TextStyle(
                      color: RuhamaaColors.primaryDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ReviewRow(label: 'التصنيف', value: category),
              _ReviewRow(label: 'الشيء', value: _title.text.trim()),
              _ReviewRow(label: 'الحالة', value: condition),
              _ReviewRow(label: 'الصور', value: _images.isEmpty ? 'بدون صور' : '${_images.length} صورة'),
              if (_description.text.trim().isNotEmpty)
                _ReviewRow(label: 'ملاحظات', value: _description.text.trim()),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: RuhamaaColors.softGreen,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded, color: RuhamaaColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _inspired
                      ? 'بعد الإرسال يراجع رحماء العطاء ويطابقه بعدل. البطاقة التي رأيتها تحفّز العطاء فقط ولا تمنح صاحبها حقًا حصريًا في هذا الشيء.'
                      : 'بعد الإرسال يراجع رحماء العطاء ويبحث عن احتياج مناسب. لا يختار المتبرع المستفيد ولا تظهر هوية أي طرف للآخر.',
                  style: const TextStyle(color: RuhamaaColors.primaryDark, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _back,
                child: const Text('تعديل'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.volunteer_activism_outlined),
                label: Text(_saving ? 'جارٍ الحفظ والرفع...' : 'أرسل عطائي'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    const labels = ['التصنيف', 'التفاصيل', 'المراجعة'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index + 1 <= current;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: active ? RuhamaaColors.primary : RuhamaaColors.border,
                foregroundColor: active ? Colors.white : RuhamaaColors.textMuted,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                labels[index],
                style: TextStyle(
                  fontSize: 11,
                  color: active ? RuhamaaColors.primaryDark : RuhamaaColors.textMuted,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(label, style: const TextStyle(color: RuhamaaColors.textMuted)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? RuhamaaColors.softGreen : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? RuhamaaColors.primary : RuhamaaColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? RuhamaaColors.primary : RuhamaaColors.textMuted,
                size: 23,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: RuhamaaColors.primaryDark,
            fontWeight: FontWeight.w900,
          ),
    );
  }
}
