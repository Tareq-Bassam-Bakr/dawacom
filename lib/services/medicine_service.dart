import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/formats.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../models/medicine.dart';

/// التعامل مع مجموعتي `medicines` و`prescriptions` في Firestore.
class MedicineService {
  MedicineService._();
  static final instance = MedicineService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('medicines');

  CollectionReference<Map<String, dynamic>> get _prescriptions =>
      _db.collection('prescriptions');

  static String prescriptionId(String medicineId, String recipientId) =>
      '${medicineId}_$recipientId';

  /// تحويل استعلام إلى قائمة مرتبة محلياً (لتجنب الحاجة لفهارس مركبة).
  Stream<List<Medicine>> _stream(
    Query<Map<String, dynamic>> query, {
    bool newestFirst = true,
    bool Function(Medicine m)? where,
  }) {
    return query.snapshots().map((snap) {
      var list = snap.docs.map(Medicine.fromDoc).toList();
      if (where != null) list = list.where(where).toList();
      list.sort((a, b) {
        final da = a.createdAt ?? DateTime.now();
        final db = b.createdAt ?? DateTime.now();
        return newestFirst ? db.compareTo(da) : da.compareTo(db);
      });
      return list;
    });
  }

  Query<Map<String, dynamic>> _byStatus(MedicineStatus s) =>
      _col.where('status', isEqualTo: s.value);

  /// الأدوية المتاحة للطلب، مع إخفاء المنتهية الصلاحية تلقائياً.
  Stream<List<Medicine>> available() =>
      _stream(_byStatus(MedicineStatus.approved), where: (m) => !m.isExpired);

  Stream<List<Medicine>> myDonations(String uid) =>
      _stream(_col.where('donorId', isEqualTo: uid));

  Stream<List<Medicine>> myRequests(String uid) =>
      _stream(_col.where('recipientId', isEqualTo: uid));

  /// هل يخص الدواء هذا الصيدلي؟ صيدليته، أو دواء قديم بلا صيدلية في محافظته.
  static bool belongsTo(
    Medicine m,
    AppUser pharmacist, {
    bool allCities = false,
  }) {
    if (m.pharmacyId == pharmacist.uid) return true;
    return m.pharmacyId.isEmpty && (allCities || m.city == pharmacist.city);
  }

  /// التبرعات بانتظار مراجعة هذا الصيدلي (الأقدم أولاً).
  Stream<List<Medicine>> pendingFor(
    AppUser pharmacist, {
    bool allCities = false,
  }) => _stream(
    _byStatus(MedicineStatus.pending),
    newestFirst: false,
    where: (m) => belongsTo(m, pharmacist, allCities: allCities),
  );

  /// الأدوية المحجوزة التي تنتظر أن يستلمها المحتاج من هذه الصيدلية.
  Stream<List<Medicine>> awaitingPickupFor(AppUser pharmacist) =>
      _byStatus(MedicineStatus.requested).snapshots().map((snap) {
        final list = snap.docs
            .map(Medicine.fromDoc)
            .where((m) => belongsTo(m, pharmacist))
            .toList();
        // المتجاوزة للمهلة أولاً، ثم الأقدم حجزاً.
        list.sort((a, b) {
          if (a.isReservationOverdue != b.isReservationOverdue) {
            return a.isReservationOverdue ? -1 : 1;
          }
          final da = a.requestedAt ?? DateTime.now();
          final db = b.requestedAt ?? DateTime.now();
          return da.compareTo(db);
        });
        return list;
      });

  /// الأدوية المتاحة في هذه الصيدلية المنتهية أو القريبة من الانتهاء.
  Stream<List<Medicine>> expiryAlertsFor(AppUser pharmacist) =>
      _byStatus(MedicineStatus.approved).snapshots().map((snap) {
        final list = snap.docs
            .map(Medicine.fromDoc)
            .where(
              (m) =>
                  belongsTo(m, pharmacist) && (m.isExpired || m.isNearExpiry),
            )
            .toList();
        list.sort(
          (a, b) => (a.daysToExpiry ?? 0).compareTo(b.daysToExpiry ?? 0),
        );
        return list;
      });

