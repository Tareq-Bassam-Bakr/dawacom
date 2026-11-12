import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../core/formats.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../services/image_service.dart';
import '../../services/medicine_service.dart';
import '../../widgets/common.dart';

/// شاشة إضافة تبرع دواء جديد.
class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key, required this.user});
  final AppUser user;

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _pharmacy = TextEditingController();
  final _notes = TextEditingController();
  final _expiryField = TextEditingController();

  String _category = AppConstants.categories.first;
  late String _city = AppConstants.cities.contains(widget.user.city)
      ? widget.user.city
      : AppConstants.cities.first;
  DateTime? _expiry;
  Uint8List? _image;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _pharmacy.dispose();
    _notes.dispose();
    _expiryField.dispose();
    super.dispose();
  }

  int? get _daysToExpiry {
    final e = _expiry;
    if (e == null) return null;
    return DateUtils.dateOnly(
      e,
    ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
  }

  Future<void> _pickExpiry() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 10),
      locale: const Locale('ar'),
      helpText: 'تاريخ انتهاء الصلاحية',
      confirmText: 'تأكيد',
      cancelText: 'إلغاء',
      fieldLabelText: 'أدخل التاريخ',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked == null) return;
    setState(() {
      _expiry = picked;
      _expiryField.text = AppFormats.date(picked);
    });
  }

  Future<void> _pickImage() async {
    FocusScope.of(context).unfocus();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'صورة الدواء',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('التقاط صورة بالكاميرا'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            if (_image != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'إزالة الصورة',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _image = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final bytes = await ImageService.pick(source);
      if (bytes != null && mounted) setState(() => _image = bytes);
    } catch (e) {
      if (mounted) AppSnack.error(context, e);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final expiry = _expiry;
    if (expiry == null) {
      AppSnack.show(context, 'يرجى تحديد تاريخ انتهاء الصلاحية', error: true);
      return;
    }
    if (_daysToExpiry! < AppConstants.minDaysToExpiry) {
      AppSnack.show(
        context,
        'لا يمكن التبرع بدواء تبقى على انتهائه أقل من ${AppConstants.minDaysToExpiry} يوماً',
        error: true,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await MedicineService.instance.add(
        donor: widget.user,
        name: _name.text,
        category: _category,
        quantity: int.parse(_quantity.text.trim()),
        expiryDate: expiry,
        pharmacy: _pharmacy.text,
        city: _city,
        notes: _notes.text,
        imageBytes: _image,
      );
      if (!mounted) return;
      Navigator.pop(context);
      AppSnack.success(context, 'تم إرسال تبرعك، سيراجعه الصيدلاني قريباً');
    } catch (e) {
      if (mounted) AppSnack.error(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysToExpiry;
    final nearExpiry =
        days != null &&
        days >= AppConstants.minDaysToExpiry &&
        days <= AppConstants.nearExpiryDays;
    final tooClose = days != null && days < AppConstants.minDaysToExpiry;

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة تبرع دواء')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ImagePicker(image: _image, onTap: _pickImage),
              const SizedBox(height: 20),

              const SectionTitle('معلومات الدواء'),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'اسم الدواء',
                  hintText: 'مثال: Panadol Extra 500mg',
                  prefixIcon: Icon(Icons.medication_rounded),
                ),
                validator: (v) =>
                    Validators.required(v, 'يرجى إدخال اسم الدواء'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'التصنيف',
                  prefixIcon: Icon(AppConstants.categoryIcon(_category)),
                ),
                items: AppConstants.categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(
                              AppConstants.categoryIcon(c),
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(c),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'الكمية (علب)',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      validator: Validators.quantity,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _expiryField,
                      readOnly: true,
                      onTap: _pickExpiry,
                      decoration: const InputDecoration(
                        labelText: 'تاريخ الانتهاء',
                        hintText: 'اختر التاريخ',
                        prefixIcon: Icon(Icons.event_rounded),
                        suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                      ),
                      validator: (_) =>
                          _expiry == null ? 'حدد تاريخ الانتهاء' : null,
                    ),
                  ),
                ],
              ),
              if (tooClose) ...[
                const SizedBox(height: 10),
                InfoBanner(
                  icon: Icons.block_rounded,
                  color: AppColors.danger,
                  text:
                      'يتبقى ${AppFormats.days(days)} فقط على انتهاء الصلاحية. لا نقبل أدوية تبقى على انتهائها أقل من ${AppConstants.minDaysToExpiry} يوماً.',
                ),
              ] else if (nearExpiry) ...[
                const SizedBox(height: 10),
                InfoBanner(
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  text:
                      'الصلاحية قريبة من الانتهاء (${AppFormats.days(days)}). قد يرفض الصيدلاني الدواء إن لم يتوفر وقت كافٍ لاستخدامه.',
                ),
              ],
              const SizedBox(height: 20),

              const SectionTitle('مكان الاستلام'),
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
              const SizedBox(height: 14),
              TextFormField(
                controller: _pharmacy,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم الصيدلية أو مكان الاستلام',
                  hintText: 'مثال: صيدلية الشفاء - شارع بغداد',
                  prefixIcon: Icon(Icons.store_mall_directory_outlined),
                ),
                validator: (v) =>
                    Validators.required(v, 'يرجى إدخال مكان الاستلام'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                maxLength: 300,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  hintText: 'مثال: العلبة مغلقة، تحتاج تبريد، الجرعة...',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.notes_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const InfoBanner(
                icon: Icons.verified_outlined,
                text:
                    'سيراجع صيدلاني مدقّق تبرعك للتحقق من سلامة الدواء قبل عرضه للمحتاجين.',
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'إرسال التبرع',
                icon: Icons.send_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePicker extends StatelessWidget {
  const _ImagePicker({required this.image, required this.onTap});
  final Uint8List? image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 190,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: image == null ? AppColors.primaryLight : AppColors.border,
            width: image == null ? 1.6 : 1,
          ),
        ),
        child: image == null ? _placeholder() : _preview(image!),
      ),
    );
  }

  Widget _placeholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_a_photo_rounded,
            color: AppColors.primary,
            size: 30,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'أضف صورة الدواء',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'صورة واضحة للعلبة وتاريخ الصلاحية تساعد الصيدلاني على التحقق',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _preview(Uint8List bytes) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
        PositionedDirectional(
          bottom: 10,
          end: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'تغيير الصورة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
