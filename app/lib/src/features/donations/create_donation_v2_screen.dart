import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../catalog/item_category_catalog.dart';
import '../../core/app_error.dart';
import '../../data/donation_image_repository.dart';
import '../../data/item_repository_v2.dart';
import '../../domain/donation_image_rules.dart';
import '../../domain/item_form_rules.dart';
import '../../theme/ruhamaa_theme.dart';
import '../contributions/contribution_screen.dart';
import '../items/form_guards.dart';
import '../items/item_form_components.dart';

class CreateDonationV2Screen extends StatefulWidget {
  const CreateDonationV2Screen({
    super.key,
    this.prefillCategory,
    this.prefillGroup,
    this.prefillItemTypeKey,
    this.prefillTitle,
    this.prefillAttributes,
    this.inspiredByDiscoveryCardId,
  });

  final String? prefillCategory;
  final String? prefillGroup;
  final String? prefillItemTypeKey;
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
  static const int _doneStep = 3;

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  final List<_PickedPhoto> _images = [];
  final Map<String, String> _attributes = {};

  String _category = 'clothes';
  String? _group;
  String? _itemTypeKey;
  String _condition = 'good';
  bool _saving = false;
  bool _picking = false;
  bool _uploading = false;
  bool _touched = false;
  bool _selectionMissing = false;
  int _step = 0;

  /// Title that was filled from the selected item, if any. A title that
  /// differs from it was typed by the person and is never overwritten.
  String? _autoTitle;

  /// Set as soon as the donation exists on the server. From then on the form
  /// is replaced by the result view, so a second donation cannot be created.
  CreatedOperation? _created;

  static const conditions = <String, String>{
    'new': 'جديد',
    'excellent': 'ممتاز',
    'good': 'جيد',
    'minor_repair': 'يحتاج إصلاحًا بسيطًا',
  };

  bool get _inspired => widget.inspiredByDiscoveryCardId != null;

  int get _pendingPhotos => _images.where((photo) => !photo.uploaded).length;

