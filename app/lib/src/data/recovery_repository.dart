import 'package:supabase_flutter/supabase_flutter.dart';

class WarehouseItem {
  const WarehouseItem({required this.id,required this.code,required this.name,required this.active});
  final String id; final String code; final String name; final bool active;
  factory WarehouseItem.fromJson(Map<String,dynamic> json)=>WarehouseItem(id:'${json['id']}',code:'${json['code']}',name:'${json['name']}',active:json['active']==true);
}

class IntakeCandidate {
  const IntakeCandidate({required this.id,required this.code,required this.itemType,required this.condition});
  final String id; final String code; final String itemType; final String condition;
  factory IntakeCandidate.fromJson(Map<String,dynamic> json)=>IntakeCandidate(id:'${json['donation_id']}',code:'${json['public_code']}',itemType:'${json['item_type']}',condition:'${json['condition']??''}');
}

class InventoryQueueItem {
  const InventoryQueueItem({required this.id,required this.code,required this.donationCode,required this.itemType,required this.warehouseName,required this.binLocation,required this.grade,required this.status,this.workOrderId,this.workOrderStatus,this.recyclingId});
  final String id; final String code; final String donationCode; final String itemType; final String warehouseName; final String binLocation; final String grade; final String status; final String? workOrderId; final String? workOrderStatus; final String? recyclingId;
  factory InventoryQueueItem.fromJson(Map<String,dynamic> json)=>InventoryQueueItem(
    id:'${json['inventory_item_id']}',code:'${json['inventory_code']}',donationCode:'${json['donation_code']}',itemType:'${json['item_type']}',warehouseName:'${json['warehouse_name']}',binLocation:'${json['bin_location']??''}',grade:'${json['grade']??''}',status:'${json['status']}',
    workOrderId:json['work_order_id'] as String?,workOrderStatus:json['work_order_status'] as String?,recyclingId:json['recycling_id'] as String?,
  );
}

class RecoverySummary {
  const RecoverySummary({required this.awaitingInspection,required this.cleaning,required this.repairing,required this.ready,required this.recycled,required this.repairCostYer,required this.recyclingProceedsYer});
  final int awaitingInspection; final int cleaning; final int repairing; final int ready; final int recycled; final int repairCostYer; final int recyclingProceedsYer;
  static int _int(dynamic value)=>value is num?value.toInt():int.tryParse('$value')??0;
  factory RecoverySummary.fromJson(Map<String,dynamic> json)=>RecoverySummary(awaitingInspection:_int(json['awaiting_inspection']),cleaning:_int(json['cleaning']),repairing:_int(json['repairing']),ready:_int(json['ready']),recycled:_int(json['recycled']),repairCostYer:_int(json['repair_cost_yer']),recyclingProceedsYer:_int(json['recycling_proceeds_yer']));
}

class RecoveryRepository {
  RecoveryRepository(this._client); final SupabaseClient _client;
  Future<List<WarehouseItem>> warehouses() async { final rows=await _client.from('warehouses').select('id,code,name,active').order('created_at'); return (rows as List).cast<Map<String,dynamic>>().map(WarehouseItem.fromJson).toList(); }
  Future<void> createWarehouse({required String code,required String name,String? addressNote}) async {
    await _client.rpc('admin_create_warehouse',params:{'p_code':code,'p_name':name,'p_address_note':addressNote});
  }
  Future<List<IntakeCandidate>> intakeCandidates() async { final rows=await _client.rpc('admin_inventory_intake_candidates'); return (rows as List).cast<Map<String,dynamic>>().map(IntakeCandidate.fromJson).toList(); }
  Future<List<InventoryQueueItem>> queue() async { final rows=await _client.rpc('admin_inventory_queue'); return (rows as List).cast<Map<String,dynamic>>().map(InventoryQueueItem.fromJson).toList(); }
  Future<RecoverySummary> summary() async => RecoverySummary.fromJson((await _client.rpc('admin_inventory_summary')) as Map<String,dynamic>);
  Future<List<AdminRecoveryPriorityItem>> priorities() async { final rows=await _client.rpc('admin_recovery_priorities',params:{'p_limit':50}); return (rows as List).cast<Map<String,dynamic>>().map(AdminRecoveryPriorityItem.fromJson).toList(); }
  Future<void> receive({required String donationId,required String warehouseId,String? binLocation}) async { await _client.rpc('admin_receive_inventory_item',params:{'p_donation_id':donationId,'p_warehouse_id':warehouseId,'p_bin_location':binLocation}); }
  Future<void> inspect({required String inventoryId,required String grade,String? note,int? estimatedCostYer}) async { await _client.rpc('admin_inspect_inventory_item',params:{'p_inventory_item_id':inventoryId,'p_grade':grade,'p_note':note,'p_estimated_cost_yer':estimatedCostYer}); }
  Future<void> advanceWork({required String workOrderId,required String action,int? actualCostYer,String? note}) async { await _client.rpc('admin_advance_item_work_order',params:{'p_work_order_id':workOrderId,'p_action':action,'p_actual_cost_yer':actualCostYer,'p_note':note}); }
  Future<void> confirmRecycling({required String recyclingId,String? materialType,double? weightKg,int? proceedsYer,String? note}) async { await _client.rpc('admin_confirm_item_recycling',params:{'p_recycling_id':recyclingId,'p_material_type':materialType,'p_weight_kg':weightKg,'p_proceeds_yer':proceedsYer,'p_note':note}); }
}

class AdminRecoveryPriorityItem {
  const AdminRecoveryPriorityItem({required this.key,required this.kind,required this.id,required this.code,required this.title,required this.subtitle,required this.priority,required this.ageHours,required this.actionKey});
  final String key; final String kind; final String id; final String code; final String title; final String subtitle; final int priority; final double ageHours; final String actionKey;
  factory AdminRecoveryPriorityItem.fromJson(Map<String,dynamic> json)=>AdminRecoveryPriorityItem(key:'${json['queue_key']}',kind:'${json['queue_kind']}',id:'${json['entity_id']}',code:'${json['public_code']}',title:'${json['title']}',subtitle:'${json['subtitle']}',priority:(json['priority'] as num).toInt(),ageHours:(json['age_hours'] as num).toDouble(),actionKey:'${json['action_key']}');
}
