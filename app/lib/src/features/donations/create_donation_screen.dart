import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/sanad_repository.dart';

class CreateDonationScreen extends StatefulWidget {
  const CreateDonationScreen({super.key});

  @override
  State<CreateDonationScreen> createState() => _CreateDonationScreenState();
}

class _CreateDonationScreenState extends State<CreateDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _condition = 'good';
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await SanadRepository(Supabase.instance.client).createDonation(
        title: _title.text.trim(),
        description: _description.text.trim(),
        condition: _condition,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل التبرع بنجاح.')));
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ التبرع. حاول مرة أخرى.')));
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
            const Text('أخبرنا عن الشيء الذي تريد أن يستفيد منه غيرك.'),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'ما هو الشيء؟', hintText: 'مثال: سرير طفل'),
              validator: (v) => v == null || v.trim().length < 3 ? 'اكتب اسمًا واضحًا للشيء' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _condition,
              decoration: const InputDecoration(labelText: 'الحالة'),
              items: const [
                DropdownMenuItem(value: 'new', child: Text('جديد')),
                DropdownMenuItem(value: 'excellent', child: Text('ممتاز')),
                DropdownMenuItem(value: 'good', child: Text('جيد')),
                DropdownMenuItem(value: 'minor_repair', child: Text('يحتاج إصلاحًا بسيطًا')),
              ],
              onChanged: (v) => setState(() => _condition = v ?? 'good'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'وصف اختياري', hintText: 'الحالة، العمر التقريبي، أي ملاحظات مهمة'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'جارٍ الحفظ...' : 'إرسال التبرع'),
            ),
          ],
        ),
      ),
    );
  }
}
