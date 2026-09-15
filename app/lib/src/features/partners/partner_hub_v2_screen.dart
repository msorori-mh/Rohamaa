import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/partner_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import '../services/service_catalog.dart';

const partnerKindsV2 = <String, String>{
  'salon': 'صالون / كوافير',
  'clothing_shop': 'محل ملابس / فساتين',
  'event_setup': 'تجهيز مناسبات / كوش',
  'repair_shop': 'صيانة أجهزة',
  'printing_shop': 'طباعة وقرطاسية',
  'workshop': 'ورشة / مهنة',
  'other': 'نشاط آخر',
};

Set<String> allowedPartnerServiceCategories(String partnerKind) {
  switch (partnerKind) {
    case 'salon':
    case 'clothing_shop':
      return {'beauty_wedding'};
    case 'event_setup':
      return {'event_setup'};
    case 'repair_shop':
      return {'appliance_repair', 'device_repair'};
    case 'printing_shop':
      return {'printing_stationery'};
    case 'workshop':
      return {'carpentry', 'tailoring', 'painting', 'moving_assembly', 'appliance_repair', 'device_repair'};
    default:
      return ruhamaaServiceCategories.map((category) => category.key).toSet();
  }
}

class PartnerHubV2Screen extends StatefulWidget {
  const PartnerHubV2Screen({super.key});

  @override
  State<PartnerHubV2Screen> createState() => _PartnerHubV2ScreenState();
}

class _PartnerHubV2ScreenState extends State<PartnerHubV2Screen> {
  late Future<List<Map<String, dynamic>>> _future;
  PartnerRepository get _repo => PartnerRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = _repo.myPartners();

  String _statusLabel(String status) {
    switch (status) {
      case 'verified': return 'شريك موثّق';
      case 'rejected': return 'يحتاج مراجعة';
      case 'suspended': return 'موقوف';
      default: return 'قيد التحقق';
    }
  }

  Future<void> _register() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPartnerV2Screen()));
    if (mounted) setState(_reload);
  }

  Future<void> _offer(Map<String, dynamic> partner) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PartnerServiceOfferV2Screen(partner: partner)));
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شركاء رحماء')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('تعذر تحميل بيانات الشركاء. تحقق من اتصالك وحاول مجددًا.'));
          final rows = snapshot.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: RuhamaaColors.softGreen, borderRadius: BorderRadius.circular(22)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('قدّم خدمة من خلال نشاطك', style: TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w900, fontSize: 17)),
                    SizedBox(height: 7),
                    Text(
                      'نسجّل المحلات والورش والجهات بعد التحقق منها، ثم نتيح لها تقديم خدمات مجانية بخصوصية.',
                      style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _register, icon: const Icon(Icons.add_business_outlined), label: const Text('تسجيل نشاطك')),
              const SizedBox(height: 18),
              if (rows.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('لم تسجّل نشاطًا كشريك رحماء بعد.')))
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
                                      Text(partnerKindsV2['${row['partner_kind']}'] ?? '${row['partner_kind']}', style: const TextStyle(color: RuhamaaColors.textMuted)),
                                    ],
                                  ),
                                ),
                                Chip(label: Text(_statusLabel(status))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('القدرة: حتى ${row['monthly_case_capacity']} خدمات شهريًا', style: const TextStyle(color: RuhamaaColors.textMuted)),
                            if (verified) ...[
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: () => _offer(row),
                                icon: const Icon(Icons.volunteer_activism_outlined),
                                label: const Text('أضف خدمة من هذا الشريك'),
                              ),
                            ] else ...[
                              const SizedBox(height: 10),
                              const Text('لن يقبل النظام أي عرض خدمة تجاري باسم هذا النشاط قبل اعتماد الشريك.', style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 12)),
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

class RegisterPartnerV2Screen extends StatefulWidget {
  const RegisterPartnerV2Screen({super.key});

  @override
  State<RegisterPartnerV2Screen> createState() => _RegisterPartnerV2ScreenState();
}

