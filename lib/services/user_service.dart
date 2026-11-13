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

  /// هل يصل التطبيق إلى خوادم Firestore؟ true عندما تأتي البيانات من الخادم،
  /// وfalse عندما يعمل التطبيق من النسخة المحفوظة على الجهاز.
  Stream<bool> serverStatus(String uid) => _col
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .map((d) => !d.metadata.isFromCache)
      .distinct();

  Future<AppUser?> get(String uid) async {
    final d = await _col.doc(uid).get();
    return d.exists ? AppUser.fromDoc(d) : null;
  }

  Future<void> create(AppUser user) => _col.doc(user.uid).set({
    ...user.toCreateMap(),
    'createdAt': FieldValue.serverTimestamp(),
  });

  /// صيدليات محافظة معيّنة (الموثّقة أولاً ثم قيد التوثيق).
  Stream<List<AppUser>> pharmaciesIn(String city) => _col
      .where('role', isEqualTo: UserRole.pharmacist.value)
      .where('city', isEqualTo: city)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map(AppUser.fromDoc).toList();
        list.sort((a, b) {
          if (a.verified != b.verified) return a.verified ? -1 : 1;
          return a.pharmacyLabel.compareTo(b.pharmacyLabel);
        });
        return list;
      });

  Future<void> updateProfile(
    String uid, {
    required String name,
    required String phone,
    required String city,
    String? licenseNumber,
    String? pharmacyName,
    String? pharmacyAddress,
    String? pharmacyHours,
  }) => _col.doc(uid).update({
    'name': name.trim(),
    'phone': phone.trim(),
    'city': city,
    'licenseNumber': ?licenseNumber?.trim(),
    'pharmacyName': ?pharmacyName?.trim(),
    'pharmacyAddress': ?pharmacyAddress?.trim(),
    'pharmacyHours': ?pharmacyHours?.trim(),
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
