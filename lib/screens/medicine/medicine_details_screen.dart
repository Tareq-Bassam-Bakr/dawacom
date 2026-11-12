import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../models/medicine.dart';
import '../../services/medicine_service.dart';
import '../../widgets/common.dart';
import '../../widgets/medicine_image.dart';
import '../../widgets/status_chip.dart';

/// شاشة تفاصيل الدواء الكاملة، تتحدث مباشرة مع أي تغيير في حالته.
class MedicineDetailsScreen extends StatelessWidget {
  const MedicineDetailsScreen({
    super.key,
    required this.initial,
    required this.user,
  });

  final Medicine initial;
  final AppUser user;

  static Future<void> open(
    BuildContext context, {
    required Medicine medicine,
    required AppUser user,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicineDetailsScreen(initial: medicine, user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Medicine?>(
      stream: MedicineService.instance.watch(initial.id),
      initialData: initial,
      builder: (context, snapshot) {
        final m = snapshot.data;
        if (m == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('تفاصيل الدواء')),
            body: const EmptyState(
              icon: Icons.delete_outline_rounded,
              title: 'تم حذف هذا الدواء',
              subtitle: 'لم يعد هذا التبرع متاحاً.',
            ),
          );
        }
        return _DetailsBody(medicine: m, user: user);
      },
    );
  }
}

class _DetailsBody extends StatefulWidget {
  const _DetailsBody({required this.medicine, required this.user});
  final Medicine medicine;
  final AppUser user;

  @override
  State<_DetailsBody> createState() => _DetailsBodyState();
}

class _DetailsBodyState extends State<_DetailsBody> {
  bool _busy = false;

  Medicine get m => widget.medicine;
  AppUser get user => widget.user;

