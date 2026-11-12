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
import '../profile/profile_screen.dart';

/// لوحة الصيدلاني: مراجعة التبرعات الجديدة وقبولها أو رفضها.
class PharmacistHome extends StatefulWidget {
  const PharmacistHome({super.key, required this.user});
  final AppUser user;

  @override
  State<PharmacistHome> createState() => _PharmacistHomeState();
}

class _PharmacistHomeState extends State<PharmacistHome> {
  final Set<String> _busy = {};

  Future<void> _review(Medicine m, MedicineStatus status) async {
    if (status == MedicineStatus.rejected) {
      final ok = await showConfirmDialog(
        context,
        title: 'رفض الدواء',
        message: 'هل أنت متأكد من رفض "${m.name}"؟',
        confirmLabel: 'رفض',
        destructive: true,
        icon: Icons.cancel_outlined,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy.add(m.id));
    try {
      await MedicineService.instance.review(m.id, status);
      if (mounted) {
        AppSnack.success(
          context,
          status == MedicineStatus.approved
              ? 'تم قبول "${m.name}" وعرضه للمحتاجين'
              : 'تم رفض "${m.name}"',
        );
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(m.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تدقيق الأدوية'),
        actions: [
          IconButton(
            tooltip: 'حسابي',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(user: user)),
            ),
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: Colors.white,
              child: Text(
                user.initial,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<Medicine>>(
        stream: MedicineService.instance.pending(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(message: AppSnack.messageOf(snapshot.error!));
          }
          if (!snapshot.hasData) return const LoadingView();

          final list = snapshot.data!;
          return Column(
            children: [
              _Header(user: user, pendingCount: list.length),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.task_alt_rounded,
                        title: 'لا توجد أدوية بانتظار المراجعة',
                        subtitle: 'أحسنت! كل التبرعات تمت مراجعتها.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final m = list[i];
                          final busy = _busy.contains(m.id);
                          return MedicineCard(
                            medicine: m,
                            onTap: () => MedicineDetailsScreen.open(
                              context,
                              medicine: m,
                              user: user,
                            ),
                            footer: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person_outline_rounded,
                                      size: 16,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'المتبرع: ${m.donorName}'
                                        '${m.donorPhone.isEmpty ? '' : ' • ${m.donorPhone}'}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      AppFormats.timeAgo(m.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                if (m.isNearExpiry || m.isExpired) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    m.isExpired
                                        ? 'تنبيه: الدواء منتهي الصلاحية'
                                        : 'تنبيه: الصلاحية تنتهي خلال ${AppFormats.days(m.daysToExpiry!)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: m.isExpired
                                          ? AppColors.danger
                                          : AppColors.warning,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: busy
                                            ? null
                                            : () => _review(
                                                m,
                                                MedicineStatus.rejected,
                                              ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.danger,
                                          side: const BorderSide(
                                            color: AppColors.danger,
                                          ),
                                          minimumSize: const Size.fromHeight(
                                            44,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('رفض'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton.icon(
                                        onPressed: busy
                                            ? null
                                            : () => _review(
                                                m,
                                                MedicineStatus.approved,
                                              ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.success,
                                          minimumSize: const Size.fromHeight(
                                            44,
                                          ),
                                        ),
                                        icon: busy
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.check_rounded,
                                                size: 18,
                                              ),
                                        label: const Text('قبول'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.pendingCount});
  final AppUser user;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً د. ${user.displayName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pendingCount == 0
                      ? 'لا توجد تبرعات جديدة بانتظارك'
                      : '${AppFormats.medicines(pendingCount)} بانتظار مراجعتك',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '$pendingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
