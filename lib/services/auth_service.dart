import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'user_service.dart';

/// خدمة المصادقة (تسجيل الدخول، إنشاء الحساب، استعادة كلمة المرور).
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// يكون true أثناء إنشاء حساب جديد، كي لا تُنشئ بوابة الدخول ملفاً
  /// احتياطياً بدور "مستخدم" قبل أن يُحفظ الملف الحقيقي بالدور المختار.
  final ValueNotifier<bool> registering = ValueNotifier(false);

  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  /// إنشاء حساب جديد وحفظ ملفه في Firestore.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String city,
    required UserRole role,
  }) async {
    registering.value = true;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      try {
        await UserService.instance.create(
          AppUser(
            uid: user.uid,
            name: name,
            // نستخدم البريد كما يحفظه Firebase (بأحرف صغيرة) ليطابق قواعد الأمان.
            email: user.email ?? email.trim(),
            phone: phone,
            city: city,
            role: role,
          ),
        );
      } catch (_) {
        // حذف الحساب الناقص حتى يستطيع المستخدم إعادة المحاولة بالبريد نفسه.
        try {
          await user.delete();
        } catch (_) {
          await _auth.signOut();
        }
        rethrow;
      }
      try {
        await user.updateDisplayName(name.trim());
      } catch (_) {
        // الاسم محفوظ في Firestore، وفشل تحديثه هنا لا يؤثر على الحساب.
      }
    } finally {
      registering.value = false;
    }
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  /// تحويل أكواد أخطاء Firebase Auth إلى رسائل عربية واضحة.
  static String messageFor(FirebaseAuthException e) => switch (e.code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'INVALID_LOGIN_CREDENTIALS' => 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
    'invalid-email' => 'صيغة البريد الإلكتروني غير صحيحة',
    'user-disabled' => 'تم تعطيل هذا الحساب، تواصل مع إدارة المنصة',
    'too-many-requests' => 'محاولات كثيرة متتالية، انتظر قليلاً ثم حاول مجدداً',
    'network-request-failed' => 'لا يوجد اتصال بالإنترنت',
    'email-already-in-use' => 'هذا البريد مسجّل مسبقاً، جرّب تسجيل الدخول',
    'weak-password' => 'كلمة المرور ضعيفة، استخدم 6 أحرف على الأقل',
    'operation-not-allowed' => 'تسجيل الدخول بالبريد غير مفعّل حالياً',
    'requires-recent-login' =>
      'يرجى تسجيل الخروج ثم الدخول مجدداً لإتمام العملية',
    _ => 'حدث خطأ أثناء المصادقة (${e.code})',
  };
}
