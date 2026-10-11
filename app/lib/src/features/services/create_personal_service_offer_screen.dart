import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/service_repository.dart';
import '../../domain/service_flow_rules.dart';
import '../../theme/ruhamaa_theme.dart';
import '../items/form_guards.dart';
import 'service_catalog.dart';

class CreatePersonalServiceOfferScreen extends StatefulWidget {
  const CreatePersonalServiceOfferScreen({super.key});

  @override
  State<CreatePersonalServiceOfferScreen> createState() => _CreatePersonalServiceOfferScreenState();
}

class _CreatePersonalServiceOfferScreenState extends State<CreatePersonalServiceOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _availabilityNote = TextEditingController();
  final _hours = TextEditingController(text: '3');

  String _category = ruhamaaServiceCategories.first.key;
  String _serviceType = ruhamaaServiceCategories.first.types.first;
  String _pricingMode = 'free';
  String _materialsMode = 'case_by_case';
  bool _saving = false;
  bool _touched = false;

  /// Set once the offer exists on the server, so that it is never sent twice.
  bool _created = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _availabilityNote.dispose();
    _hours.dispose();
    super.dispose();
  }

  String? _titleError(String? value) => ServiceFlowRules.validateTitle(
        value,
        emptyMessage: 'اكتب عنوانًا واضحًا للخدمة.',
      );

  Future<bool> _ensureArea(ServiceRepository repo) async {
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
    if (!_formKey.currentState!.validate()) return;
    // A field scrolled far out of view is not built, so the form cannot show
    // its message: check the values themselves as well.
    final problem = _titleError(_title.text) ??
        ServiceFlowRules.validateOptionalNote(_description.text) ??
        ServiceFlowRules.validateHours(_hours.text) ??
        ServiceFlowRules.validateOptionalNote(_availabilityNote.text);
    final hours = ServiceFlowRules.parseHours(_hours.text);
    if (problem != null || hours == null) {
      showInfoSnack(context, problem ?? 'حدد عدد ساعات بين 1 و24.');
      return;
    }
    setState(() => _saving = true);
    try {
      if (!_created) {
        final repo = ServiceRepository(Supabase.instance.client);
        if (!await _ensureArea(repo)) return;
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
        _created = true;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('تم تسجيل خدمتك'),
          content: const Text(
            'سنراجع الخدمة ونخبرك عند وجود طلب مناسب. لن تظهر خدمتك كإعلان عام.',
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم'))],
        ),
      );
      if (mounted) leaveForm(context);
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
    return PopScope<Object?>(
      canPop: !_saving && (!_touched || _created),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('تبرّع بوقتك أو مهارتك')),
        body: Form(
          key: _formKey,
          onChanged: () {
            if (!_touched) setState(() => _touched = true);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: RuhamaaColors.softGreen, borderRadius: BorderRadius.circular(18)),
                child: const Text(
                  'هذا الخيار للأفراد. إذا كنت تمثل نشاطًا تجاريًا، فسجّله أولًا من صفحة الشركاء.',
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
                        _touched = true;
                        _category = category.key;
                        _serviceType = category.types.first;
                      }),
                    )).toList(),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey('service-type-$_category'),
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
                  labelText: 'ماذا تستطيع تقديمه؟',
                  hintText: 'مثال: 3 ساعات سباكة منزلية بسيطة',
                  counterText: '',
                ),
                validator: _titleError,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                maxLength: ServiceFlowRules.detailsMax,
                decoration: const InputDecoration(labelText: 'حدود الخدمة والتفاصيل (اختياري)'),
                validator: ServiceFlowRules.validateOptionalNote,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hours,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                maxLength: 5,
                decoration: const InputDecoration(
                  labelText: 'عدد الساعات المتاحة',
                  suffixText: 'ساعة',
                  counterText: '',
                ),
                validator: ServiceFlowRules.validateHours,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _availabilityNote,
                maxLength: ServiceFlowRules.noteMax,
                decoration: const InputDecoration(
                  labelText: 'متى تكون متاحًا؟ (اختياري)',
                  counterText: '',
                ),
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
                  DropdownMenuItem(value: 'provider', child: Text('أستطيع توفيرها')),
                  DropdownMenuItem(value: 'recipient', child: Text('صاحب الاحتياج يوفرها')),
                  DropdownMenuItem(value: 'case_by_case', child: Text('تُراجع حسب الحالة')),
                ],
                onChanged: (value) => setState(() => _materialsMode = value ?? 'case_by_case'),
              ),
              const SizedBox(height: 18),
              const Text(
                'الخدمة تطوعية وليست مقايضة، ولا تغيّر أولوية طلباتك.',
                style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.handyman_outlined),
                label: Text(_saving ? 'جارٍ الإرسال...' : 'إرسال الخدمة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
