import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/contribution_repository.dart';

class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key, this.donationId, this.needId, this.deliveryId});

  final String? donationId;
  final String? needId;
  final String? deliveryId;

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  final _referenceController = TextEditingController();
  int? _amount;
  bool _saving = false;

  static const amounts = [1000, 2000, 3000, 4000, 5000];

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_amount == null) return;
    setState(() => _saving = true);
    try {
      await ContributionRepository(Supabase.instance.client).createContribution(
        amountYer: _amount!,
        paymentMethod: 'manual_transfer',
        paymentReference: _referenceController.text,
        donationId: widget.donationId,
        needId: widget.needId,
        deliveryId: widget.deliveryId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل المساهمة وبانتظار التحقق من التحويل')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تسجيل المساهمة: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المساهمة في التوصيل')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'يمكنك المساهمة في تكاليف تشغيل سند واستلام وتوصيل التبرعات. المساهمة اختيارية ولا تؤثر على أولوية الاستحقاق.',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: amounts.map((amount) {
              return ChoiceChip(
                label: Text('$amount ريال'),
                selected: _amount == amount,
                onSelected: (_) => setState(() => _amount = amount),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _referenceController,
            decoration: const InputDecoration(
              labelText: 'رقم الحوالة أو المرجع',
              helperText: 'سيتم التحقق من المرجع قبل اعتماد المساهمة.',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving || _amount == null ? null : _submit,
            child: Text(_saving ? 'جاري الحفظ...' : 'تسجيل المساهمة'),
          ),
        ],
      ),
    );
  }
}
