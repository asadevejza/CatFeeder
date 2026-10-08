import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../localization/app_strings.dart';
import '../models/cat.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class ScheduleFormScreen extends StatefulWidget {
  final String baseUrl;
  final List<Cat> cats;
  final Map<String, dynamic>? existingSchedule;
  final int? initialCatId;

  const ScheduleFormScreen({
    super.key,
    required this.baseUrl,
    required this.cats,
    this.existingSchedule,
    this.initialCatId,
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
      final schedule = widget.existingSchedule!;
      final rawCatId = schedule['catId'];
      selectedCatId = rawCatId is num ? rawCatId.toInt() : int.tryParse('$rawCatId');
      final rawPortion = schedule['portionGrams'];
      selectedPortion = rawPortion is num ? rawPortion.toInt().clamp(5, 200).toInt() : 50;

      final timeString = schedule['time']?.toString() ?? '08:00:00';
      final parts = timeString.split(':');
      selectedTime = TimeOfDay(
        hour: int.tryParse(parts.isNotEmpty ? parts[0] : '8') ?? 8,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      );

      final days = schedule['daysOfWeek'];
      if (days is List) {
        selectedDays.addAll(days.map((e) => e.toString().trim()).where((e) => e.isNotEmpty));
      } else {
        selectedDays.addAll((days?.toString() ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
      }
    } else {
      selectedCatId = widget.initialCatId ?? (widget.cats.isNotEmpty ? widget.cats.first.id : null);
    }
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: selectedTime);
    if (picked != null && mounted) setState(() => selectedTime = picked);
  }

  String get _timeAsString {
    final hour = selectedTime.hour.toString().padLeft(2, '0');
    final minute = selectedTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  Future<void> save() async {
    if (selectedCatId == null) {
      _message(AppStrings.t('choose_cat'));
      return;
    }
    if (selectedDays.isEmpty) {
      _message(AppStrings.t('choose_day'));
      return;
    }

    setState(() => isSaving = true);

    final body = <String, dynamic>{
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
        int? scheduleId;
        if (isEditMode) {
          final rawId = widget.existingSchedule!['id'];
          scheduleId = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
        } else {
          try {
            final decoded = json.decode(response.body);
            if (decoded is Map) {
              final rawId = decoded['id'] ?? decoded['scheduleId'];
              scheduleId = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
            }
          } catch (_) {}

          // Neki backend-i vrate 204/bez tijela i ne vrate ID novog reda.
          // U tom slučaju pronađemo upravo spremljeni raspored ponovnim GET-om.
          if (scheduleId == null) {
            try {
              final schedulesResponse = await http.get(
                Uri.parse('${widget.baseUrl}/feedingschedules'),
                headers: apiHeaders(),
              );
              if (schedulesResponse.statusCode == 200) {
                final all = json.decode(schedulesResponse.body) as List<dynamic>;
                final match = all.where((item) {
                  if (item is! Map) return false;
                  final rawCatId = item['catId'];
                  final itemCatId = rawCatId is num ? rawCatId.toInt() : int.tryParse('$rawCatId');
                  return itemCatId == selectedCatId &&
                      item['time']?.toString().startsWith(_timeAsString.substring(0, 5)) == true &&
                      '${item['daysOfWeek'] ?? ''}' == selectedDays.join(',');
                }).toList();
                if (match.isNotEmpty) {
                  final rawId = match.last['id'];
                  scheduleId = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
                }
              }
            } catch (_) {}
          }
        }

        if (scheduleId != null) {
          final cat = widget.cats.firstWhere(
            (item) => item.id == selectedCatId,
            orElse: () => widget.cats.first,
          );
          try {
            await NotificationService.scheduleForFeedingSchedule(
              scheduleId: scheduleId!,
              catName: cat.name,
              timeString: _timeAsString,
              portionGrams: selectedPortion,
              daysOfWeekCsv: selectedDays.join(','),
            );
          } catch (_) {}
        }

        Navigator.pop(context, true);
      } else {
        var message = AppStrings.t('schedule_save_error');
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map && decoded['error'] != null) message = decoded['error'].toString();
        } catch (_) {}
        _message(message);
      }
    } catch (e) {
      if (!mounted) return;
      _message('${AppStrings.t('connection_error_prefix')}$e');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditMode ? 'Uredi hranjenje' : 'Novi termin hranjenja'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Za koju mačku?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (widget.cats.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.tint50, borderRadius: BorderRadius.circular(15)),
                  child: const Text('Prvo dodaj mačku.'),
                )
              else
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: widget.cats.map((cat) {
                    final selected = selectedCatId == cat.id;
                    return ChoiceChip(
                      label: Text(cat.name),
                      selected: selected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w800),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: BorderSide(color: selected ? AppColors.primary : AppColors.cardBorder),
                      ),
                      onSelected: (_) => setState(() => selectedCatId = cat.id),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),
              const Text('Vrijeme hranjenja', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              InkWell(
                onTap: pickTime,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 17),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
                  child: Row(
                    children: [
                      Container(width: 39, height: 39, decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.access_time_rounded, color: AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(selectedTime.format(context), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900))),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Text('Količina obroka', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900))),
                  Text('$selectedPortion g', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.cardBorder)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: selectedPortion <= 5 ? null : () => setState(() => selectedPortion = (selectedPortion - 5).clamp(5, 200).toInt()),
                          style: IconButton.styleFrom(backgroundColor: AppColors.lavender),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        Expanded(
                          child: Slider(
                            min: 5,
                            max: 200,
                            divisions: 39,
                            value: selectedPortion.toDouble(),
                            activeColor: AppColors.primary,
                            onChanged: (v) => setState(() => selectedPortion = (v / 5).round() * 5),
                          ),
                        ),
                        IconButton(
                          onPressed: selectedPortion >= 200 ? null : () => setState(() => selectedPortion = (selectedPortion + 5).clamp(5, 200).toInt()),
                          style: IconButton.styleFrom(backgroundColor: AppColors.lavender),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 7,
                      children: [20, 40, 60, 80, 100, 150].map((grams) {
                        final selected = selectedPortion == grams;
                        return ChoiceChip(
                          label: Text('$grams g'),
                          selected: selected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w800, fontSize: 10.5),
                          onSelected: (_) => setState(() => selectedPortion = grams),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Dani u sedmici', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _dayOptions.map((day) {
                  final selected = selectedDays.contains(day['en']);
                  return FilterChip(
                    label: Text(day['bs']!),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w800),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                      side: BorderSide(color: selected ? AppColors.primary : AppColors.cardBorder),
                    ),
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          selectedDays.add(day['en']!);
                        } else {
                          selectedDays.remove(day['en']!);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isSaving ? null : save,
                  child: isSaving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(isEditMode ? 'Sačuvaj promjene' : 'Dodaj hranjenje'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
