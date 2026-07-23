import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/cat.dart';

class ScheduleFormScreen extends StatefulWidget {
  final String baseUrl;
  final List<Cat> cats;
  final Map<String, dynamic>? existingSchedule; // null = dodavanje novog

  const ScheduleFormScreen({
    super.key,
    required this.baseUrl,
    required this.cats,
    this.existingSchedule,
  });

  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}


class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  static const List<Map<String, String>> _dayOptions = [
    {'en': 'Monday', 'bs': 'Pon'},
    {'en': 'Tuesday', 'bs': 'Uto'},
    {'en': 'Wednesday', 'bs': 'Sri'},
    {'en': 'Thursday', 'bs': 'Čet'},
    {'en': 'Friday', 'bs': 'Pet'},
    {'en': 'Saturday', 'bs': 'Sub'},
    {'en': 'Sunday', 'bs': 'Ned'},
  ];

  int? selectedCatId;
  TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
  int selectedPortion = 50;
  final Set<String> selectedDays = {};
  bool isSaving = false;

  bool get isEditMode => widget.existingSchedule != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      final s = widget.existingSchedule!;
      selectedCatId = s['catId'] as int?;
      selectedPortion = (s['portionGrams'] as num?)?.toInt() ?? 50;

      final timeStr = (s['time'] as String?) ?? '08:00:00';
      final parts = timeStr.split(':');
      selectedTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
      );

      final daysStr = (s['daysOfWeek'] as String?) ?? '';
      selectedDays.addAll(daysStr.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty));
    } else if (widget.cats.isNotEmpty) {
      selectedCatId = widget.cats.first.id;
    }
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: selectedTime);
    if (picked != null) setState(() => selectedTime = picked);
  }

  String get _timeAsString {
    final h = selectedTime.hour.toString().padLeft(2, '0');
    final m = selectedTime.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  Future<void> save() async {
    if (selectedCatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izaberi mačku.')));
      return;
    }
    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izaberi bar jedan dan u sedmici.')));
      return;
    }

    setState(() => isSaving = true);

    final body = {
      'catId': selectedCatId,
      'time': _timeAsString,
      'portionGrams': selectedPortion,
      'daysOfWeek': selectedDays.join(','),
      if (isEditMode) 'id': widget.existingSchedule!['id'],
    };

    try {
      final http.Response response;
      if (isEditMode) {
        final id = widget.existingSchedule!['id'];
        response = await http.put(
          Uri.parse('${widget.baseUrl}/feedingschedules/$id'),
          headers: apiHeaders(withJsonBody: true),
          body: json.encode(body),
        );
      } else {
        response = await http.post(
          Uri.parse('${widget.baseUrl}/feedingschedules'),
          headers: apiHeaders(withJsonBody: true),
          body: json.encode(body),
        );
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        Navigator.pop(context, true);
      } else {
        String message = 'Greška pri čuvanju rasporeda.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditMode ? 'Uredi raspored' : 'Novi raspored')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Mačka', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (widget.cats.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.lightBlue.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Nemaš nijednu mačku — dodaj je prvo na ekranu za hranjenje.'),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: widget.cats.map((cat) {
                    final selected = cat.id == selectedCatId;
                    return ChoiceChip(
                      label: Text(cat.name),
                      selected: selected,
                      selectedColor: Colors.lightBlue,
                      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: selected ? Colors.lightBlue : Colors.lightBlue.shade100),
                      ),
                      onSelected: (_) => setState(() => selectedCatId = cat.id),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 26),
              const Text('Vrijeme hranjenja', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              InkWell(
                onTap: pickTime,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.lightBlue.shade100, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: Colors.lightBlue),
                      const SizedBox(width: 12),
                      Text(selectedTime.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 26),
              const Text('Količina obroka', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [50, 100, 150].map((grams) {
                  final selected = selectedPortion == grams;
                  return GestureDetector(
                    onTap: () => setState(() => selectedPortion = grams),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? Colors.lightBlue : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? Colors.lightBlue : Colors.lightBlue.shade100, width: 2),
                      ),
                      child: Text('$grams g',
                          style: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w700)),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 26),
              const Text('Dani u sedmici', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _dayOptions.map((day) {
                  final selected = selectedDays.contains(day['en']);
                  return FilterChip(
                    label: Text(day['bs']!),
                    selected: selected,
                    selectedColor: Colors.lightBlue,
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: selected ? Colors.lightBlue : Colors.lightBlue.shade100),
                    ),
                    onSelected: (isSelected) => setState(() {
                      if (isSelected) {
                        selectedDays.add(day['en']!);
                      } else {
                        selectedDays.remove(day['en']!);
                      }
                    }),
                  );
                }).toList(),
              ),

              const SizedBox(height: 34),
              ElevatedButton(
                onPressed: isSaving ? null : save,
                child: isSaving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(isEditMode ? 'Sačuvaj izmjene' : 'Dodaj raspored'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
