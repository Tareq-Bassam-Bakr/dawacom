/// تنسيق التواريخ والأعداد بالعربية (بأرقام عربية غربية).
abstract final class AppFormats {
  static const months = <String>[
    'كانون الثاني',
    'شباط',
    'آذار',
    'نيسان',
    'أيار',
    'حزيران',
    'تموز',
    'آب',
    'أيلول',
    'تشرين الأول',
    'تشرين الثاني',
    'كانون الأول',
  ];

  /// مثال: 12 آذار 2027
  static String date(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';

  /// مثال: 03/2027
  static String monthYear(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// صياغة عدد الأيام بالعربية: يوم واحد، يومان، 5 أيام، 40 يوماً.
  static String days(int n) {
    if (n <= 0) return 'اليوم';
    if (n == 1) return 'يوم واحد';
    if (n == 2) return 'يومان';
    if (n <= 10) return '$n أيام';
    return '$n يوماً';
  }

  /// صياغة عدد العلب.
  static String boxes(int n) {
    if (n == 1) return 'علبة واحدة';
    if (n == 2) return 'علبتان';
    if (n <= 10) return '$n علب';
    return '$n علبة';
  }

  /// صياغة عدد الأدوية.
  static String medicines(int n) {
    if (n == 0) return 'لا توجد أدوية';
    if (n == 1) return 'دواء واحد';
    if (n == 2) return 'دواءان';
    if (n <= 10) return '$n أدوية';
    return '$n دواءً';
  }

  /// "منذ 5 دقائق"، "منذ ساعتين"، أو التاريخ الكامل إن كان قديماً.
  static String timeAgo(DateTime? d) {
    if (d == null) return 'الآن';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      if (m == 1) return 'منذ دقيقة';
      if (m == 2) return 'منذ دقيقتين';
      return m <= 10 ? 'منذ $m دقائق' : 'منذ $m دقيقة';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      if (h == 1) return 'منذ ساعة';
      if (h == 2) return 'منذ ساعتين';
      return h <= 10 ? 'منذ $h ساعات' : 'منذ $h ساعة';
    }
    if (diff.inDays < 7) {
      final dd = diff.inDays;
      if (dd == 1) return 'منذ يوم';
      if (dd == 2) return 'منذ يومين';
      return 'منذ $dd أيام';
    }
    return date(d);
  }
}
