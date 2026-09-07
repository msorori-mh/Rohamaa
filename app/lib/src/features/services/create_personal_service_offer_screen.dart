import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/service_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import 'service_catalog.dart';

class CreatePersonalServiceOfferScreen extends StatefulWidget {
  const CreatePersonalServiceOfferScreen({super.key});

  @override
  State<CreatePersonalServiceOfferScreen> createState() => _CreatePersonalServiceOfferScreenState();
}

class _CreatePersonalServiceOfferScreenState extends State<CreatePersonalServiceOfferScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _availabilityNote = TextEditingController();
  final _hours = TextEditingController(text: '3');

  String _category = ruhamaaServiceCategories.first.key;
  String _serviceType = ruhamaaServiceCategories.first.types.first;
  String _pricingMode = 'free';
  String _materialsMode = 'case_by_case';
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _availabilityNote.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final hours = double.tryParse(_hours.text.trim());
    if (_title.text.trim().length < 3 || hours == null || hours <= 0 || hours > 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب عنوانًا واضحًا وحدد ساعات بين 1 و24.')),
      );
      return;
    }
    final repo = ServiceRepository(Supabase.instance.client);
    if (await repo.defaultServiceAreaId() == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل بيانات التوصيل ونطاق الخدمة أولًا.')));
      await context.push('/onboarding');
      if (await repo.defaultServiceAreaId() == null) return;
    }
    setState(() => _saving = true);
    try {
      await repo.createServiceOffer(
        providerKind: 'person',
        category: _category,
        serviceType: _serviceType,
        title: _title.text.trim(),
        description: _description.text.trim(),
        availabilityMode: 'custom',
        availableHours: hours,
        availabilityNote: _availabilityNote.text.trim(),
        materialsMode: _materialsMode,
        pricingMode: _pricingMode,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تم تسجيل وقتك أو مهارتك'),
          content: const Text(
            'يراجع فريق رحماء العرض قبل مطابقته باحتياج مناسب. لن يظهر كإعلان عام، وتقديمك للخدمة لا يزيد أولوية احتياجاتك الشخصية.',
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تسجيل العرض: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryData = serviceCategoryByKey(_category);
    return Scaffold(
      appBar: AppBar(title: const Text('أقدّم وقتي أو مهارتي')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: RuhamaaColors.softGreen, borderRadius: BorderRadius.circular(18)),
            child: const Text(
              'هذا المسار للأفراد. إذا كنت تمثل محلًا أو ورشة أو صالونًا فاستخدم «شركاء رحماء» حتى يتم التحقق من النشاط أولًا.',
              style: TextStyle(color: RuhamaaColors.primaryDark, height: 1.5),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ruhamaaServiceCategories.map((category) => ChoiceChip(
                  avatar: Icon(category.icon, size: 18),
                  label: Text(category.label),
                  selected: _category == category.key,
                  onSelected: (_) => setState(() {
                    _category = category.key;
                    _serviceType = category.types.first;
                  }),
                )).toList(),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _serviceType,
            decoration: const InputDecoration(labelText: 'نوع الخدمة'),
            items: categoryData.types.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
            onChanged: (value) => setState(() => _serviceType = value ?? categoryData.types.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'ماذا تستطيع تقديمه؟', hintText: 'مثال: 3 ساعات سباكة منزلية بسيطة'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'حدود الخدمة والتفاصيل (اختياري)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hours,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'عدد الساعات المتاحة', suffixText: 'ساعة'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _availabilityNote,
            decoration: const InputDecoration(labelText: 'متى تكون متاحًا؟ (اختياري)'),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'free', label: Text('مجانية بالكامل')),
              ButtonSegment(value: 'materials_only', label: Text('العمل مجاني والمواد فقط')),
            ],
            selected: {_pricingMode},
            onSelectionChanged: (value) => setState(() => _pricingMode = value.first),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _materialsMode,
            decoration: const InputDecoration(labelText: 'المواد / القطع'),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('لا تحتاج مواد غالبًا')),
              DropdownMenuItem(value: 'provider', child: Text('أستطيع توفيرها')),
              DropdownMenuItem(value: 'recipient', child: Text('صاحب الاحتياج يوفرها')),
              DropdownMenuItem(value: 'case_by_case', child: Text('تُراجع حسب الحالة')),
            ],
            onChanged: (value) => setState(() => _materialsMode = value ?? 'case_by_case'),
          ),
          const SizedBox(height: 18),
          const Text(
            'لا توجد نقاط أو مقايضة: تقديمك لهذه الساعات لا يرفع أولوية طلباتك، ومن يحصل على خدمتك لا يصبح مدينًا لك بخدمة مقابلة.',
            style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.handyman_outlined),
            label: Text(_saving ? 'جارٍ الحفظ...' : 'سجّل وقتي أو مهارتي'),
          ),
        ],
      ),
    );
  }
}
