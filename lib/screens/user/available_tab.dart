import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../core/formats.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../models/medicine.dart';
import '../../services/medicine_service.dart';
import '../../widgets/common.dart';
import '../../widgets/medicine_card.dart';
import '../medicine/medicine_details_screen.dart';

/// تبويب الأدوية المتاحة مع البحث والفلترة.
class AvailableTab extends StatefulWidget {
  const AvailableTab({super.key, required this.user});
  final AppUser user;

  @override
  State<AvailableTab> createState() => _AvailableTabState();
}

class _AvailableTabState extends State<AvailableTab> {
  final _search = TextEditingController();
  String? _city;
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _search.text.trim().isNotEmpty || _city != null || _category != null;

  void _clearFilters() {
    setState(() {
      _search.clear();
      _city = null;
      _category = null;
    });
  }

  List<Medicine> _apply(List<Medicine> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((m) {
      if (_city != null && m.city != _city) return false;
      if (_category != null && m.category != _category) return false;
      if (q.isNotEmpty &&
          !m.name.toLowerCase().contains(q) &&
          !m.category.toLowerCase().contains(q) &&
          !m.pharmacy.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickCity() async {
    final r = await _pickOption(
      title: 'اختر المحافظة',
      allLabel: 'كل المحافظات',
      options: AppConstants.cities,
      selected: _city,
      icon: Icons.location_city_rounded,
    );
    if (r != null) setState(() => _city = r.value);
  }

  Future<void> _pickCategory() async {
    final r = await _pickOption(
      title: 'اختر التصنيف',
      allLabel: 'كل التصنيفات',
      options: AppConstants.categories,
      selected: _category,
      icon: Icons.category_rounded,
      optionIcon: AppConstants.categoryIcon,
    );
    if (r != null) setState(() => _category = r.value);
  }

  /// تُعيد null عند الإلغاء، أو [_Pick] بقيمة null لاختيار "الكل".
  Future<_Pick?> _pickOption({
    required String title,
    required String allLabel,
    required List<String> options,
    required String? selected,
    required IconData icon,
    IconData Function(String)? optionIcon,
  }) {
    return showModalBottomSheet<_Pick>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  _OptionTile(
                    label: allLabel,
                    icon: Icons.all_inclusive_rounded,
                    selected: selected == null,
                    onTap: () => Navigator.pop(ctx, const _Pick(null)),
                  ),
                  for (final o in options)
                    _OptionTile(
                      label: o,
                      icon: optionIcon?.call(o),
                      selected: selected == o,
                      onTap: () => Navigator.pop(ctx, _Pick(o)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FilterBar(
          controller: _search,
          city: _city,
          category: _category,
          onChanged: (_) => setState(() {}),
          onPickCity: _pickCity,
          onPickCategory: _pickCategory,
        ),
        Expanded(
          child: StreamBuilder<List<Medicine>>(
            stream: MedicineService.instance.available(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorView(message: AppSnack.messageOf(snapshot.error!));
              }
              if (!snapshot.hasData) return const LoadingView();

              final all = snapshot.data!;
              if (all.isEmpty) {
                return const EmptyState(
                  icon: Icons.medication_outlined,
                  title: 'لا توجد أدوية متاحة حالياً',
                  subtitle: 'كن أول من يتبرع، اضغط "تبرع الآن" لإضافة دواء.',
                );
              }

              final list = _apply(all);
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'لا توجد نتائج مطابقة',
                  subtitle: 'جرّب تغيير كلمات البحث أو الفلاتر.',
                  action: TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    label: const Text('مسح الفلاتر'),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: list.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Row(
                      children: [
                        Text(
                          '${AppFormats.medicines(list.length)} ${_hasFilters ? 'مطابق' : 'متاح'}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (_hasFilters)
                          TextButton.icon(
                            onPressed: _clearFilters,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('مسح الفلاتر'),
                          ),
                      ],
                    );
                  }
                  final m = list[i - 1];
                  return MedicineCard(
                    medicine: m,
                    onTap: () => MedicineDetailsScreen.open(
                      context,
                      medicine: m,
                      user: widget.user,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Pick {
  const _Pick(this.value);
  final String? value;
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: icon == null ? null : Icon(icon, color: AppColors.primary),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          color: selected ? AppColors.primaryDark : AppColors.textDark,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
          : null,
      selected: selected,
      selectedTileColor: AppColors.primarySoft,
      onTap: onTap,
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.city,
    required this.category,
    required this.onChanged,
    required this.onPickCity,
    required this.onPickCategory,
  });

  final TextEditingController controller;
  final String? city;
  final String? category;
  final ValueChanged<String> onChanged;
  final VoidCallback onPickCity;
  final VoidCallback onPickCategory;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ابحث عن دواء بالاسم أو التصنيف...',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FilterButton(
                  icon: Icons.location_city_rounded,
                  label: city ?? 'كل المحافظات',
                  active: city != null,
                  onTap: onPickCity,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FilterButton(
                  icon: category == null
                      ? Icons.category_rounded
                      : AppConstants.categoryIcon(category!),
                  label: category ?? 'كل التصنيفات',
                  active: category != null,
                  onTap: onPickCategory,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.primaryDark : Colors.white;
    return Material(
      color: active ? Colors.white : Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded, size: 18, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
