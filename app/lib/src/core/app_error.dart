import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'socket_error_stub.dart' if (dart.library.io) 'socket_error_io.dart';

/// Single place that turns low-level failures into Arabic copy a person can
/// act on. Screens must never show `$e` directly: raw messages expose table,
/// policy and URL names and are unreadable for the people using the app.
const String kGenericErrorMessage = 'تعذر إتمام العملية. حاول مرة أخرى.';
const String kOfflineErrorMessage =
    'لا يوجد اتصال بالإنترنت. تحقق من الشبكة ثم حاول مرة أخرى.';

/// Known server-side messages (raised by SQL functions, policies and Edge
/// Functions) mapped to user-facing copy.
///
/// Keys are lower-case and matched as substrings of the lower-cased server
/// text. The first matching entry wins, in the order written here, so a more
/// specific key must come before a generic one that it contains (for example
/// 'need cannot be cancelled' before 'cannot be cancelled'). Public only so
/// the unit tests can check every entry.
const Map<String, String> kServerErrorMessages = <String, String>{
  'account suspended': 'حسابك موقوف مؤقتًا. تواصل مع فريق عطاء.',
  'row-level security': 'لا تملك صلاحية تنفيذ هذا الإجراء.',
  'permission denied': 'لا تملك صلاحية تنفيذ هذا الإجراء.',
  'admin required': 'هذا الإجراء متاح للإدارة فقط.',
  'admin access required': 'هذا الإجراء متاح للإدارة فقط.',
  'active courier required': 'هذا الإجراء متاح للموصل المفعّل فقط.',
  'courier required': 'هذا الإجراء متاح للموصل المفعّل فقط.',
  'not assigned courier': 'هذه المهمة ليست مسندة إليك.',
  'delivery not assigned': 'هذه المهمة ليست مسندة إليك.',
  'delivery not found': 'تعذر العثور على مهمة التوصيل.',
  'assignment offer expired': 'انتهت مهلة قبول المهمة.',
  'assignment is no longer awaiting response': 'تم الرد على هذه المهمة مسبقًا.',
  'pin unavailable in this state': 'الرمز غير متاح في هذه المرحلة.',
  'is not ready for verification': 'المهمة ليست في مرحلة تأكيد الرمز.',
  'delivery already completed': 'اكتملت هذه العملية مسبقًا.',
  'need cannot be cancelled': 'لا يمكن إلغاء الطلب في هذه المرحلة.',
  'donation cannot be cancelled': 'لا يمكن إلغاء التبرع في هذه المرحلة.',
  'cannot be withdrawn': 'لا يمكن السحب في هذه المرحلة.',
  'donation already has an active': 'لهذا التبرع عرض أو مطابقة جارية بالفعل.',
  'pledge already answered': 'سُجّلت إجابتك عن هذه المساهمة مسبقًا ولا يمكن تعديلها.',
  'already matched': 'تمت المطابقة مسبقًا.',
  'already exists': 'هذا السجل موجود مسبقًا.',
  'duplicate key': 'هذا السجل موجود مسبقًا.',
  'cancellation reason too long': 'سبب الإلغاء أطول من المسموح. اختصره ثم حاول مجددًا.',
  'value too long': 'النص المدخل أطول من المسموح.',
  'violates check constraint': 'إحدى القيم المدخلة غير مقبولة.',
  'invalid login credentials': 'بيانات الدخول غير صحيحة.',
  'email not confirmed': 'لم يتم تأكيد البريد الإلكتروني بعد.',
  'current_password_invalid': 'كلمة المرور الحالية غير صحيحة.',
  'password_too_short': 'كلمة المرور قصيرة جدًا.',
  'password_not_complex':
      'كلمة المرور يجب أن تحتوي حرفًا كبيرًا وصغيرًا ورقمًا ورمزًا.',
  'password_unchanged': 'اختر كلمة مرور مختلفة عن الحالية.',
  'email_exists': 'هذا البريد مستخدم مسبقًا.',
  'already been registered': 'هذا البريد مستخدم مسبقًا.',
  'payload too large': 'حجم الملف أكبر من المسموح.',
  'mime type': 'نوع الملف غير مدعوم. استخدم صورة JPG أو PNG أو WebP.',
  'jwt expired': 'انتهت الجلسة. سجّل الدخول من جديد.',
  'refresh token': 'انتهت الجلسة. سجّل الدخول من جديد.',
  'session_not_found': 'انتهت الجلسة. سجّل الدخول من جديد.',
  'authentication required': 'سجّل الدخول أولًا ثم حاول مرة أخرى.',
  'unauthorized': 'انتهت الجلسة. سجّل الدخول من جديد.',
  'staff_required': 'هذا الإجراء متاح لفريق عطاء فقط.',
  'current_password_required': 'أدخل كلمة المرور الحالية.',
  'should be different': 'اختر كلمة مرور مختلفة عن الحالية.',
  'password_update_failed': 'تعذر تغيير كلمة المرور. اختر كلمة مرور أخرى وحاول مجددًا.',
  'profile_update_failed': 'تم تغيير كلمة المرور. سجّل الدخول بها من جديد.',
  'too_many_attempts': 'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.',
  'verification_failed': 'لم نتمكن من التحقق من كلمة المرور الحالية الآن. حاول مرة أخرى بعد قليل.',
  'account is not active': 'حسابك غير مفعّل حاليًا. تواصل مع فريق عطاء.',
  'staff accounts must be managed':
      'حسابات فريق عطاء تُدار من الإدارة. تواصل مع مدير عطاء.',
  'workflow state is server controlled': 'لا يمكن تعديل هذه الحالة من التطبيق.',
  'not pickup owner': 'هذه العملية لا تخص حسابك.',
  'not delivery owner': 'هذه العملية لا تخص حسابك.',
  'not offer owner': 'هذا العرض لا يخص حسابك.',
  'offer unavailable': 'لم يعد هذا العرض متاحًا.',
  'need unavailable': 'لم يعد هذا الطلب متاحًا للمطابقة.',
  'service match is not active': 'هذه المطابقة لم تعد نشطة.',
  'both participants must accept': 'يجب أن يوافق الطرفان قبل تحديد الموعد.',
  'scheduled time is required': 'حدّد موعد الخدمة أولًا.',
  'self service matching is not allowed': 'لا يمكن مطابقة خدمة وطلب يعودان للحساب نفسه.',
  'service offer is not approved': 'هذه الخدمة لم تُعتمد بعد.',
  'service request is not open': 'طلب الخدمة لم يعد مفتوحًا.',
  'not awaiting response': 'تم الرد على هذا العرض مسبقًا.',
  'not a participant': 'هذه العملية لا تخص حسابك.',
  'cannot be cancelled': 'لا يمكن الإلغاء في هذه المرحلة.',
  'no pending': 'لا يوجد طلب قيد الانتظار يمكن إلغاؤه.',
  'rate limit': 'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.',
  'too many requests': 'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.',
  'account deletion in progress': 'يجري حذف هذا الحساب، ولا يمكن تعديل حالته الآن.',
  'delivery in progress': 'لدى الحساب عملية توصيل جارية. انتظر اكتمالها أولًا.',
  'delivery_in_progress': 'لدى الحساب عملية توصيل جارية. انتظر اكتمالها أولًا.',
  'failure cannot be reported in this state': 'لا يمكن الإبلاغ عن تعذر في هذه المرحلة.',
  'invalid party for this phase': 'هذا الطرف لا يناسب مرحلة المهمة الحالية. اختر طرفًا آخر.',
  'pause reason required': 'اكتب سبب إيقاف المهمة.',
  'delivery cannot be paused': 'لا يمكن إيقاف المهمة في هذه المرحلة.',
  'collected item cannot change courier': 'استُلم الشيء فعلًا، ولا يمكن نقل المهمة إلى موصل آخر بهذه الطريقة.',
  'vehicle inactive': 'المركبة المختارة غير مفعّلة. اختر مركبة أخرى أو بدون مركبة.',
  'courier reported cash not received': 'أفاد الموصل بأن المبلغ لم يُستلم، فلا يمكن اعتماد المساهمة.',
  'delivery is already closed': 'هذه المهمة مغلقة.',
  'pledge is not awaiting': 'هذه المساهمة لم تعد بانتظار التأكيد.',
  'pledge is not linked': 'هذه المساهمة لا تخص مهمتك.',
  'cancellation reason required': 'اكتب سبب الإلغاء.',
  'temp_password_expired': 'انتهت صلاحية كلمة المرور المؤقتة. اطلب من الإدارة إعادة تعيين كلمة المرور.',
  'password_too_long': 'كلمة المرور طويلة جدًا.',
  'session_revoke_failed': 'لم يكتمل الطلب. حاول مرة أخرى.',
  'request_not_open': 'هذا الطلب لم يعد مفتوحًا.',
  'request_not_pending': 'هذا الطلب لم يعد قيد الانتظار.',
  'request_not_found': 'تعذر العثور على الطلب.',
  'request_not_processing': 'هذا الطلب ليس قيد التنفيذ. حدّث القائمة.',
  'storage_cleanup_failed': 'لم يكتمل حذف صور الحساب. إعادة المحاولة آمنة وتكمل من حيث توقف الحذف.',
  'storage_cleanup': 'تعذر حذف صور الحساب. أعد المحاولة.',
  'auth_delete_failed': 'لم يكتمل حذف بيانات الدخول. إعادة المحاولة آمنة وتكمل من حيث توقف الحذف.',
  'prepare_failed': 'لم يبدأ حذف الحساب. إعادة المحاولة آمنة.',
  'complete_failed': 'نُفّذ الحذف لكن لم يُغلق الطلب. إعادة المحاولة آمنة وتغلقه.',
  'cannot_delete_self': 'لا يمكنك حذف حسابك الإداري من هنا.',
  'staff_account': 'حسابات الفريق لا تُحذف من هذه الشاشة.',
  'courier inactive': 'الموصل غير مفعّل.',
  'match must be accepted first': 'يجب قبول العرض قبل إنشاء مهمة التوصيل.',
  'delivery cannot be reassigned': 'لا يمكن إعادة إسناد المهمة في هذه المرحلة.',
  'delivery is not ready for dropoff': 'المهمة ليست جاهزة للتسليم بعد.',
  'valid rejection reason required': 'اختر سبب الاعتذار.',
  'contribution is no longer pending': 'تمت مراجعة هذه المساهمة مسبقًا.',
  'while a match offer': 'لا يمكن نشر الطلب ما دام له عرض أو تسليم جارٍ.',
  'need is not eligible': 'هذا الطلب غير مؤهل للنشر الآن.',
  'need not eligible': 'هذا الطلب غير مؤهل للنشر الآن.',
  'maximum number of public need cards': 'بلغ الحساب الحد الأقصى من البطاقات المعروضة.',
  'cannot suspend self': 'لا يمكنك إيقاف حسابك.',
  'admin cannot remove own admin role': 'لا يمكنك إزالة دور الإدارة عن حسابك.',
  'primary admin role cannot be changed': 'لا يمكن تغيير دور المدير الرئيسي.',
  'creating additional admins is disabled': 'إنشاء مديرين إضافيين غير متاح.',
  'area has assigned staff': 'النطاق مرتبط بأعضاء من الفريق.',
  'invalid area code': 'رمز النطاق غير صالح.',
  'area access denied': 'هذا النطاق خارج صلاحياتك.',
  'staff required': 'هذا الإجراء متاح لفريق عطاء فقط.',
  'active warehouse required': 'اختر مستودعًا مفعّلًا.',
  'donation unavailable for intake': 'هذا التبرع غير متاح للاستلام في المستودع.',
  'donation unavailable': 'لم يعد هذا التبرع متاحًا للمطابقة.',
  'donation already received': 'تم استلام هذا التبرع مسبقًا.',
  'item already inspected': 'تم فحص هذا الشيء مسبقًا.',
  'work order is not queued': 'أمر العمل ليس في قائمة الانتظار.',
  'work order cannot be completed': 'ابدأ أمر العمل قبل إكماله.',
  'recycling already closed': 'أُغلقت إعادة التدوير مسبقًا.',
  'inventory transition required': 'أكمل خطوة المخزون أولًا.',
  'incident not found': 'تعذر العثور على البلاغ.',
  'resolution is required': 'اكتب نتيجة المعالجة.',
  'admin_required': 'هذا الإجراء متاح للإدارة فقط.',
  'invalid_email': 'البريد الإلكتروني غير صالح.',
  'reserved_email': 'هذا البريد محجوز ولا يمكن استخدامه.',
  'full_name_required': 'اكتب الاسم الكامل.',
  'full_name_too_long': 'الاسم أطول من المسموح.',
  'too_many_areas': 'عدد النطاقات المختارة أكبر من المسموح.',
  'invalid_user': 'الحساب المطلوب غير موجود.',
  'not_staff': 'هذا الإجراء متاح لحسابات الموصلين والمشرفين فقط.',
  'invalid_role': 'الدور المختار غير صالح.',
  'area_required': 'اختر نطاقًا واحدًا على الأقل.',
  'invalid_area': 'النطاق المختار غير صالح.',
  'create_user_failed': 'تعذر إنشاء الحساب. تحقق من البريد وحاول مجددًا.',
  'staff_setup_failed': 'تعذر إكمال إعداد الحساب. لم يُنشأ أي حساب.',
  'rollback_failed': 'تعذر إكمال الإعداد وبقي حساب غير مكتمل. تواصل مع الدعم الفني.',
  'active user required': 'حسابك غير مفعّل حاليًا. تواصل مع فريق عطاء.',
  'current partner safety terms must be accepted': 'يجب قبول شروط السلامة الحالية أولًا.',
  'partner must be verified': 'لا يمكن إضافة خدمة قبل اعتماد النشاط.',
  'business service offers require': 'لا يمكن إضافة خدمة قبل اعتماد النشاط.',
  'partners may offer': 'هذه الخدمة خارج نطاق نشاطك المعتمد.',
  'outside the verified v1 scope': 'هذه الخدمة خارج نطاق نشاطك المعتمد.',
  'service area is required': 'أكمل عنوانك ونطاق الخدمة أولًا.',
  'service area must belong': 'أكمل عنوانك ونطاق الخدمة أولًا.',
  'display name is required': 'اكتب اسم النشاط.',
  'invalid monthly capacity': 'اكتب عدد الحالات بين 1 و100.',
  'account already deleted': 'حُذف هذا الحساب مسبقًا.',
  'courier_deliveries_open': 'لدى هذا الحساب مهام توصيل مفتوحة. أعد إسنادها أو ألغها أولًا.',
  'courier has open deliveries': 'لدى هذا الحساب مهام توصيل مفتوحة. أعد إسنادها أو ألغها أولًا.',
  'auth_identity_active': 'لم يكتمل حذف هوية الدخول بعد. أعد المحاولة.',
  'location_service_disabled': 'خدمة الموقع متوقفة في الجهاز. فعّلها ثم حاول مرة أخرى.',
};

