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
        _ => 'متابعة رحماء',
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
      'donation:out_for_delivery' => const OperationStatusCopy(label: 'في الطريق للتسليم', nextStep: 'يتابع فريق رحماء إتمام التسليم.'),
      'donation:delivered' => const OperationStatusCopy(label: 'تم التسليم', nextStep: 'شكرًا لصناعة هذا الأثر.'),
      'donation:cancelled' || 'donation:rejected' => const OperationStatusCopy(label: 'توقفت العملية', nextStep: 'راجع التنبيهات لمعرفة آخر تحديث.', attention: true),
      'need:submitted' => const OperationStatusCopy(label: 'تم إرسال الطلب', nextStep: 'سيراجعه فريق رحماء بسرية.'),
      'need:waiting' => const OperationStatusCopy(label: 'نبحث عن شيء مناسب', nextStep: 'سيصلك تنبيه عند توفر تبرع مناسب.'),
      'need:candidate_found' => const OperationStatusCopy(label: 'وُجد شيء مناسب', nextStep: 'يتحقق الفريق منه قبل إرسال العرض.'),
      'need:confirmed' => const OperationStatusCopy(label: 'تمت المراجعة', nextStep: 'الطلب جاهز للبحث عن تبرع مناسب.'),
      'need:matched' => const OperationStatusCopy(label: 'وُجد تبرع مناسب', nextStep: 'يجري ترتيب التسليم.'),
      'need:delivery_scheduled' => const OperationStatusCopy(label: 'تم ترتيب التسليم', nextStep: 'تابع تبويب التسليم ورمز الاستلام.'),
      'need:fulfilled' => const OperationStatusCopy(label: 'تم تلبية الطلب', nextStep: 'نتمنى أن يكون ما وصلك نافعًا.'),
      'need:cancelled' || 'need:expired' => const OperationStatusCopy(label: 'أُغلق الطلب', nextStep: 'يمكنك إرسال طلب جديد عند الحاجة.', attention: true),
      'item_match:offered' => const OperationStatusCopy(label: 'ينتظر قرارك', nextStep: 'راجع العرض ثم اقبله أو ارفضه.', attention: true),
      'item_processing:inspection_pending' => const OperationStatusCopy(label: 'وصل إلى مركز رحماء', nextStep: 'بانتظار الفحص والتصنيف.'),
      'item_processing:cleaning_queued' => const OperationStatusCopy(label: 'بانتظار التنظيف', nextStep: 'سيُجهز التبرع قبل توزيعه.'),
      'item_processing:cleaning' => const OperationStatusCopy(label: 'قيد التنظيف والتجهيز', nextStep: 'سيُعرض للطلبات المناسبة بعد تجهيزه.'),
      'item_processing:repair_queued' => const OperationStatusCopy(label: 'بانتظار الإصلاح', nextStep: 'يجري ترتيب إصلاحه للاستفادة منه.'),
      'item_processing:repairing' => const OperationStatusCopy(label: 'قيد الإصلاح', nextStep: 'سيُفحص مجددًا قبل إتاحته.'),
      'item_processing:ready_for_distribution' => const OperationStatusCopy(label: 'جاهز للتوزيع', nextStep: 'يبحث الفريق عن طلب مناسب.'),
      'item_processing:recycling' => const OperationStatusCopy(label: 'محوّل لإعادة التدوير', nextStep: 'تعذر استخدامه بأمان وسيُستفاد من مواده.'),
      'item_processing:recycled' => const OperationStatusCopy(label: 'تمت إعادة التدوير', nextStep: 'اكتملت الاستفادة البيئية من المواد.'),
      'delivery:assigned' => const OperationStatusCopy(label: 'يجري ترتيب الاستلام', nextStep: 'سيظهر الرمز عندما يحين وقت التسليم.'),
      'delivery:heading_to_pickup' => const OperationStatusCopy(label: 'الموصل في طريقه للاستلام', nextStep: 'جهّز التبرع ولا تعطِ الرمز إلا عند وصوله.'),
      'delivery:picked_up' => const OperationStatusCopy(label: 'تم الاستلام', nextStep: 'التبرع لدى موصل رحماء.'),
      'delivery:heading_to_recipient' => const OperationStatusCopy(label: 'في الطريق للتسليم', nextStep: 'لا تعطِ رمز التسليم إلا عند وصول الموصل.'),
      'delivery:delivered' => const OperationStatusCopy(label: 'اكتمل التسليم', nextStep: 'اكتملت هذه العملية بنجاح.'),
      'delivery:failed' || 'delivery:rescheduled' => const OperationStatusCopy(label: 'تحتاج إعادة تنسيق', nextStep: 'سيتواصل فريق رحماء لترتيب موعد مناسب.', attention: true),
      'service_offer:submitted' => const OperationStatusCopy(label: 'بانتظار المراجعة', nextStep: 'سيتحقق الفريق من العرض قبل إتاحته.'),
      'service_offer:approved' => const OperationStatusCopy(label: 'الخدمة متاحة', nextStep: 'سيصلك تنبيه عند وجود طلب مناسب.'),
      'service_request:submitted' || 'service_request:reviewing' => const OperationStatusCopy(label: 'قيد المراجعة', nextStep: 'نبحث عن خدمة مناسبة.'),
      'service_match:proposed' => const OperationStatusCopy(label: 'عرض خدمة', nextStep: 'راجع العرض وأرسل قرارك.', attention: true),
      'service_match:accepted' => const OperationStatusCopy(label: 'وافق الطرفان', nextStep: 'يجري الفريق ترتيب الموعد.'),
      'service_match:scheduled' => const OperationStatusCopy(label: 'تم تحديد الموعد', nextStep: 'التزم بالموعد وتعليمات الخصوصية.'),
      'service_offer:completed' || 'service_request:completed' || 'service_match:completed' => const OperationStatusCopy(label: 'اكتملت الخدمة', nextStep: 'يمكن الإبلاغ بسرية إذا حدثت مشكلة.'),
      'service_offer:rejected' || 'service_request:rejected' || 'service_match:declined' || 'service_match:cancelled' => const OperationStatusCopy(label: 'توقفت الخدمة', nextStep: 'راجع التنبيهات لمعرفة آخر تحديث.', attention: true),
      _ => OperationStatusCopy(label: _fallback(status), nextStep: 'تابع التنبيهات لمعرفة أي تحديث جديد.'),
    };
  }

  static String _fallback(String value) => value.replaceAll('_', ' ');
}
