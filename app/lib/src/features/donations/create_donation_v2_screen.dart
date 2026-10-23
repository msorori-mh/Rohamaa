import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_error.dart';
import '../../data/account_repository.dart';
import '../../data/donation_image_repository.dart';
import '../../data/item_repository_v2.dart';
import '../../domain/donation_image_rules.dart';
import '../../domain/item_form_rules.dart';
import '../../domain/operation_rules.dart';
import '../../theme/ruhamaa_theme.dart';
import '../contributions/contribution_screen.dart';
import '../items/community_form_widgets.dart';
import '../items/form_guards.dart';

/// «تبرّع»: one screen with the category, a free-text description, the
/// condition, an optional photo and the pickup address. After sending, the
/// form is replaced by the "sent" view of the same screen.
class CreateDonationV2Screen extends StatefulWidget {
  const CreateDonationV2Screen({
    super.key,
    this.prefillCategory,
    this.prefillTitle,
    this.prefillAttributes,
    this.inspiredByDiscoveryCardId,
  });

  /// Filled from a reviewed need card (`/verified-needs`).
  final String? prefillCategory;
  final String? prefillTitle;
  final Map<String, String>? prefillAttributes;
  final String? inspiredByDiscoveryCardId;

  @override
  State<CreateDonationV2Screen> createState() => _CreateDonationV2ScreenState();
}

/// A photo the person picked, and whether it has reached the server.
class _PickedPhoto {
  _PickedPhoto(this.file);

  final XFile file;
  bool uploaded = false;
}

