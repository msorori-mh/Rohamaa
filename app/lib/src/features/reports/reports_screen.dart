import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/report_repository.dart';
import '../../data/staff_repository.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _from;
  late DateTime _to;
  String? _areaId;
  String _role = 'user';
  List<Map<String, dynamic>> _areas = const [];
  StaffReportSummary? _summary;
  CommunityImpactSummary? _impact;
  List<Map<String, dynamic>> _daily = const [];
  List<Map<String, dynamic>> _couriers = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day);
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final staff = StaffRepository(Supabase.instance.client);
      final status = await staff.myStatus();
      final areas = await staff.reportAreas();
      if (!mounted) return;
      setState(() {
        _role = status.role;
        _areas = areas;
        if (_role == 'supervisor' && areas.length == 1) _areaId = areas.first['id'] as String;
      });
      await _reload();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _reload() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ReportRepository(Supabase.instance.client);
      final results = await Future.wait<dynamic>([
        repo.summary(from: _from, to: _to, areaId: _areaId),
        repo.communityImpact(from: _from, to: _to, areaId: _areaId),
        repo.daily(from: _from, to: _to, areaId: _areaId),
        repo.couriers(from: _from, to: _to, areaId: _areaId),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as StaffReportSummary;
        _impact = results[1] as CommunityImpactSummary;
        _daily = (results[2] as List).cast<Map<String, dynamic>>();
        _couriers = (results[3] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2026),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range == null) return;
    setState(() { _from = range.start; _to = range.end; });
    await _reload();
  }

  Future<void> _addExpense() async {
    if (_areas.isEmpty) return;
    final category = TextEditingController();
    final amount = TextEditingController();
    final description = TextEditingController();
    String selectedArea = _areaId ?? _areas.first['id'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة مصروف تشغيلي'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedArea,
                    decoration: const InputDecoration(labelText: 'المدينة / المنطقة'),
                    items: _areas.map((a) => DropdownMenuItem(value: a['id'] as String, child: Text('${a['name_ar']}'))).toList(),
                    onChanged: (v) => setDialogState(() => selectedArea = v ?? selectedArea),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: category, decoration: const InputDecoration(labelText: 'التصنيف', hintText: 'راتب، صيانة، شحن، اتصالات...')),
                  const SizedBox(height: 12),
                  TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ بالريال')),
                  const SizedBox(height: 12),
                  TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظات اختيارية')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final amountValue = int.tryParse(amount.text.trim());
      if (category.text.trim().isEmpty || amountValue == null || amountValue <= 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل التصنيف والمبلغ بشكل صحيح')));
      } else {
        await ReportRepository(Supabase.instance.client).addExpense(
          areaId: selectedArea,
          date: DateTime.now(),
          category: category.text.trim(),
          amountYer: amountValue,
          description: description.text.trim(),
        );
        await _reload();
      }
    }
    category.dispose(); amount.dispose(); description.dispose();
  }

  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  double _double(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String _money(int value) {
    final negative = value < 0;
    final s = value.abs().toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return '${negative ? '-' : ''}${out.toString()} ريال';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير الأساسية'),
        actions: [if (_role == 'admin') IconButton(tooltip: 'إضافة مصروف', onPressed: _addExpense, icon: const Icon(Icons.add_card_outlined))],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(onPressed: _pickRange, icon: const Icon(Icons.date_range_outlined), label: Text('${_date(_from)} ← ${_date(_to)}')),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _areaId,
                    decoration: const InputDecoration(labelText: 'النطاق'),
                    items: [
                      if (_role == 'admin') const DropdownMenuItem<String?>(value: null, child: Text('كل المناطق')),
                      ..._areas.map((a) => DropdownMenuItem<String?>(value: a['id'] as String, child: Text('${a['name_ar']}'))),
                    ],
                    onChanged: (value) async { setState(() => _areaId = value); await _reload(); },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_error != null)
              Center(child: Text('تعذر تحميل التقرير: $_error'))
            else if (_summary != null && _impact != null) ...[
              Text('الأثر المجتمعي', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric('أشياء وصلت بنجاح', '${_impact!.deliveredItems}', Icons.inventory_2_outlined),
                  _Metric('عطاءات بتصنيف V2', '${_impact!.v2Donations}', Icons.category_outlined),
                  _Metric('احتياجات بتصنيف V2', '${_impact!.v2Needs}', Icons.fact_check_outlined),
                  _Metric('بطاقات احتياج راجعها رحماء', '${_impact!.reviewedNeedCards}', Icons.visibility_outlined),
                  _Metric('تبرعات ألهمتها البطاقات', '${_impact!.inspiredDonations}', Icons.lightbulb_outline_rounded),
                  _Metric('معدل إلهام البطاقات', '${_impact!.reviewedNeedInspirationRate.toStringAsFixed(1)}%', Icons.insights_outlined),
                  _Metric('عروض وقت ومهارة', '${_impact!.serviceOffers}', Icons.handyman_outlined),
                  _Metric('طلبات خدمات', '${_impact!.serviceRequests}', Icons.support_agent_outlined),
                  _Metric('خدمات مكتملة', '${_impact!.completedServices}', Icons.task_alt_outlined),
                  _Metric('ساعات خدمة مكتملة (تقديري)', _impact!.completedServiceHoursEstimate.toStringAsFixed(1), Icons.schedule_outlined),
                  _Metric('خدمات نفذها شركاء', '${_impact!.completedPartnerServices}', Icons.storefront_outlined),
                  _Metric('شركاء اعتمدوا خلال الفترة', '${_impact!.verifiedPartners}', Icons.verified_outlined),
                  _Metric('بلاغات خدمات', '${_impact!.serviceIncidents}', Icons.report_problem_outlined),
                  _Metric('بلاغات أُغلقت', '${_impact!.resolvedServiceIncidents}', Icons.fact_check_outlined),
                ],
              ),
              const SizedBox(height: 28),
              Text('التشغيل والتوصيل', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric('التبرعات', '${_summary!.donations}', Icons.inventory_2_outlined),
                  _Metric('الاحتياجات', '${_summary!.needs}', Icons.front_hand_outlined),
                  _Metric('التوصيلات الناجحة', '${_summary!.delivered}', Icons.check_circle_outline),
                  _Metric('نجاح التوصيل', '${_summary!.deliverySuccessRate.toStringAsFixed(1)}%', Icons.local_shipping_outlined),
                  _Metric('متوسط زمن التوصيل', '${_summary!.avgDeliveryHours.toStringAsFixed(1)} ساعة', Icons.schedule_outlined),
                  _Metric('تكلفة التوصيل المكتمل', _money(_summary!.costPerDeliveredYer), Icons.calculate_outlined),
                  _Metric('المساهمات المحققة', _money(_summary!.verifiedContributionsYer), Icons.volunteer_activism_outlined),
                  _Metric('المصروفات التشغيلية', _money(_summary!.operatingExpensesYer), Icons.receipt_long_outlined),
                  _Metric('تغطية التشغيل', '${_summary!.contributionCoverageRate.toStringAsFixed(1)}%', Icons.pie_chart_outline),
                  _Metric(_summary!.operatingGapYer > 0 ? 'الفجوة التشغيلية' : 'الفائض التشغيلي', _money(_summary!.operatingGapYer > 0 ? _summary!.operatingGapYer : _summary!.operatingSurplusYer), Icons.account_balance_wallet_outlined),
                  _Metric('مساهمات معلقة', '${_summary!.pendingContributions}', Icons.pending_actions_outlined),
                  _Metric('الموصلون النشطون', '${_summary!.activeCouriers}', Icons.delivery_dining_outlined),
                  if (_summary!.openRiskFlags != null) _Metric('مخاطر مفتوحة', '${_summary!.openRiskFlags}', Icons.shield_outlined),
                ],
              ),
              const SizedBox(height: 28),
              Text('أداء الموصلين', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('الموصل')),
                      DataColumn(label: Text('المهام')),
                      DataColumn(label: Text('تم التسليم')),
                      DataColumn(label: Text('تعثر/إعادة جدولة')),
                      DataColumn(label: Text('النجاح')),
                      DataColumn(label: Text('متوسط الساعات')),
                    ],
                    rows: _couriers.map((r) => DataRow(cells: [
                      DataCell(Text('${r['courier_name']}')),
                      DataCell(Text('${_int(r['assigned'])}')),
                      DataCell(Text('${_int(r['delivered'])}')),
                      DataCell(Text('${_int(r['unsuccessful'])}')),
                      DataCell(Text('${_double(r['success_rate']).toStringAsFixed(1)}%')),
                      DataCell(Text(_double(r['avg_delivery_hours']).toStringAsFixed(1))),
                    ])).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text('الحركة اليومية', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [DataColumn(label: Text('اليوم')), DataColumn(label: Text('تبرعات')), DataColumn(label: Text('احتياجات')), DataColumn(label: Text('تم التسليم')), DataColumn(label: Text('مساهمات'))],
                    rows: _daily.reversed.take(31).map((r) => DataRow(cells: [
                      DataCell(Text('${r['day']}')),
                      DataCell(Text('${r['donations']}')),
                      DataCell(Text('${r['needs']}')),
                      DataCell(Text('${r['delivered']}')),
                      DataCell(Text(_money(_int(r['verified_contributions_yer'])))),
                    ])).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 210,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon),
                const SizedBox(height: 12),
                Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(label),
              ],
            ),
          ),
        ),
      );
}
