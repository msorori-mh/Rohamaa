import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/account_repository.dart';
import '../../domain/contact_rules.dart';
import '../../theme/ruhamaa_theme.dart';

/// What the location button should offer after a failed capture.
enum _LocationHelp { none, openLocationSettings, openAppSettings }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _area = TextEditingController();
  final _description = TextEditingController();

  bool _loading = true;
  Object? _loadError;
  List<Map<String, dynamic>> _areas = const [];
  String? _addressId;
  String? _serviceAreaId;
  double? _latitude;
  double? _longitude;

  bool _busy = false;
  bool _locating = false;
  String? _locationMessage;
  _LocationHelp _locationHelp = _LocationHelp.none;

  AccountRepository get _repo => AccountRepository(Supabase.instance.client);
  bool get _hasPosition => _latitude != null && _longitude != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _area.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = _repo;
      final areas = await repo.activeServiceAreas();
      final profile = await repo.deliveryProfile();
      if (!mounted) return;
      final areaIds = areas.map((area) => area['id'] as String).toSet();
      String? selected = profile.serviceAreaId;
      if (selected == null || !areaIds.contains(selected)) {
        selected = null;
        if (areas.isNotEmpty) {
          final marib = areas.where((area) => area['code'] == 'MARIB').toList();
          selected = (marib.isNotEmpty ? marib.first : areas.first)['id'] as String;
        }
      }
      setState(() {
        _areas = areas;
        _addressId = profile.addressId;
        _serviceAreaId = selected;
        _latitude = profile.latitude;
        _longitude = profile.longitude;
        _name.text = (profile.fullName ?? '').trim();
        _phone.text = (profile.phone ?? '').trim();
        _area.text = (profile.area ?? '').trim();
        _description.text = (profile.description ?? '').trim();
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      debugPrint('Ataa delivery profile load failed: ${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  void _retryLoad() {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _load();
  }

  void _locationFailed(String message, [_LocationHelp help = _LocationHelp.none]) {
    if (!mounted) return;
    setState(() {
      _locating = false;
      _locationMessage = message;
      _locationHelp = help;
    });
  }

  Future<void> _captureLocation() async {
    if (_locating || _busy) return;
    setState(() {
      _locating = true;
      _locationMessage = null;
      _locationHelp = _LocationHelp.none;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationFailed(
          'خدمة الموقع متوقفة في جهازك. فعّلها ثم حاول مرة أخرى، أو اكتب وصفًا واضحًا للعنوان.',
          _LocationHelp.openLocationSettings,
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _locationFailed(
          'إذن الموقع مرفوض لهذا التطبيق. يمكنك السماح به من إعدادات التطبيق، أو الاكتفاء بوصف واضح للعنوان.',
          _LocationHelp.openAppSettings,
        );
        return;
      }
      if (permission == LocationPermission.denied) {
        _locationFailed(
          'لم يُمنح إذن الموقع. يمكنك المحاولة مرة أخرى أو الاكتفاء بوصف واضح للعنوان.',
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locating = false;
        _locationMessage = null;
        _locationHelp = _LocationHelp.none;
      });
    } on TimeoutException {
      _locationFailed(
        'استغرق تحديد الموقع وقتًا طويلًا. جرّب في مكان مكشوف، أو اكتب وصفًا واضحًا للعنوان.',
      );
    } catch (error) {
      debugPrint('Ataa location capture failed: ${error.runtimeType}');
      _locationFailed(
        'لم نتمكن من تحديد موقعك الآن. حاول مرة أخرى أو اكتب وصفًا واضحًا للعنوان.',
      );
    }
  }

  Future<void> _openLocationHelp() async {
    final help = _locationHelp;
    try {
      if (help == _LocationHelp.openLocationSettings) {
        await Geolocator.openLocationSettings();
      } else if (help == _LocationHelp.openAppSettings) {
        await Geolocator.openAppSettings();
      }
    } catch (error) {
      debugPrint('Ataa settings shortcut failed: ${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('افتح إعدادات الجهاز يدويًا ثم عد إلى التطبيق.')),
      );
    }
  }

  void _clearPosition() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _locationMessage = null;
      _locationHelp = _LocationHelp.none;
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final serviceAreaId = _serviceAreaId;
    if (serviceAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد المدينة أو نطاق الخدمة.')),
      );
      return;
    }
    final phone = ContactRules.normalizeYemenMobile(_phone.text);
    if (phone == null) return;

    setState(() => _busy = true);
    try {
      await _repo.saveDeliveryProfile(
        fullName: _name.text.trim(),
        phone: phone,
        serviceAreaId: serviceAreaId,
        area: _area.text.trim(),
        description: _description.text.trim(),
        addressId: _addressId,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ بيانات التوصيل.')),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/home');
      }
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: 'لم يتم حفظ البيانات. تحقق من اتصالك ثم حاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عنوان الاستلام والتسليم')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final loadError = _loadError;
    if (loadError != null) {
      return ErrorRetry(error: loadError, onRetry: _retryLoad);
    }
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: RuhamaaColors.softGreen,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: RuhamaaColors.primary, size: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'موقعك خاص',
                        style: TextStyle(color: RuhamaaColors.primaryDark, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'لا نشارك هذه البيانات إلا عند الحاجة لإتمام الاستلام أو التسليم.',
                        style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          TextFormField(
            key: const Key('onboarding-name'),
            controller: _name,
            enabled: !_busy,
            maxLength: ContactRules.maxNameLength,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'الاسم',
              prefixIcon: Icon(Icons.person_outline_rounded),
              counterText: '',
            ),
            validator: ContactRules.validateFullName,
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('onboarding-phone'),
            controller: _phone,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              hintText: '7XXXXXXXX',
              helperText: 'رقم جوال يمني من 9 أرقام يبدأ بـ 7',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: ContactRules.validatePhone,
          ),
          const SizedBox(height: 14),
          if (_areas.isEmpty)
            const Text('لا توجد مدينة مفعلة للخدمة حاليًا.')
          else
            DropdownButtonFormField<String>(
              initialValue: _serviceAreaId,
              decoration: const InputDecoration(
                labelText: 'المدينة أو منطقة الخدمة',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              items: _areas.map((a) {
                final prefix = a['kind'] == 'city' ? 'مدينة' : 'منطقة';
                return DropdownMenuItem<String>(
                  value: a['id'] as String,
                  child: Text('$prefix: ${a['name_ar']}'),
                );
              }).toList(),
              onChanged: _busy ? null : (v) => setState(() => _serviceAreaId = v),
              validator: (v) => v == null ? 'حدد نطاق الخدمة' : null,
            ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('onboarding-area'),
            controller: _area,
            enabled: !_busy,
            maxLength: ContactRules.maxAreaLength,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'الحي أو المنطقة',
              hintText: 'مثال: الروضة',
              prefixIcon: Icon(Icons.home_work_outlined),
              counterText: '',
            ),
            validator: ContactRules.validateArea,
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('onboarding-description'),
            controller: _description,
            enabled: !_busy,
            maxLines: 3,
            maxLength: ContactRules.maxDescriptionLength,
            decoration: InputDecoration(
              labelText: _hasPosition ? 'وصف العنوان (اختياري)' : 'وصف العنوان',
              hintText: 'مثال: بجوار المدرسة أو المسجد',
              prefixIcon: const Icon(Icons.description_outlined),
            ),
            validator: (v) => ContactRules.validateDescription(v, hasPosition: _hasPosition),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            key: const Key('onboarding-capture-location'),
            onPressed: _locating || _busy ? null : _captureLocation,
            icon: _locating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _hasPosition ? Icons.check_circle_rounded : Icons.my_location_rounded,
                  ),
            label: Text(
              _locating
                  ? 'جارٍ تحديد الموقع...'
                  : _hasPosition
                      ? 'تم تحديد الموقع — اضغط للتحديث'
                      : 'تحديد موقعي الحالي (اختياري)',
            ),
          ),
          if (!_hasPosition && _locationMessage == null) ...[
            const SizedBox(height: 8),
            const Text(
              'تحديد الموقع يساعد الموصل على الوصول أسرع. إن لم ترغب، اكتب وصفًا واضحًا للعنوان.',
              style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 12, height: 1.5),
            ),
          ],
          if (_locationMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RuhamaaColors.warmGoldSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 20, color: RuhamaaColors.warmGold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationMessage!,
                          style: const TextStyle(color: RuhamaaColors.primaryDark, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                  if (_locationHelp != _LocationHelp.none)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: _openLocationHelp,
                        icon: const Icon(Icons.settings_outlined),
                        label: Text(
                          _locationHelp == _LocationHelp.openLocationSettings
                              ? 'فتح إعدادات الموقع'
                              : 'فتح إعدادات التطبيق',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_hasPosition) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RuhamaaColors.warmGoldSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 20, color: RuhamaaColors.warmGold),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'حُفظ الموقع لاستخدامه في الاستلام أو التسليم فقط.',
                      style: TextStyle(color: RuhamaaColors.primaryDark),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy || _locating ? null : _clearPosition,
                    child: const Text('إزالة'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          FilledButton.icon(
            key: const Key('onboarding-save'),
            onPressed: _busy || _locating ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_busy ? 'جارٍ الحفظ...' : 'حفظ العنوان'),
          ),
        ],
      ),
    );
  }
}
