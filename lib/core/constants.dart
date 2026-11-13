import 'package:flutter/material.dart';

/// ثوابت التطبيق العامة: الاسم، المحافظات، التصنيفات.
abstract final class AppConstants {
  static const appName = 'دواكم';
  static const tagline = 'منصة الدواء التكافلي';
  static const description =
      'تبرّع بالدواء الفائض لديك، أو اطلب ما تحتاجه مجاناً عبر صيدليات موثوقة.';

  /// المحافظات السورية.
  static const cities = <String>[
    'دمشق',
    'ريف دمشق',
    'حلب',
    'حمص',
    'حماة',
    'اللاذقية',
    'طرطوس',
    'إدلب',
    'دير الزور',
    'الرقة',
    'الحسكة',
    'درعا',
    'السويداء',
    'القنيطرة',
  ];

  /// تصنيفات الأدوية.
  static const categories = <String>[
    'مسكنات وخافضات حرارة',
    'مضادات حيوية',
    'قلب وضغط',
    'سكري',
    'تنفسية وربو',
    'هضمية',
    'فيتامينات ومكملات',
    'أعصاب ونفسية',
    'جلدية',
    'أطفال',
    'عيون وأذن',
    'مستلزمات طبية',
    'أخرى',
  ];

  static IconData categoryIcon(String category) => switch (category) {
    'مسكنات وخافضات حرارة' => Icons.healing_rounded,
    'مضادات حيوية' => Icons.biotech_rounded,
    'قلب وضغط' => Icons.favorite_rounded,
    'سكري' => Icons.water_drop_rounded,
    'تنفسية وربو' => Icons.air_rounded,
    'هضمية' => Icons.medication_liquid_rounded,
    'فيتامينات ومكملات' => Icons.eco_rounded,
    'أعصاب ونفسية' => Icons.psychology_rounded,
    'جلدية' => Icons.face_retouching_natural_rounded,
    'أطفال' => Icons.child_care_rounded,
    'عيون وأذن' => Icons.visibility_rounded,
    'مستلزمات طبية' => Icons.medical_services_rounded,
    _ => Icons.medication_rounded,
  };

  /// أقل مدة صلاحية متبقية مسموح بها للتبرع (6 أشهر)، كما تشترط برامج
  /// إعادة توزيع الأدوية المرخّصة.
  static const minDaysToExpiry = 180;

  /// الدواء المتاح الذي يتبقى على انتهائه هذه المدة أو أقل يُعد "قريب الانتهاء".
  static const nearExpiryDays = 60;

  /// المهلة المتاحة للمحتاج لاستلام الدواء بعد حجزه.
  static const reservationDays = 3;

  /// أسباب الرفض الجاهزة التي يختار منها الصيدلي.
  static const rejectionReasons = <String>[
    'العبوة مفتوحة أو الختم غير سليم',
    'الصلاحية أقل من 6 أشهر',
    'مادة مراقبة (مخدرة أو نفسية)',
    'تحتاج تبريداً ولا يمكن ضمان حفظها',
    'تاريخ الصلاحية أو اسم الدواء غير واضح',
    'الصورة لا تطابق الدواء',
    'الدواء غير متوفر عند الاستلام',
    'سبب آخر',
  ];
}
