import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/common.dart';
import '../../widgets/connection_banner.dart';
import '../pharmacist/pharmacist_home.dart';
import '../user/user_home.dart';
import 'login_screen.dart';

/// بوابة الدخول: تراقب حالة المصادقة وتوجّه المستخدم للواجهة المناسبة لدوره.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        return _ProfileGate(user: user);
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({required this.user});
  final User user;

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  // نحتفظ بالمتابعتين طوال عمر الشاشة حتى لا تُعاد مع كل تحديث للحساب.
  late Stream<AppUser?> _profile;
  late Stream<bool> _status;

  User get user => widget.user;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _ProfileGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != user.uid) _subscribe();
  }

  void _subscribe() {
    _profile = UserService.instance.watch(user.uid);
    _status = UserService.instance.serverStatus(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _GateError(message: AppSnack.messageOf(snapshot.error!));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        final appUser = snapshot.data;
        if (appUser == null) {
          // أثناء إنشاء الحساب ننتظر حفظ الملف الحقيقي بدل إنشاء ملف احتياطي.
          return ValueListenableBuilder<bool>(
            valueListenable: AuthService.instance.registering,
            builder: (_, registering, _) => registering
                ? const SplashScreen(message: 'جاري إنشاء حسابك...')
                : _MissingProfile(user: user),
          );
        }

        return ConnectionBanner(
          online: _status,
          child: appUser.isPharmacist
              ? PharmacistHome(user: appUser)
              : UserHome(user: appUser),
        );
      },
    );
  }
}

/// يُنشئ ملف المستخدم إن كان الحساب موجوداً في Auth دون ملف في Firestore.
class _MissingProfile extends StatefulWidget {
  const _MissingProfile({required this.user});
  final User user;

  @override
  State<_MissingProfile> createState() => _MissingProfileState();
}

class _MissingProfileState extends State<_MissingProfile> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _create();
  }

  Future<void> _create() async {
    setState(() => _error = null);
    try {
      await UserService.instance.ensureProfile(widget.user);
    } catch (e) {
      if (mounted) setState(() => _error = AppSnack.messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _GateError(message: _error!, onRetry: _create);
    return const SplashScreen(message: 'جاري تجهيز حسابك...');
  }
}

class _GateError extends StatelessWidget {
  const _GateError({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ErrorView(message: message, onRetry: onRetry),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: TextButton.icon(
                onPressed: AuthService.instance.signOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('تسجيل الخروج'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شاشة البداية.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 110),
            const SizedBox(height: 18),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              AppConstants.tagline,
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 14),
              Text(message!, style: const TextStyle(color: Colors.white70)),
            ],
          ],
        ),
      ),
    );
  }
}
