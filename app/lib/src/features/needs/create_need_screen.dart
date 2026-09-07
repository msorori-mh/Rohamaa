import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/sanad_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import '../contributions/contribution_screen.dart';

class CreateNeedScreen extends StatefulWidget {
  const CreateNeedScreen({super.key});

  @override
  State<CreateNeedScreen> createState() => _CreateNeedScreenState();
}

class _CreateNeedScreenState extends State<CreateNeedScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _reason = TextEditingController();
  bool _acceptsUsed = true;
  bool _saving = false;
  String _category = 'clothes';
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

  @override
  void dispose() {
    _title.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<bool> _ensureProfile() async {
    final repo = SanadRepository(Supabase.instance.client);
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
      final repo = SanadRepository(Supabase.instance.client);
      final needId = await repo.createNeed(
        title: _title.text.trim(),
        reason: _reason.text.trim(),
        acceptsUsed: _acceptsUsed,
        category: _category,
        addressId: await repo.defaultAddressId(),
      );
      if (!mounted) return;
      final contribute = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تم تسجيل احتياجك'),
          content: const Text(
            'طلبك مستمر سواء ساهمت أم لا، وعدم القدرة على المساهمة لا يقلل أولوية الاستحقاق. إذا كان بإمكانك المساهمة بجزء من تكلفة التوصيل، فهذا يساعد رحماء على استمرار الخدمة وعلى إيصال احتياجات أخرى لأشخاص لا يستطيعون تحمل التكلفة. لا يوجد دفع داخل التطبيق، والمبلغ يُسلَّم نقدًا للموصل عند التوصيل.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('بدون مساهمة'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('أرغب بالمساهمة'),
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ الطلب: $e')),
        );
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
            _ProgressHeader(current: _step + 1),
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
      key: const ValueKey('need-category'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RuhamaaColors.warmGoldSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.favorite_rounded, color: RuhamaaColors.warmGold),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'سجّل احتياجك بخصوصية. لا توجد قائمة تبرعات للتصفح؛ رحماء يبحث عن التطابق المناسب لك.',
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
        const _SectionTitle('ما الفئة التي تحتاجها؟'),
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
      key: const ValueKey('need-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('تفاصيل تساعدنا في فهم احتياجك'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'ماذا تحتاج؟',
            hintText: 'مثال: كتب الصف السادس أو ملابس أطفال',
          ),
          validator: (v) => v == null || v.trim().length < 3
              ? 'اكتب احتياجًا واضحًا'
              : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _reason,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'تفاصيل خاصة بالمطابقة',
            hintText: 'مثل المقاس، العدد، العمر أو أي تفاصيل تساعد على إيجاد المناسب',
            helperText: 'هذه التفاصيل خاصة بفريق رحماء ولا تظهر للمتبرع.',
          ),
          validator: (v) => v == null || v.trim().length < 8
              ? 'أضف تفاصيل مختصرة تساعدنا في المطابقة'
              : null,
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: RuhamaaColors.border),
          ),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            title: const Text(
              'أقبل المستعمل بحالة جيدة',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('يساعد هذا الخيار على توسيع فرص العثور على شيء مناسب.'),
            value: _acceptsUsed,
            onChanged: (v) => setState(() => _acceptsUsed = v),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: RuhamaaColors.softGreen,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, color: RuhamaaColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'المتبرع لا يرى اسمك أو تفاصيل احتياجك أو موقعك. نستخدم بياناتك فقط للمطابقة والتوصيل.',
                  style: TextStyle(color: RuhamaaColors.primaryDark, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: _back, child: const Text('السابق')),
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
    return Column(
      key: const ValueKey('need-review'),
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
                  Icon(Icons.fact_check_outlined, color: RuhamaaColors.warmGold),
                  SizedBox(width: 9),
                  Text(
                    'راجع احتياجك قبل التسجيل',
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
              _ReviewRow(label: 'الاحتياج', value: _title.text.trim()),
              _ReviewRow(
                label: 'المستعمل',
                value: _acceptsUsed ? 'أقبل المستعمل بحالة جيدة' : 'أفضل غير المستعمل',
              ),
              _ReviewRow(label: 'التفاصيل', value: _reason.text.trim()),
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
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: RuhamaaColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'بعد التسجيل يبحث رحماء عن تطابق مناسب. عدم المساهمة في التوصيل لا يؤثر على أولوية الاحتياج، ولا تظهر هويتك للمتبرع.',
                  style: TextStyle(color: RuhamaaColors.primaryDark, height: 1.5),
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
                backgroundColor: active ? RuhamaaColors.warmGold : RuhamaaColors.border,
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
      color: selected ? RuhamaaColors.warmGoldSoft : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? RuhamaaColors.warmGold : RuhamaaColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? RuhamaaColors.warmGold : RuhamaaColors.textMuted,
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
