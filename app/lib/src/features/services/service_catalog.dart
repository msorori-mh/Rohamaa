import 'package:flutter/material.dart';

class ServiceCategoryOption {
  const ServiceCategoryOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.types,
  });

  final String key;
  final String label;
  final IconData icon;
  final List<String> types;
}

const ruhamaaServiceCategories = <ServiceCategoryOption>[
  ServiceCategoryOption(
    key: 'plumbing',
    label: 'سباكة',
    icon: Icons.plumbing_rounded,
    types: ['سباكة عامة', 'تسريبات ومواسير', 'تركيب حنفيات وأدوات صحية'],
  ),
  ServiceCategoryOption(
    key: 'electrical',
    label: 'كهرباء',
    icon: Icons.electrical_services_rounded,
    types: ['كهرباء منزلية', 'إنارة ومفاتيح', 'أعطال كهربائية بسيطة'],
  ),
  ServiceCategoryOption(
    key: 'carpentry',
    label: 'نجارة وأثاث',
    icon: Icons.carpenter_rounded,
    types: ['إصلاح أثاث', 'تركيب أثاث', 'نجارة خفيفة'],
  ),
  ServiceCategoryOption(
    key: 'tailoring',
    label: 'خياطة',
    icon: Icons.content_cut_rounded,
    types: ['تعديل ملابس', 'خياطة بسيطة', 'إصلاح ملابس'],
  ),
  ServiceCategoryOption(
    key: 'appliance_repair',
    label: 'صيانة منزلية',
    icon: Icons.home_repair_service_rounded,
    types: ['صيانة أجهزة منزلية', 'فحص جهاز', 'إصلاح عطل بسيط'],
  ),
  ServiceCategoryOption(
    key: 'device_repair',
    label: 'هواتف وكمبيوتر',
    icon: Icons.devices_rounded,
    types: ['صيانة هاتف', 'صيانة كمبيوتر أو لابتوب', 'إعداد وبرمجيات بسيطة'],
  ),
  ServiceCategoryOption(
    key: 'painting',
    label: 'دهان وصيانة',
    icon: Icons.format_paint_rounded,
    types: ['دهان غرفة أو جزء منها', 'ترميم بسيط', 'صيانة منزلية خفيفة'],
  ),
  ServiceCategoryOption(
    key: 'moving_assembly',
    label: 'تركيب ونقل خفيف',
    icon: Icons.handyman_rounded,
    types: ['تركيب أغراض', 'فك وتركيب أثاث خفيف', 'مساعدة في نقل خفيف'],
  ),
  ServiceCategoryOption(
    key: 'beauty_wedding',
    label: 'تجهيز مناسبات',
    icon: Icons.face_retouching_natural_rounded,
    types: ['تجهيز عروس', 'كوافير أو عناية', 'حلاقة أو تجهيز شخصي'],
  ),
  ServiceCategoryOption(
    key: 'event_setup',
    label: 'كوش وزينة',
    icon: Icons.celebration_rounded,
    types: ['كوشة بسيطة', 'زينة مناسبة', 'تركيب وتجهيز مناسبة'],
  ),
  ServiceCategoryOption(
    key: 'printing_stationery',
    label: 'طباعة وقرطاسية',
    icon: Icons.print_rounded,
    types: ['طباعة', 'تصوير مستندات', 'تجهيز مواد مدرسية بسيطة'],
  ),
  ServiceCategoryOption(
    key: 'other',
    label: 'مهارة أخرى',
    icon: Icons.more_horiz_rounded,
    types: ['خدمة أخرى'],
  ),
];

ServiceCategoryOption serviceCategoryByKey(String key) =>
    ruhamaaServiceCategories.firstWhere(
      (category) => category.key == key,
      orElse: () => ruhamaaServiceCategories.last,
    );
