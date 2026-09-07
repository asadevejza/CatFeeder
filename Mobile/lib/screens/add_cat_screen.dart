import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/cat.dart';
import '../models/cat_profile.dart';
import '../services/cat_avatar_service.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';

class AddCatScreen extends StatefulWidget {
  final Future<int?> Function(String name, CatProfile profile) onSave;
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
  late final _goalController = TextEditingController(text: (widget.existingProfile?.dailyGoalGrams ?? 200).toString());
  late String _gender = widget.existingProfile?.gender ?? 'Mužjak';
  bool _isSaving = false;
  bool _isDeleting = false;

  XFile? _pickedImage;
  String? _existingAvatarPath;

  bool get isEditMode => widget.existingCat != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode) _loadExistingAvatar();
  }

  Future<void> _loadExistingAvatar() async {
    final path = await CatAvatarService.getAvatarPath(widget.existingCat!.id);
    if (!mounted || path == null) return;
    setState(() => _existingAvatarPath = path);
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;
    setState(() => _pickedImage = picked);
    // U edit modu mačka već ima ID pa sliku možemo sačuvati odmah.
    if (isEditMode) {
      await CatAvatarService.setAvatar(widget.existingCat!.id, picked);
    }
  }

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
      dailyGoalGrams: int.tryParse(_goalController.text.trim()) ?? 200,
    );
    bool ok;
    if (isEditMode) {
      ok = await widget.onUpdate!(widget.existingCat!.id, _nameController.text.trim(), profile);
    } else {
      final newId = await widget.onSave(_nameController.text.trim(), profile);
      ok = newId != null;
      if (ok && _pickedImage != null) {
        await CatAvatarService.setAvatar(newId!, _pickedImage!);
      }
    }
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
              Center(child: _avatarPicker()),
              const SizedBox(height: 24),
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
              const SizedBox(height: 18),
              Text(AppStrings.t('daily_goal_label'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              _field(_goalController, '200', keyboardType: TextInputType.number, suffix: 'g'),
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

  Widget _avatarPicker() {
    ImageProvider? image;
    if (_pickedImage != null) {
      image = FileImage(File(_pickedImage!.path));
    } else if (_existingAvatarPath != null) {
      image = FileImage(File(_existingAvatarPath!));
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [AppColors.primaryLight, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: CircleAvatar(
              radius: 45,
              backgroundColor: AppColors.tint50,
              backgroundImage: image,
              child: image == null ? const Text('🐈', style: TextStyle(fontSize: 38)) : null,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint, {TextInputType? keyboardType, String? suffix}) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        suffixText: suffix,
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
