/// Arabic labels and small validation rules shared by the staff screens
/// (admin, supervisor). Pure Dart so they can be unit-tested.
abstract final class StaffLabels {
  static const roles = <String, String>{
    'user': 'مستخدم',
    'courier': 'موصل',
    'supervisor': 'مشرف',
    'admin': 'مدير',
  };

  static String roleLabel(String? role) => roles[role] ?? 'دور غير معروف';

  /// Roles `admin_set_user_role` accepts (additional admins are disabled).
  static const assignableRoles = <String>['user', 'courier', 'supervisor'];

  static const needStatuses = <String, String>{
    'submitted': 'طلب جديد',
    'waiting': 'بانتظار تبرع مناسب',
    'candidate_found': 'وُجد تبرع مرشح',
    'confirmed': 'تمت المراجعة',
    'matched': 'تمت المطابقة',
    'delivery_scheduled': 'تم ترتيب التسليم',
    'fulfilled': 'تمت التلبية',
    'cancelled': 'ملغى',
    'expired': 'منتهي',
  };

  static String needStatusLabel(String? status) =>
      needStatuses[status] ?? 'حالة غير معروفة';

  /// Statuses `admin_publish_need_discovery_card` accepts.
  static const publishableNeedStatuses = {'submitted', 'waiting'};

  static bool canPublishNeed(String? status) =>
      publishableNeedStatuses.contains(status);

  static const donationStatuses = <String, String>{
    'draft': 'مسودة',
    'submitted': 'تبرع جديد',
    'under_review': 'قيد الفحص',
    'available': 'جاهز للمطابقة',
    'matched': 'تمت المطابقة',
    'pickup_scheduled': 'تم ترتيب الاستلام',
    'picked_up': 'استلمه الموصل',
    'out_for_delivery': 'في الطريق للتسليم',
    'delivered': 'تم التسليم',
    'cancelled': 'ملغى',
    'rejected': 'مرفوض',
  };

  static String donationStatusLabel(String? status) =>
      donationStatuses[status] ?? 'حالة غير معروفة';

  static const donationConditions = <String, String>{
    'new': 'جديد',
    'excellent': 'ممتاز',
    'good': 'جيد',
    'minor_repair': 'يحتاج إصلاحًا بسيطًا',
  };

  static String donationConditionLabel(String? condition) {
    if (condition == null || condition.isEmpty) return '';
    return donationConditions[condition] ?? condition;
  }

  static const incidentStatuses = <String, String>{
    'open': 'بلاغ جديد',
    'reviewing': 'قيد المراجعة',
    'resolved': 'تمت المعالجة',
    'dismissed': 'أُغلق دون إجراء',
  };

  static String incidentStatusLabel(String? status) =>
      incidentStatuses[status] ?? 'حالة غير معروفة';

  static const incidentTypes = <String, String>{
    'unexpected_charge': 'طلب مبلغ غير متفق عليه',
    'privacy': 'مشكلة خصوصية',
    'photo_marketing': 'تصوير أو تسويق',
    'no_show': 'عدم الحضور',
    'conduct': 'سلوك غير مناسب',
    'quality': 'مشكلة في التنفيذ',
    'other': 'أخرى',
  };

  static String incidentTypeLabel(String? type) =>
      incidentTypes[type] ?? 'نوع آخر';

  static const partnerStatuses = <String, String>{
    'pending': 'بانتظار المراجعة',
    'verified': 'موثّق',
    'rejected': 'مرفوض',
    'suspended': 'موقوف',
  };

  static String partnerStatusLabel(String? status) =>
      partnerStatuses[status] ?? 'بانتظار المراجعة';

  static const deletionStatuses = <String, String>{
    'pending': 'بانتظار القرار',
    'processing': 'قيد التنفيذ',
    'completed': 'تم الحذف',
    'rejected': 'مرفوض',
  };

  static String deletionStatusLabel(String? status) =>
      deletionStatuses[status] ?? 'حالة غير معروفة';

  /// Only pending requests can be decided; a request stuck in `processing`
  /// may be retried.
  static bool canDecideDeletion(String? status) =>
      status == 'pending' || status == 'processing';

