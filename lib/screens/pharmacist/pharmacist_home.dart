import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../models/medicine.dart';
import '../../services/medicine_service.dart';
import '../../widgets/common.dart';
import '../../widgets/medicine_card.dart';
import '../../widgets/pharmacy_card.dart';
import '../../widgets/review_sheets.dart';
import '../medicine/medicine_details_screen.dart';
import '../profile/profile_screen.dart';

/// لوحة الصيدلي: مراجعة التبرعات، متابعة الحجوزات، وتنبيهات الصلاحية.
class PharmacistHome extends StatefulWidget {
  const PharmacistHome({super.key, required this.user});
  final AppUser user;

  @override
  State<PharmacistHome> createState() => _PharmacistHomeState();
}

/// آخر حالة لقائمة يتابعها الصيدلي.
class _Feed {
  List<Medicine>? items;
  Object? error;
  StreamSubscription<List<Medicine>>? sub;

  void listen(Stream<List<Medicine>> stream, VoidCallback onChange) {
    sub?.cancel();
    items = null;
    error = null;
    sub = stream.listen(
      (v) {
        items = v;
        error = null;
        onChange();
      },
      onError: (Object e) {
        error = e;
        onChange();
      },
    );
  }

  void dispose() => sub?.cancel();
}

class _PharmacistHomeState extends State<PharmacistHome> {
  int _index = 0;
  bool _allCities = false;
  final Set<String> _busy = {};

  final _pending = _Feed();
  final _pickup = _Feed();
  final _expiry = _Feed();

  AppUser get user => widget.user;
  final _service = MedicineService.instance;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant PharmacistHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    // إعادة الاشتراك إن تغيّرت محافظة الصيدلية من الملف الشخصي.
    if (oldWidget.user.city != user.city) _subscribe();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _subscribe() {
    _pending.listen(_service.pendingFor(user, allCities: _allCities), _refresh);
    _pickup.listen(_service.awaitingPickupFor(user), _refresh);
    _expiry.listen(_service.expiryAlertsFor(user), _refresh);
  }

  @override
  void dispose() {
    _pending.dispose();
    _pickup.dispose();
    _expiry.dispose();
    super.dispose();
  }

  void _toggleAllCities(bool v) {
    setState(() => _allCities = v);
    _pending.listen(_service.pendingFor(user, allCities: v), _refresh);
  }

  void _open(Medicine m) =>
      MedicineDetailsScreen.open(context, medicine: m, user: user);

