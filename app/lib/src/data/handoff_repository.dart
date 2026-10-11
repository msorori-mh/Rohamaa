import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/handoff_pin_rules.dart';

class UserHandoff {
  const UserHandoff({
    required this.deliveryId,
    required this.deliveryCode,
    required this.kind,
    required this.itemCode,
    required this.itemType,
    required this.status,
  });

  final String deliveryId;
  final String deliveryCode;
  final String kind;
  final String itemCode;
  final String itemType;
  final String status;

  factory UserHandoff.fromJson(Map<String, dynamic> json) => UserHandoff(
        deliveryId: json['delivery_id'] as String,
        deliveryCode: json['delivery_code'] as String,
        kind: json['handoff_kind'] as String,
        itemCode: json['item_code'] as String,
        itemType: json['item_type'] as String,
        status: json['delivery_status'] as String,
      );
}

class HandoffRepository {
  HandoffRepository(this._client);
  final SupabaseClient _client;

  Future<List<UserHandoff>> myHandoffs() async {
    final rows = await _client.rpc('user_my_handoffs');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(UserHandoff.fromJson)
        .toList();
  }

  /// PINs issued during this app run. The server stores only a hash, so the
  /// app keeps the plain PIN in memory to show the same one until it expires.
  static final Map<String, IssuedHandoffPin> _issuedPins = <String, IssuedHandoffPin>{};

  String _pinKey(String deliveryId, String kind) =>
      '${_client.auth.currentUser?.id}:$deliveryId:$kind';

  /// The PIN already issued for this handoff when it is still valid.
  IssuedHandoffPin? activePin({required String deliveryId, required String kind, DateTime? now}) {
    final key = _pinKey(deliveryId, kind);
    final pin = _issuedPins[key];
    if (pin == null) return null;
    if (HandoffPinRules.isExpired(pin, now ?? DateTime.now())) {
      _issuedPins.remove(key);
      return null;
    }
    return pin;
  }

  /// Asks the server for a new PIN. This invalidates any earlier PIN.
  Future<IssuedHandoffPin> issueNewPin({required String deliveryId, required String kind}) async {
    // Taken before the request so the local countdown never outlives the
    // server-side expiry.
    final requestedAt = DateTime.now();
    final result = await _client.rpc('user_issue_handoff_pin', params: {
      'p_delivery_id': deliveryId,
      'p_kind': kind,
    });
    final issued = IssuedHandoffPin(pin: '$result', issuedAt: requestedAt);
    _issuedPins[_pinKey(deliveryId, kind)] = issued;
    return issued;
  }

  /// Returns the still-valid PIN, or issues one when there is none.
  Future<IssuedHandoffPin> currentOrNewPin({required String deliveryId, required String kind}) async {
    final existing = activePin(deliveryId: deliveryId, kind: kind);
    if (existing != null) return existing;
    return issueNewPin(deliveryId: deliveryId, kind: kind);
  }

  /// Forgets cached PINs, e.g. when the person signs out.
  static void clearIssuedPins() => _issuedPins.clear();
}