  @override
  void initState() {
    super.initState();
    _category = canonicalItemCategoryKey(widget.prefillCategory ?? 'clothes');
    final category = itemCategoryByKey(_category);
    final groupCandidate = widget.prefillGroup;
    if (groupCandidate != null && category.groups.any((group) => group.key == groupCandidate)) {
      _group = groupCandidate;
    }
    final typeCandidate = widget.prefillItemTypeKey;
    if (typeCandidate != null && itemTypeByKey(category, typeCandidate) != null) {
      _itemTypeKey = typeCandidate;
      _group ??= category.groups
          .firstWhere((group) => group.items.any((item) => item.key == typeCandidate))
          .key;
    }
    _attributes.addAll(widget.prefillAttributes ?? const {});
    final prefillTitle = widget.prefillTitle?.trim();
    if (prefillTitle != null && prefillTitle.isNotEmpty) {
      _title.text = prefillTitle;
    } else if (_itemTypeKey != null) {
      final label = itemTypeByKey(category, _itemTypeKey)?.label ?? '';
      _title.text = label;
      _autoTitle = label;
    }
    if (_inspired) _step = _itemTypeKey == null ? 0 : 1;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<bool> _ensureProfile() async {
    final repo = ItemRepositoryV2(Supabase.instance.client);
    if (await repo.hasOperationalProfile()) return true;
    if (!mounted) return false;
    showInfoSnack(context, 'أكمل رقم الهاتف وعنوان التوصيل أولًا.');
    await context.push('/onboarding');
    return repo.hasOperationalProfile();
  }

  void _clearAutoTitle() {
    if (!isCustomItemTitle(title: _title.text, autoTitle: _autoTitle)) {
      _title.clear();
    }
    _autoTitle = null;
  }

  void _changeCategory(String value) {
    if (value == _category) return;
    setState(() {
      _touched = true;
      _category = value;
      _group = null;
      _itemTypeKey = null;
      _attributes.clear();
      _clearAutoTitle();
    });
  }

  void _changeGroup(String value) {
    if (value == _group) return;
    setState(() {
      _touched = true;
      _group = value;
      _itemTypeKey = null;
      _clearAutoTitle();
    });
  }

  void _changeItem(String value) {
    final category = itemCategoryByKey(_category);
    final label = itemTypeByKey(category, value)?.label ?? '';
    setState(() {
      _touched = true;
      _selectionMissing = false;
      _itemTypeKey = value;
      _title.text = titleAfterItemChange(
        currentTitle: _title.text,
        previousAutoTitle: _autoTitle,
        newItemLabel: label,
      );
      _autoTitle = label;
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

  void _nextFromCategory() {
    if (_group == null || _itemTypeKey == null) {
      setState(() => _selectionMissing = true);
      return;
    }
    setState(() => _step = 1);
  }

  void _nextFromDetails() {
    if (!_formKey.currentState!.validate()) return;
    // A field scrolled far out of view is not built, so the form cannot show
    // its message: check the values themselves as well.
    final problem = validateItemTitle(_title.text, emptyMessage: 'اكتب اسمًا واضحًا للشيء') ??
        validateOptionalText(_description.text);
    if (problem != null) {
      showInfoSnack(context, problem);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _step = 2);
  }

  /// System back and the on-screen back buttons: go to the previous step, or
  /// leave the form after confirming when data was entered.
  Future<void> _handleBack() async {
    if (_saving || _uploading) return;
    if (_created != null) {
      leaveForm(context);
      return;
    }
    if (_step > 0) {
      setState(() => _step -= 1);
      return;
    }
    if (_touched) {
      final discard = await confirmDiscardChanges(context);
      if (!mounted) return;
      if (!discard) return;
    }
    leaveForm(context);
  }

  Future<void> _submit() async {
    if (_saving || _created != null) return;
    if (_group == null || _itemTypeKey == null) return;
    setState(() => _saving = true);
    try {
      if (!await _ensureProfile()) return;
      final repo = ItemRepositoryV2(Supabase.instance.client);
      final created = await repo.createDonation(
        category: _category,
        categoryGroup: _group!,
        itemTypeKey: _itemTypeKey!,
        title: _title.text.trim(),
        condition: _condition,
        attributes: _attributes,
        description: _description.text,
        addressId: await repo.defaultAddressId(),
        inspiredByDiscoveryCardId: widget.inspiredByDiscoveryCardId,
      );
      // The donation exists from here on. Photo problems are reported on the
      // result view and never turn the donation into a failure.
      _created = created;
      if (!mounted) return;
      setState(() {
        _step = _doneStep;
        _saving = false;
      });
      await _uploadPendingPhotos();
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'تعذر إرسال التبرع. تحقق من اتصالك وحاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  /// Uploads every photo that has not reached the server yet, each one on its
  /// own, for the donation that was already created. Never throws.
  Future<void> _uploadPendingPhotos() async {
    final created = _created;
    if (created == null || _uploading || _pendingPhotos == 0) return;
    setState(() => _uploading = true);
    final repo = DonationImageRepository(Supabase.instance.client);
    for (var index = 0; index < _images.length; index++) {
      final photo = _images[index];
      if (photo.uploaded) continue;
      try {
        final bytes = await photo.file.readAsBytes();
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
    if (created == null || _uploading) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ContributionScreen(donationId: created.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = _created != null;
    return PopScope<Object?>(
      canPop: done ? !_uploading : _step == 0 && !_touched && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('تبرّع بشيء')),
        body: Form(
          key: _formKey,
          onChanged: () {
            if (!_touched) setState(() => _touched = true);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _Progress(current: _step + 1),
              const SizedBox(height: 18),
              if (_inspired && !done) ...[
                const _InfoBox(
                  icon: Icons.lightbulb_outline_rounded,
                  color: RuhamaaColors.warmGoldSoft,
                  iconColor: RuhamaaColors.warmGold,
                  text: 'ملأنا بعض البيانات من الطلب الذي اخترته. سنوجّه تبرعك إلى الطلب الأنسب والأعلى أولوية.',
                ),
                const SizedBox(height: 16),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: done
                    ? _doneView()
                    : switch (_step) {
                        0 => _categoryStep(),
                        1 => _detailsStep(),
                        _ => _reviewStep(),
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryStep() {
    return Column(
      key: const ValueKey('donation-v2-category'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _InfoBox(
          icon: Icons.favorite_outline_rounded,
          color: RuhamaaColors.softGreen,
          iconColor: RuhamaaColors.primary,
          text: 'اختر النوع الأقرب حتى نصل تبرعك بالشخص المناسب.',
        ),
        const SizedBox(height: 18),
        ItemClassificationSelector(
          categoryKey: _category,
          groupKey: _group,
          itemTypeKey: _itemTypeKey,
          onCategoryChanged: _changeCategory,
          onGroupChanged: _changeGroup,
          onItemTypeChanged: _changeItem,
        ),
        if (_selectionMissing) ...[
          const SizedBox(height: 12),
          Text(
            'اختر القسم ثم نوع الشيء بالتحديد.',
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700),
          ),
        ],
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
    final category = itemCategoryByKey(_category);
    return Column(
      key: const ValueKey('donation-v2-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          itemPathLabel(categoryKey: _category, groupKey: _group, itemTypeKey: _itemTypeKey),
          style: const TextStyle(color: RuhamaaColors.primary, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _title,
          maxLength: ItemFormLimits.title,
          decoration: const InputDecoration(
            labelText: 'اسم مختصر للشيء',
            hintText: 'يمكنك إضافة وصف مختصر أدق',
            counterText: '',
          ),
          validator: (value) => validateItemTitle(value, emptyMessage: 'اكتب اسمًا واضحًا للشيء'),
        ),
        const SizedBox(height: 16),
        ItemAttributesEditor(
          category: category,
          values: _attributes,
          onChanged: (key, value) {
            _attributes[key] = value;
            if (category.attributes.any((attribute) => attribute.key == key && attribute.isChoice)) setState(() {});
          },
        ),
        const SizedBox(height: 4),
        Text('حالة الشيء', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: conditions.entries.map((entry) => ChoiceChip(
                label: Text(entry.value),
                selected: _condition == entry.key,
                onSelected: (_) => setState(() {
                  _touched = true;
                  _condition = entry.key;
                }),
              )).toList(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _description,
          maxLines: 3,
          maxLength: ItemFormLimits.description,
          decoration: const InputDecoration(
            labelText: 'ملاحظات إضافية (اختياري)',
            hintText: 'أي تفاصيل لا تغطيها الحقول السابقة',
          ),
          validator: validateOptionalText,
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _saving || _picking ? null : _pickImages,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(_images.isEmpty ? 'إضافة صور (حتى 4)' : 'تم اختيار ${_images.length} صورة — تغيير'),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Expanded(
              child: Text(
                'صور JPG أو PNG أو WebP، وحجم كل صورة حتى 5 ميجابايت.',
                style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 12, height: 1.4),
              ),
            ),
            if (_images.isNotEmpty)
              TextButton(onPressed: _clearImages, child: const Text('إزالة الصور')),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: _handleBack, child: const Text('السابق'))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _picking ? null : _nextFromDetails,
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
    final path = itemPathLabel(categoryKey: _category, groupKey: _group, itemTypeKey: _itemTypeKey);
    final condition = conditions[_condition] ?? 'غير محددة';
    final attributeText = describeItemAttributes(_category, _attributes);
    final notes = _description.text.trim();
    return Column(
      key: const ValueKey('donation-v2-review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('راجع تبرعك قبل الإرسال', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 14),
                _ReviewRow('التصنيف', path),
                _ReviewRow('الشيء', _title.text.trim()),
                _ReviewRow('الحالة', condition),
                if (attributeText.isNotEmpty) _ReviewRow('الخصائص', attributeText),
                if (notes.isNotEmpty) _ReviewRow('ملاحظات', notes),
                _ReviewRow('الصور', _images.isEmpty ? 'بدون صور' : '${_images.length} صورة'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _InfoBox(
          icon: Icons.balance_outlined,
          color: RuhamaaColors.softGreen,
          iconColor: RuhamaaColors.primary,
          text: _inspired
              ? 'سنوجّه تبرعك إلى الطلب الأنسب والأعلى أولوية.'
              : 'يراجع عطاء التبرع ويوجهه بخصوصية. لا تظهر هوية أي طرف للآخر.',
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: _saving ? null : _handleBack, child: const Text('تعديل'))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.volunteer_activism_outlined),
                label: Text(_saving ? 'جارٍ الإرسال...' : 'إرسال التبرع'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Result view shown once the donation exists. The form and its send
  /// button are gone, so the same donation is the only one photos can go to.
  Widget _doneView() {
    final code = _created?.publicCode ?? '';
    final total = _images.length;
    final pending = _pendingPhotos;
    return Column(
      key: const ValueKey('donation-v2-done'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const Icon(Icons.task_alt_rounded, color: RuhamaaColors.primary, size: 54),
                const SizedBox(height: 10),
                const Text(
                  'تم تسجيل تبرعك',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: RuhamaaColors.primaryDark, fontWeight: FontWeight.w900, fontSize: 20),
                ),
                if (code.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SelectableText(
                    'رقم التبرع: $code',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'سنراجع التبرع ونتواصل معك لترتيب الاستلام. يمكنك أيضًا المساهمة في تكلفة التوصيل إن رغبت.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        if (total > 0) ...[
          const SizedBox(height: 14),
          if (_uploading) ...[
            _InfoBox(
              icon: Icons.cloud_upload_outlined,
              color: RuhamaaColors.softGreen,
              iconColor: RuhamaaColors.primary,
              text: 'جارٍ رفع الصور (${total - pending} من $total)...',
            ),
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ] else if (pending == 0)
            _InfoBox(
              icon: Icons.photo_library_outlined,
              color: RuhamaaColors.softGreen,
              iconColor: RuhamaaColors.primary,
              text: total == 1 ? 'رُفعت الصورة مع التبرع.' : 'رُفعت $total صور مع التبرع.',
            )
          else ...[
            _InfoBox(
              icon: Icons.warning_amber_rounded,
              color: RuhamaaColors.warmGoldSoft,
              iconColor: RuhamaaColors.warmGold,
              text: pending == total
                  ? 'تبرعك مسجّل، لكن لم تُرفع الصور ($total). يمكنك إعادة المحاولة الآن دون تسجيل تبرع جديد.'
                  : 'تبرعك مسجّل، لكن لم تُرفع $pending من $total صور. يمكنك إعادة المحاولة الآن دون تسجيل تبرع جديد.',
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('donation-retry-photos'),
              onPressed: _uploadPendingPhotos,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة رفع الصور التي لم تُرفع'),
            ),
          ],
        ],
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _contribute,
          icon: const Icon(Icons.favorite_outline_rounded),
          label: const Text('المساهمة في التوصيل'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const Key('donation-done'),
          onPressed: _uploading ? null : () => leaveForm(context),
          icon: const Icon(Icons.check_rounded),
          label: const Text('تم'),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.current});
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
                backgroundColor: active ? RuhamaaColors.primary : RuhamaaColors.border,
                foregroundColor: active ? Colors.white : RuhamaaColors.textMuted,
                child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 5),
              Text(labels[index], style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        );
      }),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.color, required this.iconColor, required this.text});
  final IconData icon;
  final Color color;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: RuhamaaColors.primaryDark, height: 1.5))),
          ],
        ),
      );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 74, child: Text(label, style: const TextStyle(color: RuhamaaColors.textMuted))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
}
