import 'package:flutter/material.dart';
import '../models/cat_profile.dart';

// Ekran za dodavanje nove mačke poslije onboarding-a (npr. sa "Me" ili "Care" taba).
class AddCatScreen extends StatefulWidget {
  final Future<bool> Function(String name, CatProfile profile) onSave;
  const AddCatScreen({super.key, required this.onSave});

  @override
  State<AddCatScreen> createState() => _AddCatScreenState();
}

class _AddCatScreenState extends State<AddCatScreen> {
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  String _gender = 'Mužjak';
  bool _isSaving = false;

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
    final ok = await widget.onSave(_nameController.text.trim(), profile);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nije uspjelo dodavanje mačke.')));
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
      appBar: AppBar(title: const Text('Dodaj mačku')),
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
                      _field(_ageController, 'npr. 2', keyboardType: TextInputType.number),
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
                      _field(_weightController, 'npr. 4.5', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Rasa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            _field(_breedController, 'npr. Domaća kratkodlaka'),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Sačuvaj'),
            ),
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
          color: selected ? Colors.lightBlue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? Colors.lightBlue : Colors.grey.shade200, width: selected ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.lightBlue : Colors.black45),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.lightBlue.shade900 : Colors.black54,
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }
}
