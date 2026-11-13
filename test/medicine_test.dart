import 'package:dawacom/models/app_user.dart';
import 'package:dawacom/models/medicine.dart';
import 'package:dawacom/services/medicine_service.dart';
import 'package:flutter_test/flutter_test.dart';

Medicine med({
  String pharmacyId = '',
  String city = 'دمشق',
  MedicineStatus status = MedicineStatus.approved,
  DateTime? expiry,
  String? expiryText,
  DateTime? requestedAt,
}) => Medicine(
  id: 'm1',
  name: 'Test',
  category: 'أخرى',
  quantity: 1,
  pharmacy: '',
  city: city,
  status: status,
  donorId: 'donor',
  donorName: 'متبرع',
  pharmacyId: pharmacyId,
  expiryDate: expiry,
  expiryText: expiryText,
  requestedAt: requestedAt,
);

void main() {
  group('parseLegacyExpiry', () {
    test('day/month/year', () {
      expect(Medicine.parseLegacyExpiry('20/3/2026'), DateTime(2026, 3, 20));
      expect(Medicine.parseLegacyExpiry('11/11/2026'), DateTime(2026, 11, 11));
    });

    test('year-month-day with backslash and ISO', () {
      expect(Medicine.parseLegacyExpiry(r'2026\3\1'), DateTime(2026, 3, 1));
      expect(Medicine.parseLegacyExpiry('2026-03-01'), DateTime(2026, 3, 1));
    });

    test('month/year means end of month', () {
      expect(Medicine.parseLegacyExpiry('03/2027'), DateTime(2027, 3, 31));
      expect(Medicine.parseLegacyExpiry('02/28'), DateTime(2028, 2, 29));
    });

    test('Arabic-Indic digits', () {
      expect(Medicine.parseLegacyExpiry('٢٠/٣/٢٠٢٦'), DateTime(2026, 3, 20));
    });

    test('invalid text returns null', () {
      expect(Medicine.parseLegacyExpiry(''), isNull);
      expect(Medicine.parseLegacyExpiry('قريباً'), isNull);
      expect(Medicine.parseLegacyExpiry('31/2/2026'), isNull);
      expect(Medicine.parseLegacyExpiry('13/2026'), isNull);
    });

    test('legacy expired medicine is detected as expired', () {
      expect(med(expiryText: '20/3/2020').isExpired, isTrue);
      expect(med(expiryText: '20/3/2099').isExpired, isFalse);
    });
  });

  group('reservation', () {
    test('overdue after the reservation period', () {
      final old = med(
        status: MedicineStatus.requested,
        requestedAt: DateTime.now().subtract(const Duration(days: 4)),
      );
      final fresh = med(
        status: MedicineStatus.requested,
        requestedAt: DateTime.now().subtract(const Duration(hours: 5)),
      );
      expect(old.isReservationOverdue, isTrue);
      expect(fresh.isReservationOverdue, isFalse);
    });
  });

  group('belongsTo', () {
    const pharmacist = AppUser(
      uid: 'ph1',
      name: 'صيدلي',
      email: 'p@x.com',
      city: 'دمشق',
      role: UserRole.pharmacist,
    );

    test('own pharmacy medicines', () {
      expect(
        MedicineService.belongsTo(med(pharmacyId: 'ph1'), pharmacist),
        isTrue,
      );
      expect(
        MedicineService.belongsTo(med(pharmacyId: 'ph2'), pharmacist),
        isFalse,
      );
    });

    test('legacy medicines follow the governorate filter', () {
      final elsewhere = med(city: 'حلب');
      expect(MedicineService.belongsTo(med(), pharmacist), isTrue);
      expect(MedicineService.belongsTo(elsewhere, pharmacist), isFalse);
      expect(
        MedicineService.belongsTo(elsewhere, pharmacist, allCities: true),
        isTrue,
      );
    });
  });
}
