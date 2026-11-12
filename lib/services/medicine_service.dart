import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/formats.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../models/medicine.dart';

/// التعامل مع مجموعة `medicines` في Firestore.
class MedicineService {
  MedicineService._();
  static final instance = MedicineService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('medicines');

  /// تحويل استعلام إلى قائمة مرتبة محلياً (لتجنب الحاجة لفهارس مركبة).
  Stream<List<Medicine>> _stream(
    Query<Map<String, dynamic>> query, {
    bool newestFirst = true,
  }) {
    return query.snapshots().map((snap) {
      final list = snap.docs.map(Medicine.fromDoc).toList();
      list.sort((a, b) {
        final da = a.createdAt ?? DateTime.now();
        final db = b.createdAt ?? DateTime.now();
        return newestFirst ? db.compareTo(da) : da.compareTo(db);
      });
      return list;
    });
  }

  /// الأدوية المقبولة والمتاحة للطلب.
  Stream<List<Medicine>> available() =>
      _stream(_col.where('status', isEqualTo: MedicineStatus.approved.value));

  /// الأدوية بانتظار تدقيق الصيدلاني (الأقدم أولاً).
  Stream<List<Medicine>> pending() => _stream(
    _col.where('status', isEqualTo: MedicineStatus.pending.value),
    newestFirst: false,
  );

  Stream<List<Medicine>> myDonations(String uid) =>
      _stream(_col.where('donorId', isEqualTo: uid));

  Stream<List<Medicine>> myRequests(String uid) =>
      _stream(_col.where('recipientId', isEqualTo: uid));

  /// متابعة دواء واحد (null إذا حُذف).
  Stream<Medicine?> watch(String id) => _col
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Medicine.fromDoc(d) : null);

  Future<int> countWhere(String field, Object value) async {
    final snap = await _col.where(field, isEqualTo: value).count().get();
    return snap.count ?? 0;
  }

  /// إضافة تبرع جديد بحالة "قيد التدقيق".
  Future<void> add({
    required AppUser donor,
    required String name,
    required String category,
    required int quantity,
    required DateTime expiryDate,
    required String pharmacy,
    required String city,
    String notes = '',
    Uint8List? imageBytes,
  }) {
    return _col.add({
      'name': name.trim(),
      'nameLower': name.trim().toLowerCase(),
      'category': category,
      'quantity': quantity,
      'expiryDate': Timestamp.fromDate(expiryDate),
      // يُحفظ أيضاً كنص للتوافق مع الإصدار السابق.
      'expiry': AppFormats.monthYear(expiryDate),
      'pharmacy': pharmacy.trim(),
      'city': city,
      'notes': notes.trim(),
      'imageBase64': imageBytes == null ? null : base64Encode(imageBytes),
      'status': MedicineStatus.pending.value,
      'donorId': donor.uid,
      'donorName': donor.displayName,
      'donorPhone': donor.phone,
      'recipientId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// قبول أو رفض الدواء من قبل الصيدلاني.
  Future<void> review(String id, MedicineStatus status) => _col.doc(id).update({
    'status': status.value,
    'reviewedAt': FieldValue.serverTimestamp(),
  });

  /// حجز الدواء باسم المحتاج ضمن معاملة لضمان عدم حجزه مرتين.
  Future<void> request({
    required String medicineId,
    required AppUser recipient,
  }) {
    final ref = _col.doc(medicineId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const AppException('هذا الدواء لم يعد موجوداً');
      }
      final data = snap.data()!;
      if (data['donorId'] == recipient.uid) {
        throw const AppException('لا يمكنك طلب دواء تبرعت به أنت');
      }
      if (data['status'] != MedicineStatus.approved.value) {
        throw const AppException('عذراً، تم حجز هذا الدواء للتو من شخص آخر');
      }
      tx.update(ref, {
        'status': MedicineStatus.requested.value,
        'recipientId': recipient.uid,
        'recipientName': recipient.displayName,
        'recipientPhone': recipient.phone,
        'requestedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
