import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../catalog/item_category_catalog.dart';
import '../../core/app_error.dart';
import '../../data/item_repository_v2.dart';
import '../../domain/item_form_rules.dart';
import '../../theme/ruhamaa_theme.dart';
import '../contributions/contribution_screen.dart';
import '../items/form_guards.dart';
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
  bool _touched = false;
  bool _selectionMissing = false;
  int _step = 0;

  /// Title that was filled from the selected item, if any. A title that
  /// differs from it was typed by the person and is never overwritten.
  String? _autoTitle;

  /// Set once the need exists on the server, so that pressing send again can
  /// never create a second need.
  CreatedOperation? _created;

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
    showInfoSnack(context, 'أكمل رقم الهاتف وعنوان التوصيل أولًا.');
    await context.push('/onboarding');
    return repo.hasOperationalProfile();
  }

  void _clearAutoTitle() {
    if (!isCustomItemTitle(title: _title.text, autoTitle: _autoTitle)) {
      _title.clear();
    }
    _autoTitle = null;
  }

  void _changeCategory(String value) {
    if (value == _category) return;
    setState(() {
      _touched = true;
      _category = value;
      _group = null;
      _itemTypeKey = null;
      _attributes.clear();
      _clearAutoTitle();
      _sizeFlexible = false;
    });
  }

  void _changeGroup(String value) {
    if (value == _group) return;
    setState(() {
      _touched = true;
      _group = value;
      _itemTypeKey = null;
      _clearAutoTitle();
    });
  }

  void _changeItem(String value) {
    final category = itemCategoryByKey(_category);
    final label = itemTypeByKey(category, value)?.label ?? '';
    setState(() {
      _touched = true;
      _selectionMissing = false;
      _itemTypeKey = value;
      _title.text = titleAfterItemChange(
        currentTitle: _title.text,
        previousAutoTitle: _autoTitle,
        newItemLabel: label,
      );
      _autoTitle = label;
    });
  }

  void _nextFromCategory() {
    if (_group == null || _itemTypeKey == null) {
      setState(() => _selectionMissing = true);
      return;
    }
    setState(() => _step = 1);
  }

  void _nextFromDetails() {
    if (!_formKey.currentState!.validate()) return;
    // A field scrolled far out of view is not built, so the form cannot show
    // its message: check the values themselves as well.
    final problem = validateItemTitle(_title.text, emptyMessage: 'اكتب احتياجًا واضحًا') ??
        validateRequiredText(
          _privateDetails.text,
          min: 8,
          emptyMessage: 'أضف تفاصيل مختصرة تساعدنا في البحث',
        );
    if (problem != null) {
      showInfoSnack(context, problem);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _step = 2);
  }

  /// System back and the on-screen back buttons: go to the previous step, or
  /// leave the form after confirming when data was entered.
  Future<void> _handleBack() async {
    if (_saving) return;
    if (_step > 0) {
      setState(() => _step -= 1);
      return;
    }
    if (_touched) {
      final discard = await confirmDiscardChanges(context);
      if (!mounted) return;
      if (!discard) return;
    }
    leaveForm(context);
  }

  Future<void> _submit() async {
    if (_saving || _group == null || _itemTypeKey == null) return;
    setState(() => _saving = true);
    try {
      var created = _created;
      if (created == null) {
        if (!await _ensureProfile()) return;
        if (_category == 'clothes') {
          _attributes['size_flexible'] = _sizeFlexible ? 'true' : 'false';
        }
        final repo = ItemRepositoryV2(Supabase.instance.client);
        created = await repo.createNeed(
          category: _category,
          categoryGroup: _group!,
          itemTypeKey: _itemTypeKey!,
          title: _title.text.trim(),
          attributes: _attributes,
          privateDetails: _privateDetails.text.trim(),
          acceptsUsed: _acceptsUsed,
          addressId: await repo.defaultAddressId(),
        );
        _created = created;
      }
      final need = created;
      const intro =
          'سنراجع طلبك ونبحث عن شيء مناسب. المساهمة في التوصيل اختيارية ولا تؤثر في قبول طلبك أو أولويته.';
      final message = need.publicCode.isEmpty ? intro : 'رقم الطلب: ${need.publicCode}\n\n$intro';

      if (!mounted) return;
      final contribute = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('تم تسجيل طلبك'),
          content: Text(message),
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
          MaterialPageRoute<void>(builder: (_) => ContributionScreen(needId: need.id)),
        );
      }
      if (mounted) leaveForm(context);
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر إرسال الطلب. تحقق من اتصالك وحاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _step == 0 && !_touched && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('اطلب ما تحتاجه')),
        body: Form(
          key: _formKey,
          onChanged: () {
            if (!_touched) setState(() => _touched = true);
          },
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
          text: 'اختر ما تحتاجه بدقة لنبحث لك عن الشيء الأنسب بخصوصية.',
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
        if (_selectionMissing) ...[
          const SizedBox(height: 12),
          Text(
            'اختر القسم ثم نوع الشيء بالتحديد.',
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700),
          ),
        ],
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
          maxLength: ItemFormLimits.title,
          decoration: const InputDecoration(
            labelText: 'اسم مختصر للطلب',
            hintText: 'يمكنك جعله أدق من النوع المختار',
            counterText: '',
          ),
          validator: (value) => validateItemTitle(value, emptyMessage: 'اكتب احتياجًا واضحًا'),
        ),
        const SizedBox(height: 16),
        ItemAttributesEditor(
          category: category,
          values: _attributes,
          onChanged: (key, value) {
            _attributes[key] = value;
            if (category.attributes.any((attribute) => attribute.key == key && attribute.isChoice)) setState(() {});
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
              onChanged: (value) => setState(() {
                _touched = true;
                _sizeFlexible = value;
              }),
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
            onChanged: (value) => setState(() {
              _touched = true;
              _acceptsUsed = value;
            }),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _privateDetails,
          maxLines: 4,
          maxLength: ItemFormLimits.description,
          decoration: const InputDecoration(
            labelText: 'تفاصيل تساعدنا',
            hintText: 'أي معلومات مهمة لفهم المطلوب أو شروط الملاءمة',
            helperText: 'هذه التفاصيل خاصة بفريق عطاء ولا تظهر للمتبرعين كما كتبتها.',
          ),
          validator: (value) => validateRequiredText(
            value,
            min: 8,
            emptyMessage: 'أضف تفاصيل مختصرة تساعدنا في البحث',
          ),
        ),
        const SizedBox(height: 14),
        const _InfoBox(
          icon: Icons.lock_outline_rounded,
          color: RuhamaaColors.softGreen,
          iconColor: RuhamaaColors.primary,
          text: 'قد نعرض بطاقة مختصرة عن الطلب دون اسمك أو رقمك أو عنوانك.',
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: _handleBack, child: const Text('السابق'))),
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
    final attributeText = describeItemAttributes(_category, _attributes);
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
                const Text('راجع طلبك قبل الإرسال', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 14),
                _ReviewRow('التصنيف', path),
                _ReviewRow('الطلب', _title.text.trim()),
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
          text: 'نرتّب الطلبات حسب الحاجة والملاءمة. المساهمة في التوصيل أو التبرع ليست شرطًا ولا تغيّر الأولوية.',
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: _saving ? null : _handleBack, child: const Text('تعديل'))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.favorite_outline_rounded),
                label: Text(_saving ? 'جارٍ الإرسال...' : 'إرسال الطلب'),
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