  Future<void> _act(
    Medicine m,
    Future<void> Function() action,
    String ok,
  ) async {
    setState(() => _busy.add(m.id));
    try {
      await action();
      if (mounted) AppSnack.success(context, ok);
    } catch (e) {
      if (mounted) AppSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(m.id));
    }
  }

  Future<void> _approve(Medicine m) async {
    final rx = await showApproveDialog(context, m);
    if (rx == null || !mounted) return;
    await _act(
      m,
      () => _service.approve(m, user, requiresPrescription: rx),
      'تم قبول "${m.name}" وعرضه للمحتاجين',
    );
  }

  Future<void> _reject(Medicine m) async {
    final input = await showRejectSheet(context, m);
    if (input == null || !mounted) return;
    await _act(
      m,
      () => _service.reject(m, user, reason: input.reason, note: input.note),
      'تم رفض "${m.name}" وإبلاغ المتبرع بالسبب',
    );
  }

  Future<void> _cancelReservation(Medicine m) async {
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
    await _act(
      m,
      () => _service.cancelReservation(m),
      'تم إلغاء الحجز، والدواء متاح من جديد',
    );
  }

  static const _titles = [
    'مراجعة التبرعات',
    'بانتظار الاستلام',
    'تنبيهات الصلاحية',
    'حسابي',
  ];

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pending.items?.length ?? 0;
    final overdueCount =
        _pickup.items?.where((m) => m.isReservationOverdue).length ?? 0;
    final pickupCount = _pickup.items?.length ?? 0;
    final expiryCount = _expiry.items?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: Column(
        children: [
          if (_index != 3)
            _Header(
              user: user,
              pending: pendingCount,
              pickup: pickupCount,
              expiry: expiryCount,
            ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                _reviewTab(),
                _pickupTab(),
                _expiryTab(),
                ProfileView(user: user),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Badge.count(
              count: pendingCount,
              isLabelVisible: pendingCount > 0,
              child: const Icon(Icons.fact_check_outlined),
            ),
            selectedIcon: const Icon(Icons.fact_check_rounded),
            label: 'المراجعة',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: overdueCount > 0 ? overdueCount : pickupCount,
              isLabelVisible: pickupCount > 0,
              backgroundColor: overdueCount > 0 ? AppColors.danger : null,
              child: const Icon(Icons.inventory_outlined),
            ),
            selectedIcon: const Icon(Icons.inventory_rounded),
            label: 'الاستلام',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: expiryCount,
              isLabelVisible: expiryCount > 0,
              backgroundColor: AppColors.warning,
              child: const Icon(Icons.event_note_outlined),
            ),
            selectedIcon: const Icon(Icons.event_note_rounded),
            label: 'الصلاحية',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }

  /// غلاف موحد لحالات التحميل والخطأ والقائمة الفارغة.
  Widget _feedView(
    _Feed feed, {
    required Widget empty,
    required Widget Function(List<Medicine> items) builder,
  }) {
    if (feed.error != null) {
      return ErrorView(message: AppSnack.messageOf(feed.error!));
    }
    final items = feed.items;
    if (items == null) return const LoadingView();
    if (items.isEmpty) return empty;
    return builder(items);
  }

  // ---------- المراجعة ----------

  Widget _reviewTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'التبرعات القديمة غير المرتبطة بصيدلية تظهر من:',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.primary,
                  selectedForegroundColor: Colors.white,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textDark,
                  side: const BorderSide(color: AppColors.border),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.location_on_outlined, size: 18),
                    label: Text('محافظتي (${user.city})'),
                  ),
                  const ButtonSegment(
                    value: true,
                    icon: Icon(Icons.public_rounded, size: 18),
                    label: Text('كل المحافظات'),
                  ),
                ],
                selected: {_allCities},
                onSelectionChanged: (s) => _toggleAllCities(s.first),
              ),
            ],
          ),
        ),
        Expanded(
          child: _feedView(
            _pending,
            empty: const EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'لا توجد تبرعات بانتظار المراجعة',
              subtitle: 'ستظهر هنا التبرعات التي يختار أصحابها صيدليتك.',
            ),
            builder: (items) => ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _reviewCard(items[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _reviewCard(Medicine m) {
    final busy = _busy.contains(m.id);
    final canAct = user.verified && !busy;
    final days = m.daysToExpiry;

    return MedicineCard(
      medicine: m,
      onTap: () => _open(m),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FooterLine(
            icon: Icons.person_outline_rounded,
            text:
                'المتبرع: ${m.donorName}${m.donorPhone.isEmpty ? '' : ' • ${m.donorPhone}'}',
            trailing: AppFormats.timeAgo(m.createdAt),
          ),
          if (!m.hasPharmacy)
            const _FooterLine(
              icon: Icons.history_rounded,
              text: 'تبرع قديم بلا صيدلية، سيُنسب لصيدليتك عند مراجعته',
              color: AppColors.info,
            ),
          if (m.isExpired || (days != null && days < 180))
            _FooterLine(
              icon: Icons.warning_amber_rounded,
              text: m.isExpired
                  ? 'منتهي الصلاحية'
                  : 'الصلاحية ${AppFormats.days(days!)} فقط (أقل من 6 أشهر)',
              color: m.isExpired ? AppColors.danger : AppColors.warning,
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canAct ? () => _reject(m) : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('رفض'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: canAct ? () => _approve(m) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('قبول'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- بانتظار الاستلام ----------

  Widget _pickupTab() {
    return _feedView(
      _pickup,
      empty: const EmptyState(
        icon: Icons.inventory_outlined,
        title: 'لا توجد حجوزات بانتظار الاستلام',
        subtitle:
            'عندما يحجز محتاج دواءً من صيدليتك سيظهر هنا مع بيانات التواصل.',
      ),
      builder: (items) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final m = items[i];
          final deadline = m.reservationDeadline;
          final busy = _busy.contains(m.id);
          return MedicineCard(
            medicine: m,
            onTap: () => _open(m),
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.info.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.info,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.recipientName ?? 'محتاج',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if ((m.recipientPhone ?? '').isNotEmpty)
                            Text(
                              m.recipientPhone!,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if ((m.recipientPhone ?? '').isNotEmpty)
                      IconButton.filledTonal(
                        tooltip: 'اتصال بالمحتاج',
                        onPressed: () => callPhone(context, m.recipientPhone!),
                        icon: const Icon(Icons.call_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _FooterLine(
                  icon: m.isReservationOverdue
                      ? Icons.timer_off_rounded
                      : Icons.timer_outlined,
                  text: m.isReservationOverdue
                      ? 'تجاوز مهلة الاستلام (${deadline == null ? '' : AppFormats.date(deadline)})'
                      : 'آخر موعد للاستلام: ${deadline == null ? '—' : AppFormats.date(deadline)}',
                  color: m.isReservationOverdue
                      ? AppColors.danger
                      : AppColors.textMuted,
                ),
                if (m.requiresPrescription)
                  _FooterLine(
                    icon: Icons.receipt_long_rounded,
                    text: m.hasPrescription
                        ? 'أرفق الوصفة الطبية، راجعها قبل التسليم'
                        : 'يحتاج وصفة طبية ولم تُرفق',
                    color: m.hasPrescription
                        ? AppColors.info
                        : AppColors.warning,
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: user.verified && !busy
                      ? () => _cancelReservation(m)
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: m.isReservationOverdue
                        ? AppColors.warning
                        : AppColors.danger,
                    side: BorderSide(
                      color: m.isReservationOverdue
                          ? AppColors.warning
                          : AppColors.danger,
                    ),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.event_busy_rounded, size: 18),
                  label: Text(
                    m.isReservationOverdue
                        ? 'إعادة إتاحة الدواء'
                        : 'إلغاء الحجز',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------- الصلاحية ----------

  Widget _expiryTab() {
    return _feedView(
      _expiry,
      empty: const EmptyState(
        icon: Icons.event_available_rounded,
        title: 'لا توجد أدوية قريبة من الانتهاء',
        subtitle:
            'تظهر هنا الأدوية المتاحة في صيدليتك التي يتبقى على انتهائها شهران أو أقل.',
      ),
      builder: (items) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i == 0) {
            return const InfoBanner(
              icon: Icons.visibility_off_outlined,
              color: AppColors.warning,
              text:
                  'الأدوية المنتهية مخفية تلقائياً عن المحتاجين. القريبة من الانتهاء ما زالت معروضة، فقدّمها لمن يحتاجها أولاً.',
            );
          }
          final m = items[i - 1];
          return MedicineCard(medicine: m, onTap: () => _open(m));
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.pending,
    required this.pickup,
    required this.expiry,
  });

  final AppUser user;
  final int pending;
  final int pickup;
  final int expiry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.pharmacyLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'د. ${user.displayName} • ${user.city}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              VerifiedBadge(verified: user.verified),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _HeaderStat(value: pending, label: 'بانتظار المراجعة'),
              _HeaderStat(value: pickup, label: 'بانتظار الاستلام'),
              _HeaderStat(value: expiry, label: 'قريبة الانتهاء'),
            ],
          ),
          if (!user.verified) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'حسابك قيد التوثيق. ستتحقق إدارة المنصة من رقم ترخيصك، وبعدها تستطيع قبول التبرعات وإدارة الحجوزات.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterLine extends StatelessWidget {
  const _FooterLine({
    required this.icon,
    required this.text,
    this.color = AppColors.textMuted,
    this.trailing,
  });

  final IconData icon;
  final String text;
  final Color color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: color,
                fontWeight: color == AppColors.textMuted
                    ? FontWeight.w400
                    : FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}
