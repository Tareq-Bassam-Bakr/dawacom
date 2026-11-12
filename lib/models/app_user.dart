import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// دور المستخدم في المنصة.
enum UserRole {
  user('user', 'متبرع / محتاج'),
  pharmacist('pharmacist', 'صيدلاني مدقّق');

  const UserRole(this.value, this.label);
  final String value;
  final String label;

  static UserRole fromValue(String? v) =>
      values.firstWhere((r) => r.value == v, orElse: () => UserRole.user);
}

/// بيانات المستخدم كما تُحفظ في مجموعة `users`.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.city = '',
    this.role = UserRole.user,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String city;
  final UserRole role;
  final DateTime? createdAt;

  bool get isPharmacist => role == UserRole.pharmacist;

  String get displayName => name.trim().isEmpty ? 'مستخدم' : name.trim();

  String get initial =>
      displayName.isEmpty ? '؟' : displayName.characters.first;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final created = d['createdAt'];
    return AppUser(
      uid: doc.id,
      name: (d['name'] ?? '') as String,
      email: (d['email'] ?? '') as String,
      phone: (d['phone'] ?? '') as String,
      city: (d['city'] ?? '') as String,
      role: UserRole.fromValue(d['role'] as String?),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name.trim(),
    'email': email.trim(),
    'phone': phone.trim(),
    'city': city,
    'role': role.value,
  };

  AppUser copyWith({String? name, String? phone, String? city}) => AppUser(
    uid: uid,
    name: name ?? this.name,
    email: email,
    phone: phone ?? this.phone,
    city: city ?? this.city,
    role: role,
    createdAt: createdAt,
  );
}
