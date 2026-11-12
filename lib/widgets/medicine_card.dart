import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formats.dart';
import '../models/medicine.dart';
import 'medicine_image.dart';
import 'status_chip.dart';

/// بطاقة الدواء المستخدمة في كل القوائم.
class MedicineCard extends StatelessWidget {
  const MedicineCard({
    super.key,
    required this.medicine,
    this.onTap,
    this.showStatus = false,
    this.footer,
  });

  final Medicine medicine;
  final VoidCallback? onTap;
  final bool showStatus;

  /// محتوى إضافي أسفل البطاقة (أزرار، معلومات تواصل...).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final m = medicine;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MedicineImage(medicine: m, width: 86, height: 86),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                m.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (showStatus) ...[
                              const SizedBox(width: 6),
                              StatusChip(m.status, compact: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        _IconText(m.categoryIcon, m.category),
                        const SizedBox(height: 2),
                        _IconText(
                          Icons.place_outlined,
                          m.pharmacy.isEmpty
                              ? m.city
                              : '${m.pharmacy} • ${m.city}',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Flexible(child: ExpiryBadge(m)),
                            const SizedBox(width: 10),
                            _QuantityPill(m.quantity),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (footer != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _QuantityPill extends StatelessWidget {
  const _QuantityPill(this.quantity);
  final int quantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        AppFormats.boxes(quantity),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}
