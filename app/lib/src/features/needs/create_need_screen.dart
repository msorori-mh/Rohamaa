import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/sanad_repository.dart';
import '../contributions/contribution_screen.dart';

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
  String _category = 'other';

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
    _reason.dispose();
    super.dispose();
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
      final needId = await repo.createNeed(
        title: _title.text.trim(),
        reason: _reason.text.trim(),
        acceptsUsed: _acceptsUsed,
        category: _category,
        addressId: await repo.defaultAddressId(),
      );
      if (!mounted) return;
      final contribute = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تم تسجيل احتياجك'),
          content: const Text('إذا رغبت، يمكنك المساهمة اختياريًا في تكلفة التوصيل عند توفر المطابقة. عدم الدفع لا يقلل أولوية طلبك.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ليس الآن')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('أساهم')),
          ],
        ),
      );
      if (!mounted) return;
      if (contribute == true) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ContributionScreen(needId: needId)));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الطلب: $e')));
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
            const Text('سجّل احتياجك فقط. لا توجد قائمة تبرعات للتصفح حفاظًا على عدالة المطابقة والخصوصية.'),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'الفئة'),
              items: categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => _category = v ?? 'other'),
            ),
            const SizedBox(height: 16),
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
