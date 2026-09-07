import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/partner_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import '../services/service_catalog.dart';

const partnerKinds = <String, String>{
  'salon': 'صالون / كوافير',
  'clothing_shop': 'محل ملابس / فساتين',
  'event_setup': 'تجهيز مناسبات / كوش',
  'repair_shop': 'صيانة أجهزة',
  'printing_shop': 'طباعة وقرطاسية',
  'workshop': 'ورشة / مهنة',
  'other': 'نشاط آخر',
};

class PartnerHubScreen extends StatefulWidget {
  const PartnerHubScreen({super.key});

  @override
  State<PartnerHubScreen> createState() => _PartnerHubScreenState();
}

class _PartnerHubScreenState extends State<PartnerHubScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  PartnerRepository get _repo => PartnerRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = _repo.myPartners();

  Future<void> _register() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPartnerScreen()));
    if (mounted) setState(_reload);
  }

  Future<void> _offer(Map<String, dynamic> partner) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PartnerOfferScreen(partner: partner)));
    if (mounted) setState(_reload);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'verified':
        return 'شريك موثّق';
      case 'rejected':
        return 'يحتاج مراجعة';
      case 'suspended':
        return 'موقوف';
      default:
        return 'قيد التحقق';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شركاء رحماء')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('تعذر تحميل الشركاء: ${snapshot.error}'));
          }
          final rows = snapshot.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: RuhamaaColors.softGreen,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حوّل وقتًا فارغًا في نشاطك إلى أثر حقيقي',
                      style: TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'المحل أو الورشة أو الصالون يسجل أولًا كشريك رحماء. بعد التحقق فقط يمكنه تقديم خدمات مجانية أو عمل مجاني مع المواد حسب الحالة. لا توجد إعلانات أو أسعار أو قائمة مستفيدين.',
                      style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _register,
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('سجّل نشاطًا كشريك رحماء'),
              ),
              const SizedBox(height: 18),
              if (rows.isEmpty)
                const _EmptyPartner()
              else
                ...rows.map((row) {
                  final status = '${row['verification_status']}';
                  final verified = status == 'verified';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: verified ? RuhamaaColors.softGreen : RuhamaaColors.warmGoldSoft,
                                  foregroundColor: verified ? RuhamaaColors.primary : RuhamaaColors.warmGold,
                                  child: Icon(verified ? Icons.verified_rounded : Icons.storefront_outlined),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${row['display_name']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                      Text(partnerKinds['${row['partner_kind']}'] ?? '${row['partner_kind']}', style: const TextStyle(color: RuhamaaColors.textMuted)),
                                    ],
                                  ),
                                ),
                                Chip(label: Text(_statusLabel(status))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('السعة المعلنة: حتى ${row['monthly_case_capacity']} حالات شهريًا', style: const TextStyle(color: RuhamaaColors.textMuted)),
                            if (verified) ...[
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: () => _offer(row),
                                icon: const Icon(Icons.volunteer_activism_outlined),
                                label: const Text('أضف خدمة من هذا الشريك'),
                              ),
                            ] else ...[
                              const SizedBox(height: 10),
                              const Text(
                                'لا يمكن إنشاء عرض باسم هذا النشاط قبل اكتمال تحقق فريق رحماء.',
                                style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 12, height: 1.4),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class RegisterPartnerScreen extends StatefulWidget {
  const RegisterPartnerScreen({super.key});

  @override
  State<RegisterPartnerScreen> createState() => _RegisterPartnerScreenState();
}

class _RegisterPartnerScreenState extends State<RegisterPartnerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _capacity = TextEditingController(text: '4');
  String _kind = 'salon';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = PartnerRepository(Supabase.instance.client);
    if (await repo.defaultServiceAreaId() == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل بيانات التوصيل ونطاق الخدمة أولًا.')));
      await context.push('/onboarding');
      if (await repo.defaultServiceAreaId() == null) return;
    }
    setState(() => _saving = true);
    try {
      await repo.registerPartner(
        displayName: _name.text,
        partnerKind: _kind,
        description: _description.text,
        contactPhone: _phone.text,
        monthlyCaseCapacity: int.parse(_capacity.text.trim()),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تم إرسال طلب الشراكة'),
          content: const Text(
            'سيراجع فريق رحماء النشاط قبل تفعيل أي خدمة باسمه. بيانات الاتصال لا تظهر للمستفيدين أثناء مرحلة التحقق أو التصفح.',
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تسجيل الشريك: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل شريك رحماء')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم النشاط / المحل'),
              validator: (value) => value == null || value.trim().length < 3 ? 'اكتب اسم النشاط' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'نوع النشاط'),
              items: partnerKinds.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
              onChanged: (value) => setState(() => _kind = value ?? 'other'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'وصف مختصر للنشاط',
                hintText: 'ما الخدمات التي يقدمها عادةً؟',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم تواصل النشاط',
                helperText: 'خاص بفريق رحماء للتنسيق والتحقق؛ لا يعرض للعامة.',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'عدد الحالات التقريبي الذي تستطيع خدمته شهريًا'),
              validator: (value) {
                final number = int.tryParse(value?.trim() ?? '');
                return number == null || number < 1 || number > 100 ? 'اكتب رقمًا بين 1 و100' : null;
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: RuhamaaColors.warmGoldSoft, borderRadius: BorderRadius.circular(18)),
              child: const Text(
                'الشراكة لا تمنح أولوية تجارية أو ظهورًا إعلانيًا. الخدمة في V1 مجانية، أو يكون العمل مجانيًا وتُراجع المواد/قطع الغيار حسب الحالة. لا توجد مساومة أو تسويق للمستفيدين.',
                style: TextStyle(color: RuhamaaColors.primaryDark, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(_saving ? 'جارٍ الإرسال...' : 'إرسال للمراجعة'),
            ),
          ],
        ),
      ),
    );
  }
}

