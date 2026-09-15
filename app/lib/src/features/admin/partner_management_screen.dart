import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/partner_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import '../partners/partner_hub_v2_screen.dart' show partnerKindsV2;

class PartnerManagementScreen extends StatefulWidget {
  const PartnerManagementScreen({super.key});

  @override
  State<PartnerManagementScreen> createState() => _PartnerManagementScreenState();
}

class _PartnerManagementScreenState extends State<PartnerManagementScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  PartnerRepository get _repo => PartnerRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = _repo.adminPartners();

  String _statusLabel(String value) {
    switch (value) {
      case 'verified':
        return 'موثّق';
      case 'rejected':
        return 'مرفوض';
      case 'suspended':
        return 'موقوف';
      default:
        return 'بانتظار المراجعة';
    }
  }

  Future<String?> _noteDialog(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'ملاحظة داخلية (اختياري)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('تأكيد')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _setStatus(Map<String, dynamic> row, String status) async {
    String? note;
    if (status != 'verified') {
      note = await _noteDialog(status == 'suspended' ? 'إيقاف الشريك' : 'رفض طلب الشراكة');
      if (note == null) return;
    }
    try {
      await _repo.setPartnerStatus('${row['id']}', status, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'verified' ? 'تم اعتماد شريك رحماء.' : 'تم تحديث حالة الشريك.')),
      );
      setState(_reload);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث الشريك: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شركاء رحماء')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('تعذر تحميل الشركاء. حاول مجددًا.'));
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) {
            return const Center(child: Text('لا توجد طلبات شراكة حتى الآن.'));
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final row = rows[index];
                final status = '${row['verification_status']}';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: status == 'verified' ? RuhamaaColors.softGreen : RuhamaaColors.warmGoldSoft,
                              foregroundColor: status == 'verified' ? RuhamaaColors.primary : RuhamaaColors.warmGold,
                              child: Icon(status == 'verified' ? Icons.verified_rounded : Icons.storefront_outlined),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${row['display_name']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                  Text(partnerKindsV2['${row['partner_kind']}'] ?? '${row['partner_kind']}', style: const TextStyle(color: RuhamaaColors.textMuted)),
                                ],
                              ),
                            ),
                            Chip(label: Text(_statusLabel(status))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (row['description'] != null) Text('${row['description']}', style: const TextStyle(height: 1.45)),
                        const SizedBox(height: 7),
                        Text('سعة تقريبية: ${row['monthly_case_capacity']} حالات/شهر', style: const TextStyle(color: RuhamaaColors.textMuted)),
                        if (row['contact_phone'] != null)
                          Text('تواصل خاص للتحقق: ${row['contact_phone']}', style: const TextStyle(color: RuhamaaColors.textMuted)),
                        const SizedBox(height: 14),
                        if (status == 'pending' || status == 'rejected')
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _setStatus(row, 'rejected'),
                                  child: const Text('رفض'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: () => _setStatus(row, 'verified'),
                                  icon: const Icon(Icons.verified_user_outlined),
                                  label: const Text('اعتماد كشريك'),
                                ),
                              ),
                            ],
                          )
                        else if (status == 'verified')
                          OutlinedButton.icon(
                            onPressed: () => _setStatus(row, 'suspended'),
                            icon: const Icon(Icons.pause_circle_outline_rounded),
                            label: const Text('إيقاف الشريك وعروضه'),
                          )
                        else if (status == 'suspended')
                          FilledButton.icon(
                            onPressed: () => _setStatus(row, 'verified'),
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('إعادة تفعيل الشريك'),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