  /// Courier confirmation on a cash contribution, as seen by the admin.
  static String courierReceiptLabel(Object? received) {
    if (received == true) return 'أكد الموصل استلام المبلغ';
    if (received == false) return 'أفاد الموصل بأن المبلغ لم يُستلم';
    return 'لم يؤكد الموصل الاستلام بعد';
  }

  /// Error codes returned by the staff Edge Functions (`admin-create-staff`,
  /// `staff-change-password`, `admin-delete-account`).
  static const functionErrors = <String, String>{
    'unauthorized': 'انتهت الجلسة. سجّل الدخول من جديد.',
    'admin_required': 'هذا الإجراء متاح للإدارة فقط.',
    'staff_required': 'هذا الإجراء متاح لفريق عطاء فقط.',
    'invalid_json': 'البيانات المرسلة غير صالحة.',
    'invalid_email': 'البريد الإلكتروني غير صحيح.',
    'reserved_email': 'هذا البريد محجوز ولا يمكن استخدامه.',
    'email_exists': 'هذا البريد مستخدم مسبقًا.',
    'full_name_required': 'أدخل الاسم الكامل.',
    'invalid_role': 'الدور المختار غير مسموح.',
    'area_required': 'اختر منطقة واحدة على الأقل.',
    'invalid_area': 'المنطقة المختارة غير مفعّلة.',
    'create_user_failed':
        'لم يُنشأ الحساب. تحقق من أن البريد غير مستخدم ثم حاول مجددًا.',
    'staff_setup_failed': 'لم يكتمل إعداد الحساب ولم يُحفظ. حاول مجددًا.',
    'password_too_short': 'كلمة المرور قصيرة جدًا.',
    'password_not_complex':
        'كلمة المرور يجب أن تحتوي حرفًا كبيرًا وصغيرًا ورقمًا ورمزًا.',
    'password_unchanged': 'اختر كلمة مرور مختلفة عن الحالية.',
    'current_password_required': 'أدخل كلمة المرور الحالية.',
    'current_password_invalid': 'كلمة المرور الحالية غير صحيحة.',
    'password_update_failed': 'لم تتغير كلمة المرور. حاول مجددًا.',
    'profile_update_failed': 'تغيّرت كلمة المرور لكن لم يُحدَّث الحساب.',
    'request_not_found': 'طلب الحذف غير موجود.',
    'request_not_pending': 'تمت معالجة هذا الطلب مسبقًا.',
    'open_operations': 'للحساب عمليات جارية يجب إغلاقها قبل الحذف.',
    'method_not_allowed': 'الطلب غير مدعوم.',
  };

  /// Arabic copy for an Edge Function error code, or null when unknown.
  static String? functionErrorLabel(String? code) =>
      code == null ? null : functionErrors[code];

  /// Extracts the `error` code from an Edge Function error payload, which is
  /// a decoded JSON map (`{error: code, message: ...}`) or a plain string.
  static String? functionErrorCode(Object? details) {
    if (details is Map) {
      final code = details['error'];
      if (code is String && code.isNotEmpty) return code;
      return null;
    }
    if (details is String) {
      final match = RegExp(r'"error"\s*:\s*"([a-z_]+)"').firstMatch(details);
      return match?.group(1);
    }
    return null;
  }

  /// Same rules as the `admin-create-staff` function, for inline validation.
  static String? staffPasswordError(String? value) {
    final v = value ?? '';
    if (v.length < 8) return 'استخدم 8 أحرف على الأقل';
    if (!RegExp(r'[a-z]').hasMatch(v) ||
        !RegExp(r'[A-Z]').hasMatch(v) ||
        !RegExp(r'[0-9]').hasMatch(v) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(v)) {
      return 'أضف حرفًا كبيرًا وصغيرًا ورقمًا ورمزًا';
    }
    return null;
  }

  /// Same pattern as `admin_create_service_area`.
  static String? areaCodeError(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (v.length < 2) return 'أدخل كودًا من حرفين على الأقل';
    if (!RegExp(r'^[A-Z0-9_-]{2,30}$').hasMatch(v)) {
      return 'استخدم أحرفًا إنجليزية وأرقامًا و _ أو - فقط';
    }
    return null;
  }
}