class PartnerOfferScreen extends StatefulWidget {
  const PartnerOfferScreen({super.key, required this.partner});
  final Map<String, dynamic> partner;

  @override
  State<PartnerOfferScreen> createState() => _PartnerOfferScreenState();
}

class _PartnerOfferScreenState extends State<PartnerOfferScreen> {
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل عنوان الخدمة وحدد ساعات بين 1 و24.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await PartnerRepository(Supabase.instance.client).createPartnerOffer(
        partnerId: '${widget.partner['id']}',
        category: _category,
        serviceType: _serviceType,
        title: _title.text,
        description: _description.text,
        availabilityMode: 'custom',
        availableHours: hours,
        availabilityNote: _availabilityNote.text,
        materialsMode: _materialsMode,
        pricingMode: _pricingMode,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تم تسجيل عرض الشريك'),
          content: const Text('سيُراجع العرض تشغيليًا قبل مطابقته باحتياج مناسب. لن يظهر كإعلان عام ولن يرى الشريك قائمة المحتاجين.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تسجيل الخدمة: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryData = serviceCategoryByKey(_category);
    return Scaffold(
      appBar: AppBar(title: Text('خدمة من ${widget.partner['display_name']}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
            value: _serviceType,
            decoration: const InputDecoration(labelText: 'نوع الخدمة'),
            items: categoryData.types.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
            onChanged: (value) => setState(() => _serviceType = value ?? categoryData.types.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'عنوان العرض', hintText: 'مثال: تجهيز عروس مجانًا لحالة واحدة'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'حدود الخدمة وتفاصيلها'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hours,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'الوقت المتاح لهذه الحالة', suffixText: 'ساعة'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _availabilityNote,
            decoration: const InputDecoration(labelText: 'متى تكون الخدمة متاحة؟'),
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
              DropdownMenuItem(value: 'provider', child: Text('الشريك يوفرها')),
              DropdownMenuItem(value: 'recipient', child: Text('صاحب الاحتياج يوفرها')),
              DropdownMenuItem(value: 'case_by_case', child: Text('تُراجع حسب الحالة')),
            ],
            onChanged: (value) => setState(() => _materialsMode = value ?? 'case_by_case'),
          ),
          const SizedBox(height: 20),
          const Text(
            'يمنع على الشريك اشتراط تصوير المستفيد، نشر قصته، الحصول على بياناته للتسويق، شراء خدمة أخرى، أو دفع مبلغ غير متفق عليه عبر رحماء.',
            style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.volunteer_activism_outlined),
            label: Text(_saving ? 'جارٍ الحفظ...' : 'سجّل خدمة الشريك'),
          ),
        ],
      ),
    );
  }
}

class _EmptyPartner extends StatelessWidget {
  const _EmptyPartner();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.storefront_outlined, size: 56, color: RuhamaaColors.textMuted),
            SizedBox(height: 10),
            Text('لم تسجّل نشاطًا كشريك رحماء بعد', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
