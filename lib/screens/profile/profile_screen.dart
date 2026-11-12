import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../models/medicine.dart';
import '../../services/auth_service.dart';
import '../../services/medicine_service.dart';
import '../../services/user_service.dart';
import '../../widgets/common.dart';

/// شاشة الملف الشخصي كاملة (مع AppBar) — تُستخدم عند فتحها كصفحة مستقلة.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ProfileView(user: user),
    );
  }
}

/// محتوى الملف الشخصي — يُضمَّن داخل التبويبات أو داخل ProfileScreen.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key, required this.user});
  final AppUser user;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late String _city;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _phone = TextEditingController(text: widget.user.phone);
    _city = AppConstants.cities.contains(widget.user.city)
        ? widget.user.city
        : AppConstants.cities.first;
  }

  @override
  void didUpdateWidget(covariant ProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // تحديث الحقول إن تغيّر المستخدم من الخارج ولم يكن يعدّل حالياً.
    if (oldWidget.user.uid != widget.user.uid) {
      _name.text = widget.user.name;
      _phone.text = widget.user.phone;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _name.text.trim() != widget.user.name.trim() ||
      _phone.text.trim() != widget.user.phone.trim() ||
      _city != widget.user.city;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await UserService.instance.updateProfile(
        widget.user.uid,
        name: _name.text,
        phone: _phone.text,
        city: _city,
      );
      if (mounted) AppSnack.success(context, 'تم حفظ بياناتك بنجاح');
    } catch (e) {
      if (mounted) AppSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showConfirmDialog(
      context,
      title: 'تسجيل الخروج',
      message: 'هل تريد تسجيل الخروج من حسابك؟',
      confirmLabel: 'خروج',
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (!ok || !mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await AuthService.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(user: user),
              const SizedBox(height: 16),
              _Stats(user: user),
              const SizedBox(height: 20),
              const SectionTitle('بياناتي'),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: Validators.name,
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: user.email,
                readOnly: true,
                enabled: false,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email_outlined),
                  helperText: 'لا يمكن تغيير البريد الإلكتروني',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  hintText: '09xxxxxxxx',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: Validators.phone,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _city,
                decoration: const InputDecoration(
                  labelText: 'المحافظة',
                  prefixIcon: Icon(Icons.location_city_rounded),
                ),
                items: AppConstants.cities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _city = v ?? _city),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'حفظ التعديلات',
                icon: Icons.save_outlined,
                loading: _saving,
                onPressed: _dirty ? _save : null,
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: _logout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('تسجيل الخروج'),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  '${AppConstants.appName} • الإصدار 1.0.0',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              user.initial,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user.isPharmacist
                            ? Icons.local_pharmacy_rounded
                            : Icons.volunteer_activism_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        user.role.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class _Stats extends StatelessWidget {
  const _Stats({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final service = MedicineService.instance;
    if (user.isPharmacist) {
      return _StatCard(
        icon: Icons.pending_actions_rounded,
        label: 'أدوية بانتظار تدقيقك',
        future: service.countWhere('status', MedicineStatus.pending.value),
        color: AppColors.warning,
      );
    }
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.volunteer_activism_rounded,
            label: 'تبرعاتي',
            future: service.countWhere('donorId', user.uid),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.assignment_turned_in_rounded,
            label: 'طلباتي',
            future: service.countWhere('recipientId', user.uid),
            color: AppColors.info,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.future,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Future<int> future;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<int>(
                  future: future,
                  builder: (_, s) => Text(
                    s.hasData ? '${s.data}' : '—',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
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
