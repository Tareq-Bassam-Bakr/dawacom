import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/formats.dart';

/// حالة الدواء في دورة حياته داخل المنصة.
enum MedicineStatus {
  pending('pending', 'قيد التدقيق', Icons.hourglass_top_rounded),
  approved('approved', 'متاح', Icons.check_circle_rounded),
  requested('requested', 'محجوز', Icons.assignment_turned_in_rounded),
  rejected('rejected', 'مرفوض', Icons.cancel_rounded);

  const MedicineStatus(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;

  static MedicineStatus fromValue(String? v) => values.firstWhere(
    (s) => s.value == v,
    orElse: () => MedicineStatus.pending,
  );
}

/// نموذج الدواء كما يُحفظ في مجموعة `medicines`.
class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.pharmacy,
    required this.city,
    required this.status,
    required this.donorId,
    required this.donorName,
    this.donorPhone = '',
    this.expiryDate,
    this.expiryText,
    this.notes = '',
    this.imageBytes,
    this.recipientId,
    this.recipientName,
    this.recipientPhone,
    this.createdAt,
    this.requestedAt,
    this.reviewedAt,
  });

  final String id;
  final String name;
  final String category;
  final int quantity;
  final DateTime? expiryDate;

  /// نص الصلاحية للسجلات القديمة التي حُفظت كنص حر (MM/YY).
  final String? expiryText;
  final String pharmacy;
  final String city;
  final String notes;
  final Uint8List? imageBytes;
  final MedicineStatus status;
  final String donorId;
  final String donorName;
  final String donorPhone;
  final String? recipientId;
  final String? recipientName;
  final String? recipientPhone;
  final DateTime? createdAt;
  final DateTime? requestedAt;
  final DateTime? reviewedAt;

  bool get hasImage => imageBytes != null && imageBytes!.isNotEmpty;

  IconData get categoryIcon => AppConstants.categoryIcon(category);

  /// عدد الأيام المتبقية حتى انتهاء الصلاحية (null إن كان التاريخ غير معروف).
  int? get daysToExpiry {
    final e = expiryDate;
    if (e == null) return null;
    return DateUtils.dateOnly(
      e,
    ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
  }

  bool get isExpired => (daysToExpiry ?? 1) < 0;

  bool get isNearExpiry {
    final d = daysToExpiry;
    return d != null && d >= 0 && d <= AppConstants.nearExpiryDays;
  }

  /// نص الصلاحية للعرض.
  String get expiryLabel {
    final e = expiryDate;
    if (e != null) return AppFormats.date(e);
    final t = expiryText?.trim();
    return (t == null || t.isEmpty) ? 'غير محدد' : t;
  }

  bool isDonatedBy(String uid) => donorId == uid;
  bool isRequestedBy(String uid) => recipientId == uid;

  factory Medicine.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};

    Uint8List? bytes;
    final img = d['imageBase64'];
    if (img is String && img.isNotEmpty) {
      try {
        bytes = base64Decode(img);
      } catch (_) {
        bytes = null;
      }
    }

    return Medicine(
      id: doc.id,
      name: _str(d['name']),
      category: _str(d['category'], 'أخرى'),
      quantity: _int(d['quantity']),
      expiryDate: _date(d['expiryDate']),
      expiryText: d['expiry'] as String?,
      pharmacy: _str(d['pharmacy']),
      city: _str(d['city']),
      notes: _str(d['notes']),
      imageBytes: bytes,
      status: MedicineStatus.fromValue(d['status'] as String?),
      donorId: _str(d['donorId']),
      donorName: _str(d['donorName'], 'متبرع'),
      donorPhone: _str(d['donorPhone']),
      recipientId: d['recipientId'] as String?,
      recipientName: d['recipientName'] as String?,
      recipientPhone: d['recipientPhone'] as String?,
      createdAt: _date(d['createdAt']),
      requestedAt: _date(d['requestedAt']),
      reviewedAt: _date(d['reviewedAt']),
    );
  }

  static String _str(dynamic v, [String fallback = '']) =>
      v is String && v.isNotEmpty ? v : fallback;

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v'.trim()) ?? 1;
  }

  static DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;
}
