import 'package:supabase_flutter/supabase_flutter.dart';

class StaffReportSummary {
  const StaffReportSummary({
    required this.donations,
    required this.needs,
    required this.deliveries,
    required this.delivered,
    required this.deliverySuccessRate,
    required this.avgDeliveryHours,
    required this.verifiedContributionsYer,
    required this.pendingContributions,
    required this.operatingExpensesYer,
    required this.contributionCoverageRate,
    required this.activeCouriers,
    this.openRiskFlags,
  });

  final int donations;
  final int needs;
  final int deliveries;
  final int delivered;
  final double deliverySuccessRate;
  final double avgDeliveryHours;
  final int verifiedContributionsYer;
  final int pendingContributions;
  final int operatingExpensesYer;
  final double contributionCoverageRate;
  final int activeCouriers;
  final int? openRiskFlags;

  int get costPerDeliveredYer => delivered == 0 ? 0 : (operatingExpensesYer / delivered).round();
  int get operatingGapYer => operatingExpensesYer > verifiedContributionsYer ? operatingExpensesYer - verifiedContributionsYer : 0;
  int get operatingSurplusYer => verifiedContributionsYer > operatingExpensesYer ? verifiedContributionsYer - operatingExpensesYer : 0;

  static int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  static double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  factory StaffReportSummary.fromJson(Map<String, dynamic> json) => StaffReportSummary(
        donations: _int(json['donations']),
        needs: _int(json['needs']),
        deliveries: _int(json['deliveries']),
        delivered: _int(json['delivered']),
        deliverySuccessRate: _double(json['delivery_success_rate']),
        avgDeliveryHours: _double(json['avg_delivery_hours']),
        verifiedContributionsYer: _int(json['verified_contributions_yer']),
        pendingContributions: _int(json['pending_contributions']),
        operatingExpensesYer: _int(json['operating_expenses_yer']),
        contributionCoverageRate: _double(json['contribution_coverage_rate']),
        activeCouriers: _int(json['active_couriers']),
        openRiskFlags: json['open_risk_flags'] == null ? null : _int(json['open_risk_flags']),
      );
}

class ReportRepository {
  ReportRepository(this._client);
  final SupabaseClient _client;

  Future<StaffReportSummary> summary({required DateTime from, required DateTime to, String? areaId}) async {
    final result = await _client.rpc('staff_report_summary', params: {
      'p_from': _date(from),
      'p_to': _date(to),
      'p_area_id': areaId,
    });
    return StaffReportSummary.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<List<Map<String, dynamic>>> daily({required DateTime from, required DateTime to, String? areaId}) async {
    final result = await _client.rpc('staff_report_daily', params: {
      'p_from': _date(from),
      'p_to': _date(to),
      'p_area_id': areaId,
    });
    return (result as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> couriers({required DateTime from, required DateTime to, String? areaId}) async {
    final result = await _client.rpc('staff_report_couriers', params: {
      'p_from': _date(from),
      'p_to': _date(to),
      'p_area_id': areaId,
    });
    return (result as List).cast<Map<String, dynamic>>();
  }

  Future<void> addExpense({required String areaId, required DateTime date, required String category, required int amountYer, String? description}) async {
    await _client.rpc('admin_add_operating_expense', params: {
      'p_area_id': areaId,
      'p_expense_date': _date(date),
      'p_category': category,
      'p_amount_yer': amountYer,
      'p_description': description,
    });
  }

  String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
