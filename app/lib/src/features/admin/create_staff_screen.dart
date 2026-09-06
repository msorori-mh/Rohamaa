import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/staff_repository.dart';

class CreateStaffScreen extends StatefulWidget {
  const CreateStaffScreen({super.key});

  @override
  State<CreateStaffScreen> createState() => _CreateStaffScreenState();
}

class _CreateStaffScreenState extends State<CreateStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'courier';
  String? _areaId;
  bool _busy = false;
  bool _obscure = true;
  late Future<List<Map<String, dynamic>>> _areasFuture;

  @override
  void initState() {
    super.initState();
    _areasFuture = StaffRepository(Supabase.instance.client).serviceAreas();
  }

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _areaId == null) return;
    setState(() => _busy = true);
    try {
      await StaffRepository(Supabase.instance.client).createStaff(
        email: _email.text,
        temporaryPassword: _password.text,
        fullName: _name.text,
        role: _role,
        areaIds: [_areaId!],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_role == 'courier' ? 'تم إنشاء حساب الموصل. سيُطلب منه تغيير كلمة المرور عند أول دخول.' : 'تم إنشاء حساب المشرف. سيُطلب منه تغيير كلمة المرور عند أول دخول.')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب فريق سند')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('أنشئ حسابًا للموصل أو مشرف مدينة/منطقة. كلمة المرور هنا مؤقتة ولا يتم حفظها في جداول التطبيق.'),
                const SizedBox(height: 20),
                SegmentedButton<String>(
                  segments: const [ButtonSegment(value: 'courier', label: Text('موصل'), icon: Icon(Icons.delivery_dining_outlined)), ButtonSegment(value: 'supervisor', label: Text('مشرف'), icon: Icon(Icons.supervisor_account_outlined))],
                  selected: {_role},
                  onSelectionChanged: (v) => setState(() => _role = v.first),
                ),
                const SizedBox(height: 20),
                TextFormField(controller: _name, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'الاسم الكامل'), validator: (v) => (v ?? '').trim().length < 2 ? 'أدخل الاسم' : null),
                const SizedBox(height: 14),
                TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'البريد الإلكتروني'), validator: (v) => !RegExp(r'^\S+@\S+\.\S+$').hasMatch((v ?? '').trim()) ? 'أدخل بريدًا صحيحًا' : null),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(labelText: 'كلمة المرور الابتدائية', helperText: '8 أحرف على الأقل. سيُجبر المستخدم على تغييرها.', suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
                  validator: (v) => (v ?? '').length < 8 ? 'استخدم 8 أحرف على الأقل' : null,
                ),
                const SizedBox(height: 14),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _areasFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) return const LinearProgressIndicator();
                    final areas = snapshot.data ?? const [];
                    if (areas.isEmpty) return const Text('لا توجد مناطق مفعلة.');
                    _areaId ??= areas.first['id'] as String;
                    return DropdownButtonFormField<String>(
                      value: _areaId,
                      decoration: const InputDecoration(labelText: 'المدينة / المنطقة'),
                      items: areas.map((a) => DropdownMenuItem(value: a['id'] as String, child: Text('${a['name_ar']}'))).toList(),
                      onChanged: (v) => setState(() => _areaId = v),
                    );
                  },
                ),
                const SizedBox(height: 26),
                FilledButton.icon(onPressed: _busy ? null : _submit, icon: const Icon(Icons.person_add_alt_1_outlined), label: Text(_busy ? 'جارٍ إنشاء الحساب...' : 'إنشاء الحساب')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
