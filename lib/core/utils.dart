import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'app_theme.dart';

/// خطأ مفهوم للمستخدم تُعرض رسالته مباشرة.
class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// رسائل سريعة موحدة الشكل.
abstract final class AppSnack {
  static void show(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: error ? AppColors.danger : AppColors.success,
          duration: Duration(seconds: error ? 4 : 3),
          content: Row(
            children: [
              Icon(
                error ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message);

  static void error(BuildContext context, Object e) =>
      show(context, messageOf(e), error: true);

  /// تحويل أي استثناء إلى رسالة عربية مفهومة.
  static String messageOf(Object e) {
    if (e is AppException) return e.message;
    if (e is FirebaseAuthException) return AuthService.messageFor(e);
    if (e is FirebaseException) {
      return switch (e.code) {
        'permission-denied' => 'ليست لديك صلاحية لتنفيذ هذا الإجراء',
        'unavailable' => 'تعذر الاتصال بالخادم، تحقق من اتصالك بالإنترنت',
        'not-found' => 'العنصر المطلوب لم يعد موجوداً',
        'resource-exhausted' => 'تم تجاوز الحد المسموح، حاول لاحقاً',
        _ => 'خطأ في الخادم (${e.code})',
      };
    }
    return 'حدث خطأ غير متوقع، حاول مرة أخرى';
  }
}

/// قواعد التحقق من المدخلات.
abstract final class Validators {
  static String? required(String? v, [String message = 'هذا الحقل مطلوب']) =>
      (v == null || v.trim().isEmpty) ? message : null;

  static String? name(String? v) {
    if (v == null || v.trim().isEmpty) return 'يرجى إدخال الاسم';
    if (v.trim().length < 3) return 'الاسم قصير جداً';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
    final re = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    return re.hasMatch(v.trim()) ? null : 'صيغة البريد الإلكتروني غير صحيحة';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'يرجى إدخال كلمة المرور';
    if (v.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    return null;
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'يرجى إدخال رقم الهاتف';
    final digits = v.replaceAll(RegExp(r'[\s\-()]'), '');
    final re = RegExp(r'^(\+?963|00963|0)?9\d{8}$');
    return re.hasMatch(digits)
        ? null
        : 'أدخل رقماً سورياً صحيحاً مثل 09xxxxxxxx';
  }

  static String? quantity(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null || n < 1) return 'أدخل كمية صحيحة (1 أو أكثر)';
    if (n > 999) return 'الكمية كبيرة جداً';
    return null;
  }
}

/// نافذة تأكيد موحدة. تُعيد true عند التأكيد.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  String cancelLabel = 'إلغاء',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: icon == null
          ? null
          : Icon(
              icon,
              size: 40,
              color: destructive ? AppColors.danger : AppColors.primary,
            ),
      title: Text(title),
      content: Text(message),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? AppColors.danger : AppColors.primary,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
