import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/donation_image_repository.dart';
import '../../data/sanad_repository.dart';
import '../contributions/contribution_screen.dart';

class CreateDonationScreen extends StatefulWidget {
  const CreateDonationScreen({super.key});

  @override
  State<CreateDonationScreen> createState() => _CreateDonationScreenState();
}

class _CreateDonationScreenState extends State<CreateDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  String _condition = 'good';
  String _category = 'other';
  bool _saving = false;

  static const categories = <String, String>{
    'clothes': 'ملابس',
    'books': 'كتب وتعليم',
    'furniture': 'أثاث',
    'children': 'مستلزمات أطفال',
    'home': 'أدوات منزلية',
    'electronics': 'أجهزة',
    'events': 'مستلزمات مناسبات',
    'other': 'أخرى',
  };

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(maxWidth: 1440, maxHeight: 1440, imageQuality: 72, limit: 4);
    if (!mounted) return;
    setState(() {
      _images
        ..clear()
        ..addAll(picked.take(4));
    });
  }

  Future<bool> _ensureProfile() async {
    final repo = SanadRepository(Supabase.instance.client);
    if (await repo.hasOperationalProfile()) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل رقم الهاتف وعنوان التوصيل أولًا.')));
    await context.push('/onboarding');
    return repo.hasOperationalProfile();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (!await _ensureProfile()) return;
      final repo = SanadRepository(Supabase.instance.client);
      final donationId = await repo.createDonation(
        title: _title.text.trim(),
        description: _description.text.trim(),
        condition: _condition,
        category: _category,
        addressId: await repo.defaultAddressId(),
      );
      final imageRepo = DonationImageRepository(Supabase.instance.client);
      for (var i = 0; i < _images.length; i++) {
        final x = _images[i];
        final Uint8List bytes = await x.readAsBytes();
        final ext = x.name.contains('.') ? x.name.split('.').last : 'jpg';
        await imageRepo.upload(donationId: donationId, bytes: bytes, extension: ext, sortOrder: i);
      }
      if (!mounted) return;
      final contribute = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تم تسجيل التبرع'),
          content: const Text('هل ترغب بالمساهمة اختياريًا في تكلفة استلام وتوصيل هذا التبرع؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ليس الآن')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('نعم، أساهم')),
          ],
        ),
      );
      if (!mounted) return;
      if (contribute == true) await Navigator.push(context, MaterialPageRoute(builder: (_) => ContributionScreen(donationId: donationId)));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ التبرع: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لدي شيء')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('أخبرنا عن الشيء الذي تريد أن يستفيد منه غيرك. لن تظهر هويتك للمستفيد.'),
            const SizedBox(height: 20),
            OutlinedButton.icon(onPressed: _saving ? null : _pickImages, icon: const Icon(Icons.add_a_photo_outlined), label: Text(_images.isEmpty ? 'إضافة صور (حتى 4)' : 'تم اختيار ${_images.length} صورة — تغيير')),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(value: _category, decoration: const InputDecoration(labelText: 'الفئة'), items: categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) => setState(() => _category = v ?? 'other')),
            const SizedBox(height: 16),
            TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'ما هو الشيء؟', hintText: 'مثال: سرير طفل'), validator: (v) => v == null || v.trim().length < 3 ? 'اكتب اسمًا واضحًا للشيء' : null),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(value: _condition, decoration: const InputDecoration(labelText: 'الحالة'), items: const [DropdownMenuItem(value: 'new', child: Text('جديد')), DropdownMenuItem(value: 'excellent', child: Text('ممتاز')), DropdownMenuItem(value: 'good', child: Text('جيد')), DropdownMenuItem(value: 'minor_repair', child: Text('يحتاج إصلاحًا بسيطًا'))], onChanged: (v) => setState(() => _condition = v ?? 'good')),
            const SizedBox(height: 16),
            TextFormField(controller: _description, maxLines: 4, decoration: const InputDecoration(labelText: 'وصف اختياري', hintText: 'الحالة، العمر التقريبي، أي ملاحظات مهمة')),
            const SizedBox(height: 24),
            FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'جارٍ الحفظ والرفع...' : 'إرسال التبرع')),
          ],
        ),
      ),
    );
  }
}
