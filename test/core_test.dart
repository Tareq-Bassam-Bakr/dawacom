import 'package:dawacom/core/formats.dart';
import 'package:dawacom/core/utils.dart';
import 'package:dawacom/models/app_user.dart';
import 'package:dawacom/models/medicine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFormats', () {
    test('date uses Levantine month names', () {
      expect(AppFormats.date(DateTime(2027, 3, 12)), '12 آذار 2027');
    });

    test('days pluralization', () {
      expect(AppFormats.days(1), 'يوم واحد');
      expect(AppFormats.days(2), 'يومان');
      expect(AppFormats.days(5), '5 أيام');
      expect(AppFormats.days(40), '40 يوماً');
    });

    test('monthYear pads month', () {
      expect(AppFormats.monthYear(DateTime(2027, 3)), '03/2027');
    });
  });

  group('Validators', () {
    test('accepts Syrian mobile numbers', () {
      expect(Validators.phone('0931234567'), isNull);
      expect(Validators.phone('+963931234567'), isNull);
      expect(Validators.phone('0093 1234567'), isNotNull);
      expect(Validators.phone('12345'), isNotNull);
    });

    test('validates email', () {
      expect(Validators.email('user@example.com'), isNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('validates quantity', () {
      expect(Validators.quantity('3'), isNull);
      expect(Validators.quantity('0'), isNotNull);
      expect(Validators.quantity('abc'), isNotNull);
    });
  });

  group('Enums', () {
    test('MedicineStatus.fromValue falls back to pending', () {
      expect(MedicineStatus.fromValue('approved'), MedicineStatus.approved);
      expect(MedicineStatus.fromValue('weird'), MedicineStatus.pending);
    });

    test('UserRole.fromValue falls back to user', () {
      expect(UserRole.fromValue('pharmacist'), UserRole.pharmacist);
      expect(UserRole.fromValue(null), UserRole.user);
    });
  });
}
