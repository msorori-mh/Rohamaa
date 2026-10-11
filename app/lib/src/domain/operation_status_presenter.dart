class OperationStatusCopy {
  const OperationStatusCopy({required this.label, required this.nextStep, this.attention = false});

  final String label;
  final String nextStep;
  final bool attention;
}

abstract final class OperationStatusPresenter {
  static String kindLabel(String kind) => switch (kind) {
        'donation' => 'تبرع',
        'need' => 'طلب',
        'item_match' => 'عرض مناسب',
        'delivery' => 'توصيل',
        'service_offer' => 'خدمة مقدمة',
        'service_request' => 'طلب خدمة',
        'service_match' => 'خدمة',
        'item_processing' => 'تجهيز التبرع',
        _ => 'متابعة عطاء',
      };

  static OperationStatusCopy present(String kind, String status) {
    final key = '$kind:$status';
    return switch (key) {
      'donation:draft' => const OperationStatusCopy(label: 'مسودة', nextStep: 'أكمل البيانات ثم أرسل التبرع.'),
      'donation:submitted' => const OperationStatusCopy(label: 'تم الإرسال', nextStep: 'سيراجع الفريق التبرع.'),
      'donation:under_review' => const OperationStatusCopy(label: 'قيد المراجعة', nextStep: 'لا يلزمك إجراء الآن.'),
      'donation:available' => const OperationStatusCopy(label: 'جاهز للتوجيه', nextStep: 'يبحث الفريق عن طلب مناسب.'),
      'donation:matched' => const OperationStatusCopy(label: 'وُجد طلب مناسب', nextStep: 'يجري تأكيد الخطوة التالية.'),
      'donation:pickup_scheduled' => const OperationStatusCopy(label: 'تم ترتيب الاستلام', nextStep: 'تابع تبويب التسليم عند وصول الموصل.'),
      'donation:picked_up' => const OperationStatusCopy(label: 'استلم الموصل التبرع', nextStep: 'التبرع في طريقه إلى صاحبه.'),
      'donation:out_for_delivery' => const OperationStatusCopy(label: 'في الطريق للتسليم', nextStep: 'يتابع فريق عطاء إتمام التسليم.'),
      'donation:delivered' => const OperationStatusCopy(label: 'تم التسليم', nextStep: 'شكرًا لصناعة هذا الأثر.'),
      'donation:cancelled' => const OperationStatusCopy(label: 'أُلغي التبرع', nextStep: 'يمكنك تسجيل تبرع جديد في أي وقت.'),
      'donation:rejected' => const OperationStatusCopy(label: 'توقفت العملية', nextStep: 'راجع التنبيهات لمعرفة آخر تحديث.', attention: true),
      'need:submitted' => const OperationStatusCopy(label: 'تم إرسال الطلب', nextStep: 'سيراجعه فريق عطاء بسرية.'),
      'need:waiting' => const OperationStatusCopy(label: 'نبحث عن شيء مناسب', nextStep: 'سيصلك تنبيه عند توفر تبرع مناسب.'),
      'need:candidate_found' => const OperationStatusCopy(label: 'وُجد شيء مناسب', nextStep: 'يتحقق الفريق منه قبل إرسال العرض.'),
      'need:confirmed' => const OperationStatusCopy(label: 'تمت المراجعة', nextStep: 'الطلب جاهز للبحث عن تبرع مناسب.'),
      'need:matched' => const OperationStatusCopy(label: 'وُجد تبرع مناسب', nextStep: 'يجري ترتيب التسليم.'),
      'need:delivery_scheduled' => const OperationStatusCopy(label: 'تم ترتيب التسليم', nextStep: 'تابع تبويب التسليم ورمز الاستلام.'),
      'need:fulfilled' => const OperationStatusCopy(label: 'تم تلبية الطلب', nextStep: 'نتمنى أن يكون ما وصلك نافعًا.'),
      'need:cancelled' => const OperationStatusCopy(label: 'أُلغي الطلب', nextStep: 'يمكنك إرسال طلب جديد عند الحاجة.'),
      'need:expired' => const OperationStatusCopy(label: 'أُغلق الطلب', nextStep: 'يمكنك إرسال طلب جديد عند الحاجة.', attention: true),
      'item_match:offered' => const OperationStatusCopy(label: 'ينتظر قرارك', nextStep: 'راجع العرض ثم اقبله أو ارفضه.', attention: true),
      'item_match:accepted' => const OperationStatusCopy(label: 'قبلت العرض', nextStep: 'يرتب فريق عطاء التوصيل.'),
      'item_match:declined' => const OperationStatusCopy(label: 'رفضت العرض', nextStep: 'سنواصل البحث عن شيء مناسب.'),
      'item_match:cancelled' => const OperationStatusCopy(label: 'أُلغي العرض', nextStep: 'سنواصل البحث عن شيء مناسب.'),
      'item_processing:inspection_pending' => const OperationStatusCopy(label: 'وصل إلى مركز عطاء', nextStep: 'بانتظار الفحص والتصنيف.'),
      'item_processing:cleaning_queued' => const OperationStatusCopy(label: 'بانتظار التنظيف', nextStep: 'سيُجهز التبرع قبل توزيعه.'),
      'item_processing:cleaning' => const OperationStatusCopy(label: 'قيد التنظيف والتجهيز', nextStep: 'سيُعرض للطلبات المناسبة بعد تجهيزه.'),
      'item_processing:repair_queued' => const OperationStatusCopy(label: 'بانتظار الإصلاح', nextStep: 'يجري ترتيب إصلاحه للاستفادة منه.'),
      'item_processing:repairing' => const OperationStatusCopy(label: 'قيد الإصلاح', nextStep: 'سيُفحص مجددًا قبل إتاحته.'),
      'item_processing:ready_for_distribution' => const OperationStatusCopy(label: 'جاهز للتوزيع', nextStep: 'يبحث الفريق عن طلب مناسب.'),
      'item_processing:recycling' => const OperationStatusCopy(label: 'محوّل لإعادة التدوير', nextStep: 'تعذر استخدامه بأمان وسيُستفاد من مواده.'),
      'item_processing:recycled' => const OperationStatusCopy(label: 'تمت إعادة التدوير', nextStep: 'اكتملت الاستفادة البيئية من المواد.'),
      'item_processing:withdrawn' => const OperationStatusCopy(label: 'أُخرج من مركز عطاء', nextStep: 'لم يعد هذا التبرع ضمن المخزون. راجع التنبيهات لمعرفة آخر تحديث.'),
      'delivery:assigned' => const OperationStatusCopy(label: 'يجري ترتيب الاستلام', nextStep: 'سيظهر الرمز عندما يحين وقت التسليم.'),
      'delivery:heading_to_pickup' => const OperationStatusCopy(label: 'الموصل في طريقه للاستلام', nextStep: 'جهّز التبرع ولا تعطِ الرمز إلا عند وصوله.'),
      'delivery:picked_up' => const OperationStatusCopy(label: 'تم الاستلام', nextStep: 'التبرع لدى موصل عطاء.'),
      'delivery:heading_to_recipient' => const OperationStatusCopy(label: 'في الطريق للتسليم', nextStep: 'لا تعطِ رمز التسليم إلا عند وصول الموصل.'),
      'delivery:delivered' => const OperationStatusCopy(label: 'اكتمل التسليم', nextStep: 'اكتملت هذه العملية بنجاح.'),
      'delivery:failed' || 'delivery:rescheduled' => const OperationStatusCopy(label: 'تحتاج إعادة تنسيق', nextStep: 'سيتواصل فريق عطاء لترتيب موعد مناسب.', attention: true),
      'service_offer:submitted' => const OperationStatusCopy(label: 'بانتظار المراجعة', nextStep: 'سيتحقق الفريق من العرض قبل إتاحته.'),
      'service_offer:approved' => const OperationStatusCopy(label: 'الخدمة متاحة', nextStep: 'سيصلك تنبيه عند وجود طلب مناسب.'),
      'service_offer:paused' => const OperationStatusCopy(label: 'الخدمة موقوفة مؤقتًا', nextStep: 'لن تُعرض على طلبات جديدة حتى يُعاد تفعيلها.'),
      'service_offer:matched' => const OperationStatusCopy(label: 'وُجد طلب مناسب لخدمتك', nextStep: 'راجع العروض وأرسل قرارك.'),
      'service_offer:cancelled' || 'service_offer:withdrawn' => const OperationStatusCopy(label: 'سُحبت الخدمة', nextStep: 'يمكنك تقديم خدمة جديدة في أي وقت.'),
      'service_request:submitted' || 'service_request:reviewing' => const OperationStatusCopy(label: 'قيد المراجعة', nextStep: 'نبحث عن خدمة مناسبة.'),
      'service_request:matched' => const OperationStatusCopy(label: 'وُجدت خدمة مناسبة', nextStep: 'راجع العروض وأرسل قرارك.'),
      'service_request:scheduled' => const OperationStatusCopy(label: 'تم تحديد موعد الخدمة', nextStep: 'التزم بالموعد وتعليمات الخصوصية.'),
      'service_request:cancelled' || 'service_request:withdrawn' => const OperationStatusCopy(label: 'أُلغي طلب الخدمة', nextStep: 'يمكنك إرسال طلب جديد عند الحاجة.'),
      'service_match:proposed' => const OperationStatusCopy(label: 'عرض خدمة', nextStep: 'راجع العرض وأرسل قرارك.', attention: true),
      'service_match:accepted' => const OperationStatusCopy(label: 'وافق الطرفان', nextStep: 'يجري الفريق ترتيب الموعد.'),
      'service_match:scheduled' => const OperationStatusCopy(label: 'تم تحديد الموعد', nextStep: 'التزم بالموعد وتعليمات الخصوصية.'),
      'service_offer:completed' || 'service_request:completed' || 'service_match:completed' => const OperationStatusCopy(label: 'اكتملت الخدمة', nextStep: 'يمكن الإبلاغ بسرية إذا حدثت مشكلة.'),
      'service_offer:rejected' || 'service_request:rejected' || 'service_match:declined' || 'service_match:cancelled' => const OperationStatusCopy(label: 'توقفت الخدمة', nextStep: 'راجع التنبيهات لمعرفة آخر تحديث.', attention: true),
      _ => const OperationStatusCopy(label: fallbackLabel, nextStep: 'تابع التنبيهات لمعرفة أي تحديث جديد.'),
    };
  }