bool isNetworkError(Object error) {
  if (isSocketException(error) || error is TimeoutException) return true;
  if (error is AuthRetryableFetchException) return true;
  final text = error.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused') ||
      text.contains('connection closed') ||
      text.contains('network is unreachable') ||
      text.contains('clientexception') ||
      text.contains('timeoutexception');
}

String? _serverText(Object error) {
  if (error is PostgrestException) return error.message;
  if (error is AuthException) return error.message;
  if (error is StorageException) return error.message;
  if (error is FunctionException) return '${error.details ?? ''}';
  return null;
}

/// Returns Arabic copy for [error]. Never returns the raw exception text.
String friendlyError(Object error, {String? fallback}) {
  if (isNetworkError(error)) return kOfflineErrorMessage;
  final text = (_serverText(error) ?? error.toString()).toLowerCase();
  for (final entry in kServerErrorMessages.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  return fallback ?? kGenericErrorMessage;
}

/// Shows [friendlyError] in a snackbar when [context] is still mounted.
void showErrorSnack(BuildContext context, Object error, {String? fallback}) {
  if (!context.mounted) return;
  debugPrint('app error: ${error.runtimeType}');
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(friendlyError(error, fallback: fallback))),
    );
}

/// Full-area error state with a retry action, for FutureBuilder error
/// branches. Wraps content in a scroll view so pull-to-refresh keeps working.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isNetworkError(error)
                        ? Icons.wifi_off_rounded
                        : Icons.error_outline_rounded,
                    size: 44,
                  ),
                  const SizedBox(height: 12),
                  Text(friendlyError(error), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state that still scrolls, so a surrounding RefreshIndicator works.
class ScrollableEmpty extends StatelessWidget {
  const ScrollableEmpty({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
