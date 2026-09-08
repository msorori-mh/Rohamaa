import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/ruhamaa_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _area = TextEditingController();
  final _description = TextEditingController();
  Position? _position;
  bool _busy = false;
  String? _serviceAreaId;
  late Future<List<Map<String, dynamic>>> _serviceAreasFuture;

  @override
  void initState() {
    super.initState();
    _serviceAreasFuture = _loadServiceAreas();
  }

  Future<List<Map<String, dynamic>>> _loadServiceAreas() async {
    final rows = await Supabase.instance.client
        .from('service_areas')
        .select('id,code,name_ar,kind,parent_id')
        .eq('active', true)
        .order('kind')
        .order('name_ar');
    final areas = (rows as List).cast<Map<String, dynamic>>();
    if (_serviceAreaId == null && areas.isNotEmpty) {
      final marib = areas.where((a) => a['code'] == 'MARIB').toList();
      _serviceAreaId = (marib.isNotEmpty ? marib.first : areas.first)['id'] as String;
    }
    return areas;
  }

  @override
  void dispose() {
    _phone.dispose();
    _area.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم منح إذن الموقع. يمكنك المحاولة لاحقًا.'),
          ),
        );
      }
      return;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    if (mounted) setState(() => _position = position);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد الموقع الجغرافي أولًا.')),
      );
      return;
    }
    if (_serviceAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد المدينة أو نطاق الخدمة.')),
      );
      return;
    }

    setState(() => _busy = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    try {
      await client.from('profiles').update({'phone': _phone.text.trim()}).eq('id', userId);
      await client
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', userId)
          .eq('is_default', true);
      await client.from('addresses').insert({
        'user_id': userId,
        'label': 'الافتراضي',
        'service_area_id': _serviceAreaId,
        'area': _area.text.trim(),
        'description': _description.text.trim(),
        'latitude': _position!.latitude,
        'longitude': _position!.longitude,
        'is_default': true,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ بيانات التوصيل.')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ البيانات. تحقق من اتصالك وحاول مرة أخرى.')),
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
      body: Form(
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
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) => v == null || v.trim().length < 7
                  ? 'أدخل رقم هاتف صحيحًا'
                  : null,
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _serviceAreasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return const Text('تعذر تحميل مناطق الخدمة. تحقق من اتصالك وحاول مجددًا.');
                }
                final areas = snapshot.data ?? const [];
                if (areas.isEmpty) {
                  return const Text('لا توجد مدينة مفعلة للخدمة حاليًا.');
                }
                return DropdownButtonFormField<String>(
                  initialValue: _serviceAreaId,
                  decoration: const InputDecoration(
                labelText: 'المدينة أو منطقة الخدمة',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  items: areas.map((a) {
                    final prefix = a['kind'] == 'city' ? 'مدينة' : 'منطقة';
                    return DropdownMenuItem(
                      value: a['id'] as String,
                      child: Text('$prefix: ${a['name_ar']}'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _serviceAreaId = v),
                  validator: (v) => v == null ? 'حدد نطاق الخدمة' : null,
                );
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _area,
              decoration: const InputDecoration(
                labelText: 'الحي أو المنطقة',
                hintText: 'مثال: الروضة',
                prefixIcon: Icon(Icons.home_work_outlined),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'أدخل الحي أو المنطقة'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'وصف العنوان',
                hintText: 'مثال: بجوار المدرسة أو المسجد',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _captureLocation,
              icon: Icon(
                _position == null ? Icons.my_location_rounded : Icons.check_circle_rounded,
              ),
              label: Text(
                _position == null
                    ? 'تحديد موقعي الحالي'
                    : 'تم تحديد الموقع — اضغط للتحديث',
              ),
            ),
            if (_position != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RuhamaaColors.warmGoldSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 20, color: RuhamaaColors.warmGold),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'حُفظ الموقع لاستخدامه في الاستلام أو التسليم فقط.',
                        style: TextStyle(color: RuhamaaColors.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_busy ? 'جارٍ الحفظ...' : 'حفظ العنوان'),
            ),
          ],
        ),
      ),
    );
  }
}
