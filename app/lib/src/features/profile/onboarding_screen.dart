import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void dispose() {
    _phone.dispose();
    _area.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم منح إذن الموقع. يمكنك المحاولة لاحقًا.')));
      return;
    }
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    if (mounted) setState(() => _position = position);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدد الموقع الجغرافي أولًا.')));
      return;
    }
    setState(() => _busy = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    try {
      await client.from('profiles').update({'phone': _phone.text.trim()}).eq('id', userId);
      await client.from('addresses').update({'is_default': false}).eq('user_id', userId).eq('is_default', true);
      await client.from('addresses').insert({
        'user_id': userId,
        'label': 'الافتراضي',
        'area': _area.text.trim(),
        'description': _description.text.trim(),
        'latitude': _position!.latitude,
        'longitude': _position!.longitude,
        'is_default': true,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ بيانات التوصيل.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ البيانات: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بيانات التوصيل')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('هذه البيانات لا تظهر للمتبرع أو المستفيد الآخر، وتستخدم فقط لتشغيل الاستلام والتوصيل.'),
            const SizedBox(height: 20),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف'), validator: (v) => v == null || v.trim().length < 7 ? 'أدخل رقم هاتف صحيحًا' : null),
            const SizedBox(height: 14),
            TextFormField(controller: _area, decoration: const InputDecoration(labelText: 'المنطقة / الحي', hintText: 'مثال: الروضة'), validator: (v) => v == null || v.trim().isEmpty ? 'أدخل المنطقة' : null),
            const SizedBox(height: 14),
            TextFormField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'وصف العنوان', hintText: 'علامة مميزة تساعد المندوب فقط')),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: _captureLocation, icon: const Icon(Icons.my_location), label: Text(_position == null ? 'تحديد موقعي الحالي' : 'تم تحديد الموقع — اضغط للتحديث')),
            const SizedBox(height: 24),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'جارٍ الحفظ...' : 'حفظ')),
          ],
        ),
      ),
    );
  }
}
