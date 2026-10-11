import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/admin_repository.dart';

class DeliveryAssignmentScreen extends StatefulWidget {
  const DeliveryAssignmentScreen({super.key, this.matchId, this.deliveryId})
      : assert((matchId == null) != (deliveryId == null));

  final String? matchId;
  final String? deliveryId;

  @override
  State<DeliveryAssignmentScreen> createState() => _DeliveryAssignmentScreenState();
}

class _DeliveryAssignmentScreenState extends State<DeliveryAssignmentScreen> {
  List<Map<String, dynamic>> _couriers = const [];
  List<Map<String, dynamic>> _vehicles = const [];
  String? _courierId;
  String? _vehicleId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = AdminRepository(Supabase.instance.client);
      final results = await Future.wait([
        repo.activeCouriers(),
        repo.activeVehicles(),
      ]);
      if (!mounted) return;
      setState(() {
        _couriers = results[0];
        _vehicles = results[1];
        _courierId = _couriers.isEmpty ? null : _couriers.first['user_id'] as String;
        _vehicleId = _vehicles.isEmpty ? null : _vehicles.first['id'] as String;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل المندوبين والدراجات: $e')));
    }
  }

  Future<void> _assign() async {
    if (_courierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد مندوب نشط متاح.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = AdminRepository(Supabase.instance.client);
      if (widget.deliveryId != null) {
        await repo.reassignDelivery(
          deliveryId: widget.deliveryId!,
          courierId: _courierId!,
          vehicleId: _vehicleId,
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تم إسناد المهمة من جديد'),
            content: const Text('وصلت المهمة إلى الموصل الجديد، وسيقبلها أو يعتذر عنها من حسابه.'),
            actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم'))],
          ),
        );
        if (mounted) Navigator.pop(context, true);
        return;
      }
      final result = await repo.createDelivery(
        matchId: widget.matchId!, courierId: _courierId!, vehicleId: _vehicleId,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تم إنشاء مهمة التوصيل'),
          content: Text('رقم العملية: ${result['public_code']}\n\nوصلت المهمة إلى الموصل، وسيقبلها أو يعتذر عنها. بعد القبول تظهر له بيانات الاستلام اللازمة.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم'))],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء مهمة التوصيل: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.deliveryId == null ? 'إسناد التوصيل' : 'إعادة إسناد التوصيل')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _courierId,
                  decoration: const InputDecoration(labelText: 'المندوب'),
                  items: _couriers.map((row) {
                    final profile = row['profiles'] as Map<String, dynamic>?;
                    final name = profile?['full_name'] as String? ?? 'مندوب';
                    return DropdownMenuItem(value: row['user_id'] as String, child: Text(name));
                  }).toList(),
                  onChanged: (value) => setState(() => _courierId = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _vehicleId,
                  decoration: const InputDecoration(labelText: 'الدراجة'),
                  items: _vehicles.map((row) => DropdownMenuItem(value: row['id'] as String, child: Text('${row['code']}'))).toList(),
                  onChanged: (value) => setState(() => _vehicleId = value),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving || _courierId == null ? null : _assign,
                  child: Text(_saving ? 'جارٍ الإسناد...' : widget.deliveryId == null ? 'إرسال المهمة للموصل' : 'إعادة إسناد المهمة'),
                ),
              ],
            ),
    );
  }
}
