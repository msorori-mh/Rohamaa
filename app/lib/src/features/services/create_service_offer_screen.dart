import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/service_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import 'service_catalog.dart';

class CreateServiceOfferScreen extends StatefulWidget {
  const CreateServiceOfferScreen({super.key});

  @override
  State<CreateServiceOfferScreen> createState() => _CreateServiceOfferScreenState();
}

class _CreateServiceOfferScreenState extends State<CreateServiceOfferScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _availabilityNote = TextEditingController();
  final _customHours = TextEditingController(text: '3');

  int _step = 0;
  String _providerKind = 'person';
  String _category = ruhamaaServiceCategories.first.key;
  String _serviceType = ruhamaaServiceCategories.first.types.first;
  String _availabilityMode = 'hours';
  double _availableHours = 3;
  String _materialsMode = 'case_by_case';
  String _pricingMode = 'free';
  bool _saving = false;

  ServiceCategoryOption get _categoryData => serviceCategoryByKey(_category);

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _availabilityNote.dispose();
    _customHours.dispose();
    super.dispose();
  }

  Future<bool> _ensureArea() async {
    final repo = ServiceRepository(Supabase.instance.client);
    if (await repo.defaultServiceAreaId() != null) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('أكمل بيانات التوصيل ونطاق الخدمة أولًا.')),
    );
    await context.push('/onboarding');
    return await repo.defaultServiceAreaId() != null;
  }

  bool _validateDetails() {
    if (_title.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب عنوانًا واضحًا لما تستطيع تقديمه.')),
      );
      return false;
    }
    if (_availabilityMode == 'custom') {
      final hours = double.tryParse(_customHours.text.trim());
      if (hours == null || hours <= 0 || hours > 24) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدد عدد ساعات بين 1 و24.')),
        );
        return false;
      }
      _availableHours = hours;
    }
    return true;
  }

  void _next() {
    if (_step == 1 && !_validateDetails()) return;
    if (_step < 2) setState(() => _step += 1);
  }

  void _back() {
    if (_step > 0) setState(() => _step -= 1);
  }

  Future<void> _submit() async {
    if (!_validateDetails()) return;
    setState(() => _saving = true);
    try {
      if (!await _ensureArea()) return;
      await ServiceRepository(Supabase.instance.client).createServiceOffer(
        providerKind: _providerKind,
        category: _category,
        serviceType: _serviceType,
        title: _title.text.trim(),
        description: _description.text.trim(),
        availabilityMode: _availabilityMode,
        availableHours: _availableHours,
        availabilityNote: _availabilityNote.text.trim(),
        materialsMode: _materialsMode,
        pricingMode: _pricingMode,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('شكرًا لعطائك من وقتك'),
          content: const Text(
            'تم تسجيل ما تستطيع تقديمه. يراجع فريق رحماء العرض قبل مطابقته باحتياج مناسب. لن يُعرض كإعلان عام، وتقديمك للخدمة لا يؤثر على أولوية أي احتياج تسجله لنفسك.',
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تسجيل عطائك من الوقت أو المهارة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أقدّم وقتي أو مهارتي')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: _StepHeader(current: _step),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: _step == 0
                    ? _buildCategoryStep()
                    : _step == 1
                        ? _buildDetailsStep()
                        : _buildReviewStep(),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _back,
                        child: const Text('السابق'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : (_step == 2 ? _submit : _next),
                      child: Text(
                        _saving
                            ? 'جارٍ الحفظ...'
                            : _step == 2
                                ? 'سجّل عطائي من الوقت'
                                : 'التالي',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _InfoBox(
          icon: Icons.handshake_outlined,
          text: 'يمكنك أن تحتاج شيئًا وفي الوقت نفسه تقدّم مهارة أو جزءًا من وقتك. لا يوجد نظام مقايضة أو نقاط بين الناس.',
          warm: false,
        ),
        const SizedBox(height: 18),
        const _SectionTitle('من سيقدّم الخدمة؟'),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'person', label: Text('أنا شخص'), icon: Icon(Icons.person_outline_rounded)),
            ButtonSegment(value: 'business', label: Text('محل أو جهة'), icon: Icon(Icons.storefront_outlined)),
          ],
          selected: {_providerKind},
          onSelectionChanged: (value) => setState(() => _providerKind = value.first),
        ),
        const SizedBox(height: 22),
        const _SectionTitle('ما المهارة أو الخدمة؟'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: ruhamaaServiceCategories.map((category) {
            final selected = category.key == _category;
            return Material(
              color: selected ? RuhamaaColors.softGreen : Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() {
                  _category = category.key;
                  _serviceType = category.types.first;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? RuhamaaColors.primary : RuhamaaColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(category.icon, color: selected ? RuhamaaColors.primary : RuhamaaColors.textMuted),
                      const SizedBox(width: 7),
                      Expanded(child: Text(category.label, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600))),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        const _SectionTitle('حدد النوع الأقرب'),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categoryData.types.map((type) => ChoiceChip(
                label: Text(type),
                selected: _serviceType == type,
                onSelected: (_) => setState(() => _serviceType = type),
              )).toList(),
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const _SectionTitle('صف ما تستطيع تقديمه'),
        const SizedBox(height: 10),
        TextField(
          controller: _title,
          decoration: InputDecoration(
            labelText: _providerKind == 'business' ? 'اسم الخدمة أو العرض' : 'عنوان بسيط',
            hintText: _providerKind == 'business' ? 'مثال: تجهيز عروس مجانًا' : 'مثال: أقدّم سباكة منزلية بسيطة',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'تفاصيل إضافية (اختياري)',
            hintText: 'ما الأعمال التي تستطيع تنفيذها وما حدود الخدمة؟',
          ),
        ),
        const SizedBox(height: 20),
        const _SectionTitle('كم من الوقت تستطيع تقديمه؟'),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _timeChip('3 ساعات', 'hours', 3),
            _timeChip('نصف يوم', 'half_day', 4),
            _timeChip('يوم كامل', 'day', 8),
            ChoiceChip(
              label: const Text('وقت آخر'),
              selected: _availabilityMode == 'custom',
              onSelected: (_) => setState(() => _availabilityMode = 'custom'),
            ),
          ],
        ),
        if (_availabilityMode == 'custom') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customHours,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'عدد الساعات', suffixText: 'ساعة'),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _availabilityNote,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'متى تكون متاحًا؟ (اختياري)',
            hintText: 'مثال: بعد العصر أو يوم الجمعة',
          ),
        ),
        const SizedBox(height: 20),
        const _SectionTitle('التكلفة والمواد'),
        const SizedBox(height: 9),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'free', label: Text('الخدمة مجانية')),
            ButtonSegment(value: 'materials_only', label: Text('العمل مجاني والمواد فقط')),
          ],
          selected: {_pricingMode},
          onSelectionChanged: (value) => setState(() => _pricingMode = value.first),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _materialsMode,
          decoration: const InputDecoration(labelText: 'من يوفر المواد إن احتاجت الخدمة؟'),
          items: const [
            DropdownMenuItem(value: 'none', child: Text('لا تحتاج مواد غالبًا')),
            DropdownMenuItem(value: 'provider', child: Text('أستطيع توفيرها')),
            DropdownMenuItem(value: 'recipient', child: Text('من يحتاج الخدمة يوفرها')),
            DropdownMenuItem(value: 'case_by_case', child: Text('حسب الحالة وبعد مراجعة رحماء')),
          ],
          onChanged: (value) => setState(() => _materialsMode = value ?? 'case_by_case'),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const _SectionTitle('راجع عطائك قبل الإرسال'),
        const SizedBox(height: 12),
        _ReviewTile(label: 'المجال', value: '${_categoryData.label} — $_serviceType'),
        _ReviewTile(label: 'العرض', value: _title.text.trim()),
        _ReviewTile(label: 'الوقت المتاح', value: '${_availableHours.toStringAsFixed(_availableHours % 1 == 0 ? 0 : 1)} ساعة'),
        _ReviewTile(label: 'نوع مقدم الخدمة', value: _providerKind == 'business' ? 'محل أو جهة' : 'شخص'),
        _ReviewTile(label: 'المقابل', value: _pricingMode == 'free' ? 'مجاني بالكامل' : 'العمل مجاني؛ المواد فقط حسب الحالة'),
        const SizedBox(height: 12),
        _InfoBox(
          icon: Icons.verified_user_outlined,
          text: 'يعرض هذا التسجيل على فريق رحماء للمراجعة. لن يظهر للعامة، ولن يحصل مقدم الخدمة على اسم أو عنوان الشخص الآخر إلا بالقدر الضروري بعد اعتماد المطابقة.',
          warm: true,
        ),
        const SizedBox(height: 12),
        _InfoBox(
          icon: Icons.balance_outlined,
          text: 'تقديمك وقتًا أو مهارة لا يمنحك نقاطًا ولا يرفع أولوية طلباتك. يمكن لأي شخص أن يحتاج ويعطي في الوقت نفسه.',
          warm: false,
        ),
      ],
    );
  }

  Widget _timeChip(String label, String mode, double hours) {
    return ChoiceChip(
      label: Text(label),
      selected: _availabilityMode == mode,
      onSelected: (_) => setState(() {
        _availabilityMode = mode;
        _availableHours = hours;
      }),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    const labels = ['المهارة', 'الوقت والتفاصيل', 'المراجعة'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= current;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: active ? RuhamaaColors.primary : RuhamaaColors.border,
                foregroundColor: active ? Colors.white : RuhamaaColors.textMuted,
                child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(height: 5),
              Text(labels[index], textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: RuhamaaColors.textMuted)),
            ],
          ),
        );
      }),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: RuhamaaColors.primaryDark,
              fontWeight: FontWeight.w900,
            ),
      );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text, required this.warm});
  final IconData icon;
  final String text;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final background = warm ? RuhamaaColors.warmGoldSoft : RuhamaaColors.softGreen;
    final accent = warm ? RuhamaaColors.warmGold : RuhamaaColors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: RuhamaaColors.primaryDark, height: 1.5))),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          title: Text(label, style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 12)),
          subtitle: Text(value.isEmpty ? '—' : value, style: const TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      );
}
