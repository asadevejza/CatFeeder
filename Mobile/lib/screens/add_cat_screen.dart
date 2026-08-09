import 'package:flutter/material.dart';
import '../models/cat.dart';
import '../models/cat_profile.dart';
import '../theme/app_colors.dart';

// Dodaj NOVU mačku (existingCat == null) ili uredi POSTOJEĆU (existingCat != null).
class AddCatScreen extends StatefulWidget {
  final Future<bool> Function(String name, CatProfile profile) onSave;
  final Cat? existingCat;
  final CatProfile? existingProfile;
  final Future<bool> Function(int catId, String name, CatProfile profile)? onUpdate;
  final Future<bool> Function()? onDelete;

  const AddCatScreen({
    super.key,
    required this.onSave,
    this.existingCat,
    this.existingProfile,
    this.onUpdate,
    this.onDelete,
  });

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
      breed: _breedController.text.trim().isEmpty ? 'Nepoznata rasa' : _breedController.text.trim(),
      ageYears: int.parse(_ageController.text.trim()),
      weightKg: double.parse(_weightController.text.trim().replaceAll(',', '.')),
    );

    final bool ok;
    if (isEditMode) {
      ok = await widget.onUpdate!(widget.existingCat!.id, _nameController.text.trim(), profile);
    } else {
      ok = await widget.onSave(_nameController.text.trim(), profile);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditMode ? 'Nije uspjelo čuvanje izmjena.' : 'Nije uspjelo dodavanje mačke.')),
      );
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Obrisati ${widget.existingCat!.name}?'),
        content: const Text('Ovo će trajno obrisati i historiju hranjenja i rasporede. Ne može se poništiti.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Otkaži')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Obriši', style: TextStyle(color: Colors.redAccent))),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brisanje nije uspjelo.')));
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
    return Scaffold(
      appBar: AppBar(title: Text(isEditMode ? 'Uredi profil' : 'Dodaj mačku')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Ime mačke', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            _field(_nameController, 'npr. Bella'),
            const SizedBox(height: 18),
            const Text('Spol', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _genderChip('Mužjak', Icons.male_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _genderChip('Ženka', Icons.female_rounded)),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Godine', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 8),
                      _field(_ageController, '2', keyboardType: TextInputType.number),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Težina (kg)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 8),
                      _field(_weightController, '4.5', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Rasa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            _field(_breedController, 'Domaća kratkodlaka'),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(isEditMode ? 'Sačuvaj izmjene' : 'Sačuvaj'),
            ),
            if (isEditMode && widget.onDelete != null) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: _isDeleting ? null : _delete,
                child: _isDeleting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Obriši mačku', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
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

  Widget _genderChip(String label, IconData icon) {
    final selected = _gender == label;
    return InkWell(
      onTap: () => setState(() => _gender = label),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.tint50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade200, width: selected ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : Colors.black45),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primaryDark : Colors.black54,
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }
}
