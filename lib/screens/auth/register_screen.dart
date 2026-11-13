import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _pharmacyName = TextEditingController();
  final _pharmacyAddress = TextEditingController();
  final _pharmacyHours = TextEditingController();
  final _license = TextEditingController();
  String _city = AppConstants.cities.first;
  UserRole _role = UserRole.user;
  bool _obscure = true;
  bool _loading = false;

  bool get _isPharmacist => _role == UserRole.pharmacist;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _pharmacyName.dispose();
    _pharmacyAddress.dispose();
    _pharmacyHours.dispose();
    _license.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.register(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        phone: _phone.text,
        city: _city,
        role: _role,
        licenseNumber: _license.text,
        pharmacyName: _pharmacyName.text,
        pharmacyAddress: _pharmacyAddress.text,
        pharmacyHours: _pharmacyHours.text,
      );
      if (!mounted) return;
      // العودة إلى الجذر؛ AuthGate سيعرض الواجهة المناسبة للحساب الجديد.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) AppSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب جديد')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo(size: 72)),
                    const SizedBox(height: 12),
                    const Text(
                      'انضم إلى ${AppConstants.appName}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const Text(
                      AppConstants.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, height: 1.6),
                    ),
                    const SizedBox(height: 24),

                    const _FieldLabel('نوع الحساب'),
                    SegmentedButton<UserRole>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppColors.primary,
                        selectedForegroundColor: Colors.white,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      segments: const [
                        ButtonSegment(
                          value: UserRole.user,
                          icon: Icon(Icons.volunteer_activism_rounded),
                          label: Text('متبرع / محتاج'),
                        ),
                        ButtonSegment(
                          value: UserRole.pharmacist,
                          icon: Icon(Icons.local_pharmacy_rounded),
                          label: Text('صيدلي'),
                        ),
                      ],
                      selected: {_role},
                      onSelectionChanged: (s) =>
                          setState(() => _role = s.first),
                    ),
                    if (_role == UserRole.pharmacist) ...[
                      const SizedBox(height: 8),
                      const InfoBanner(
                        icon: Icons.verified_user_outlined,
                        text:
                            'حساب الصيدلي يمثّل صيدليتك، ويستقبل التبرعات ويراجعها ويسلّمها للمحتاجين. يحتاج توثيقاً من إدارة المنصة برقم ترخيصك قبل أن تستطيع قبول الأدوية.',
                      ),
                    ],
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'الاسم الكامل',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: Validators.name,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      textDirection: TextDirection.ltr,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      textDirection: TextDirection.ltr,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: InputDecoration(
                        labelText: _isPharmacist
                            ? 'هاتف الصيدلية'
                            : 'رقم الهاتف',
                        hintText: _isPharmacist
                            ? '011xxxxxxx أو 09xxxxxxxx'
                            : '09xxxxxxxx',
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      validator: _isPharmacist
                          ? Validators.anyPhone
                          : Validators.phone,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _city,
                      decoration: InputDecoration(
                        labelText: _isPharmacist
                            ? 'محافظة الصيدلية'
                            : 'المحافظة',
                        prefixIcon: const Icon(Icons.location_city_rounded),
                      ),
                      items: AppConstants.cities
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _city = v ?? _city),
                    ),
                    if (_isPharmacist) ...[
                      const SizedBox(height: 24),
                      const _FieldLabel('بيانات الصيدلية'),
                      TextFormField(
                        controller: _pharmacyName,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'اسم الصيدلية',
                          hintText: 'مثال: صيدلية الشفاء',
                          prefixIcon: Icon(Icons.local_pharmacy_outlined),
                        ),
                        validator: (v) =>
                            Validators.required(v, 'يرجى إدخال اسم الصيدلية'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pharmacyAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'العنوان',
                          hintText: 'الحي، الشارع، معلم قريب',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                        validator: (v) =>
                            Validators.required(v, 'يرجى إدخال عنوان الصيدلية'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pharmacyHours,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'ساعات الدوام (اختياري)',
                          hintText: 'مثال: يومياً 9 صباحاً - 10 مساءً',
                          prefixIcon: Icon(Icons.schedule_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _license,
                        textInputAction: TextInputAction.next,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'رقم ترخيص مزاولة المهنة',
                          helperText:
                              'يُستخدم لتوثيق حسابك من قبل إدارة المنصة',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) =>
                            Validators.required(v, 'يرجى إدخال رقم الترخيص'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        helperText: '6 أحرف على الأقل',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: 'إنشاء الحساب',
                      icon: Icons.person_add_alt_1_rounded,
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'لديك حساب بالفعل؟',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('تسجيل الدخول'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}