  /// متابعة دواء واحد (null إذا حُذف).
  Stream<Medicine?> watch(String id) => _col
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Medicine.fromDoc(d) : null);

  Future<int> countWhere(String field, Object value) async {
    final snap = await _col.where(field, isEqualTo: value).count().get();
    return snap.count ?? 0;
  }

  Map<String, dynamic> _pharmacyFields(AppUser pharmacy) => {
    'pharmacyId': pharmacy.uid,
    'pharmacy': pharmacy.pharmacyLabel,
    'pharmacyAddress': pharmacy.pharmacyAddress,
    'pharmacyPhone': pharmacy.phone,
    'pharmacyHours': pharmacy.pharmacyHours,
    'city': pharmacy.city,
  };

  /// إضافة تبرع جديد إلى صيدلية يختارها المتبرع، بحالة "قيد التدقيق".
  Future<void> add({
    required AppUser donor,
    required AppUser pharmacy,
    required String name,
    required String category,
    required int quantity,
    required DateTime expiryDate,
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
      ..._pharmacyFields(pharmacy),
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

  /// تصحيح بيانات الدواء من قبل الصيدلي أثناء المراجعة.
  Future<void> updateDetails(
    String id, {
    required String name,
    required String category,
    required int quantity,
    required DateTime expiryDate,
    required String batchNumber,
    required bool requiresPrescription,
  }) => _col.doc(id).update({
    'name': name.trim(),
    'nameLower': name.trim().toLowerCase(),
    'category': category,
    'quantity': quantity,
    'expiryDate': Timestamp.fromDate(expiryDate),
    'expiry': AppFormats.monthYear(expiryDate),
    'batchNumber': batchNumber.trim(),
    'requiresPrescription': requiresPrescription,
  });

  /// الحقول المشتركة لقرار الصيدلي. الدواء القديم بلا صيدلية يُنسب لصيدليته.
  Map<String, dynamic> _reviewFields(Medicine m, AppUser pharmacist) => {
    if (!m.hasPharmacy) ..._pharmacyFields(pharmacist),
    'pharmacyId': pharmacist.uid,
    'reviewerName': pharmacist.displayName,
    'reviewedAt': FieldValue.serverTimestamp(),
  };

  Future<void> approve(
    Medicine m,
    AppUser pharmacist, {
    required bool requiresPrescription,
  }) => _col.doc(m.id).update({
    ..._reviewFields(m, pharmacist),
    'status': MedicineStatus.approved.value,
    'requiresPrescription': requiresPrescription,
    'rejectionReason': '',
    'rejectionNote': '',
  });

  Future<void> reject(
    Medicine m,
    AppUser pharmacist, {
    required String reason,
    String note = '',
  }) => _col.doc(m.id).update({
    ..._reviewFields(m, pharmacist),
    'status': MedicineStatus.rejected.value,
    'rejectionReason': reason,
    'rejectionNote': note.trim(),
  });

  /// حجز الدواء باسم المحتاج ضمن معاملة لضمان عدم حجزه مرتين.
  /// إن كان الدواء يحتاج وصفة تُحفظ صورتها في مستند منفصل خاص.
  Future<void> request({
    required String medicineId,
    required AppUser recipient,
    Uint8List? prescription,
  }) {
    final ref = _col.doc(medicineId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const AppException('هذا الدواء لم يعد موجوداً');
      }
      final m = Medicine.fromDoc(snap);
      if (m.donorId == recipient.uid) {
        throw const AppException('لا يمكنك طلب دواء تبرعت به أنت');
      }
      if (m.status != MedicineStatus.approved) {
        throw const AppException('عذراً، تم حجز هذا الدواء للتو من شخص آخر');
      }
      if (m.isExpired) {
        throw const AppException('انتهت صلاحية هذا الدواء ولم يعد متاحاً');
      }
      if (m.requiresPrescription && prescription == null) {
        throw const AppException('هذا الدواء يحتاج صورة الوصفة الطبية');
      }
      if (prescription != null) {
        tx.set(_prescriptions.doc(prescriptionId(m.id, recipient.uid)), {
          'medicineId': m.id,
          'recipientId': recipient.uid,
          'pharmacyId': m.pharmacyId,
          'imageBase64': base64Encode(prescription),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      tx.update(ref, {
        'status': MedicineStatus.requested.value,
        'recipientId': recipient.uid,
        'recipientName': recipient.displayName,
        'recipientPhone': recipient.phone,
        'hasPrescription': prescription != null,
        'requestedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// إلغاء الحجز وإعادة الدواء متاحاً للآخرين.
  Future<void> cancelReservation(Medicine m) => _col.doc(m.id).update({
    'status': MedicineStatus.approved.value,
    'recipientId': null,
    'recipientName': null,
    'recipientPhone': null,
    'hasPrescription': false,
    'requestedAt': null,
  });

  /// صورة الوصفة التي أرفقها المحتاج (null إن لم توجد).
  Future<Uint8List?> prescription(Medicine m) async {
    final recipientId = m.recipientId;
    if (recipientId == null) return null;
    final d = await _prescriptions.doc(prescriptionId(m.id, recipientId)).get();
    final img = d.data()?['imageBase64'];
    if (img is! String || img.isEmpty) return null;
    return base64Decode(img);
  }
}
