import 'package:flutter/material.dart';
import '../models/cat.dart';
import '../models/cat_profile.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';

class AddCatScreen extends StatefulWidget {
  final Future<bool> Function(String name, CatProfile profile) onSave;
  final Cat? existingCat;
  final CatProfile? existingProfile;
  final Future<bool> Function(int catId, String name, CatProfile profile)? onUpdate;
  final Future<bool> Function()? onDelete;

  const AddCatScreen({super.key, required this.onSave, this.existingCat, this.existingProfile, this.onUpdate, this.onDelete});

  @override
  State<AddCatScreen> createState() => _AddCatScreenState();
}

class _AddCatScreenState extends State<AddCatScreen> {
  late final _nameController = TextEditingController(text: widget.existingCat?.name ?? '');
  late final _breedController = TextEditingController(text: widget.existingProfile?.breed ?? '');
  late final _ageController = TextEditingController(text: widget.existingProfile?.ageYears.toString() ?? '');
  late final _weightController = TextEditingController(text: widget.existingProfile?.weightKg.toString() ?? '');
  late String _gender = widget.existingProfile?.gender ?? 'Mužjak';
  bool _isSaving = false;
  bool _isDeleting = false;

  bool get isEditMode => widget.existingCat != null;

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty &&
      int.tryParse(_ageController.text.trim()) != null &&
      double.tryParse(_weightController.text.trim().replaceAll(',', '.')) != null;

  Future<void> _save() async {
    if (!_isValid) return;
    setState(() => _isSaving = true);
    final profile = CatProfile(
      gender: _gender,
      breed: _breedController.text.trim().isEmpty ? AppStrings.t('unknown_breed') : _breedController.text.trim(),
      ageYears: int.parse(_ageController.text.trim()),
      weightKg: double.parse(_weightController.text.trim().replaceAll(',', '.')),
    );
    final bool ok = isEditMode
        ? await widget.onUpdate!(widget.existingCat!.id, _nameController.text.trim(), profile)
        : await widget.onSave(_nameController.text.trim(), profile);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditMode ? AppStrings.t('save_changes_failed') : AppStrings.t('add_cat_failed'))));
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${AppStrings.t('delete_cat_q')} ${widget.existingCat!.name}?'),
        content: Text(AppStrings.t('delete_cat_warning')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.t('delete'), style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isDeleting = true);
    final ok = await widget.onDelete!();
    if (!mounted) return;
    setState(() => _isDeleting = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t('delete_failed'))));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.locale,
      builder: (context, _, __) => Scaffold(
        appBar: AppBar(title: Text(isEditMode ? AppStrings.t('edit_profile') : AppStrings.t('add_cat_title'))),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(AppStrings.t('cat_name_label'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              _field(_nameController, AppStrings.t('eg_bella')),
              const SizedBox(height: 18),
              Text(AppStrings.t('gender_label'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _genderChip('Mužjak', AppStrings.t('male'), Icons.male_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _genderChip('Ženka', AppStrings.t('female'), Icons.female_rounded)),
              ]),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(AppStrings.t('age_label'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    _field(_ageController, '2', keyboardType: TextInputType.number),
                  ]),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(AppStrings.t('weight_kg_label'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    _field(_weightController, '4.5', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              Text(AppStrings.t('breed_label'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              _field(_breedController, AppStrings.t('eg_domestic_shorthair')),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(isEditMode ? AppStrings.t('save_changes') : AppStrings.t('save')),
              ),
              if (isEditMode && widget.onDelete != null) ...[
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _isDeleting ? null : _delete,
                  child: _isDeleting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(AppStrings.t('delete_cat_button'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // [value] je kanonska (bosanska) vrijednost koja se čuva u profilu;
  // [label] je prevedeni tekst koji se prikazuje korisniku.
  Widget _genderChip(String value, String label, IconData icon) {
    final selected = _gender == value;
    return InkWell(
      onTap: () => setState(() => _gender = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.tint50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade200, width: selected ? 1.6 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? AppColors.primary : Colors.black45),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? AppColors.primaryDark : Colors.black54, fontSize: 13)),
        ]),
      ),
    );
  }
}