class _CreateDonationV2ScreenState extends State<CreateDonationV2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  final List<_PickedPhoto> _images = [];

  /// Row id generated once for this form and sent with the insert, so a
  /// retry after a lost response finds the first donation instead of adding
  /// a second one.
  final String _operationId = const Uuid().v4();

  String _category = 'clothes';
  String _condition = 'good';
  bool _saving = false;
  bool _picking = false;
  bool _uploading = false;
  bool _leaving = false;
  bool _touched = false;

  /// Default address area for the «يُستلم من عنوانك» line.
  String? _area;
  bool _addressLoaded = false;

  /// Set as soon as the donation exists on the server. From then on the form
  /// is replaced by the result view, so a second donation cannot be created.
  CreatedOperation? _created;

  static const _emptyDescription = 'صِف ما تتبرّع به في كلمات قليلة.';

  bool get _inspired => widget.inspiredByDiscoveryCardId != null;

  int get _pendingPhotos => _images.where((photo) => !photo.uploaded).length;

  @override
  void initState() {
    super.initState();
    _category = canonicalItemCategoryKey(widget.prefillCategory ?? 'clothes');
    final title = widget.prefillTitle?.trim() ?? '';
    final details = describeItemAttributes(_category, widget.prefillAttributes ?? const {});
    _description.text = [
      if (title.isNotEmpty) title,
      if (details.isNotEmpty) details,
    ].join('\n');
    _loadAddress();
  }

  @override
  void dispose() {
    _description.dispose();
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
      debugPrint('Donation address load failed: ${error.runtimeType}');
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

  void _changeCondition(String value) {
    if (value == _condition) return;
    setState(() {
      _touched = true;
      _condition = value;
    });
  }

  /// Replaces the selection with up to [DonationImageRules.maxImages] valid
  /// photos. Photos of an unsupported type or above the size limit are left
  /// out and the reason is shown.
  Future<void> _pickImages() async {
    if (_picking || _saving || _created != null) return;
    setState(() => _picking = true);
    try {
      final picked = await _picker.pickMultiImage(
        maxWidth: 1440,
        maxHeight: 1440,
        imageQuality: 72,
        limit: DonationImageRules.maxImages,
      );
      if (picked.isEmpty) return;
      final accepted = <_PickedPhoto>[];
      String? problem;
      var rejected = 0;
      for (final file in picked) {
        if (accepted.length >= DonationImageRules.maxImages) {
          problem ??= DonationImageRules.tooManyMessage;
          rejected += 1;
          continue;
        }
        final reason = DonationImageRules.validate(
          fileName: file.name,
          sizeBytes: await file.length(),
          mimeType: file.mimeType,
        );
        if (reason != null) {
          problem ??= reason;
          rejected += 1;
          continue;
        }
        accepted.add(_PickedPhoto(file));
      }
      if (!mounted) return;
      setState(() {
        _touched = true;
        _images
          ..clear()
          ..addAll(accepted);
      });
      final message = problem;
      if (message != null) {
        showInfoSnack(
          context,
          rejected > 1 ? 'لم تُضف $rejected صور. $message' : message,
        );
      }
    } catch (error) {
      debugPrint('Donation photo picking failed: ${error.runtimeType}');
      if (mounted) showInfoSnack(context, 'لم نتمكن من فتح الصور. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _clearImages() {
    if (_saving || _created != null) return;
    setState(_images.clear);
  }

  /// System back and the on-screen back button: leave the form after
  /// confirming when data was entered, or leave the result view.
  Future<void> _handleBack() async {
    if (_saving) return;
    if (_created != null) {
      await _leaveResult();
      return;
    }
    if (_touched) {
      final discard = await confirmDiscardChanges(context);
      if (!mounted) return;
      if (!discard) return;
    }
    leaveForm(context);
  }

  /// Leaves the result view, to [destination] when given (a tab route) or
  /// back to the previous screen. The person is never held: while photos are
  /// still uploading, or when some failed, leaving only asks for a
  /// confirmation first.
  Future<void> _leaveResult({String? destination}) async {
    if (_leaving) return;
    final title = DonationImageRules.leaveWarningTitle(
      uploading: _uploading,
      pending: _pendingPhotos,
    );
    final message = DonationImageRules.leaveWarningMessage(
      uploading: _uploading,
      pending: _pendingPhotos,
    );
    if (title != null && message != null) {
      _leaving = true;
      final leave = await confirmAction(
        context,
        title: title,
        message: message,
        confirmLabel: 'مغادرة',
        cancelLabel: 'البقاء',
        confirmKey: const Key('donation-leave-confirm'),
      );
      _leaving = false;
      if (!mounted || !leave) return;
    }
    if (destination == null) {
      leaveForm(context);
    } else {
      context.go(destination);
    }
  }

  void _followUp() {
    _leaveResult(
      destination: OperationRules.withRequestId(
        '/handoffs?tab=0',
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving || _picking || _created != null) return;
    final valid = _formKey.currentState?.validate() ?? false;
    // Check the value itself as well: the field may be scrolled out of view.
    final problem = validateItemDescription(_description.text, emptyMessage: _emptyDescription);
    if (!valid || problem != null) {
      if (problem != null) showInfoSnack(context, problem);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      if (!await _ensureProfile()) return;
      final repo = ItemRepositoryV2(Supabase.instance.client);
      final description = _description.text.trim();
      final created = await repo.createDonation(
        id: _operationId,
        category: _category,
        title: itemTitleFromDescription(description),
        condition: _condition,
        description: description,
        addressId: await repo.defaultAddressId(),
        inspiredByDiscoveryCardId: widget.inspiredByDiscoveryCardId,
      );
      // The donation exists from here on. Photo problems are reported on the
      // result view and never turn the donation into a failure.
      _created = created;
      if (!mounted) return;
      setState(() => _saving = false);
      await _uploadPendingPhotos();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'لم يُرسل التبرّع. تحقق من اتصالك وحاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  /// Uploads every photo that has not reached the server yet, each one on its
  /// own, for the donation that was already created. Never throws. A photo
  /// that takes longer than [DonationImageRules.uploadTimeout] counts as
  /// failed and can be retried. The loop keeps running if the person leaves.
  Future<void> _uploadPendingPhotos() async {
    final created = _created;
    if (created == null || _uploading || _pendingPhotos == 0) return;
    setState(() => _uploading = true);
    final repo = DonationImageRepository(Supabase.instance.client);
    for (var index = 0; index < _images.length; index++) {
      final photo = _images[index];
      if (photo.uploaded) continue;
      try {
        final bytes = await photo.file
            .readAsBytes()
            .timeout(DonationImageRules.uploadTimeout);
        await repo.upload(
          donationId: created.id,
          bytes: bytes,
          fileName: photo.file.name,
          mimeType: photo.file.mimeType,
          sortOrder: index,
        );
        photo.uploaded = true;
      } catch (error) {
        debugPrint('Donation photo upload failed: ${error.runtimeType}');
      }
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _contribute() async {
    final created = _created;
    if (created == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ContributionScreen(donationId: created.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = _created != null;
    return PopScope<Object?>(
      canPop: done ? !_uploading && _pendingPhotos == 0 : !_touched && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: done ? null : communityAppBar(title: 'تبرّع', onBack: _handleBack),
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
              key: const ValueKey('donation-form'),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              children: [
                if (_inspired) ...[
                  const CommunityNote(
                    icon: Icons.lightbulb_outline_rounded,
                    background: RuhamaaColors.warmGoldSoft,
                    textColor: RuhamaaColors.goldInk,
                    text: 'ملأنا الوصف من الطلب الذي اخترته. سنوجّه تبرّعك إلى الطلب الأنسب والأعلى أولوية.',
                  ),
                  const SizedBox(height: 18),
                ],
                const CommunityFieldLabel('بماذا تتبرّع؟'),
                const SizedBox(height: 10),
                CommunityCategoryGrid(selected: _category, onChanged: _changeCategory),
                const SizedBox(height: 18),
                const CommunityFieldLabel('صِفه بكلماتك'),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('donation-description'),
                  controller: _description,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: ItemFormLimits.description,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(color: RuhamaaColors.text, fontSize: 16, height: 1.5),
                  decoration: communityInputDecoration(
                    hint: 'مثال: ثوب رجالي مقاس 52، نظيف وبحالة جيدة',
                    tone: CommunityTone.give,
                  ),
                  validator: (value) => validateItemDescription(value, emptyMessage: _emptyDescription),
                ),
                const SizedBox(height: 18),
                const CommunityFieldLabel('حالته'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final entry in donationConditionChoices.entries) ...[
                      if (entry.key != donationConditionChoices.keys.first) const SizedBox(width: 8),
                      Expanded(
                        child: _ConditionPill(
                          label: entry.value,
                          selected: _condition == entry.key,
                          onTap: () => _changeCondition(entry.key),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                _PhotoTile(
                  count: _images.length,
                  busy: _picking,
                  onPick: _saving ? null : _pickImages,
                  onClear: _images.isEmpty || _saving ? null : _clearImages,
                ),
                const SizedBox(height: 18),
                CommunityAddressLine(
                  prefix: 'يُستلم من عنوانك',
                  area: _area,
                  loaded: _addressLoaded,
                  onChange: _changeAddress,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
              child: CommunityPillButton(
                key: const Key('donation-submit'),
                label: _saving ? 'جارٍ الإرسال...' : 'أرسل تبرّعي',
                showArrow: !_saving,
                onPressed: _saving || _picking ? null : _submit,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Result view shown once the donation exists. The form and its send
  /// button are gone, so the same donation is the only one photos can go to.
  Widget _sentView() {
    final code = _created?.publicCode ?? '';
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('donation-sent'),
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
            children: [
              CommunitySentSummary(
                heading: 'جزاك الله خيرًا',
                message: 'وصل تبرّعك إلى فريق عطاء. سنبحث عمّن يحتاجه ونخبرك بكل خطوة.',
                codeLabel: 'رقم التبرّع',
                code: code,
              ),
              const SizedBox(height: 30),
              const CommunityNextSteps(
                steps: [
                  'يراجعه الفريق ويصنّفه.',
                  'نجد من يحتاجه، دون أن يعرف أحدكما الآخر.',
                  'يأتي الموصل لاستلامه، وتعطيه رمزًا من التطبيق.',
                ],
              ),
              ..._photoStatus(),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: _contribute,
                  style: TextButton.styleFrom(foregroundColor: RuhamaaColors.textMuted),
                  icon: const Icon(Icons.favorite_outline_rounded, size: 18),
                  label: const Text('المساهمة في تكلفة التوصيل (اختياري)'),
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
                key: const Key('donation-done'),
                label: 'تابع تبرّعك',
                onPressed: _followUp,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  key: const Key('donation-home'),
                  onPressed: () => _leaveResult(destination: '/home'),
                  style: TextButton.styleFrom(
                    foregroundColor: RuhamaaColors.primary,
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

  /// Upload progress, success or the retry for failed photos.
  List<Widget> _photoStatus() {
    final total = _images.length;
    if (total == 0) return const [];
    final pending = _pendingPhotos;
    if (_uploading) {
      return [
        const SizedBox(height: 14),
        CommunityNote(
          icon: Icons.cloud_upload_outlined,
          background: RuhamaaColors.softGreen,
          iconColor: RuhamaaColors.primary,
          textColor: RuhamaaColors.primaryDark,
          text: 'جارٍ رفع الصور (${total - pending} من $total)... '
              'يمكنك المغادرة دون انتظار اكتمال الرفع.',
        ),
        const SizedBox(height: 8),
        const LinearProgressIndicator(),
      ];
    }
    if (pending == 0) {
      return [
        const SizedBox(height: 14),
        CommunityNote(
          icon: Icons.photo_library_outlined,
          background: RuhamaaColors.softGreen,
          iconColor: RuhamaaColors.primary,
          textColor: RuhamaaColors.primaryDark,
          text: total == 1 ? 'رُفعت الصورة مع التبرّع.' : 'رُفعت $total صور مع التبرّع.',
        ),
      ];
    }
    return [
      const SizedBox(height: 14),
      CommunityNote(
        icon: Icons.warning_amber_rounded,
        background: RuhamaaColors.warmGoldSoft,
        textColor: RuhamaaColors.goldInk,
        text: pending == total
            ? 'تبرّعك مسجّل، لكن لم تُرفع الصور ($total). يمكنك إعادة المحاولة الآن دون تسجيل تبرّع جديد.'
            : 'تبرّعك مسجّل، لكن لم تُرفع $pending من $total صور. يمكنك إعادة المحاولة الآن دون تسجيل تبرّع جديد.',
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        key: const Key('donation-retry-photos'),
        onPressed: _uploadPendingPhotos,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('إعادة رفع الصور التي لم تُرفع'),
      ),
    ];
  }
}

/// One of the three condition choices (48 high, pill shaped).
class _ConditionPill extends StatelessWidget {
  const _ConditionPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: selected
          ? const BorderSide(color: RuhamaaColors.primary, width: 2)
          : const BorderSide(color: RuhamaaColors.inputBorder),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? RuhamaaColors.primary : Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : RuhamaaColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Optional photo picker tile. Shows how many photos were chosen.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.count,
    required this.busy,
    required this.onPick,
    required this.onClear,
  });

  final int count;
  final bool busy;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFBFB59F), width: 1.5),
    );
    final chosen = count > 0;
    return Material(
      color: Colors.white,
      shape: shape,
      child: InkWell(
        key: const Key('donation-photo'),
        customBorder: shape,
        onTap: busy ? null : onPick,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: RuhamaaColors.sand,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  chosen ? Icons.photo_library_outlined : Icons.photo_camera_outlined,
                  color: RuhamaaColors.goldDeep,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (chosen)
                      Text(
                        count == 1 ? 'اخترت صورة واحدة' : 'اخترت $count صور',
                        style: const TextStyle(color: RuhamaaColors.text, fontSize: 16, fontWeight: FontWeight.w700),
                      )
                    else
                      const Text.rich(
                        TextSpan(
                          text: 'أضف صورة ',
                          children: [
                            TextSpan(
                              text: '(اختياري)',
                              style: TextStyle(fontWeight: FontWeight.w500, color: RuhamaaColors.iconMuted),
                            ),
                          ],
                        ),
                        style: TextStyle(color: RuhamaaColors.text, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      chosen
                          ? 'اضغط لتغييرها. حتى ${DonationImageRules.maxImages} صور JPG أو PNG أو WebP.'
                          : 'تساعد الفريق على إيجاد من يحتاجه',
                      style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
              if (chosen)
                TextButton(
                  onPressed: onClear,
                  child: const Text('إزالة'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
