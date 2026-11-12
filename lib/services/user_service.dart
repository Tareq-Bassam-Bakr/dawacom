import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

/// التعامل مع مجموعة `users` في Firestore.
class UserService {
  UserService._();
  static final instance = UserService._();

  final CollectionReference<Map<String, dynamic>> _col = FirebaseFirestore
      .instance
      .collection('users');

  Stream<AppUser?> watch(String uid) => _col
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? AppUser.fromDoc(d) : null);

  Future<AppUser?> get(String uid) async {
    final d = await _col.doc(uid).get();
    return d.exists ? AppUser.fromDoc(d) : null;
  }

  Future<void> create(AppUser user) => _col.doc(user.uid).set({
    ...user.toMap(),
    'createdAt': FieldValue.serverTimestamp(),
  });

  Future<void> updateProfile(
    String uid, {
    required String name,
    required String phone,
    required String city,
  }) => _col.doc(uid).update({
    'name': name.trim(),
    'phone': phone.trim(),
    'city': city,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// إنشاء ملف للمستخدم إن كان حسابه موجوداً في Auth دون ملف في Firestore.
  Future<void> ensureProfile(User user) async {
    final d = await _col.doc(user.uid).get();
    if (d.exists) return;
    await create(
      AppUser(
        uid: user.uid,
        name: user.displayName ?? '',
        email: user.email ?? '',
      ),
    );
  }
}