class _RegisterPartnerV2ScreenState extends State<RegisterPartnerV2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _capacity = TextEditingController(text: '4');
  String _kind = 'salon';
  bool _termsAccepted = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose(); _description.dispose(); _phone.dispose(); _capacity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اقرأ قواعد شركاء رحماء ووافق عليها قبل الإرسال.')));
      return;
    }
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
          content: const Text('سنراجع بيانات النشاط. يمكنك تقديم الخدمات باسمه بعد اكتمال التحقق.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Partner registration failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إرسال طلب الشراكة. تحقق من اتصالك وحاول مرة أخرى.')));
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
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'اسم النشاط / المحل'), validator: (v) => v == null || v.trim().length < 3 ? 'اكتب اسم النشاط' : null),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'نوع النشاط'),
              items: partnerKindsV2.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
              onChanged: (value) => setState(() => _kind = value ?? 'other'),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'وصف مختصر للنشاط')),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم تواصل النشاط', helperText: 'نستخدمه للتحقق والتنسيق، ولا نعرضه للعامة.')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'عدد الحالات التقريبي شهريًا'),
              validator: (value) {
                final n = int.tryParse(value?.trim() ?? '');
                return n == null || n < 1 || n > 100 ? 'اكتب رقمًا بين 1 و100' : null;
              },
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: RuhamaaColors.warmGoldSoft, borderRadius: BorderRadius.circular(18)),
              child: const Text(
                'قواعد شركاء رحماء V1:\n• لا تصوير للمستفيد أو نشر قصته.\n• لا استخدام لبياناته في التسويق.\n• لا رسوم أو مبالغ لم تُراجع مسبقًا مع رحماء.\n• لا اشتراط شراء خدمة أخرى أو إعطاء تقييم.\n• الخدمة مجانية، أو العمل مجاني والمواد فقط حسب الحالة المراجعة.\n• أي خرق قد يوقف الشريك وعروضه.',
                style: TextStyle(color: RuhamaaColors.primaryDark, height: 1.55),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _termsAccepted,
              onChanged: (value) => setState(() => _termsAccepted = value ?? false),
              title: const Text('قرأت قواعد شركاء رحماء وأوافق عليها', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 18),
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

class PartnerServiceOfferV2Screen extends StatefulWidget {
  const PartnerServiceOfferV2Screen({super.key, required this.partner});
  final Map<String, dynamic> partner;

  @override
  State<PartnerServiceOfferV2Screen> createState() => _PartnerServiceOfferV2ScreenState();
}

class _PartnerServiceOfferV2ScreenState extends State<PartnerServiceOfferV2Screen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _availability = TextEditingController();
  final _hours = TextEditingController(text: '3');
  late String _category;
  late String _serviceType;
  String _pricingMode = 'free';
  String _materialsMode = 'case_by_case';
  bool _saving = false;

  Set<String> get _allowedCategories => allowedPartnerServiceCategories('${widget.partner['partner_kind']}');

  @override
  void initState() {
    super.initState();
    final firstCategory = ruhamaaServiceCategories.firstWhere((category) => _allowedCategories.contains(category.key));
    _category = firstCategory.key;
    _serviceType = firstCategory.types.first;
  }

  @override
  void dispose() {
    _title.dispose(); _description.dispose(); _availability.dispose(); _hours.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final hours = double.tryParse(_hours.text.trim());
    if (_title.text.trim().length < 3 || hours == null || hours <= 0 || hours > 24) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل عنوان الخدمة وحدد ساعات صحيحة.')));
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
        availabilityNote: _availability.text,
        materialsMode: _materialsMode,
        pricingMode: _pricingMode,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل عرض الشريك للمراجعة التشغيلية.')));
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Partner service offer failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إرسال الخدمة. تحقق من اتصالك وحاول مرة أخرى.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryData = serviceCategoryByKey(_category);
    final visibleCategories = ruhamaaServiceCategories.where((category) => _allowedCategories.contains(category.key)).toList();
    return Scaffold(
      appBar: AppBar(title: Text('خدمة من ${widget.partner['display_name']}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: RuhamaaColors.softGreen, borderRadius: BorderRadius.circular(16)),
            child: const Text(
              'اختر خدمة متوافقة مع نشاطك المعتمد. تحتاج الخدمات الجديدة إلى مراجعة.',
              style: TextStyle(color: RuhamaaColors.primaryDark, height: 1.45, fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visibleCategories.map((category) => ChoiceChip(
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
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'عنوان العرض', hintText: 'مثال: تجهيز عروس مجانًا لحالة واحدة')),
          const SizedBox(height: 12),
          TextField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'حدود الخدمة وتفاصيلها')),
          const SizedBox(height: 12),
          TextField(controller: _hours, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الوقت المتاح', suffixText: 'ساعة')),
          const SizedBox(height: 12),
          TextField(controller: _availability, decoration: const InputDecoration(labelText: 'الأيام / الأوقات المتاحة')),
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
          const SizedBox(height: 22),
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
