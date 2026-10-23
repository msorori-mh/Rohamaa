import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_error.dart';
import '../../data/account_repository.dart';
import '../../data/item_repository_v2.dart';
import '../../domain/item_form_rules.dart';
import '../../domain/operation_rules.dart';
import '../../theme/ruhamaa_theme.dart';
import '../contributions/contribution_screen.dart';
import '../items/community_form_widgets.dart';
import '../items/form_guards.dart';

/// «ما أحتاجه»: one private screen with the category, a free-text
/// description and the delivery address. After sending, the form is replaced
/// by a confirmation view of the same screen.
class CreateNeedV2Screen extends StatefulWidget {
  const CreateNeedV2Screen({super.key});

  @override
  State<CreateNeedV2Screen> createState() => _CreateNeedV2ScreenState();
}

class _CreateNeedV2ScreenState extends State<CreateNeedV2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();

  /// Row id generated once for this form and sent with the insert, so a
  /// retry after a lost response finds the first need instead of adding one.
  final String _operationId = const Uuid().v4();

  String _category = 'clothes';
  bool _saving = false;
  bool _touched = false;

  /// Default address area for the «يُسلَّم إلى عنوانك» line.
  String? _area;
  bool _addressLoaded = false;

  /// Set once the need exists on the server. From then on the form is
  /// replaced by the confirmation, so a second need cannot be created.
  CreatedOperation? _created;

  static const _emptyDetails = 'صِف ما تحتاجه في كلمات قليلة.';

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  /// Reads the default address for the address line. Optional information:
  /// a failure keeps the generic wording.
  Future<void> _loadAddress() async {
    try {
      final profile = await AccountRepository(Supabase.instance.client).deliveryProfile();
      if (!mounted) return;
      final area = profile.area?.trim() ?? '';
      setState(() {
        _area = area.isNotEmpty ? area : profile.description?.trim();
        _addressLoaded = true;
      });
    } catch (error) {
      debugPrint('Need address load failed: ${error.runtimeType}');
    }
  }

  Future<void> _changeAddress() async {
    if (_saving) return;
    await context.push('/onboarding');
    if (mounted) await _loadAddress();
  }

  Future<bool> _ensureProfile() async {
    final repo = ItemRepositoryV2(Supabase.instance.client);
    if (await repo.hasOperationalProfile()) return true;
    if (!mounted) return false;
    showInfoSnack(context, 'أكمل رقم الهاتف وعنوان التوصيل أولًا.');
    await context.push('/onboarding');
    if (mounted) await _loadAddress();
    return repo.hasOperationalProfile();
  }

  void _changeCategory(String value) {
    if (value == _category) return;
    setState(() {
      _touched = true;
      _category = value;
    });
  }

  /// System back and the on-screen back button: leave after confirming when
  /// data was entered. The confirmation view can always be left.
  Future<void> _handleBack() async {
    if (_saving) return;
    if (_created == null && _touched) {
      final discard = await confirmDiscardChanges(context);
      if (!mounted) return;
      if (!discard) return;
    }
    leaveForm(context);
  }

  Future<void> _submit() async {
    if (_saving || _created != null) return;
    final valid = _formKey.currentState?.validate() ?? false;
    // Check the value itself as well: the field may be scrolled out of view.
    final problem = validateItemDescription(_details.text, emptyMessage: _emptyDetails);
    if (!valid || problem != null) {
      if (problem != null) showInfoSnack(context, problem);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      if (!await _ensureProfile()) return;
      final repo = ItemRepositoryV2(Supabase.instance.client);
      final details = _details.text.trim();
      final created = await repo.createNeed(
        id: _operationId,
        category: _category,
        title: itemTitleFromDescription(details),
        privateDetails: details,
        addressId: await repo.defaultAddressId(),
      );
      _created = created;
      if (!mounted) return;
      setState(() => _saving = false);
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'لم يُرسل الطلب. تحقق من اتصالك وحاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  Future<void> _contribute() async {
    final created = _created;
    if (created == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ContributionScreen(needId: created.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = _created != null;
    return PopScope<Object?>(
      canPop: done || (!_touched && !_saving),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: done ? null : communityAppBar(title: 'ما أحتاجه', onBack: _handleBack),
        body: done ? SafeArea(child: _sentView()) : _form(),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      onChanged: () {
        if (!_touched) setState(() => _touched = true);
      },
      child: Column(
        children: [
          Expanded(
            child: ListView(
              key: const ValueKey('need-form'),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              children: [
                const CommunityNote(
                  icon: Icons.shield_outlined,
                  background: RuhamaaColors.warmGoldSoft,
                  textColor: RuhamaaColors.goldInk,
                  radius: 20,
                  text: 'طلبك سري. لا يظهر اسمك ولا رقمك ولا عنوانك لأي متبرّع.',
                ),
                const SizedBox(height: 18),
                const CommunityFieldLabel('ماذا تحتاج؟'),
                const SizedBox(height: 10),
                CommunityCategoryGrid(
                  selected: _category,
                  onChanged: _changeCategory,
                  tone: CommunityTone.need,
                ),
                const SizedBox(height: 18),
                const CommunityFieldLabel('صِف ما تحتاجه'),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('need-description'),
                  controller: _details,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: ItemFormLimits.description,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(color: RuhamaaColors.text, fontSize: 16, height: 1.5),
                  decoration: communityInputDecoration(
                    hint: 'مثال: ملابس شتوية لولد عمره 8 سنوات',
                    tone: CommunityTone.need,
                  ),
                  validator: (value) => validateItemDescription(value, emptyMessage: _emptyDetails),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اكتب ما يساعدنا: المقاس أو العمر أو العدد، إن وُجد.',
                  style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 18),
                CommunityAddressLine(
                  prefix: 'يُسلَّم إلى عنوانك',
                  area: _area,
                  loaded: _addressLoaded,
                  onChange: _changeAddress,
                  tone: CommunityTone.need,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
              child: CommunityPillButton(
                key: const Key('need-submit'),
                label: _saving ? 'جارٍ الإرسال...' : 'أرسل طلبي',
                color: RuhamaaColors.goldDark,
                showArrow: !_saving,
                onPressed: _saving ? null : _submit,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Gentle confirmation once the need exists.
  Widget _sentView() {
    final code = _created?.publicCode ?? '';
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('need-sent'),
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
            children: [
              CommunitySentSummary(
                heading: 'وصل طلبك',
                message: 'وصل طلبك إلى فريق عطاء بسرية. سنبحث عمّا يناسبك ونخبرك بكل خطوة.',
                codeLabel: 'رقم الطلب',
                code: code,
                tone: CommunityTone.need,
              ),
              const SizedBox(height: 30),
              const CommunityNextSteps(
                tone: CommunityTone.need,
                steps: [
                  'يراجع الفريق طلبك بسرية.',
                  'نبحث عن تبرّع يناسبك، دون أن يعرف أحد هويتك.',
                  'يوصله الموصل إليك، وتعطيه رمزًا من التطبيق.',
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: _contribute,
                  style: TextButton.styleFrom(foregroundColor: RuhamaaColors.textMuted),
                  icon: const Icon(Icons.favorite_outline_rounded, size: 18),
                  label: const Text('المساهمة في التوصيل اختيارية ولا تغيّر أولوية طلبك'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            children: [
              CommunityPillButton(
                key: const Key('need-follow-up'),
                label: 'تابع طلبك',
                color: RuhamaaColors.goldDark,
                onPressed: () => context.go(
                  OperationRules.withRequestId(
                    '/handoffs?tab=0',
                    DateTime.now().millisecondsSinceEpoch,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  key: const Key('need-home'),
                  onPressed: () => context.go('/home'),
                  style: TextButton.styleFrom(
                    foregroundColor: RuhamaaColors.goldDeep,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Tajawal'),
                  ),
                  child: const Text('العودة للرئيسية'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
