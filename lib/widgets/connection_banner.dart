import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// شريط أعلى الشاشة يظهر عندما لا يصل التطبيق إلى خوادم Firebase،
/// ويختفي برسالة قصيرة عند عودة الاتصال.
///
/// [online] يُصدر true عندما تأتي البيانات من الخادم، وfalse عندما تأتي
/// من النسخة المحفوظة على الجهاز.
class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({
    super.key,
    required this.online,
    required this.child,
    this.graceDelay = const Duration(seconds: 3),
    this.restoredDuration = const Duration(seconds: 2),
  });

  final Stream<bool> online;
  final Widget child;

  /// مهلة قبل إظهار الشريط، حتى لا يومض عند فتح التطبيق قبل وصول بيانات الخادم.
  final Duration graceDelay;

  /// مدة ظهور رسالة "عاد الاتصال".
  final Duration restoredDuration;

  static const offlineText =
      'لا يوجد اتصال بالخادم، والبيانات المعروضة قد تكون قديمة. تحقق من الإنترنت أو شغّل VPN.';
  static const restoredText = 'عاد الاتصال، والبيانات محدّثة الآن';

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  StreamSubscription<bool>? _sub;
  Timer? _graceTimer;
  Timer? _restoredTimer;
  bool _offline = false;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant ConnectionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.online != widget.online) _listen();
  }

  void _listen() {
    _sub?.cancel();
    _sub = widget.online.listen(_onStatus, onError: (_) {});
  }

  void _onStatus(bool online) {
    if (!online) {
      if (_offline || _graceTimer != null) return;
      _graceTimer = Timer(widget.graceDelay, () {
        _graceTimer = null;
        if (!mounted) return;
        _restoredTimer?.cancel();
        setState(() {
          _offline = true;
          _restored = false;
        });
      });
      return;
    }

    _graceTimer?.cancel();
    _graceTimer = null;
    if (!_offline) return;
    setState(() {
      _offline = false;
      _restored = true;
    });
    _restoredTimer?.cancel();
    _restoredTimer = Timer(widget.restoredDuration, () {
      if (mounted) setState(() => _restored = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _graceTimer?.cancel();
    _restoredTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget? bar = _offline
        ? const _Bar(
            key: ValueKey('offline'),
            color: AppColors.warning,
            icon: Icons.cloud_off_rounded,
            text: ConnectionBanner.offlineText,
          )
        : _restored
        ? const _Bar(
            key: ValueKey('restored'),
            color: AppColors.success,
            icon: Icons.cloud_done_rounded,
            text: ConnectionBanner.restoredText,
          )
        : null;

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: bar ?? const SizedBox(width: double.infinity),
        ),
        Expanded(
          // الشريط يشغل منطقة شريط الحالة، فلا تضيف الشاشة تحته مسافة علوية.
          child: bar == null
              ? widget.child
              : MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: widget.child,
                ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
