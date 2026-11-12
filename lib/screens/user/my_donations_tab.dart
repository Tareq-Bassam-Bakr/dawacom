import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../models/medicine.dart';
import '../../services/medicine_service.dart';
import '../../widgets/common.dart';
import '../../widgets/medicine_card.dart';
import '../../widgets/status_chip.dart';
import '../medicine/medicine_details_screen.dart';

/// تبويب تبرعاتي: كل الأدوية التي أضافها المستخدم وحالتها.
class MyDonationsTab extends StatelessWidget {
  const MyDonationsTab({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Medicine>>(
      stream: MedicineService.instance.myDonations(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(message: AppSnack.messageOf(snapshot.error!));
        }
        if (!snapshot.hasData) return const LoadingView();

        final list = snapshot.data!;
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.volunteer_activism_outlined,
            title: 'لم تتبرع بأي دواء بعد',
            subtitle:
                'اضغط "تبرع الآن" لإضافة دواء فائض لديك، وسيراجعه الصيدلاني قبل عرضه للمحتاجين.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: list.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == 0) return _Summary(list);
            final m = list[i - 1];
            return MedicineCard(
              medicine: m,
              showStatus: true,
              footer: _footerFor(m),
              onTap: () =>
                  MedicineDetailsScreen.open(context, medicine: m, user: user),
            );
          },
        );
      },
    );
  }

  Widget? _footerFor(Medicine m) {
    final (IconData icon, String text, Color color) = switch (m.status) {
      MedicineStatus.pending => (
        Icons.hourglass_top_rounded,
        'بانتظار مراجعة الصيدلاني للتحقق من الدواء',
        AppColors.warning,
      ),
      MedicineStatus.approved => (
        Icons.check_circle_outline_rounded,
        'تمت الموافقة، الدواء معروض الآن للمحتاجين',
        AppColors.success,
      ),
      MedicineStatus.requested => (
        Icons.person_pin_circle_outlined,
        'محجوز باسم ${m.recipientName ?? 'محتاج'}، شكراً لعطائك',
        AppColors.info,
      ),
      MedicineStatus.rejected => (
        Icons.info_outline_rounded,
        'لم يُقبل الدواء، قد يكون قريب الانتهاء أو غير مطابق للشروط',
        AppColors.danger,
      ),
    };
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, color: color, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.list);
  final List<Medicine> list;

  @override
  Widget build(BuildContext context) {
    int count(MedicineStatus s) => list.where((m) => m.status == s).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final s in MedicineStatus.values)
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${count(s)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: statusColor(s),
                      height: 1.1,
                    ),
                  ),
                  Text(
                    s.label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
