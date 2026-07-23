import 'package:flutter/material.dart';
import '../models/cat_profile.dart';

// Prikazuje se samo prilikom prvog pokretanja aplikacije. Prvo traži
// korisnikove podatke, zatim podatke o njegovoj mački (ime, spol, godine,
// rasa, težina) prije nego što pusti korisnika u glavnu aplikaciju.
class OnboardingScreen extends StatefulWidget {
  final Future<void> Function({
    required String ownerName,
    required String catName,
    required CatProfile catProfile,
  }) onFinish;

  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _isSaving = false;

  final _ownerNameController = TextEditingController();

  final _catNameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  String _gender = 'Mužjak';

  @override
  void dispose() {
    _pageController.dispose();
    _ownerNameController.dispose();
    _catNameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(step, duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
  }

  bool get _step0Valid => _ownerNameController.text.trim().isNotEmpty;

  bool get _step1Valid =>
      _catNameController.text.trim().isNotEmpty &&
      _ageController.text.trim().isNotEmpty &&
      _weightController.text.trim().isNotEmpty &&
      double.tryParse(_weightController.text.trim().replaceAll(',', '.')) != null &&
      int.tryParse(_ageController.text.trim()) != null;

  Future<void> _finish() async {
    if (!_step1Valid) return;
    setState(() => _isSaving = true);
    final profile = CatProfile(
      gender: _gender,
      breed: _breedController.text.trim().isEmpty ? 'Nepoznata rasa' : _breedController.text.trim(),
      ageYears: int.parse(_ageController.text.trim()),
      weightKg: double.parse(_weightController.text.trim().replaceAll(',', '.')),
    );
    await widget.onFinish(
      ownerName: _ownerNameController.text.trim(),
      catName: _catNameController.text.trim(),
      catProfile: profile,
    );
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _StepDots(step: _step, count: 2),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _OwnerStep(controller: _ownerNameController, onChanged: () => setState(() {})),
                  _CatStep(
                    nameController: _catNameController,
                    breedController: _breedController,
                    ageController: _ageController,
                    weightController: _weightController,
                    gender: _gender,
                    onGenderChanged: (g) => setState(() => _gender = g),
                    onChanged: () => setState(() {}),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  if (_step == 1)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () => _goToStep(0),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text('Nazad'),
                      ),
                    ),
                  if (_step == 1) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              if (_step == 0) {
                                if (_step0Valid) _goToStep(1);
                              } else {
                                _finish();
                              }
                            },
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                            )
                          : Text(_step == 0 ? 'Nastavi' : 'Završi'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int step;
  final int count;
  const _StepDots({required this.step, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: active ? 22 : 6,
          decoration: BoxDecoration(
            color: active ? Colors.lightBlue : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _OwnerStep extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  const _OwnerStep({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.lightBlue.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.pets_rounded, color: Colors.lightBlue, size: 34),
          ),
          const SizedBox(height: 20),
          const Text('Dobrodošli u CatFeeder', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Prvo da vas upoznamo — kako se zovete?',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 28),
          const Text('Vaše ime', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'npr. Asad',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatStep extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController breedController;
  final TextEditingController ageController;
  final TextEditingController weightController;
  final String gender;
  final void Function(String) onGenderChanged;
  final VoidCallback onChanged;

  const _CatStep({
    required this.nameController,
    required this.breedController,
    required this.ageController,
    required this.weightController,
    required this.gender,
    required this.onGenderChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.lightBlue.shade50, shape: BoxShape.circle),
            child: const Text('🐈', style: TextStyle(fontSize: 34)),
          ),
          const SizedBox(height: 20),
          const Text('Recite nam o vašoj mački', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Ovi podaci nam pomažu da personalizujemo njegu.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          _Label('Ime mačke'),
          _Field(controller: nameController, hint: 'npr. Bella', onChanged: onChanged),
          const SizedBox(height: 18),
          _Label('Spol'),
          Row(
            children: [
              Expanded(
                child: _GenderChip(
                  label: 'Mužjak',
                  icon: Icons.male_rounded,
                  selected: gender == 'Mužjak',
                  onTap: () => onGenderChanged('Mužjak'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderChip(
                  label: 'Ženka',
                  icon: Icons.female_rounded,
                  selected: gender == 'Ženka',
                  onTap: () => onGenderChanged('Ženka'),
                ),
              ),
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
                    _Label('Godine'),
                    _Field(controller: ageController, hint: 'npr. 2', onChanged: onChanged, keyboardType: TextInputType.number),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Težina (kg)'),
                    _Field(
                      controller: weightController,
                      hint: 'npr. 4.5',
                      onChanged: onChanged,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _Label('Rasa'),
          _Field(controller: breedController, hint: 'npr. Domaća kratkodlaka', onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  final TextInputType? keyboardType;
  const _Field({required this.controller, required this.hint, required this.onChanged, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
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
}

class _GenderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _GenderChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
