import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/admin_repository.dart';

/// Assigns a courier to an accepted match ([matchId]) or reassigns an
/// existing delivery ([deliveryId]). Exactly one of them must be given.
class DeliveryAssignmentScreen extends StatefulWidget {
  const DeliveryAssignmentScreen({super.key, this.matchId, this.deliveryId})
      : assert((matchId == null) != (deliveryId == null));

  final String? matchId;
  final String? deliveryId;

  @override
  State<DeliveryAssignmentScreen> createState() =>
      _DeliveryAssignmentScreenState();
}

class _DeliveryAssignmentScreenState extends State<DeliveryAssignmentScreen> {
  /// Dropdown value for "no vehicle"; sent to the server as null.
  static const String _noVehicle = '';

  List<Map<String, dynamic>> _couriers = const [];
  List<Map<String, dynamic>> _vehicles = const [];
  String? _courierId;
  String? _vehicleId;
  bool _loading = true;
  Object? _loadError;
  bool _saving = false;

  AdminRepository get _repo => AdminRepository(Supabase.instance.client);

  bool get _isReassign => widget.deliveryId != null;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final repo = _repo;
      final results = await Future.wait([
        repo.activeCouriers(),
        repo.activeVehicles(),
      ]);
      if (!mounted) return;
      setState(() {
        _couriers = results[0];
        _vehicles = results[1];
        _courierId =
            _couriers.isEmpty ? null : _couriers.first['user_id'] as String;
        _vehicleId =
            _vehicles.isEmpty ? null : _vehicles.first['id'] as String;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  Future<void> _done(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('تم'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  /// The vehicle to send: null when "no vehicle" is selected.
  String? get _selectedVehicleId {
    final id = _vehicleId;
    return id == null || id == _noVehicle ? null : id;
  }

  Future<void> _assign() async {
    final courierId = _courierId;
    if (courierId == null || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = _repo;
      final deliveryId = widget.deliveryId;
      if (deliveryId != null) {
        await repo.reassignDelivery(
          deliveryId: deliveryId,
          courierId: courierId,
          vehicleId: _selectedVehicleId,
        );
        if (!mounted) return;
        await _done(
          'تم إسناد المهمة من جديد',
          'وصلت المهمة إلى الموصل الجديد، وسيقبلها أو يعتذر عنها من حسابه.',
        );
        return;
      }
      final result = await repo.createDelivery(
        matchId: widget.matchId!,
        courierId: courierId,
        vehicleId: _selectedVehicleId,
      );
      if (!mounted) return;
      await _done(
        'تم إنشاء مهمة التوصيل',
        'رقم العملية: ${result['public_code']}\n\n'
            'وصلت المهمة إلى الموصل، وسيقبلها أو يعتذر عنها. '
            'بعد القبول تظهر له بيانات الاستلام اللازمة.',
      );
    } catch (error) {
      if (mounted) {
        showErrorSnack(
          context,
          error,
          fallback: _isReassign
              ? 'تعذر إعادة إسناد المهمة. حدّث القائمة ثم حاول مجددًا.'
              : 'تعذر إنشاء مهمة التوصيل. حدّث القائمة ثم حاول مجددًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _form() {
    if (_couriers.isEmpty) {
      return ScrollableEmpty(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delivery_dining_outlined, size: 44),
              const SizedBox(height: 12),
              const Text(
                'لا يوجد موصل نشط الآن. أنشئ حساب موصل من «إضافة فريق» أو فعّل موصلًا من «المستخدمون والأدوار».',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحديث'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _courierId,
          decoration: const InputDecoration(labelText: 'الموصل'),
          items: _couriers.map((row) {
            final profile = row['profiles'];
            final name =
                profile is Map ? (profile['full_name'] as String?) : null;
            return DropdownMenuItem(
              value: row['user_id'] as String,
              child: Text(
                name == null || name.trim().isEmpty ? 'موصل' : name,
              ),
            );
          }).toList(),
          onChanged: _saving
              ? null
              : (value) => setState(() => _courierId = value),
        ),
        const SizedBox(height: 16),
        if (_vehicles.isEmpty)
          const Text('لا توجد دراجة مسجلة؛ ستُسند المهمة بدون دراجة محددة.')
        else
          DropdownButtonFormField<String>(
            initialValue: _vehicleId,
            decoration: const InputDecoration(labelText: 'الدراجة'),
            items: [
              for (final row in _vehicles)
                DropdownMenuItem(
                  value: row['id'] as String,
                  child: Text('${row['code']}'),
                ),
              const DropdownMenuItem(
                value: _noVehicle,
                child: Text('بدون مركبة'),
              ),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _vehicleId = value),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving || _courierId == null ? null : _assign,
          child: Text(
            _saving
                ? 'جارٍ الإسناد...'
                : _isReassign
                    ? 'إعادة إسناد المهمة'
                    : 'إرسال المهمة للموصل',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _loadError;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isReassign ? 'إعادة إسناد التوصيل' : 'إسناد التوصيل'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? ErrorRetry(error: error, onRetry: _load)
              : _form(),
    );
  }
}
