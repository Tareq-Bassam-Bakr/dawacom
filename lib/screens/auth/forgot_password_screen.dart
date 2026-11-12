import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/utils.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) AppSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استعادة كلمة المرور')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _sent ? _buildSent() : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              size: 46,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'نسيت كلمة المرور؟',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, height: 1.6),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            autofocus: widget.initialEmail.isEmpty,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'البريد الإلكتروني',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: Validators.email,
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'إرسال رابط الاستعادة',
            icon: Icons.send_rounded,
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildSent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            size: 46,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'تم إرسال الرابط',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'أرسلنا رابط إعادة تعيين كلمة المرور إلى:\n${_email.text.trim()}\n\nإن لم تجده في صندوق الوارد، تحقق من مجلد الرسائل غير المرغوبة.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, height: 1.7),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'العودة لتسجيل الدخول',
          icon: Icons.arrow_back_rounded,
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          onPressed: () => setState(() => _sent = false),
          child: const Text('لم يصلك البريد؟ أعد المحاولة'),
        ),
      ],
    );
  }
}
