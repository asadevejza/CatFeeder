import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// Zajednički wrapper za sve bottom sheet-ove: naslov + X dugme + Save dugme.
// child je sadržaj sheet-a; onSave se poziva kad korisnik pritisne Save,
// a treba da vrati vrijednost koja se prosljeđuje nazad kroz Navigator.pop.
Future<T?> showPickerSheet<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext context, void Function(T value) submit) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                builder(context, (value) => Navigator.pop(context, value)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// 1) Jednostruki izbor sa liste (Pol, Sterilisanost, Karakter, Ciljevi...)
// ---------------------------------------------------------------------------
class SelectListSheet<T> extends StatefulWidget {
  final List<MapEntry<String, T>> options;
  final T? initialValue;
  final void Function(T value) onSubmit;

  const SelectListSheet({super.key, required this.options, required this.initialValue, required this.onSubmit});

  @override
  State<SelectListSheet<T>> createState() => _SelectListSheetState<T>();
}

class _SelectListSheetState<T> extends State<SelectListSheet<T>> {
  late T? selected = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...widget.options.map((entry) {
          final isSelected = selected == entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => selected = entry.value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 15))),
                    if (isSelected) const Icon(Icons.check, color: Colors.green, size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: selected == null ? null : () => widget.onSubmit(selected as T),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2) Datum rođenja (prikazuje i izračunatu starost dok korisnik bira)
// ---------------------------------------------------------------------------
class AgeDatePickerSheet extends StatefulWidget {
  final String catName;
  final DateTime? initialDate;
  final void Function(DateTime value) onSubmit;

  const AgeDatePickerSheet({super.key, required this.catName, required this.initialDate, required this.onSubmit});

  @override
  State<AgeDatePickerSheet> createState() => _AgeDatePickerSheetState();
}

class _AgeDatePickerSheetState extends State<AgeDatePickerSheet> {
  late DateTime picked = widget.initialDate ?? DateTime.now();

  String get _ageLabel {
    final now = DateTime.now();
    int years = now.year - picked.year;
    int months = now.month - picked.month;
    if (now.day < picked.day) months -= 1;
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    if (years < 0) return '0yr 0mo';
    return '${years}yr ${months}mo';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 15, color: Colors.black87),
            children: [
              TextSpan(text: "${widget.catName}'s age  "),
              TextSpan(text: _ageLabel, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: picked,
            maximumDate: DateTime.now(),
            minimumYear: 2000,
            onDateTimeChanged: (value) => setState(() => picked = value),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => widget.onSubmit(picked),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3) Težina — toggle lb/kg + slider (pojednostavljena verzija ravnala sa slike)
// ---------------------------------------------------------------------------
class WeightPickerSheet extends StatefulWidget {
  final double? initialKg;
  final void Function(double kg) onSubmit;

  const WeightPickerSheet({super.key, required this.initialKg, required this.onSubmit});

  @override
  State<WeightPickerSheet> createState() => _WeightPickerSheetState();
}

class _WeightPickerSheetState extends State<WeightPickerSheet> {
  bool useKg = true;
  late double kgValue = widget.initialKg ?? 4.0;

  double get _displayValue => useKg ? kgValue : kgValue * 2.20462;
  String get _unitLabel => useKg ? 'kg' : 'lb';

  void _setDisplayValue(double displayVal) {
    setState(() => kgValue = useKg ? displayVal : displayVal / 2.20462);
  }

  @override
  Widget build(BuildContext context) {
    final displayVal = _displayValue;
    final min = useKg ? 0.5 : 1.0;
    final max = useKg ? 15.0 : 33.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _unitToggleButton('lb', !useKg),
                _unitToggleButton('kg', useKg),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '${displayVal.toStringAsFixed(1)} $_unitLabel',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.green),
        ),
        const SizedBox(height: 20),
        Slider(
          value: displayVal.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) * 10).round(),
          activeColor: Colors.black87,
          onChanged: (v) => _setDisplayValue(v),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => widget.onSubmit(kgValue),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _unitToggleButton(String label, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => useKg = label == 'kg'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)] : null,
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? Colors.black87 : Colors.black45)),
      ),
    );
  }
}
