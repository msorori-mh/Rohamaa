import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/service_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import 'service_catalog.dart';

class CreateServiceRequestScreen extends StatefulWidget {
  const CreateServiceRequestScreen({super.key});

  @override
  State<CreateServiceRequestScreen> createState() => _CreateServiceRequestScreenState();
}

class _CreateServiceRequestScreenState extends State<CreateServiceRequestScreen> {
  final _title = TextEditingController();
  final _details = TextEditingController();
  final _preferredTime = TextEditingController();

  int _step = 0;
  String _category = ruhamaaServiceCategories.first.key;
  String _serviceType = ruhamaaServiceCategories.first.types.first;
  double? _estimatedHours = 3;
  bool _materialsAvailable = false;
  bool _saving = false;

  ServiceCategoryOption get _categoryData => serviceCategoryByKey(_category);

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _preferredTime.dispose();
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
        const SnackBar(content: Text('اكتب وصفًا واضحًا للخدمة التي تحتاجها.')),
      );
      return false;
    }
    if (_details.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف تفاصيل مختصرة تساعدنا في البحث.')),
      );
      return false;
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
      await ServiceRepository(Supabase.instance.client).createServiceRequest(
        category: _category,
        serviceType: _serviceType,
        title: _title.text.trim(),
        details: _details.text.trim(),
        estimatedHours: _estimatedHours,
        preferredTimeNote: _preferredTime.text.trim(),
        materialsAvailable: _materialsAvailable,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تم تسجيل طلب الخدمة'),
          content: const Text(
            'سنراجع طلبك ونبحث عن شخص أو جهة مناسبة. لن يظهر طلبك للعامة.',
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إرسال طلب الخدمة. تحقق من اتصالك وحاول مرة أخرى.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اطلب خدمة')),
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
                                ? 'إرسال طلب الخدمة'
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
        const _InfoBox(
          icon: Icons.lock_outline_rounded,
          text: 'اختر الخدمة التي تحتاجها، وسنبحث عن شخص مناسب بخصوصية.',
          warm: false,
        ),
        const SizedBox(height: 18),
        const _SectionTitle('ما نوع الخدمة التي تحتاجها؟'),
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
              color: selected ? RuhamaaColors.warmGoldSoft : Colors.white,
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
                      color: selected ? RuhamaaColors.warmGold : RuhamaaColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(category.icon, color: selected ? RuhamaaColors.warmGold : RuhamaaColors.textMuted),
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
        const _SectionTitle('صف الخدمة المطلوبة'),
        const SizedBox(height: 10),
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'ماذا تحتاج؟',
            hintText: 'مثال: إصلاح تسريب في المطبخ',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _details,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'تفاصيل الحالة',
            hintText: 'اشرح العمل المطلوب فقط دون كتابة معلومات شخصية.',
            helperText: 'هذه التفاصيل لا تظهر للعامة.',
          ),
        ),
        const SizedBox(height: 20),
        const _SectionTitle('كم تتوقع أن تحتاج الخدمة؟'),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _hoursChip('ساعة', 1),
            _hoursChip('3 ساعات', 3),
            _hoursChip('نصف يوم', 4),
            _hoursChip('يوم', 8),
            ChoiceChip(
              label: const Text('لا أعرف'),
              selected: _estimatedHours == null,
              onSelected: (_) => setState(() => _estimatedHours = null),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _preferredTime,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'وقت مناسب أو ملاحظات الموعد (اختياري)',
            hintText: 'مثال: بعد العصر أو خلال هذا الأسبوع',
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: RuhamaaColors.border),
          ),
          child: SwitchListTile(
            value: _materialsAvailable,
            onChanged: (value) => setState(() => _materialsAvailable = value),
            title: const Text('لدي المواد أو القطع المطلوبة', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('إن لم تكن متأكدًا اترك الخيار مغلقًا، ويحدد فريق رحماء ذلك لاحقًا.'),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final hoursLabel = _estimatedHours == null
        ? 'غير محدد'
        : '${_estimatedHours!.toStringAsFixed(_estimatedHours! % 1 == 0 ? 0 : 1)} ساعة تقريبًا';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const _SectionTitle('راجع طلب الخدمة'),
        const SizedBox(height: 12),
        _ReviewTile(label: 'المجال', value: '${_categoryData.label} — $_serviceType'),
        _ReviewTile(label: 'الاحتياج', value: _title.text.trim()),
        _ReviewTile(label: 'الوقت المتوقع', value: hoursLabel),
        _ReviewTile(label: 'المواد', value: _materialsAvailable ? 'متوفرة لدي' : 'تحتاج مراجعة'),
        const SizedBox(height: 12),
        const _InfoBox(
          icon: Icons.favorite_outline_rounded,
          text: 'لا يشترط أن تتبرع أو تقدم خدمة حتى تطلب المساعدة.',
          warm: true,
        ),
        const SizedBox(height: 12),
        const _InfoBox(
          icon: Icons.privacy_tip_outlined,
          text: 'بعد موافقة الطرفين، نشارك المعلومات الضرورية لتنفيذ الموعد فقط.',
          warm: false,
        ),
      ],
    );
  }

  Widget _hoursChip(String label, double hours) => ChoiceChip(
        label: Text(label),
        selected: _estimatedHours == hours,
        onSelected: (_) => setState(() => _estimatedHours = hours),
      );
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    const labels = ['الخدمة', 'التفاصيل', 'المراجعة'];
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
