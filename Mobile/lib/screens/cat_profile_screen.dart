import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../api_config.dart';
import '../models/cat.dart';
import '../services/cat_avatar_service.dart';
import 'name_input_screen.dart';
import 'breed_select_screen.dart';
import 'profile_picker_sheets.dart';
import '../theme/app_colors.dart';

// Puni profil mačke - i za dodavanje nove i za uređivanje postojeće.
// existingCat == null -> "create" mod (POST), inače "edit" mod (PUT).
class CatProfileScreen extends StatefulWidget {
  final String baseUrl;
  final Cat? existingCat;
  final VoidCallback onSaved;

  const CatProfileScreen({super.key, required this.baseUrl, this.existingCat, required this.onSaved});

  @override
  State<CatProfileScreen> createState() => _CatProfileScreenState();
}

class _CatProfileScreenState extends State<CatProfileScreen> {
  String name = '';
  String? sex;
  DateTime? birthDate;
  String? breed;
  bool? isNeutered;
  double? weightKg;
  String? personality;
  String? goals;
  String? avatarPath;

  bool isSaving = false;
  bool isDeleting = false;

  bool get isEditMode => widget.existingCat != null;
  bool get canSave => name.trim().isNotEmpty && sex != null && birthDate != null;

  @override
  void initState() {
    super.initState();
    final cat = widget.existingCat;
    name = cat?.name ?? '';
    sex = cat?.sex;
    birthDate = cat?.birthDate;
    breed = cat?.breed;
    isNeutered = cat?.isNeutered;
    weightKg = cat?.weightKg;
    personality = cat?.personality;
    goals = cat?.goals;

    if (isEditMode) _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final path = await CatAvatarService.getAvatarPath(widget.existingCat!.id);
    if (!mounted) return;
    setState(() => avatarPath = path);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    if (!isEditMode) return; // avatar treba postojeći ID mačke
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (picked == null) return;
      final path = await CatAvatarService.setAvatar(widget.existingCat!.id, picked);
      if (!mounted) return;
      setState(() => avatarPath = path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greška pri biranju slike: $e')));
    }
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('Slikaj'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Izaberi sliku iz galerije'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Navigacija ka pojedinačnim pickerima
  // ---------------------------------------------------------------------

  Future<void> _editName() async {
    final result = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => NameInputScreen(initialName: name)));
    if (result != null) setState(() => name = result);
  }

  Future<void> _editSex() async {
    final result = await showPickerSheet<String>(
      context: context,
      title: 'Gender',
      builder: (context, submit) => SelectListSheet<String>(
        initialValue: sex,
        options: const [MapEntry('Male', 'Male'), MapEntry('Female', 'Female'), MapEntry('Prefer not to say', 'Unknown')],
        onSubmit: submit,
      ),
    );
    if (result != null) setState(() => sex = result);
  }

  Future<void> _editAge() async {
    final result = await showPickerSheet<DateTime>(
      context: context,
      title: 'Age',
      builder: (context, submit) => AgeDatePickerSheet(
        catName: name.isEmpty ? 'Cat' : name,
        initialDate: birthDate,
        onSubmit: submit,
      ),
    );
    if (result != null) setState(() => birthDate = result);
  }

