import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../models/medicine.dart';
import '../../services/medicine_service.dart';
import '../../widgets/common.dart';
import '../../widgets/medicine_card.dart';
import '../medicine/medicine_details_screen.dart';

/// تبويب طلباتي: الأدوية التي حجزها المستخدم.
class MyRequestsTab extends StatelessWidget {
  const MyRequestsTab({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Medicine>>(
      stream: MedicineService.instance.myRequests(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(message: AppSnack.messageOf(snapshot.error!));
        }
        if (!snapshot.hasData) return const LoadingView();

        final list = snapshot.data!;
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'لم تطلب أي دواء بعد',
            subtitle:
                'تصفّح الأدوية المتاحة واطلب ما تحتاجه، وستجده هنا مع مكان الاستلام.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final m = list[i];
            return MedicineCard(
              medicine: m,
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.store_mall_directory_outlined,
                        size: 16,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'توجّه إلى ${m.pharmacy.isEmpty ? 'مكان الاستلام' : m.pharmacy} في ${m.city} لاستلام الدواء',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (m.status == MedicineStatus.requested &&
                      m.reservationDeadline != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      m.isReservationOverdue
                          ? 'تجاوزت مهلة الاستلام، قد تلغي الصيدلية الحجز'
                          : 'استلمه قبل ${AppFormats.date(m.reservationDeadline!)} • حُجز ${AppFormats.timeAgo(m.requestedAt)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: m.isReservationOverdue
                            ? AppColors.danger
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () =>
                  MedicineDetailsScreen.open(context, medicine: m, user: user),
            );
          },
        );
      },
    );
  }
}
