import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../catalog/item_category_catalog.dart';
import '../../data/item_repository_v2.dart';
import '../../theme/ruhamaa_theme.dart';
import '../contributions/contribution_screen.dart';
import '../items/item_form_components.dart';

class CreateNeedV2Screen extends StatefulWidget {
  const CreateNeedV2Screen({super.key});

  @override
  State<CreateNeedV2Screen> createState() => _CreateNeedV2ScreenState();
}

class _CreateNeedV2ScreenState extends State<CreateNeedV2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _privateDetails = TextEditingController();
  final Map<String, String> _attributes = {};

  String _category = 'clothes';
  String? _group;
  String? _itemTypeKey;
  bool _acceptsUsed = true;
  bool _sizeFlexible = false;
  bool _saving = false;
  int _step = 0;

  @override
  void dispose() {
    _title.dispose();
    _privateDetails.dispose();
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
      _sizeFlexible = false;
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
      _title.text = item?.label ?? '';
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
      if (_category == 'clothes') {
        _attributes['size_flexible'] = _sizeFlexible ? 'true' : 'false';
      }
      final repo = ItemRepositoryV2(Supabase.instance.client);
      final needId = await repo.createNeed(
        category: _category,
        categoryGroup: _group!,
        itemTypeKey: _itemTypeKey!,
        title: _title.text.trim(),
        attributes: _attributes,
        privateDetails: _privateDetails.text.trim(),
        acceptsUsed: _acceptsUsed,
        addressId: await repo.defaultAddressId(),
      );

      if (!mounted) return;
      final contribute = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تم تسجيل احتياجك'),
          content: const Text(
            'طلبك مستمر سواء ساهمت أم لا. عدم القدرة على المساهمة لا يقلل أولوية الاستحقاق. إن رغبت، يمكنك المساهمة بجزء من تكلفة التوصيل نقدًا للموصل عند التسليم؛ لا يوجد دفع داخل التطبيق.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('بدون مساهمة')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('أرغب بالمساهمة')),
          ],
        ),
      );
      if (!mounted) return;
      if (contribute == true) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ContributionScreen(needId: needId)),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الاحتياج: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أحتاج شيئًا')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _Progress(current: _step + 1),
            const SizedBox(height: 18),
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
      key: const ValueKey('need-v2-category'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _InfoBox(
          icon: Icons.favorite_outline_rounded,
          color: RuhamaaColors.warmGoldSoft,
          iconColor: RuhamaaColors.warmGold,
          text: 'اختر ما تحتاجه بدقة. أنت لا تتصفح تبرعات الناس؛ رحماء يستخدم هذه التفاصيل للبحث عن الشيء الأنسب لك بخصوصية.',
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
      key: const ValueKey('need-v2-details'),
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
            labelText: 'اسم مختصر للاحتياج',
            hintText: 'يمكنك جعله أدق من النوع المختار',
          ),
          validator: (value) => value == null || value.trim().length < 3 ? 'اكتب احتياجًا واضحًا' : null,
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
        if (_category == 'clothes') ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: RuhamaaColors.border),
            ),
            child: SwitchListTile(
              title: const Text('أقبل مقاسًا قريبًا', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('فعّلها فقط إذا كان الفرق البسيط في المقاس مناسبًا لك.'),
              value: _sizeFlexible,
              onChanged: (value) => setState(() => _sizeFlexible = value),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: RuhamaaColors.border),
          ),
          child: SwitchListTile(
            title: const Text('أقبل المستعمل بحالة جيدة', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('يساعد ذلك على توسيع فرص العثور على شيء مناسب.'),
            value: _acceptsUsed,
            onChanged: (value) => setState(() => _acceptsUsed = value),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _privateDetails,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'تفاصيل خاصة تساعد رحماء',
            hintText: 'أي معلومات مهمة لفهم المطلوب أو شروط الملاءمة',
            helperText: 'هذه التفاصيل خاصة بفريق رحماء ولا تظهر للمتبرعين كما كتبتها.',
          ),
          validator: (value) => value == null || value.trim().length < 8 ? 'أضف تفاصيل مختصرة تساعدنا في المطابقة' : null,
        ),
        const SizedBox(height: 14),
        const _InfoBox(
          icon: Icons.lock_outline_rounded,
          color: RuhamaaColors.softGreen,
          iconColor: RuhamaaColors.primary,
          text: 'إذا قرر فريق رحماء عرض احتياجك لتحفيز العطاء، سيكتب بطاقة محايدة منفصلة لا تحتوي اسمك أو رقمك أو عنوانك أو قصتك الخاصة.',
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
    final category = itemCategoryByKey(_category);
    final attributeLabels = <String, String>{for (final attribute in category.attributes) attribute.key: attribute.label};
    final attributeText = _attributes.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map((entry) {
          final spec = category.attributes.where((attribute) => attribute.key == entry.key).firstOrNull;
          final value = spec?.choices[entry.value] ?? entry.value;
          return '${attributeLabels[entry.key] ?? entry.key}: $value';
        })
        .join(' • ');
    return Column(
      key: const ValueKey('need-v2-review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('راجع احتياجك قبل التسجيل', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 14),
                _ReviewRow('التصنيف', path),
                _ReviewRow('الاحتياج', _title.text.trim()),
                if (attributeText.isNotEmpty) _ReviewRow('الخصائص', attributeText),
                _ReviewRow('المستعمل', _acceptsUsed ? 'أقبل المستعمل بحالة جيدة' : 'أفضل غير المستعمل'),
                if (_category == 'clothes') _ReviewRow('المقاس', _sizeFlexible ? 'أقبل مقاسًا قريبًا' : 'المقاس المذكور مهم'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _InfoBox(
          icon: Icons.balance_outlined,
          color: RuhamaaColors.softGreen,
          iconColor: RuhamaaColors.primary,
          text: 'المطابقة تعتمد على الملاءمة والأولوية والعدالة. عدم المساهمة في التوصيل وعدم تقديمك لعطاء أو خدمة لا يخفضان أولوية احتياجك.',
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
                icon: const Icon(Icons.favorite_outline_rounded),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'تسجيل الاحتياج'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
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
