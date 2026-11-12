import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formats.dart';
import '../models/medicine.dart';

Color statusColor(MedicineStatus status) => switch (status) {
  MedicineStatus.pending => AppColors.warning,
  MedicineStatus.approved => AppColors.success,
  MedicineStatus.requested => AppColors.info,
  MedicineStatus.rejected => AppColors.danger,
};

/// شارة حالة الدواء.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.compact = false});
  final MedicineStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: compact ? 13 : 15, color: color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// شارة الصلاحية: منتهي / قريب الانتهاء / تاريخ عادي.
class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge(this.medicine, {super.key});
  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String text;
    final days = medicine.daysToExpiry;

    if (medicine.isExpired) {
      color = AppColors.danger;
      text = 'منتهي الصلاحية';
    } else if (medicine.isNearExpiry) {
      color = AppColors.warning;
      text = 'ينتهي خلال ${AppFormats.days(days!)}';
    } else {
      color = AppColors.textMuted;
      text = 'ينتهي ${medicine.expiryLabel}';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.event_outlined, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
