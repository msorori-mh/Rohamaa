import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../catalog/item_category_catalog.dart';
import '../../data/donation_image_repository.dart';
import '../../data/item_repository_v2.dart';
import '../../theme/ruhamaa_theme.dart';
import '../contributions/contribution_screen.dart';
import '../items/item_form_components.dart';

class CreateDonationV2Screen extends StatefulWidget {
  const CreateDonationV2Screen({
    super.key,
    this.prefillCategory,
    this.prefillGroup,
    this.prefillItemTypeKey,
    this.prefillTitle,
    this.prefillAttributes,
    this.inspiredByDiscoveryCardId,
  });

  final String? prefillCategory;
  final String? prefillGroup;
  final String? prefillItemTypeKey;
  final String? prefillTitle;
  final Map<String, String>? prefillAttributes;
  final String? inspiredByDiscoveryCardId;

  @override
  State<CreateDonationV2Screen> createState() => _CreateDonationV2ScreenState();
}

class _CreateDonationV2ScreenState extends State<CreateDonationV2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  final Map<String, String> _attributes = {};

  String _category = 'clothes';
  String? _group;
  String? _itemTypeKey;
  String _condition = 'good';
  bool _saving = false;
  int _step = 0;

  static const conditions = <String, String>{
    'new': 'جديد',
    'excellent': 'ممتاز',
    'good': 'جيد',
    'minor_repair': 'يحتاج إصلاحًا بسيطًا',
  };

  bool get _inspired => widget.inspiredByDiscoveryCardId != null;

  String _normalizeCategory(String? value) {
    switch (value) {
      case 'books':
        return 'education';
      case 'furniture':
      case 'home':
        return 'home_furniture';
      default:
        final raw = value ?? 'clothes';
        return itemCategoriesV2.any((category) => category.key == raw) ? raw : 'other';
    }
  }

  @override
  void initState() {
    super.initState();
    _category = _normalizeCategory(widget.prefillCategory);
    final category = itemCategoryByKey(_category);
    final groupCandidate = widget.prefillGroup;
    if (groupCandidate != null && category.groups.any((group) => group.key == groupCandidate)) {
      _group = groupCandidate;
    }
    final typeCandidate = widget.prefillItemTypeKey;
    if (typeCandidate != null && itemTypeByKey(category, typeCandidate) != null) {
      _itemTypeKey = typeCandidate;
      _group ??= category.groups
          .firstWhere((group) => group.items.any((item) => item.key == typeCandidate))
          .key;
    }
    _attributes.addAll(widget.prefillAttributes ?? const {});
    final prefillTitle = widget.prefillTitle?.trim();
    if (prefillTitle != null && prefillTitle.isNotEmpty) {
      _title.text = prefillTitle;
    } else if (_itemTypeKey != null) {
      _title.text = itemTypeByKey(category, _itemTypeKey)?.label ?? '';
    }
    if (_inspired) _step = _itemTypeKey == null ? 0 : 1;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<bool> _ensureProfile() async {
    final repo = ItemRepositoryV2(Supabase.instance.client);
    if (await repo.hasOperationalProfile()) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('أكمل رقم الهاتف وعنوان التوصيل أولًا.')),
    );
    await context.push('/onboarding');
    return repo.hasOperationalProfile();
  }

  void _changeCategory(String value) {
    setState(() {
      _category = value;
      _group = null;
      _itemTypeKey = null;
      _attributes.clear();
      _title.clear();
    });
  }

  void _changeGroup(String value) {
    setState(() {
      _group = value;
      _itemTypeKey = null;
      _title.clear();
    });
  }

  void _changeItem(String value) {
    final category = itemCategoryByKey(_category);
    final item = itemTypeByKey(category, value);
    setState(() {
      _itemTypeKey = value;
      if (_title.text.trim().isEmpty || _title.text == itemTypeByKey(category, _itemTypeKey)?.label) {
        _title.text = item?.label ?? '';
      } else if (!_inspired) {
        _title.text = item?.label ?? _title.text;
      }
    });
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

  void _nextFromCategory() {
    if (_group == null || _itemTypeKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر القسم ثم نوع الشيء بالتحديد.')),
      );
      return;
    }
    setState(() => _step = 1);
  }

  void _nextFromDetails() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _step = 2);
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step -= 1);
    }
  }

  Future<void> _submit() async {
    if (_group == null || _itemTypeKey == null) return;
    setState(() => _saving = true);
    try {
      if (!await _ensureProfile()) return;
      final repo = ItemRepositoryV2(Supabase.instance.client);
      final donationId = await repo.createDonation(
        category: _category,
        categoryGroup: _group!,
        itemTypeKey: _itemTypeKey!,
        title: _title.text.trim(),
        condition: _condition,
        attributes: _attributes,
        description: _description.text,
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
            'تبرعك بالشيء هو الأهم. وإذا استطعت يمكنك أيضًا المساهمة في تكلفة الاستلام والتوصيل. لا يوجد دفع داخل التطبيق، والمبلغ يُسلَّم نقدًا للموصل عند الاستلام.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('أكتفي بالتبرع')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('أساهم في التوصيل')),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ العطاء: $e')));
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
            _Progress(current: _step + 1),
            const SizedBox(height: 18),
            if (_inspired) ...[
              _InfoBox(
                icon: Icons.lightbulb_outline_rounded,
                color: RuhamaaColors.warmGoldSoft,
                iconColor: RuhamaaColors.warmGold,
                text: 'هذه الحاجة ألهمت عطائك، لذلك ملأنا ما توفر من البيانات. البطاقة ليست حجزًا لشخص بعينه؛ رحماء يوجّه العطاء للحاجة الأعلى أولوية من الحالات المتوافقة.',
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
      key: const ValueKey('donation-v2-category'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _InfoBox(
          icon: Icons.favorite_outline_rounded,
          color: RuhamaaColors.softGreen,
          iconColor: RuhamaaColors.primary,
          text: 'اختر النوع بدقة حتى يستطيع رحماء مطابقة عطائك مع الاحتياج المناسب بدون أن تتصفح أو تختار الأشخاص.',
        ),
        const SizedBox(height: 18),
        ItemClassificationSelector(
          categoryKey: _category,
          groupKey: _group,
          itemTypeKey: _itemTypeKey,
          onCategoryChanged: _changeCategory,
          onGroupChanged: _changeGroup,
          onItemTypeChanged: _changeItem,
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
    final category = itemCategoryByKey(_category);
    return Column(
      key: const ValueKey('donation-v2-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          itemPathLabel(categoryKey: _category, groupKey: _group, itemTypeKey: _itemTypeKey),
          style: const TextStyle(color: RuhamaaColors.primary, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'اسم مختصر للشيء',
            hintText: 'يمكنك إضافة وصف مختصر أدق',
          ),
          validator: (value) => value == null || value.trim().length < 3 ? 'اكتب اسمًا واضحًا للشيء' : null,
        ),
        const SizedBox(height: 16),
        ItemAttributesEditor(
          category: category,
          values: _attributes,
          onChanged: (key, value) {
            _attributes[key] = value;
            if (category.attributes.firstWhere((attribute) => attribute.key == key).isChoice) setState(() {});
          },
        ),
        const SizedBox(height: 4),
        Text('حالة الشيء', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: conditions.entries.map((entry) => ChoiceChip(
                label: Text(entry.value),
                selected: _condition == entry.key,
                onSelected: (_) => setState(() => _condition = entry.key),
              )).toList(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _description,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'ملاحظات إضافية (اختياري)',
            hintText: 'أي تفاصيل لا تغطيها الحقول السابقة',
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _saving ? null : _pickImages,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(_images.isEmpty ? 'إضافة صور (حتى 4)' : 'تم اختيار ${_images.length} صورة — تغيير'),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: _back, child: const Text('السابق'))),
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
    final path = itemPathLabel(categoryKey: _category, groupKey: _group, itemTypeKey: _itemTypeKey);
    final condition = conditions[_condition] ?? _condition;
    final attributeText = _attributes.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' • ');
    return Column(
      key: const ValueKey('donation-v2-review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('راجع عطائك قبل الإرسال', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 14),
                _ReviewRow('التصنيف', path),
                _ReviewRow('الشيء', _title.text.trim()),
                _ReviewRow('الحالة', condition),
                if (attributeText.isNotEmpty) _ReviewRow('الخصائص', attributeText),
                _ReviewRow('الصور', _images.isEmpty ? 'بدون صور' : '${_images.length} صورة'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _InfoBox(
          icon: Icons.balance_outlined,
          color: RuhamaaColors.softGreen,
          iconColor: RuhamaaColors.primary,
          text: _inspired
              ? 'البطاقة التي رأيتها تحفّز العطاء فقط. المطابقة النهائية تتم وفق الملاءمة والأولوية والعدالة، وليس وفق اختيار المتبرع.'
              : 'يراجع رحماء العطاء ويطابقه بخصوصية. لا تختار المستفيد ولا تظهر هوية أي طرف للآخر.',
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: _saving ? null : _back, child: const Text('تعديل'))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.volunteer_activism_outlined),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'أرسل عطائي'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.current});
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
                child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 5),
              Text(labels[index], style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        );
      }),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.color, required this.iconColor, required this.text});
  final IconData icon;
  final Color color;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: RuhamaaColors.primaryDark, height: 1.5))),
          ],
        ),
      );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 74, child: Text(label, style: const TextStyle(color: RuhamaaColors.textMuted))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
}
