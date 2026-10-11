import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/partner_repository.dart';
import '../../domain/partner_form_rules.dart';
import '../../domain/service_flow_rules.dart';
import '../../theme/ruhamaa_theme.dart';
import '../items/async_list_loader.dart';
import '../items/form_guards.dart';
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

class _PartnerHubV2ScreenState extends State<PartnerHubV2Screen>
    with AsyncListLoader<PartnerHubV2Screen, Map<String, dynamic>> {
  bool _refreshing = false;

  PartnerRepository get _repo => PartnerRepository(Supabase.instance.client);

  @override
  Future<List<Map<String, dynamic>>> fetchRows() => _repo.myPartners();

  @override
  void initState() {
    super.initState();
    reloadRows();
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

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await reloadRows();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _register() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const RegisterPartnerV2Screen()),
    );
    if (mounted) await reloadRows();
  }

  Future<void> _offer(Map<String, dynamic> partner) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PartnerServiceOfferV2Screen(partner: partner)),
    );
    if (mounted) await reloadRows();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شركاء عطاء'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: buildAsyncList(
        empty: null,
        builder: (rows) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
              const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('لم تسجّل نشاطًا كشريك عطاء بعد.')))
            else
              ...rows.map(_partnerCard),
          ],
        ),
      ),
    );
  }

  Widget _partnerCard(Map<String, dynamic> row) {
    final status = '${row['verification_status']}';
    final verified = status == 'verified';
    final kind = partnerKindsV2['${row['partner_kind']}'] ?? 'نشاط آخر';
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
                        Text(kind, style: const TextStyle(color: RuhamaaColors.textMuted)),
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
  bool _termsMissing = false;
  bool _saving = false;
  bool _touched = false;

  /// Set once the partner exists on the server, so that it is never sent twice.
  bool _created = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<bool> _ensureArea(PartnerRepository repo) async {
    if (await repo.defaultServiceAreaId() != null) return true;
    if (!mounted) return false;
    showInfoSnack(context, 'أكمل بيانات التوصيل ونطاق الخدمة أولًا.');
    await context.push('/onboarding');
    return await repo.defaultServiceAreaId() != null;
  }

  Future<void> _handleBack() async {
    if (_saving) return;
    if (_touched && !_created) {
      final discard = await confirmDiscardChanges(context);
      if (!mounted) return;
      if (!discard) return;
    }
    leaveForm(context);
  }

  Future<void> _submit() async {
    if (_saving) return;
    final formValid = _formKey.currentState!.validate();
    if (!_termsAccepted) setState(() => _termsMissing = true);
    if (!formValid || !_termsAccepted) return;
    // A field scrolled far out of view is not built, so the form cannot show
    // its message: check the values themselves as well.
    final problem = PartnerFormRules.validateName(_name.text) ??
        PartnerFormRules.validateDescription(_description.text) ??
        PartnerFormRules.validatePhone(_phone.text) ??
        PartnerFormRules.validateCapacity(_capacity.text);
    final phone = PartnerFormRules.normalizeYemenMobile(_phone.text);
    final capacity = PartnerFormRules.parseCapacity(_capacity.text);
    if (problem != null || phone == null || capacity == null) {
      showInfoSnack(context, problem ?? 'راجع بيانات النشاط ثم حاول مرة أخرى.');
      return;
    }
    setState(() => _saving = true);
    try {
      if (!_created) {
        final repo = PartnerRepository(Supabase.instance.client);
        if (!await _ensureArea(repo)) return;
        await repo.registerPartner(
          displayName: _name.text,
          partnerKind: _kind,
          description: _description.text,
          contactPhone: phone,
          monthlyCaseCapacity: capacity,
        );
        _created = true;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('تم إرسال طلب الشراكة'),
          content: const Text('سنراجع بيانات النشاط. يمكنك تقديم الخدمات باسمه بعد اكتمال التحقق.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم'))],
        ),
      );
      if (mounted) leaveForm(context);
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر إرسال طلب الشراكة. تحقق من اتصالك وحاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_saving && (!_touched || _created),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('تسجيل شريك عطاء')),
        body: Form(
          key: _formKey,
          onChanged: () {
            if (!_touched) setState(() => _touched = true);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _name,
                maxLength: PartnerFormRules.nameMax,
                decoration: const InputDecoration(labelText: 'اسم النشاط / المحل', counterText: ''),
                validator: PartnerFormRules.validateName,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'نوع النشاط'),
                items: partnerKindsV2.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                onChanged: (value) => setState(() => _kind = value ?? 'other'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                maxLength: PartnerFormRules.descriptionMax,
                decoration: const InputDecoration(labelText: 'وصف مختصر للنشاط'),
                validator: PartnerFormRules.validateDescription,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                maxLength: PartnerFormRules.phoneMax,
                decoration: const InputDecoration(
                  labelText: 'رقم تواصل النشاط',
                  hintText: '7XXXXXXXX',
                  helperText: 'نستخدمه للتحقق والتنسيق، ولا نعرضه للعامة.',
                  counterText: '',
                ),
                validator: PartnerFormRules.validatePhone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                maxLength: 3,
                decoration: const InputDecoration(labelText: 'عدد الحالات التقريبي شهريًا', counterText: ''),
                validator: PartnerFormRules.validateCapacity,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: RuhamaaColors.warmGoldSoft, borderRadius: BorderRadius.circular(18)),
                child: const Text(
                  'قواعد شركاء عطاء V1:\n• لا تصوير للمستفيد أو نشر قصته.\n• لا استخدام لبياناته في التسويق.\n• لا رسوم أو مبالغ لم تُراجع مسبقًا مع عطاء.\n• لا اشتراط شراء خدمة أخرى أو إعطاء تقييم.\n• الخدمة مجانية، أو العمل مجاني والمواد فقط حسب الحالة المراجعة.\n• أي خرق قد يوقف الشريك وعروضه.',
                  style: TextStyle(color: RuhamaaColors.primaryDark, height: 1.55),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _termsAccepted,
                onChanged: (value) => setState(() {
                  _touched = true;
                  _termsAccepted = value ?? false;
                  if (_termsAccepted) _termsMissing = false;
                }),
                title: const Text('قرأت قواعد شركاء عطاء وأوافق عليها', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              if (_termsMissing)
                Text(
                  'اقرأ قواعد شركاء عطاء ووافق عليها قبل الإرسال.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
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
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _availability = TextEditingController();
  final _hours = TextEditingController(text: '3');
  late String _category;
  late String _serviceType;
  String _pricingMode = 'free';
  String _materialsMode = 'case_by_case';
  bool _saving = false;
  bool _touched = false;

  /// Set once the offer exists on the server, so that it is never sent twice.
  bool _created = false;

  Set<String> get _allowedCategories => allowedPartnerServiceCategories('${widget.partner['partner_kind']}');

  @override
  void initState() {
    super.initState();
    final firstCategory = ruhamaaServiceCategories.firstWhere(
      (category) => _allowedCategories.contains(category.key),
      orElse: () => ruhamaaServiceCategories.last,
    );
    _category = firstCategory.key;
    _serviceType = firstCategory.types.first;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _availability.dispose();
    _hours.dispose();
    super.dispose();
  }

  String? _titleError(String? value) => ServiceFlowRules.validateTitle(
        value,
        emptyMessage: 'اكتب عنوانًا واضحًا للخدمة.',
      );

  Future<void> _handleBack() async {
    if (_saving) return;
    if (_touched && !_created) {
      final discard = await confirmDiscardChanges(context);
      if (!mounted) return;
      if (!discard) return;
    }
    leaveForm(context);
  }

  Future<void> _submit() async {
    if (_saving || _created) return;
    if (!_formKey.currentState!.validate()) return;
    // A field scrolled far out of view is not built, so the form cannot show
    // its message: check the values themselves as well.
    final problem = _titleError(_title.text) ??
        ServiceFlowRules.validateOptionalNote(_description.text) ??
        ServiceFlowRules.validateHours(_hours.text) ??
        ServiceFlowRules.validateOptionalNote(_availability.text);
    final hours = ServiceFlowRules.parseHours(_hours.text);
    if (problem != null || hours == null) {
      showInfoSnack(context, problem ?? 'حدد عدد ساعات بين 1 و24.');
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
      _created = true;
      if (!mounted) return;
      showInfoSnack(context, 'تم تسجيل عرض الشريك للمراجعة التشغيلية.');
      leaveForm(context);
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر إرسال الخدمة. تحقق من اتصالك وحاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryData = serviceCategoryByKey(_category);
    final visibleCategories = ruhamaaServiceCategories.where((category) => _allowedCategories.contains(category.key)).toList();
    return PopScope<Object?>(
      canPop: !_saving && (!_touched || _created),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(title: Text('خدمة من ${widget.partner['display_name']}')),
        body: Form(
          key: _formKey,
          onChanged: () {
            if (!_touched) setState(() => _touched = true);
          },
          child: ListView(
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
                        _touched = true;
                        _category = category.key;
                        _serviceType = category.types.first;
                      }),
                    )).toList(),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey('partner-service-type-$_category'),
                initialValue: _serviceType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'نوع الخدمة'),
                items: categoryData.types.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (value) => setState(() => _serviceType = value ?? categoryData.types.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                maxLength: ServiceFlowRules.titleMax,
                decoration: const InputDecoration(
                  labelText: 'عنوان العرض',
                  hintText: 'مثال: تجهيز عروس مجانًا لحالة واحدة',
                  counterText: '',
                ),
                validator: _titleError,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                maxLength: ServiceFlowRules.detailsMax,
                decoration: const InputDecoration(labelText: 'حدود الخدمة وتفاصيلها'),
                validator: ServiceFlowRules.validateOptionalNote,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hours,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                maxLength: 5,
                decoration: const InputDecoration(labelText: 'الوقت المتاح', suffixText: 'ساعة', counterText: ''),
                validator: ServiceFlowRules.validateHours,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _availability,
                maxLength: ServiceFlowRules.noteMax,
                decoration: const InputDecoration(labelText: 'الأيام / الأوقات المتاحة', counterText: ''),
                validator: ServiceFlowRules.validateOptionalNote,
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'free', label: Text('مجانية بالكامل')),
                  ButtonSegment(value: 'materials_only', label: Text('العمل مجاني والمواد فقط')),
                ],
                selected: {_pricingMode},
                onSelectionChanged: (value) => setState(() {
                  _touched = true;
                  _pricingMode = value.first;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _materialsMode,
                isExpanded: true,
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
                onPressed: _saving || _created ? null : _submit,
                icon: const Icon(Icons.volunteer_activism_outlined),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'سجّل خدمة الشريك'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
