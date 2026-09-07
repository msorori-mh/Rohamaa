class OperationStatusCopy {
  const OperationStatusCopy({required this.label, required this.nextStep, this.attention = false});

  final String label;
  final String nextStep;
  final bool attention;
}

abstract final class OperationStatusPresenter {
  static String kindLabel(String kind) => switch (kind) {
        'donation' => 'عطاء عيني',
        'need' => 'احتياج',
        'item_match' => 'عرض مطابقة',
        'delivery' => 'استلام وتسليم',
        'service_offer' => 'وقت أو مهارة مقدمة',
        'service_request' => 'طلب خدمة',
        'service_match' => 'عملية خدمة',
        'item_processing' => 'تجهيز العطاء',
        _ => 'عملية رحماء',
      };

  static OperationStatusCopy present(String kind, String status) {
    final key = '$kind:$status';
    return switch (key) {
      'donation:draft' => const OperationStatusCopy(label: 'مسودة', nextStep: 'أكمل البيانات ثم أرسل العطاء.'),
      'donation:submitted' => const OperationStatusCopy(label: 'وصل إلى رحماء', nextStep: 'سيراجع الفريق العطاء ويتحقق من ملاءمته.'),
      'donation:under_review' => const OperationStatusCopy(label: 'قيد المراجعة', nextStep: 'لا يلزمك إجراء الآن.'),
      'donation:available' => const OperationStatusCopy(label: 'جاهز للمطابقة', nextStep: 'يبحث الفريق عن احتياج مناسب.'),
      'donation:matched' => const OperationStatusCopy(label: 'تمت المطابقة', nextStep: 'يجري تأكيد الخطوة التالية.'),
      'donation:pickup_scheduled' => const OperationStatusCopy(label: 'تم ترتيب الاستلام', nextStep: 'تابع تبويب التسليم عند وصول الموصل.'),
      'donation:picked_up' => const OperationStatusCopy(label: 'استلم الموصل العطاء', nextStep: 'العطاء في طريقه إلى المستفيد.'),
      'donation:out_for_delivery' => const OperationStatusCopy(label: 'في الطريق للتسليم', nextStep: 'يتابع فريق رحماء إتمام التسليم.'),
      'donation:delivered' => const OperationStatusCopy(label: 'تم التسليم', nextStep: 'شكرًا لصناعة هذا الأثر.'),
      'donation:cancelled' || 'donation:rejected' => const OperationStatusCopy(label: 'توقفت العملية', nextStep: 'راجع التنبيهات لمعرفة آخر تحديث.', attention: true),
      'need:submitted' => const OperationStatusCopy(label: 'وصل الاحتياج', nextStep: 'سيراجعه فريق رحماء بسرية.'),
      'need:waiting' => const OperationStatusCopy(label: 'بانتظار مورد مناسب', nextStep: 'سيصلك تنبيه عند وجود عطاء ملائم.'),
      'need:candidate_found' => const OperationStatusCopy(label: 'وُجد مرشح مناسب', nextStep: 'يجري الفريق التحقق قبل إرسال العرض.'),
      'need:confirmed' => const OperationStatusCopy(label: 'تم التحقق', nextStep: 'الاحتياج جاهز للمطابقة.'),
      'need:matched' => const OperationStatusCopy(label: 'تمت المطابقة', nextStep: 'يجري ترتيب التسليم.'),
      'need:delivery_scheduled' => const OperationStatusCopy(label: 'تم ترتيب التسليم', nextStep: 'تابع تبويب التسليم ورمز الاستلام.'),
      'need:fulfilled' => const OperationStatusCopy(label: 'تم تلبية الاحتياج', nextStep: 'نتمنى أن يكون الأثر نافعًا.'),
      'need:cancelled' || 'need:expired' => const OperationStatusCopy(label: 'أُغلق الاحتياج', nextStep: 'يمكنك تسجيل احتياج جديد عند الحاجة.', attention: true),
      'item_match:offered' => const OperationStatusCopy(label: 'ينتظر قرارك', nextStep: 'راجع العرض واقبله أو ارفضه بوضوح.', attention: true),
      'item_processing:inspection_pending' => const OperationStatusCopy(label: 'وصل إلى مركز رحماء', nextStep: 'بانتظار الفحص والتصنيف.'),
      'item_processing:cleaning_queued' => const OperationStatusCopy(label: 'بانتظار التنظيف', nextStep: 'سيُجهز العطاء قبل إعادة توزيعه.'),
      'item_processing:cleaning' => const OperationStatusCopy(label: 'قيد التنظيف والتجهيز', nextStep: 'سيعود للمطابقة بعد اكتمال التجهيز.'),
      'item_processing:repair_queued' => const OperationStatusCopy(label: 'بانتظار الإصلاح', nextStep: 'يجري ترتيب إصلاحه للاستفادة منه.'),
      'item_processing:repairing' => const OperationStatusCopy(label: 'قيد الإصلاح', nextStep: 'سيُفحص مجددًا قبل إتاحته.'),
      'item_processing:ready_for_distribution' => const OperationStatusCopy(label: 'جاهز لإعادة التوزيع', nextStep: 'يبحث الفريق عن احتياج مناسب.'),
      'item_processing:recycling' => const OperationStatusCopy(label: 'محوّل لإعادة التدوير', nextStep: 'تعذر استخدامه بأمان وسيُستفاد من مواده.'),
      'item_processing:recycled' => const OperationStatusCopy(label: 'تمت إعادة التدوير', nextStep: 'اكتملت الاستفادة البيئية من المواد.'),
      'delivery:assigned' => const OperationStatusCopy(label: 'يجري ترتيب الاستلام', nextStep: 'سيظهر الرمز عندما يحين وقت التسليم.'),
      'delivery:heading_to_pickup' => const OperationStatusCopy(label: 'الموصل في طريقه للاستلام', nextStep: 'جهّز العطاء ولا تسلّم الرمز إلا عند الوصول.'),
      'delivery:picked_up' => const OperationStatusCopy(label: 'تم الاستلام', nextStep: 'العطاء في عهدة موصل رحماء.'),
      'delivery:heading_to_recipient' => const OperationStatusCopy(label: 'في الطريق للمستفيد', nextStep: 'لا يُعطى رمز التسليم إلا عند الوصول.'),
      'delivery:delivered' => const OperationStatusCopy(label: 'اكتمل التسليم', nextStep: 'اكتملت هذه العملية بنجاح.'),
      'delivery:failed' || 'delivery:rescheduled' => const OperationStatusCopy(label: 'تحتاج إعادة تنسيق', nextStep: 'سيتواصل فريق رحماء لترتيب موعد مناسب.', attention: true),
      'service_offer:submitted' => const OperationStatusCopy(label: 'بانتظار المراجعة', nextStep: 'سيتحقق الفريق من العرض قبل إتاحته.'),
      'service_offer:approved' => const OperationStatusCopy(label: 'معتمد للمطابقة', nextStep: 'سيصلك تنبيه عند وجود طلب مناسب.'),
      'service_request:submitted' || 'service_request:reviewing' => const OperationStatusCopy(label: 'قيد المراجعة', nextStep: 'يجري البحث عن مهارة مناسبة.'),
      'service_match:proposed' => const OperationStatusCopy(label: 'اقتراح خدمة', nextStep: 'راجع العملية وأرسل موافقتك.', attention: true),
      'service_match:accepted' => const OperationStatusCopy(label: 'وافق الطرفان', nextStep: 'يجري الفريق ترتيب الموعد.'),
      'service_match:scheduled' => const OperationStatusCopy(label: 'تم تحديد الموعد', nextStep: 'التزم بالموعد وتعليمات الخصوصية.'),
      'service_offer:completed' || 'service_request:completed' || 'service_match:completed' => const OperationStatusCopy(label: 'اكتملت الخدمة', nextStep: 'يمكن الإبلاغ بسرية إذا حدثت مشكلة.'),
      'service_offer:rejected' || 'service_request:rejected' || 'service_match:declined' || 'service_match:cancelled' => const OperationStatusCopy(label: 'توقفت العملية', nextStep: 'راجع التنبيهات لمعرفة آخر تحديث.', attention: true),
      _ => OperationStatusCopy(label: _fallback(status), nextStep: 'تابع التنبيهات لمعرفة أي تحديث جديد.'),
    };
  }

  static String _fallback(String value) => value.replaceAll('_', ' ');
}