  Future<void> _editBreed() async {
    final result = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => BreedSelectScreen(initialBreed: breed)));
    if (result != null) setState(() => breed = result);
  }

  Future<void> _editNeutering() async {
    final result = await showPickerSheet<bool>(
      context: context,
      title: 'Neutering',
      builder: (context, submit) => SelectListSheet<bool>(
        initialValue: isNeutered,
        options: const [MapEntry('Neutered/Spayed', true), MapEntry('Not Neutered/Spayed', false)],
        onSubmit: submit,
      ),
    );
    if (result != null) setState(() => isNeutered = result);
  }

  Future<void> _editWeight() async {
    final result = await showPickerSheet<double>(
      context: context,
      title: 'Weight',
      builder: (context, submit) => WeightPickerSheet(initialKg: weightKg, onSubmit: submit),
    );
    if (result != null) setState(() => weightKg = result);
  }

  Future<void> _editPersonality() async {
    final result = await showPickerSheet<String>(
      context: context,
      title: 'Personality',
      builder: (context, submit) => SelectListSheet<String>(
        initialValue: personality,
        options: const [
          MapEntry('None', 'None'),
          MapEntry('Playful & Active', 'Playful & Active'),
          MapEntry('Calm & Independent', 'Calm & Independent'),
        ],
        onSubmit: submit,
      ),
    );
    if (result != null) setState(() => personality = result == 'None' ? null : result);
  }

  Future<void> _editGoals() async {
    final result = await showPickerSheet<String>(
      context: context,
      title: 'Goals',
      builder: (context, submit) => SelectListSheet<String>(
        initialValue: goals,
        options: const [
          MapEntry('None', 'None'),
          MapEntry('Support healthy weight', 'Support healthy weight'),
          MapEntry('Maintain overall health', 'Maintain overall health'),
        ],
        onSubmit: submit,
      ),
    );
    if (result != null) setState(() => goals = result == 'None' ? null : result);
  }

  // ---------------------------------------------------------------------
  // Save / Delete
  // ---------------------------------------------------------------------

  Future<void> save() async {
    if (!canSave) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ime, pol i starost su obavezni.')));
      return;
    }

    setState(() => isSaving = true);

    final body = {
      'name': name.trim(),
      'rfidTag': widget.existingCat?.rfidTag,
      'sex': sex,
      'birthDate': birthDate?.toIso8601String(),
      'breed': breed,
      'isNeutered': isNeutered,
      'weightKg': weightKg,
      'personality': personality,
      'goals': goals,
    };

    try {
      final http.Response response;
      if (isEditMode) {
        response = await http.put(
          Uri.parse('${widget.baseUrl}/cats/${widget.existingCat!.id}'),
          headers: apiHeaders(withJsonBody: true),
          body: json.encode(body),
        );
      } else {
        response = await http.post(
          Uri.parse('${widget.baseUrl}/cats'),
          headers: apiHeaders(withJsonBody: true),
          body: json.encode(body),
        );
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        widget.onSaved();
        Navigator.pop(context);
      } else {
        String message = 'Greška pri čuvanju.';
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map && decoded['error'] != null) message = decoded['error'].toString();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greška pri povezivanju: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Obrisati ${widget.existingCat!.name}?'),
        content: const Text('Ovo će trajno obrisati i cijelu njenu historiju hranjenja i sve rasporede. Ne može se poništiti.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Otkaži')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Obriši', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => isDeleting = true);
    try {
      await CatAvatarService.removeAvatar(widget.existingCat!.id);
      final response = await http.delete(
        Uri.parse('${widget.baseUrl}/cats/${widget.existingCat!.id}'),
        headers: apiHeaders(),
      );
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        widget.onSaved();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brisanje nije uspjelo.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greška: $e')));
    } finally {
      if (mounted) setState(() => isDeleting = false);
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  String get _ageDisplay {
    if (birthDate == null) return 'Please Select';
    final now = DateTime.now();
    int years = now.year - birthDate!.year;
    int months = now.month - birthDate!.month;
    if (now.day < birthDate!.day) months -= 1;
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    return '${years}yr ${months}mo';
  }

  Widget _navRow({required String label, required bool required, required String value, required VoidCallback onTap}) {
    final hasValue = value != 'Please Select';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Text.rich(
              TextSpan(
                text: label,
                style: const TextStyle(fontSize: 16),
                children: required ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.redAccent))] : [],
              ),
            ),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 15, color: hasValue ? Colors.black87 : Colors.black38)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _section(List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) Divider(height: 1, color: Colors.grey.shade100),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('Profile'), backgroundColor: const Color(0xFFF5F5F5), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: avatarPath != null ? FileImage(File(avatarPath!)) : null,
                      child: avatarPath == null
                          ? Icon(Icons.pets_rounded, size: 42, color: Colors.grey.shade500)
                          : null,
                    ),
                    if (isEditMode)
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: GestureDetector(
                          onTap: _showAvatarPicker,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('BASIC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38, letterSpacing: 0.5)),
              ),
              _section([
                _navRow(label: 'Name', required: true, value: name.isEmpty ? 'Please Select' : name, onTap: _editName),
                _navRow(label: 'Sex', required: true, value: sex ?? 'Please Select', onTap: _editSex),
                _navRow(label: 'Age', required: true, value: _ageDisplay, onTap: _editAge),
                _navRow(label: 'Breed', required: false, value: breed ?? 'Please Select', onTap: _editBreed),
              ]),

              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('HEALTH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black38, letterSpacing: 0.5)),
              ),
              _section([
                _navRow(
                  label: 'Neutering',
                  required: true,
                  value: isNeutered == null ? 'Please Select' : (isNeutered! ? 'Neutered/Spayed' : 'Not Neutered/Spayed'),
                  onTap: _editNeutering,
                ),
                _navRow(label: 'Weight', required: true, value: weightKg == null ? 'Please Select' : '${weightKg!.toStringAsFixed(1)} kg', onTap: _editWeight),
                _navRow(label: 'Personality', required: false, value: personality ?? 'Please Select', onTap: _editPersonality),
                _navRow(label: 'Goals', required: false, value: goals ?? 'Please Select', onTap: _editGoals),
              ]),

              ElevatedButton(
                onPressed: (isSaving || !canSave) ? null : save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSave ? Colors.black87 : Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isSaving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text('Save', style: TextStyle(color: canSave ? Colors.white : Colors.black38, fontWeight: FontWeight.w600)),
              ),
              if (isEditMode) ...[
                const SizedBox(height: 14),
                TextButton(
                  onPressed: isDeleting ? null : delete,
                  child: isDeleting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Obriši mačku', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
