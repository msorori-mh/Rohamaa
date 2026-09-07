import 'package:supabase_flutter/supabase_flutter.dart';

class OperationItem {
  const OperationItem({required this.kind, required this.id, required this.code, required this.title, required this.status, required this.updatedAt, required this.actionRoute, required this.requiresAction});
  final String kind;
  final String id;
  final String code;
  final String title;
  final String status;
  final DateTime updatedAt;
  final String actionRoute;
  final bool requiresAction;

  factory OperationItem.fromJson(Map<String, dynamic> json) => OperationItem(
    kind: '${json['operation_kind']}', id: '${json['operation_id']}', code: '${json['public_code']}',
    title: '${json['title']}', status: '${json['status']}',
    updatedAt: DateTime.parse('${json['updated_at']}'), actionRoute: '${json['action_route']}',
    requiresAction: json['requires_action'] == true,
  );
}

class UserNotificationItem {
  const UserNotificationItem({required this.id, required this.title, required this.body, required this.actionRoute, required this.createdAt, required this.isRead});
  final String id;
  final String title;
  final String body;
  final String actionRoute;
  final DateTime createdAt;
  final bool isRead;

  factory UserNotificationItem.fromJson(Map<String, dynamic> json) => UserNotificationItem(
    id: '${json['id']}', title: '${json['title']}', body: '${json['body']}',
    actionRoute: '${json['action_route']}', createdAt: DateTime.parse('${json['created_at']}'),
    isRead: json['read_at'] != null,
  );
}

class AdminQueueItem {
  const AdminQueueItem({required this.key, required this.kind, required this.id, required this.code, required this.title, required this.subtitle, required this.priority, required this.ageHours, required this.actionKey});
  final String key;
  final String kind;
  final String id;
  final String code;
  final String title;
  final String subtitle;
  final int priority;
  final double ageHours;
  final String actionKey;

  factory AdminQueueItem.fromJson(Map<String, dynamic> json) => AdminQueueItem(
    key: '${json['queue_key']}', kind: '${json['queue_kind']}', id: '${json['entity_id']}',
    code: '${json['public_code']}', title: '${json['title']}', subtitle: '${json['subtitle']}',
    priority: (json['priority'] as num).toInt(), ageHours: (json['age_hours'] as num).toDouble(),
    actionKey: '${json['action_key']}',
  );
}

class OperationsRepository {
  OperationsRepository(this._client);
  final SupabaseClient _client;

  Future<List<OperationItem>> myOperations() async {
    final rows = await _client.rpc('user_operations_center', params: {'p_limit': 100});
    return (rows as List).cast<Map<String, dynamic>>().map(OperationItem.fromJson).toList();
  }

  Future<List<UserNotificationItem>> myNotifications() async {
    final rows = await _client.from('user_notifications').select('id,title,body,action_route,read_at,created_at').order('created_at', ascending: false).limit(100);
    return (rows as List).cast<Map<String, dynamic>>().map(UserNotificationItem.fromJson).toList();
  }

  Future<void> markRead(String id) async {
    await _client.from('user_notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> markAllRead() async {
    await _client.from('user_notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).isFilter('read_at', null);
  }

  Future<List<AdminQueueItem>> adminQueue() async {
    final rows = await _client.rpc('admin_operations_overview', params: {'p_limit': 50});
    return (rows as List).cast<Map<String, dynamic>>().map(AdminQueueItem.fromJson).toList();
  }
}
