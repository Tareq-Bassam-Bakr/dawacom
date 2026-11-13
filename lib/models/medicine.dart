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
    this.pharmacyId = '',
    this.pharmacyAddress = '',
    this.pharmacyPhone = '',
    this.pharmacyHours = '',
    this.batchNumber = '',
    this.requiresPrescription = false,
    this.hasPrescription = false,
    this.rejectionReason = '',
    this.rejectionNote = '',
    this.reviewerName = '',
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

  /// نص الصلاحية كما حُفظ في السجلات القديمة (قبل منتقي التاريخ).
  final String? expiryText;

  /// اسم الصيدلية (أو مكان الاستلام النصي في السجلات القديمة).
  final String pharmacy;
  final String city;
  final String notes;
  final Uint8List? imageBytes;

  /// معرّف حساب الصيدلي المسؤول عن الدواء. فارغ في السجلات القديمة.
  final String pharmacyId;
  final String pharmacyAddress;
  final String pharmacyPhone;
  final String pharmacyHours;

  /// رقم التشغيلة (Batch) لتتبّع الدواء إن سحبته الشركة من السوق.
  final String batchNumber;
  final bool requiresPrescription;
  final bool hasPrescription;
  final String rejectionReason;
  final String rejectionNote;
  final String reviewerName;
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

  bool get hasPharmacy => pharmacyId.isNotEmpty;

  IconData get categoryIcon => AppConstants.categoryIcon(category);

  /// تاريخ الانتهاء الفعلي: الحقل الجديد، أو المستخرج من النص القديم.
  DateTime? get effectiveExpiry => expiryDate ?? parseLegacyExpiry(expiryText);

  /// عدد الأيام المتبقية حتى انتهاء الصلاحية (null إن كان التاريخ غير معروف).
  int? get daysToExpiry {
    final e = effectiveExpiry;
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
    final e = effectiveExpiry;
    if (e != null) return AppFormats.date(e);
    final t = expiryText?.trim();
    return (t == null || t.isEmpty) ? 'غير محدد' : t;
  }

  /// آخر موعد لاستلام الدواء المحجوز.
  DateTime? get reservationDeadline =>
      requestedAt?.add(const Duration(days: AppConstants.reservationDays));

  /// تجاوز المحتاج مهلة الاستلام.
  bool get isReservationOverdue {
    final d = reservationDeadline;
    return status == MedicineStatus.requested &&
        d != null &&
        DateTime.now().isAfter(d);
  }

  bool isDonatedBy(String uid) => donorId == uid;
  bool isRequestedBy(String uid) => recipientId == uid;

  /// هل يحق لهذا الصيدلي إدارة الدواء؟ صيدليته، أو دواء قديم غير مرتبط بصيدلية.
  bool isManagedBy(String pharmacistId) =>
      pharmacyId == pharmacistId || pharmacyId.isEmpty;

  static const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';

  /// استخراج تاريخ من نصوص الصلاحية القديمة مثل:
  /// 20/3/2026، 2026\3\1، 2026-03-01، 03/2027، 03/27.
  /// الصيغ التي بلا يوم تُعد منتهية في آخر يوم من الشهر.
  static DateTime? parseLegacyExpiry(String? text) {
    if (text == null) return null;
    var t = text.trim();
    if (t.isEmpty) return null;
    for (var i = 0; i < _arabicDigits.length; i++) {
      t = t.replaceAll(_arabicDigits[i], i.toString());
    }
    final parts = t
        .split(RegExp(r'[\\/\-.\s]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.any((p) => int.tryParse(p) == null)) return null;
    final n = parts.map(int.parse).toList();

    int fullYear(int y) => y < 100 ? 2000 + y : y;

    DateTime? build(int y, int m, int? d) {
      if (m < 1 || m > 12 || y < 2000 || y > 2100) return null;
      if (d == null) return DateTime(y, m + 1, 0);
      final date = DateTime(y, m, d);
      return date.month == m && date.day == d ? date : null;
    }

    if (n.length == 3) {
      if (parts[0].length == 4) return build(n[0], n[1], n[2]);
      return build(fullYear(n[2]), n[1], n[0]);
    }
    if (n.length == 2) {
      if (parts[0].length == 4) return build(n[0], n[1], null);
      return build(fullYear(n[1]), n[0], null);
    }
    return null;
  }

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
      pharmacyId: _str(d['pharmacyId']),
      pharmacyAddress: _str(d['pharmacyAddress']),
      pharmacyPhone: _str(d['pharmacyPhone']),
      pharmacyHours: _str(d['pharmacyHours']),
      batchNumber: _str(d['batchNumber']),
      requiresPrescription: d['requiresPrescription'] == true,
      hasPrescription: d['hasPrescription'] == true,
      rejectionReason: _str(d['rejectionReason']),
      rejectionNote: _str(d['rejectionNote']),
      reviewerName: _str(d['reviewerName']),
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
