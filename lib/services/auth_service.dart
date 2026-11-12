import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import 'user_service.dart';

/// خدمة المصادقة (تسجيل الدخول، إنشاء الحساب، استعادة كلمة المرور).
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

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
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(name.trim());
    await UserService.instance.create(
      AppUser(
        uid: user.uid,
        name: name,
        email: email,
        phone: phone,
        city: city,
        role: role,
      ),
    );
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
