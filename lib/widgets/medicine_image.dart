import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/medicine.dart';

/// صورة الدواء، أو أيقونة التصنيف إن لم تتوفر صورة.
class MedicineImage extends StatelessWidget {
  const MedicineImage({
    super.key,
    required this.medicine,
    this.width = 84,
    this.height = 84,
    this.borderRadius = 12,
    this.hero = true,
  });

  final Medicine medicine;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool hero;

  static String heroTag(Medicine m) => 'medicine-image-${m.id}';

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (medicine.hasImage) {
      child = Image.memory(
        medicine.imageBytes!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } else {
      child = _placeholder();
    }

    child = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );

    return hero ? Hero(tag: heroTag(medicine), child: child) : child;
  }

  Widget _placeholder() {
    final iconSize = ((height ?? width ?? 84) * 0.42).clamp(20.0, 72.0);
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primarySoft, AppColors.primaryLight],
        ),
      ),
      child: Icon(
        medicine.categoryIcon,
        color: AppColors.primaryDark,
        size: iconSize,
      ),
    );
  }
}

/// عرض الصورة بحجم كامل مع إمكانية التكبير.
class FullScreenImage extends StatelessWidget {
  const FullScreenImage({super.key, required this.medicine});
  final Medicine medicine;

  static void open(BuildContext context, Medicine medicine) {
    if (!medicine.hasImage) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => FullScreenImage(medicine: medicine),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(medicine.name),
      ),
      body: Center(
        child: Hero(
          tag: MedicineImage.heroTag(medicine),
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: Image.memory(medicine.imageBytes!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