  Future<void> _request() async {
    final ok = await showConfirmDialog(
      context,
      title: 'تأكيد طلب الدواء',
      message:
          'هل أنت بحاجة فعلاً لدواء "${m.name}"؟\nسيُحجز باسمك ويمكنك استلامه من ${m.pharmacy.isEmpty ? 'مكان الاستلام' : m.pharmacy} في ${m.city}.',
      confirmLabel: 'نعم، أحتاجه',
      icon: Icons.volunteer_activism_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await MedicineService.instance.request(medicineId: m.id, recipient: user);
      if (mounted) {
        AppSnack.success(
          context,
          'تم حجز الدواء باسمك، توجّه للصيدلية لاستلامه',
        );
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(MedicineStatus status) async {
    if (status == MedicineStatus.rejected) {
      final ok = await showConfirmDialog(
        context,
        title: 'رفض الدواء',
        message:
            'هل أنت متأكد من رفض "${m.name}"؟ سيُعلم المتبرع بأن الدواء لم يُقبل.',
        confirmLabel: 'رفض',
        destructive: true,
        icon: Icons.cancel_outlined,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await MedicineService.instance.review(m.id, status);
      if (mounted) {
        AppSnack.success(
          context,
          status == MedicineStatus.approved
              ? 'تمت الموافقة، الدواء معروض الآن للمحتاجين'
              : 'تم رفض الدواء',
        );
      }
    } catch (e) {
      if (mounted) AppSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMine = m.isDonatedBy(user.uid);
    final isMyRequest = m.isRequestedBy(user.uid);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: m.hasImage ? 300 : 170,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: () => FullScreenImage.open(context, m),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MedicineImage(
                      medicine: m,
                      width: null,
                      height: null,
                      borderRadius: 0,
                    ),
                    if (m.hasImage)
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black38, Colors.transparent],
                            stops: [0, 0.4],
                          ),
                        ),
                      ),
                    if (m.hasImage)
                      PositionedDirectional(
                        bottom: 12,
                        end: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.zoom_in_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'تكبير',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          m.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(m.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(m.categoryIcon, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        m.category,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'أُضيف ${AppFormats.timeAgo(m.createdAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (isMyRequest) ...[
                    InfoBanner(
                      icon: Icons.assignment_turned_in_rounded,
                      text:
                          'هذا الدواء محجوز باسمك. توجّه إلى ${m.pharmacy.isEmpty ? 'مكان الاستلام' : m.pharmacy} في ${m.city} لاستلامه.',
                    ),
                    const SizedBox(height: 16),
                  ] else if (isMine) ...[
                    InfoBanner(
                      icon: Icons.volunteer_activism_rounded,
                      color: AppColors.primary,
                      text: _mineBannerText(m),
                    ),
                    const SizedBox(height: 16),
                  ] else if (m.isExpired) ...[
                    const InfoBanner(
                      icon: Icons.block_rounded,
                      color: AppColors.danger,
                      text: 'هذا الدواء منتهي الصلاحية ولا يجوز استخدامه.',
                    ),
                    const SizedBox(height: 16),
                  ],

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.4,
                    children: [
                      InfoTile(
                        icon: Icons.inventory_2_outlined,
                        label: 'الكمية',
                        value: AppFormats.boxes(m.quantity),
                      ),
                      InfoTile(
                        icon: Icons.event_outlined,
                        label: 'تاريخ الانتهاء',
                        value: m.expiryLabel,
                        color: m.isExpired
                            ? AppColors.danger
                            : m.isNearExpiry
                            ? AppColors.warning
                            : AppColors.primary,
                      ),
                      InfoTile(
                        icon: Icons.location_city_rounded,
                        label: 'المحافظة',
                        value: m.city,
                      ),
                      InfoTile(
                        icon: Icons.store_mall_directory_outlined,
                        label: 'مكان الاستلام',
                        value: m.pharmacy.isEmpty ? 'غير محدد' : m.pharmacy,
                      ),
                    ],
                  ),
                  if (m.daysToExpiry != null && !m.isExpired) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ExpiryBadge(m),
                    ),
                  ],

                  if (m.notes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const SectionTitle('ملاحظات المتبرع'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(m.notes, style: const TextStyle(height: 1.7)),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const SectionTitle('المتبرع'),
                  _PersonCard(
                    name: m.donorName,
                    subtitle: isMine ? 'أنت' : 'متبرع كريم',
                    phone: user.isPharmacist ? m.donorPhone : null,
                  ),

                  if (user.isPharmacist &&
                      m.status == MedicineStatus.requested) ...[
                    const SizedBox(height: 16),
                    const SectionTitle('المحتاج (حجز الدواء)'),
                    _PersonCard(
                      name: m.recipientName ?? 'محتاج',
                      subtitle: 'حجز ${AppFormats.timeAgo(m.requestedAt)}',
                      phone: m.recipientPhone,
                      color: AppColors.info,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _actionBar(isMine: isMine),
    );
  }

  String _mineBannerText(Medicine m) => switch (m.status) {
    MedicineStatus.pending => 'تبرعك قيد مراجعة الصيدلاني، سنعلمك فور قبوله.',
    MedicineStatus.approved => 'تبرعك معروض الآن للمحتاجين، شكراً لعطائك.',
    MedicineStatus.requested =>
      'تم حجز تبرعك باسم ${m.recipientName ?? 'محتاج'}. جزاك الله خيراً.',
    MedicineStatus.rejected =>
      'لم يُقبل هذا التبرع. قد يكون قريب الانتهاء أو غير مطابق للشروط.',
  };

  Widget? _actionBar({required bool isMine}) {
    Widget? content;

    if (user.isPharmacist) {
      if (m.status == MedicineStatus.pending) {
        content = Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'رفض',
                icon: Icons.close_rounded,
                color: AppColors.danger,
                loading: _busy,
                onPressed: () => _review(MedicineStatus.rejected),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: 'قبول الدواء',
                icon: Icons.check_rounded,
                color: AppColors.success,
                loading: _busy,
                onPressed: () => _review(MedicineStatus.approved),
              ),
            ),
          ],
        );
      }
    } else if (!isMine && m.status == MedicineStatus.approved && !m.isExpired) {
      content = PrimaryButton(
        label: 'طلب هذا الدواء',
        icon: Icons.volunteer_activism_rounded,
        loading: _busy,
        onPressed: _request,
      );
    }

    if (content == null) return null;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: content,
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.name,
    required this.subtitle,
    this.phone,
    this.color = AppColors.primary,
  });

  final String name;
  final String subtitle;
  final String? phone;
  final Color color;

  Future<void> _call(BuildContext context) async {
    final p = phone;
    if (p == null || p.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: p.replaceAll(RegExp(r'[\s\-()]'), ''));
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      await Clipboard.setData(ClipboardData(text: p));
      if (context.mounted) {
        AppSnack.success(context, 'تم نسخ الرقم: $p');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone != null && phone!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(
              name.isEmpty ? '؟' : name.characters.first,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  hasPhone ? phone! : subtitle,
                  textDirection: hasPhone ? TextDirection.ltr : null,
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (hasPhone)
            IconButton.filled(
              tooltip: 'اتصال',
              style: IconButton.styleFrom(backgroundColor: color),
              onPressed: () => _call(context),
              icon: const Icon(Icons.call_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }
}