  /// Copy for the "handoff" tab, where the same delivery reads differently
  /// for the donor ([handoffKind] 'pickup') and the recipient ('delivery').
  static OperationStatusCopy presentHandoff(String handoffKind, String status) {
    final key = '$handoffKind:$status';
    return switch (key) {
      'pickup:assigned' => const OperationStatusCopy(label: 'يجري ترتيب الاستلام', nextStep: 'سيظهر رمز الاستلام عندما يتحرك الموصل إليك.'),
      'pickup:heading_to_pickup' => const OperationStatusCopy(label: 'الموصل في طريقه إليك', nextStep: 'جهّز التبرع، ولا تعطِ رمز الاستلام إلا عند وصول الموصل.', attention: true),
      'pickup:picked_up' => const OperationStatusCopy(label: 'تم الاستلام منك', nextStep: 'التبرع لدى موصل عطاء.'),
      'pickup:heading_to_recipient' => const OperationStatusCopy(label: 'في الطريق إلى صاحبه', nextStep: 'لا يلزمك إجراء الآن.'),
      'delivery:assigned' => const OperationStatusCopy(label: 'يجري ترتيب التوصيل', nextStep: 'سيظهر رمز التسليم عندما يتحرك الموصل إليك.'),
      'delivery:heading_to_pickup' => const OperationStatusCopy(label: 'الموصل في طريقه لاستلام ما طلبته', nextStep: 'سيصلك تنبيه عندما يتجه إليك.'),
      'delivery:picked_up' => const OperationStatusCopy(label: 'ما طلبته لدى الموصل', nextStep: 'سيتجه إليك قريبًا.'),
      'delivery:heading_to_recipient' => const OperationStatusCopy(label: 'الموصل في طريقه إليك', nextStep: 'لا تعطِ رمز التسليم إلا عند وصول الموصل.', attention: true),
      _ => present('delivery', status),
    };
  }

  /// Shown for a status this version of the app does not know yet. Never the
  /// raw database key.
  static const fallbackLabel = 'قيد المتابعة';
}
