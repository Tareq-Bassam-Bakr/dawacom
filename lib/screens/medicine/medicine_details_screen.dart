import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../core/formats.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../models/medicine.dart';
import '../../services/image_service.dart';
import '../../services/medicine_service.dart';
import '../../widgets/common.dart';
import '../../widgets/medicine_image.dart';
import '../../widgets/pharmacy_card.dart';
import '../../widgets/review_sheets.dart';
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

  /// الصيدلي المسؤول عن هذا الدواء (صيدليته أو دواء قديم بلا صيدلية).
  bool get _isMyPharmacy => user.isPharmacist && m.isManagedBy(user.uid);

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) AppSnack.success(context, success);
    } catch (e) {
      if (mounted) AppSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- المحتاج ----------

  Future<Uint8List?> _pickPrescription() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'صورة الوصفة الطبية',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'هذا الدواء يُصرف بوصفة. صوّر الوصفة بوضوح، ولن يراها إلا الصيدلي.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('تصوير الوصفة'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return null;
    try {
      return await ImageService.pick(source);
    } catch (e) {
      if (mounted) AppSnack.error(context, e);
      return null;
    }
  }

  Future<void> _request() async {
    final ok = await showConfirmDialog(
      context,
      title: 'تأكيد طلب الدواء',
      message:
          'هل أنت بحاجة فعلاً لدواء "${m.name}"؟\nسيُحجز باسمك لمدة ${AppFormats.days(AppConstants.reservationDays)}، واستلامه من ${m.pharmacy.isEmpty ? 'الصيدلية' : m.pharmacy} في ${m.city}.'
          '${m.requiresPrescription ? '\n\nهذا الدواء يحتاج صورة الوصفة الطبية.' : ''}',
      confirmLabel: m.requiresPrescription ? 'إرفاق الوصفة' : 'نعم، أحتاجه',
      icon: Icons.volunteer_activism_rounded,
    );
    if (!ok || !mounted) return;

    Uint8List? prescription;
    if (m.requiresPrescription) {
      prescription = await _pickPrescription();
      if (prescription == null || !mounted) return;
    }

    await _run(
      () => MedicineService.instance.request(
        medicineId: m.id,
        recipient: user,
        prescription: prescription,
      ),
      'تم حجز الدواء باسمك، استلمه من الصيدلية خلال 3 أيام',
    );
  }

  // ---------- الصيدلي ----------

  Future<void> _edit() async {
    final saved = await showEditMedicineSheet(context, m);
    if (saved && mounted) AppSnack.success(context, 'تم حفظ التعديلات');
  }

  Future<void> _approve() async {
    final requiresPrescription = await showApproveDialog(context, m);
    if (requiresPrescription == null || !mounted) return;
    await _run(
      () => MedicineService.instance.approve(
        m,
        user,
        requiresPrescription: requiresPrescription,
      ),
      'تمت الموافقة، الدواء معروض الآن للمحتاجين',
    );
  }

  Future<void> _reject() async {
    final input = await showRejectSheet(context, m);
    if (input == null || !mounted) return;
    await _run(
      () => MedicineService.instance.reject(
        m,
        user,
        reason: input.reason,
        note: input.note,
      ),
      'تم رفض الدواء وإبلاغ المتبرع بالسبب',
    );
  }

  Future<void> _cancelReservation() async {
    final ok = await showConfirmDialog(
      context,
      title: m.isReservationOverdue ? 'إعادة إتاحة الدواء' : 'إلغاء الحجز',
      message:
          'سيُلغى حجز ${m.recipientName ?? 'المحتاج'} ويعود "${m.name}" متاحاً للآخرين.',
      confirmLabel: 'إلغاء الحجز',
      destructive: true,
      icon: Icons.event_busy_rounded,
    );
    if (!ok || !mounted) return;
    await _run(
      () => MedicineService.instance.cancelReservation(m),
      'تم إلغاء الحجز، والدواء متاح من جديد',
    );
  }

  Future<void> _showPrescription() async {
    setState(() => _busy = true);
    try {
      final bytes = await MedicineService.instance.prescription(m);
      if (!mounted) return;
      if (bytes == null) {
        AppSnack.show(context, 'لا توجد وصفة مرفقة', error: true);
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              title: Text('وصفة ${m.recipientName ?? ''}'),
            ),
            body: Center(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) AppSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- الواجهة ----------

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
                  _titleRow(),
                  const SizedBox(height: 16),
                  ..._banners(isMine: isMine, isMyRequest: isMyRequest),
                  _infoGrid(),
                  if (m.daysToExpiry != null && !m.isExpired) ...[
                    const SizedBox(height: 10),
                    ExpiryBadge(m),
                  ],
                  const SizedBox(height: 20),
                  const SectionTitle('مكان الاستلام'),
                  MedicinePharmacyCard(medicine: m),
                  if (m.notes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const SectionTitle('ملاحظات المتبرع'),
                    _box(Text(m.notes, style: const TextStyle(height: 1.7))),
                  ],
                  const SizedBox(height: 20),
                  const SectionTitle('المتبرع'),
                  _PersonCard(
                    name: m.donorName,
                    subtitle: isMine ? 'أنت' : 'متبرع كريم',
                    phone: _isMyPharmacy ? m.donorPhone : null,
                  ),
                  if (_isMyPharmacy &&
                      m.status == MedicineStatus.requested) ...[
                    const SizedBox(height: 16),
                    const SectionTitle('المحتاج'),
                    _PersonCard(
                      name: m.recipientName ?? 'محتاج',
                      subtitle: 'حجز ${AppFormats.timeAgo(m.requestedAt)}',
                      phone: m.recipientPhone,
                      color: AppColors.info,
                    ),
                    if (m.hasPrescription) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _showPrescription,
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: const Text('عرض الوصفة الطبية'),
                      ),
                    ],
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

  Widget _titleRow() {
    return Column(
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
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
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
              ],
            ),
            if (m.requiresPrescription)
              const _Tag(
                icon: Icons.receipt_long_rounded,
                text: 'يحتاج وصفة طبية',
                color: AppColors.info,
              ),
            Text(
              'أُضيف ${AppFormats.timeAgo(m.createdAt)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _banners({required bool isMine, required bool isMyRequest}) {
    Widget? banner;

    if (user.isPharmacist && _isMyPharmacy && !user.verified) {
      banner = const InfoBanner(
        icon: Icons.hourglass_top_rounded,
        color: AppColors.warning,
        text:
            'حسابك قيد التوثيق. تستطيع مراجعة التفاصيل، لكن القبول والرفض يُفعّلان بعد توثيق إدارة المنصة.',
      );
    } else if (isMyRequest && m.status == MedicineStatus.requested) {
      final deadline = m.reservationDeadline;
      banner = m.isReservationOverdue
          ? const InfoBanner(
              icon: Icons.timer_off_rounded,
              color: AppColors.danger,
              text:
                  'تجاوزت مهلة الاستلام. قد تلغي الصيدلية حجزك في أي وقت، توجّه إليها أو اتصل بها.',
            )
          : InfoBanner(
              icon: Icons.assignment_turned_in_rounded,
              text:
                  'هذا الدواء محجوز باسمك. استلمه من ${m.pharmacy.isEmpty ? 'الصيدلية' : m.pharmacy}'
                  '${deadline == null ? ' خلال 3 أيام' : ' قبل ${AppFormats.date(deadline)}'}.',
            );
    } else if (m.status == MedicineStatus.rejected &&
        (isMine || _isMyPharmacy)) {
      banner = InfoBanner(
        icon: Icons.info_outline_rounded,
        color: AppColors.danger,
        text: [
          'سبب الرفض: ${m.rejectionReason.isEmpty ? 'غير محدد' : m.rejectionReason}',
          if (m.rejectionNote.isNotEmpty) 'ملاحظة الصيدلي: ${m.rejectionNote}',
        ].join('\n'),
      );
    } else if (isMine) {
      banner = InfoBanner(
        icon: Icons.volunteer_activism_rounded,
        color: AppColors.primary,
        text: switch (m.status) {
          MedicineStatus.pending =>
            'سلّم الدواء لـ ${m.pharmacy.isEmpty ? 'الصيدلية' : m.pharmacy} ليفحصه الصيدلي ويعرضه للمحتاجين.',
          MedicineStatus.approved =>
            'تبرعك معروض الآن للمحتاجين، شكراً لعطائك.',
          MedicineStatus.requested =>
            'تم حجز تبرعك باسم ${m.recipientName ?? 'محتاج'}. جزاك الله خيراً.',
          MedicineStatus.rejected => '',
        },
      );
    } else if (m.isExpired) {
      banner = const InfoBanner(
        icon: Icons.block_rounded,
        color: AppColors.danger,
        text: 'هذا الدواء منتهي الصلاحية ولا يجوز استخدامه.',
      );
    }

    return banner == null ? const [] : [banner, const SizedBox(height: 16)];
  }

  Widget _infoGrid() {
    final tiles = [
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
        icon: Icons.qr_code_rounded,
        label: 'رقم التشغيلة',
        value: m.batchNumber.isEmpty ? 'غير مسجّل' : m.batchNumber,
      ),
      if (m.reviewerName.isNotEmpty)
        InfoTile(
          icon: Icons.verified_user_outlined,
          label: 'راجعه',
          value: 'د. ${m.reviewerName}',
          color: AppColors.success,
        ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: tiles,
    );
  }

  Widget _box(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget? _actionBar({required bool isMine}) {
    Widget? content;

    if (_isMyPharmacy) {
      final canAct = user.verified && !_busy;
      if (m.status == MedicineStatus.pending) {
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canAct ? _edit : null,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('تصحيح البيانات'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'رفض',
                    icon: Icons.close_rounded,
                    color: AppColors.danger,
                    loading: _busy,
                    onPressed: canAct ? _reject : null,
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
                    onPressed: canAct ? _approve : null,
                  ),
                ),
              ],
            ),
          ],
        );
      } else if (m.status == MedicineStatus.requested) {
        content = PrimaryButton(
          label: m.isReservationOverdue ? 'إعادة إتاحة الدواء' : 'إلغاء الحجز',
          icon: Icons.event_busy_rounded,
          color: m.isReservationOverdue ? AppColors.warning : AppColors.danger,
          loading: _busy,
          onPressed: canAct ? _cancelReservation : null,
        );
      }
    } else if (!user.isPharmacist &&
        !isMine &&
        m.status == MedicineStatus.approved &&
        !m.isExpired) {
      content = PrimaryButton(
        label: m.requiresPrescription
            ? 'طلب الدواء (يحتاج وصفة)'
            : 'طلب هذا الدواء',
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

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
              onPressed: () => callPhone(context, phone!),
              icon: const Icon(Icons.call_rounded, color: Colors.white),
            ),
        ],
      ),
    );
  }
}
