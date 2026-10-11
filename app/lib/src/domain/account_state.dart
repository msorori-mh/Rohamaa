/// Where the app must send a signed-in person, derived from the server's
/// `my_account_state()` row. Pure logic so it can be unit tested.
enum AccountGate {
  suspended,
  deletionProcessing,
  deleted,
  passwordChange,
  admin,
  supervisor,
  courier,
  community,
}

class AccountState {
  const AccountState({
    required this.role,
    this.isSuspended = false,
    this.forcePasswordChange = false,
    this.deletionStatus,
  });

  /// Default for a signed-in person whose profile row is not visible yet.
  static const AccountState community = AccountState(role: 'user');

  static const staffRoles = <String>{'admin', 'supervisor', 'courier'};

  final String role;
  final bool isSuspended;
  final bool forcePasswordChange;

  /// null, or one of 'pending', 'processing', 'completed', 'rejected'.
  final String? deletionStatus;

  factory AccountState.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role'];
    final rawDeletion = json['deletion_status'];
    final role = rawRole == null ? '' : '$rawRole'.trim();
    final deletion = rawDeletion == null ? '' : '$rawDeletion'.trim();
    return AccountState(
      role: role.isEmpty ? 'user' : role,
      isSuspended: json['is_suspended'] == true,
      forcePasswordChange: json['force_password_change'] == true,
      deletionStatus: deletion.isEmpty ? null : deletion,
    );
  }

  bool get isStaff => staffRoles.contains(role);

  bool get deletionPending => deletionStatus == 'pending';
  bool get deletionProcessing => deletionStatus == 'processing';
  bool get deletionCompleted => deletionStatus == 'completed';
  bool get deletionRejected => deletionStatus == 'rejected';

  /// True when the account may not use the app at all.
  bool get isBlocked => isSuspended || deletionProcessing || deletionCompleted;

  AccountGate get gate {
    // The server suspends the account while a deletion is being processed,
    // so the deletion states must be tested before the suspension flag.
    if (deletionCompleted) return AccountGate.deleted;
    if (deletionProcessing) return AccountGate.deletionProcessing;
    if (isSuspended) return AccountGate.suspended;
    if (forcePasswordChange && isStaff) return AccountGate.passwordChange;
    return switch (role) {
      'admin' => AccountGate.admin,
      'supervisor' => AccountGate.supervisor,
      'courier' => AccountGate.courier,
      _ => AccountGate.community,
    };
  }
}
