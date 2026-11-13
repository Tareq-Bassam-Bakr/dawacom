import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// دور المستخدم في المنصة.
enum UserRole {
  user('user', 'متبرع / محتاج'),
  pharmacist('pharmacist', 'صيدلي');

  const UserRole(this.value, this.label);
  final String value;
  final String label;

  static UserRole fromValue(String? v) =>
      values.firstWhere((r) => r.value == v, orElse: () => UserRole.user);
}

/// بيانات المستخدم كما تُحفظ في مجموعة `users`.
///
/// حساب الصيدلي يمثل صيدليته أيضاً: اسمها وعنوانها وساعات دوامها ورقم
/// الترخيص. الحقل `verified` لا يغيّره إلا مدير المنصة من Firebase Console.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.city = '',
    this.role = UserRole.user,
    this.verified = false,
    this.licenseNumber = '',
    this.pharmacyName = '',
    this.pharmacyAddress = '',
    this.pharmacyHours = '',
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String city;
  final UserRole role;
  final bool verified;
  final String licenseNumber;
  final String pharmacyName;
  final String pharmacyAddress;
  final String pharmacyHours;
  final DateTime? createdAt;

  bool get isPharmacist => role == UserRole.pharmacist;

  /// صيدلي موثّق يحق له مراجعة الأدوية وإدارة الحجوزات.
  bool get isVerifiedPharmacist => isPharmacist && verified;

  String get displayName => name.trim().isEmpty ? 'مستخدم' : name.trim();

  String get initial =>
      displayName.isEmpty ? '؟' : displayName.characters.first;

  /// اسم الصيدلية للعرض، أو اسم الصيدلي إن لم يُدخل اسمها بعد.
  String get pharmacyLabel =>
      pharmacyName.trim().isEmpty ? 'صيدلية $displayName' : pharmacyName.trim();

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final created = d['createdAt'];
    String s(String k) => d[k] is String ? d[k] as String : '';
    return AppUser(
      uid: doc.id,
      name: s('name'),
      email: s('email'),
      phone: s('phone'),
      city: s('city'),
      role: UserRole.fromValue(d['role'] as String?),
      verified: d['verified'] == true,
      licenseNumber: s('licenseNumber'),
      pharmacyName: s('pharmacyName'),
      pharmacyAddress: s('pharmacyAddress'),
      pharmacyHours: s('pharmacyHours'),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  /// البيانات التي تُكتب عند إنشاء الحساب. `verified` تبدأ دائماً false.
  Map<String, dynamic> toCreateMap() => {
    'name': name.trim(),
    'email': email.trim(),
    'phone': phone.trim(),
    'city': city,
    'role': role.value,
    'verified': false,
    if (isPharmacist) ...{
      'licenseNumber': licenseNumber.trim(),
      'pharmacyName': pharmacyName.trim(),
      'pharmacyAddress': pharmacyAddress.trim(),
      'pharmacyHours': pharmacyHours.trim(),
    },
  };
}
