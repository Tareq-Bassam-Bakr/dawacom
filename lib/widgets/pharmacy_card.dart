import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../models/medicine.dart';
import '../services/user_service.dart';

/// شارة حالة توثيق الصيدلية.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, required this.verified, this.onDark = false});
  final bool verified;

  /// فوق خلفية ملوّنة (مثل الشريط الأخضر) تُعرض الشارة بخلفية بيضاء.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: onDark ? Colors.white : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.hourglass_top_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'موثّقة' : 'قيد التوثيق',
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة معلومات الصيدلية (الاسم، العنوان، الدوام، الهاتف).
class PharmacyCard extends StatelessWidget {
  const PharmacyCard({
    super.key,
    required this.name,
    required this.city,
    this.address = '',
    this.hours = '',
    this.phone = '',
    this.verified,
    this.selected = false,
    this.onTap,
  });

  /// بطاقة لصيدلية مسجّلة في المنصة.
  factory PharmacyCard.fromUser(
    AppUser p, {
    bool selected = false,
    VoidCallback? onTap,
  }) => PharmacyCard(
    name: p.pharmacyLabel,
    city: p.city,
    address: p.pharmacyAddress,
    hours: p.pharmacyHours,
    phone: p.phone,
    verified: p.verified,
    selected: selected,
    onTap: onTap,
  );

  final String name;
  final String city;
  final String address;
  final String hours;
  final String phone;

  /// null يعني أن حالة التوثيق غير معروفة (سجل قديم).
  final bool? verified;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_pharmacy_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (verified != null) ...[
                          const SizedBox(width: 6),
                          VerifiedBadge(verified: verified!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    _Line(
                      Icons.place_outlined,
                      address.isEmpty ? city : '$address، $city',
                    ),
                    if (hours.isNotEmpty) _Line(Icons.schedule_rounded, hours),
                    if (phone.isNotEmpty)
                      _Line(Icons.phone_outlined, phone, ltr: true),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: AppColors.primary)
              else if (onTap == null && phone.isNotEmpty)
                IconButton.filled(
                  tooltip: 'اتصال بالصيدلية',
                  onPressed: () => callPhone(context, phone),
                  icon: const Icon(Icons.call_rounded, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text, {this.ltr = false});
  final IconData icon;
  final String text;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              textDirection: ltr ? TextDirection.ltr : null,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة صيدلية الدواء ببياناتها الحية، مع الرجوع لما حُفظ في الدواء.
class MedicinePharmacyCard extends StatelessWidget {
  const MedicinePharmacyCard({super.key, required this.medicine});
  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final m = medicine;
    final snapshot = PharmacyCard(
      name: m.pharmacy.isEmpty ? 'مكان الاستلام غير محدد' : m.pharmacy,
      city: m.city,
      address: m.pharmacyAddress,
      hours: m.pharmacyHours,
      phone: m.pharmacyPhone,
    );
    if (!m.hasPharmacy) return snapshot;
    return StreamBuilder<AppUser?>(
      stream: UserService.instance.watch(m.pharmacyId),
      builder: (context, s) {
        final p = s.data;
        return p == null ? snapshot : PharmacyCard.fromUser(p);
      },
    );
  }
}
