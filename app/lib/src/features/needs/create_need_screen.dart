import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/sanad_repository.dart';

class CreateNeedScreen extends StatefulWidget {
  const CreateNeedScreen({super.key});

  @override
  State<CreateNeedScreen> createState() => _CreateNeedScreenState();
}

class _CreateNeedScreenState extends State<CreateNeedScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _reason = TextEditingController();
  bool _acceptsUsed = true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await SanadRepository(Supabase.instance.client).createNeed(
        title: _title.text.trim(),
        reason: _reason.text.trim(),
        acceptsUsed: _acceptsUsed,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل احتياجك. سنخبرك عند وجود تطابق مناسب.')));
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ الطلب. حاول مرة أخرى.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أحتاج شيئًا')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('سجّل احتياجك فقط. لا توجد قائمة تبرعات للتصفح حفاظًا على عدالة المطابقة.'),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'ماذا تحتاج؟', hintText: 'مثال: كتب الصف السادس'),
              validator: (v) => v == null || v.trim().length < 3 ? 'اكتب احتياجًا واضحًا' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reason,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'لماذا تحتاجه؟', helperText: 'هذه المعلومة داخلية وتساعد سند على المطابقة، ولا تُعرض للمتبرع.'),
              validator: (v) => v == null || v.trim().length < 8 ? 'أضف وصفًا مختصرًا للاحتياج' : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('أقبل المستعمل بحالة جيدة'),
              value: _acceptsUsed,
              onChanged: (v) => setState(() => _acceptsUsed = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'جارٍ الحفظ...' : 'تسجيل الاحتياج'),
            ),
          ],
        ),
      ),
    );
  }
}
