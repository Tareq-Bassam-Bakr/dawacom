import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/formats.dart';
import '../core/utils.dart';
import '../models/medicine.dart';
import '../services/medicine_service.dart';
import 'common.dart';

/// نتيجة نافذة الرفض.
typedef RejectionInput = ({String reason, String note});

/// نافذة اختيار سبب الرفض (إلزامي) مع ملاحظة اختيارية.
Future<RejectionInput?> showRejectSheet(BuildContext context, Medicine m) {
  return showModalBottomSheet<RejectionInput>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RejectSheet(medicine: m),
  );
}

class _RejectSheet extends StatefulWidget {
  const _RejectSheet({required this.medicine});
  final Medicine medicine;

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  String? _reason;
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'اختر سبب الرفض');
      return;
    }
    if (reason == 'سبب آخر' && _note.text.trim().isEmpty) {
      setState(() => _error = 'اكتب سبب الرفض في الملاحظة');
      return;
    }
    Navigator.pop<RejectionInput>(context, (
      reason: reason,
      note: _note.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'رفض "${widget.medicine.name}"',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'سيظهر السبب للمتبرع ليعرف لماذا لم يُقبل تبرعه.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (v) => setState(() {
                  _reason = v;
                  _error = null;
                }),
                child: Column(
                  children: [
                    for (final r in AppConstants.rejectionReasons)
                      RadioListTile<String>(
                        value: r,
                        title: Text(r),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                maxLines: 2,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: _reason == 'سبب آخر'
                      ? 'اكتب السبب'
                      : 'ملاحظة للمتبرع (اختياري)',
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              PrimaryButton(
                label: 'تأكيد الرفض',
                icon: Icons.close_rounded,
                color: AppColors.danger,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// نافذة تأكيد القبول. تُعيد قيمة "يحتاج وصفة طبية"، أو null عند الإلغاء.
Future<bool?> showApproveDialog(BuildContext context, Medicine m) {
  var requiresPrescription = m.requiresPrescription;
  final days = m.daysToExpiry;
  final shortExpiry = days != null && days < AppConstants.minDaysToExpiry;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        icon: const Icon(
          Icons.verified_rounded,
          size: 40,
          color: AppColors.success,
        ),
        title: Text('قبول "${m.name}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'سيُعرض الدواء للمحتاجين ويُستلم من صيدليتك.',
              style: TextStyle(height: 1.5),
            ),
            if (shortExpiry) ...[
              const SizedBox(height: 10),
              InfoBanner(
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
                text:
                    'الصلاحية المتبقية ${AppFormats.days(days)} فقط، أقل من الحد المعتمد (6 أشهر).',
              ),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              value: requiresPrescription,
              onChanged: (v) =>
                  setState(() => requiresPrescription = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('يحتاج وصفة طبية'),
              subtitle: const Text(
                'سيُطلب من المحتاج إرفاق صورة الوصفة عند الحجز',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(ctx, requiresPrescription),
            child: const Text('قبول الدواء'),
          ),
        ],
      ),
    ),
  );
}

/// نموذج تصحيح بيانات الدواء أثناء المراجعة. يُعيد true عند الحفظ.
Future<bool> showEditMedicineSheet(BuildContext context, Medicine m) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EditSheet(medicine: m),
  );
  return saved ?? false;
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.medicine});
  final Medicine medicine;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.medicine.name);
  late final _quantity = TextEditingController(
    text: '${widget.medicine.quantity}',
  );
  late final _batch = TextEditingController(text: widget.medicine.batchNumber);
  late String _category =
      AppConstants.categories.contains(widget.medicine.category)
      ? widget.medicine.category
      : 'أخرى';
  late DateTime? _expiry = widget.medicine.effectiveExpiry;
  late bool _requiresPrescription = widget.medicine.requiresPrescription;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _batch.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
      locale: const Locale('ar'),
      helpText: 'تاريخ انتهاء الصلاحية',
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final expiry = _expiry;
    if (expiry == null) {
      AppSnack.show(context, 'حدد تاريخ انتهاء الصلاحية', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await MedicineService.instance.updateDetails(
        widget.medicine.id,
        name: _name.text,
        category: _category,
        quantity: int.parse(_quantity.text.trim()),
        expiryDate: expiry,
        batchNumber: _batch.text,
        requiresPrescription: _requiresPrescription,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'تصحيح بيانات الدواء',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'طابق البيانات مع العبوة الفعلية قبل القبول.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'اسم الدواء والتركيز',
                    prefixIcon: Icon(Icons.medication_rounded),
                  ),
                  validator: (v) =>
                      Validators.required(v, 'يرجى إدخال اسم الدواء'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'التصنيف',
                    prefixIcon: Icon(AppConstants.categoryIcon(_category)),
                  ),
                  items: AppConstants.categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'الكمية',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        validator: Validators.quantity,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _pickExpiry,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'تاريخ الانتهاء',
                            prefixIcon: Icon(Icons.event_rounded),
                          ),
                          child: Text(
                            _expiry == null
                                ? 'اختر التاريخ'
                                : AppFormats.date(_expiry!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _batch,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'رقم التشغيلة (Batch / Lot)',
                    helperText: 'من العبوة، لتتبّع الدواء إن سُحب من السوق',
                    prefixIcon: Icon(Icons.qr_code_rounded),
                  ),
                ),
                SwitchListTile(
                  value: _requiresPrescription,
                  onChanged: (v) => setState(() => _requiresPrescription = v),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('يحتاج وصفة طبية'),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'حفظ التعديلات',
                  icon: Icons.save_outlined,
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
