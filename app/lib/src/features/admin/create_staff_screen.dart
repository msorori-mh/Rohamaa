import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/staff_repository.dart';
import '../../domain/staff_labels.dart';
import '../../theme/ruhamaa_theme.dart';
import 'staff_widgets.dart';

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

  /// Selected areas in selection order; the first one is the primary area.
  final List<String> _areaIds = <String>[];
  bool _areaMissing = false;
  bool _busy = false;
  bool _obscure = true;

  List<Map<String, dynamic>> _areas = const [];
  bool _areasLoading = true;
  Object? _areasError;

  StaffRepository get _repo => StaffRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _fetchAreas();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _fetchAreas() async {
    try {
      final areas = await _repo.serviceAreas();
      if (!mounted) return;
      setState(() {
        _areas = areas;
        _areasLoading = false;
        _areasError = null;
        if (_areaIds.isEmpty && areas.length == 1) {
          _areaIds.add(areas.first['id'] as String);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _areasLoading = false;
        _areasError = error;
      });
    }
  }

  Future<void> _retryAreas() async {
    setState(() {
      _areasLoading = true;
      _areasError = null;
    });
    await _fetchAreas();
  }

  void _toggleArea(String id, bool selected) {
    setState(() {
      if (selected) {
        if (!_areaIds.contains(id)) _areaIds.add(id);
      } else {
        _areaIds.remove(id);
      }
      if (_areaIds.isNotEmpty) _areaMissing = false;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final formValid = _formKey.currentState?.validate() ?? false;
    final areaValid = _areaIds.isNotEmpty;
    if (!areaValid) setState(() => _areaMissing = true);
    if (!formValid || !areaValid) return;
    final role = _role;
    setState(() => _busy = true);
    try {
      await _repo.createStaff(
        email: _email.text,
        temporaryPassword: _password.text,
        fullName: _name.text,
        role: role,
        areaIds: List<String>.of(_areaIds),
      );
      if (!mounted) return;
      showInfoSnack(
        context,
        role == 'courier'
            ? 'تم إنشاء حساب الموصل. سيُطلب منه تغيير كلمة المرور عند أول دخول.'
            : 'تم إنشاء حساب المشرف. سيُطلب منه تغيير كلمة المرور عند أول دخول.',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: staffFunctionErrorMessage(error) ??
              'تعذر إنشاء الحساب. تحقق من البيانات ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _areasSection() {
    final error = _areasError;
    if (_areasLoading) return const LinearProgressIndicator();
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(friendlyError(error)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _retryAreas,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة تحميل المناطق'),
          ),
        ],
      );
    }
    if (_areas.isEmpty) {
      return const Text(
        'لا توجد مناطق مفعلة. أضف مدينة أو منطقة من «المدن والمناطق» أولًا.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _role == 'supervisor'
              ? 'المدن / المناطق التي يشرف عليها'
              : 'المدينة / المنطقة التي يعمل فيها',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'يمكن اختيار أكثر من نطاق. أول نطاق تختاره هو النطاق الأساسي.',
          style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final area in _areas)
              FilterChip(
                label: Text('${area['name_ar']}'),
                selected: _areaIds.contains(area['id']),
                onSelected: _busy
                    ? null
                    : (selected) =>
                        _toggleArea(area['id'] as String, selected),
              ),
          ],
        ),
        if (_areaMissing)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'اختر منطقة واحدة على الأقل.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب فريق عطاء')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'أنشئ حسابًا للموصل أو مشرف مدينة/منطقة. كلمة المرور هنا مؤقتة ولا يتم حفظها في جداول التطبيق.',
                ),
                const SizedBox(height: 20),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'courier',
                      label: Text('موصل'),
                      icon: Icon(Icons.delivery_dining_outlined),
                    ),
                    ButtonSegment(
                      value: 'supervisor',
                      label: Text('مشرف'),
                      icon: Icon(Icons.supervisor_account_outlined),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: _busy
                      ? null
                      : (selection) =>
                          setState(() => _role = selection.first),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                  validator: (value) =>
                      (value ?? '').trim().length < 2 ? 'أدخل الاسم' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration:
                      const InputDecoration(labelText: 'البريد الإلكتروني'),
                  validator: (value) => !RegExp(r'^\S+@\S+\.\S+$')
                          .hasMatch((value ?? '').trim())
                      ? 'أدخل بريدًا صحيحًا'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الابتدائية',
                    helperText:
                        '8 أحرف+ وتحتوي حرفًا كبيرًا وصغيرًا ورقمًا ورمزًا. سيغيرها المستخدم عند أول دخول.',
                    helperMaxLines: 3,
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'إظهار' : 'إخفاء',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: StaffLabels.staffPasswordError,
                ),
                const SizedBox(height: 18),
                _areasSection(),
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: _busy || _areasLoading ? null : _submit,
                  icon: _busy
                      ? const InlineSpinner()
                      : const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(_busy ? 'جارٍ إنشاء الحساب...' : 'إنشاء الحساب'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
