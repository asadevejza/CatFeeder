import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api_config.dart';
import '../models/cat.dart';
import '../models/cat_profile.dart';
import '../services/auth_service.dart';
import '../services/cat_avatar_service.dart';
import '../services/profile_service.dart';
import '../services/user_avatar_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_logo.dart';
import 'schedule_form_screen.dart';

Cat? _findCat(List<Cat> cats, int? id) {
  if (cats.isEmpty) return null;

  for (final cat in cats) {
    if (cat.id == id) {
      return cat;
    }
  }

  return cats.first;
}

String _dayKey(DateTime d) {
  return '${d.year}-${d.month}-${d.day}';
}

int _levelQuarters(double value) {
  return ((value.clamp(0.0, 100.0) / 25).ceil())
      .clamp(0, 4)
      .toInt();
}

String _mealName(String time) {
  final hour = int.tryParse(time.split(':').first) ?? 0;

  if (hour < 11) {
    return 'Doručak';
  }

  if (hour < 17) {
    return 'Ručak';
  }

  return 'Večera';
}

String _time(dynamic value) {
  if (value == null) {
    return '--:--';
  }

  final stringValue = value.toString();

  if (stringValue.length >= 5 &&
      stringValue[2] == ':') {
    return stringValue.substring(0, 5);
  }

  final date = DateTime.tryParse(stringValue);

  if (date != null) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  return stringValue;
}

dynamic _v(dynamic raw, String key) {
  if (raw is! Map) {
    return null;
  }

  if (raw.containsKey(key)) {
    return raw[key];
  }

  final lower = key.toLowerCase();

  for (final entry in raw.entries) {
    if (entry.key.toString().toLowerCase() == lower) {
      return entry.value;
    }
  }

  return null;
}

List<String> _scheduleDays(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  final value = raw?.toString() ?? '';

  return value
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

bool _isScheduleEnabled(dynamic schedule) {
  final enabled = _v(schedule, 'enabled');

  return enabled == null ||
      enabled == true ||
      enabled.toString().toLowerCase() == 'true';
}

int? _dayNumber(String value) {
  final s = value.trim().toLowerCase();

  const map = {
    'monday': 1,
    'pon': 1,
    'ponedjeljak': 1,
    'tuesday': 2,
    'uto': 2,
    'utorak': 2,
    'wednesday': 3,
    'sri': 3,
    'srijeda': 3,
    'thursday': 4,
    'čet': 4,
    'cet': 4,
    'četvrtak': 4,
    'cetvrtak': 4,
    'friday': 5,
    'pet': 5,
    'petak': 5,
    'saturday': 6,
    'sub': 6,
    'subota': 6,
    'sunday': 7,
    'ned': 7,
    'nedjelja': 7,
  };

  return map[s];
}

class _NextFeeding {
  final DateTime dateTime;
  final int grams;
  final String meal;
  final String catName;
  final dynamic schedule;

  const _NextFeeding({
    required this.dateTime,
    required this.grams,
    required this.meal,
    required this.catName,
    required this.schedule,
  });
}

_NextFeeding? _findNextFeeding({
  required List<dynamic> schedules,
  required int? catId,
  required String catName,
  DateTime? now,
}) {
  if (catId == null) {
    return null;
  }

  final current = now ?? DateTime.now();

  _NextFeeding? best;

  for (final schedule in schedules) {
    final rawCatId = _v(schedule, 'catId');

    final scheduleCatId = rawCatId is num
        ? rawCatId.toInt()
        : int.tryParse('$rawCatId');

    if (scheduleCatId != catId ||
        !_isScheduleEnabled(schedule)) {
      continue;
    }

    final timeString = _time(
      _v(schedule, 'time'),
    );

    final parts = timeString.split(':');

    if (parts.length < 2) {
      continue;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      continue;
    }

    final days = _scheduleDays(
      _v(schedule, 'daysOfWeek'),
    );

    final allowedDays = days
        .map(_dayNumber)
        .whereType<int>()
        .toSet();

    if (allowedDays.isEmpty) {
      continue;
    }

    for (int offset = 0; offset <= 7; offset++) {
      final candidateDate = DateTime(
        current.year,
        current.month,
        current.day,
      ).add(
        Duration(days: offset),
      );

      if (!allowedDays.contains(
        candidateDate.weekday,
      )) {
        continue;
      }

      final candidate = DateTime(
        candidateDate.year,
        candidateDate.month,
        candidateDate.day,
        hour,
        minute,
      );

      if (!candidate.isAfter(current)) {
        continue;
      }

      final gramsRaw =
          _v(schedule, 'portionGrams') ??
          _v(schedule, 'portion') ??
          0;

      final grams = gramsRaw is num
          ? gramsRaw.toInt()
          : int.tryParse('$gramsRaw') ?? 0;

      final next = _NextFeeding(
        dateTime: candidate,
        grams: grams,
        meal: _mealName(timeString),
        catName: catName,
        schedule: schedule,
      );

      if (best == null ||
          candidate.isBefore(best.dateTime)) {
        best = next;
      }

      break;
    }
  }

  return best;
}

String _timeUntil(
  DateTime target,
  DateTime now,
) {
  final difference = target.difference(now);

  if (difference.isNegative) {
    return 'Sada';
  }

  final minutes = difference.inMinutes;
  final hours = minutes ~/ 60;
  final rest = minutes % 60;

  if (hours <= 0) {
    return 'za $rest min';
  }

  if (rest == 0) {
    return 'za $hours h';
  }

  return 'za $hours h $rest min';
}

String _clock(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

// ============================================================
// HOME
// ============================================================

class ModernHomeScreen extends StatefulWidget {
  final double foodLevel;
  final double temp;
  final double humidity;
  final double? waterLevel;
  final bool loading;
  final bool connectionError;
  final List<Cat> cats;
  final int? selectedCatId;
  final Map<int, Map<String, dynamic>> summaries;
  final String baseUrl;
  final Future<void> Function() onRefresh;
  final Future<bool> Function(int, int) onFeedNow;
  final VoidCallback onProfile;
  final VoidCallback onAddCat;
  final VoidCallback onOpenFeeder;
  final VoidCallback onOpenDetection;
  final VoidCallback onOpenChat;
  final void Function(int) onSelectCat;

  const ModernHomeScreen({
    super.key,
    required this.foodLevel,
    required this.waterLevel,
    required this.temp,
    required this.humidity,
    required this.loading,
    required this.connectionError,
    required this.cats,
    required this.selectedCatId,
    required this.summaries,
    required this.baseUrl,
    required this.onRefresh,
    required this.onFeedNow,
    required this.onProfile,
    required this.onAddCat,
    required this.onOpenFeeder,
    required this.onOpenDetection,
    required this.onOpenChat,
    required this.onSelectCat,
  });

  @override
  State<ModernHomeScreen> createState() =>
      _ModernHomeScreenState();
}

class _ModernHomeScreenState
    extends State<ModernHomeScreen> {
  Map<int, Uint8List> avatars = {};
  Map<int, CatProfile> profiles = {};

  Uint8List? userAvatar;
  String? userName;

  List<dynamic> schedules = [];

  bool feeding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(
    covariant ModernHomeScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.cats != widget.cats ||
        oldWidget.selectedCatId !=
            widget.selectedCatId ||
        oldWidget.baseUrl != widget.baseUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    final newAvatars = <int, Uint8List>{};
    final newProfiles = <int, CatProfile>{};

    for (final cat in widget.cats) {
      try {
        final bytes =
            await CatAvatarService.getAvatarBytes(
          cat.id,
        );

        if (bytes != null && bytes.isNotEmpty) {
          newAvatars[cat.id] = bytes;
        }
      } catch (_) {}

      try {
        newProfiles[cat.id] =
            await ProfileService.getCatProfile(
                  cat.id,
                ) ??
                CatProfile(
                  gender:
                      cat.sex?.toLowerCase() == 'female'
                          ? 'Ženka'
                          : 'Mužjak',
                  breed: cat.breed ?? 'Mješanac',
                  ageYears: 0,
                  weightKg: cat.weightKg ?? 0,
                  dailyGoalGrams:
                      int.tryParse(cat.goals ?? '') ??
                          200,
                );
      } catch (_) {
        newProfiles[cat.id] = CatProfile(
          gender:
              cat.sex?.toLowerCase() == 'female'
                  ? 'Ženka'
                  : 'Mužjak',
          breed: cat.breed ?? 'Mješanac',
          ageYears: 0,
          weightKg: cat.weightKg ?? 0,
          dailyGoalGrams:
              int.tryParse(cat.goals ?? '') ?? 200,
        );
      }
    }

    String? name;

    try {
      name = await ProfileService.getUserDisplayName();
    } catch (_) {}

    Uint8List? avatar;

    try {
      avatar = await UserAvatarService.getAvatarBytes();
    } catch (_) {}

    List<dynamic> loadedSchedules = [];

    try {
      final response = await http.get(
        Uri.parse(
          '${widget.baseUrl}/feedingschedules',
        ),
        headers: apiHeaders(),
      );

      if (response.statusCode == 200) {
        loadedSchedules =
            json.decode(response.body)
                as List<dynamic>;
      }
    } catch (_) {}

    if (!mounted) {
      return;
    }

    setState(() {
      avatars = newAvatars;
      profiles = newProfiles;
      userName = name;
      userAvatar = avatar;
      schedules = loadedSchedules;
    });
  }

  Cat? get selectedCat {
    return _findCat(
      widget.cats,
      widget.selectedCatId,
    );
  }

  Future<void> _feed() async {
    final cat = selectedCat;

    if (cat == null) {
      return;
    }

    final prefs =
        await SharedPreferences.getInstance();

    final portion = prefs.getInt(
          'feeder_default_portion_g',
        ) ??
        60;

    setState(() {
      feeding = true;
    });

    final ok = await widget.onFeedNow(
      cat.id,
      portion,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      feeding = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Obrok od $portion g je ispušten za ${cat.name}.'
              : 'Hranjenje nije uspjelo.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = selectedCat;

    final profile =
        cat == null ? null : profiles[cat.id];

    final summary =
        cat == null
            ? null
            : widget.summaries[cat.id];

    final today =
        (summary?['todayGrams'] as num?)
                ?.toInt() ??
            0;

    final goal =
        profile?.dailyGoalGrams ?? 200;

    final foodProgress = goal <= 0
        ? 0.0
        : (today / goal)
            .clamp(0.0, 1.0)
            .toDouble();

    final next = _findNextFeeding(
      schedules: schedules,
      catId: widget.selectedCatId,
      catName: cat?.name ?? '',
    );

    final greetingName =
        userName?.trim().isNotEmpty == true
            ? userName!.trim()
            : (AuthService.currentUsername
                        ?.trim()
                        .isNotEmpty ==
                    true
                ? AuthService.currentUsername!
                    .trim()
                : 'Korisniče');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: widget.onRefresh,
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              14,
              20,
              30,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pozdrav, $greetingName 👋',
                          style:
                              const TextStyle(
                            fontSize: 24,
                            fontWeight:
                                FontWeight.w900,
                            color:
                                AppColors.textDark,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Briga o tvojim mačkama, na jednom mjestu.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color:
                                AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onProfile,
                    child: Container(
                      width: 46,
                      height: 46,
                      clipBehavior:
                          Clip.antiAlias,
                      decoration:
                          BoxDecoration(
                        color:
                            AppColors.lavender,
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),
                      child: userAvatar == null
                          ? const Icon(
                              Icons
                                  .person_rounded,
                              color:
                                  AppColors
                                      .primary,
                            )
                          : Image.memory(
                              userAvatar!,
                              fit: BoxFit.cover,
                              filterQuality:
                                  FilterQuality
                                      .high,
                              gaplessPlayback:
                                  true,
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 21),

              _SectionHeader(
                title: 'Moje mačke',
                action: widget.cats.length < 6
                    ? 'Dodaj'
                    : null,
                onAction: widget.onAddCat,
              ),

              const SizedBox(height: 10),

              if (widget.cats.isEmpty)
                _EmptyCatCard(
                  onTap: widget.onAddCat,
                )
              else
                _CatSelector(
                  cats: widget.cats,
                  selectedCatId:
                      widget.selectedCatId,
                  avatars: avatars,
                  onSelect:
                      widget.onSelectCat,
                ),

              if (cat != null) ...[
                const SizedBox(height: 15),

                _SelectedCatSummary(
                  cat: cat,
                  profile: profile,
                  bytes: avatars[cat.id],
                  today: today,
                  goal: goal,
                  onTap: widget.onProfile,
                ),

                const SizedBox(height: 13),

                Row(
                  children: [
                    Expanded(
                      child: _HomeMetric(
                        icon: Icons
                            .restaurant_rounded,
                        label: 'Danas hrana',
                        value:
                            '$today g / $goal g',
                        tint:
                            AppColors.lavender,
                        progress:
                            foodProgress,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HomeMetric(
                        icon: Icons
                            .water_drop_rounded,
                        label: 'Voda',
                        value:
                            '${(widget.waterLevel ?? 0).round()}%',
                        tint: AppColors.sky,
                        progress:
                            (widget.waterLevel ??
                                    0) /
                                100,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 19),

              const Text(
                'Status hranilice',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      AppColors.textDark,
                ),
              ),

              const SizedBox(height: 9),

              _FeederStatusCard(
                food:
                    widget.foodLevel,
                water:
                    widget.waterLevel,
                next: next,
                selectedCat: cat,
                onTap:
                    widget.onOpenFeeder,
              ),

              const SizedBox(height: 19),

              const Text(
                'Brza akcija',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      AppColors.textDark,
                ),
              ),

              const SizedBox(height: 9),

              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons
                          .restaurant_rounded,
                      title:
                          'Hraniti odmah',
                      subtitle:
                          'Odabrana mačka',
                      tint:
                          AppColors.lavender,
                      onTap:
                          feeding
                              ? null
                              : _feed,
                      loading:
                          feeding,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons
                          .calendar_month_rounded,
                      title: 'Raspored',
                      subtitle:
                          'Obroci i alarmi',
                      tint: AppColors.sky,
                      onTap:
                          widget.onOpenFeeder,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons
                          .camera_alt_rounded,
                      title: 'AI pregled',
                      subtitle:
                          'Zdravlje mačke',
                      tint: AppColors.mint,
                      onTap:
                          widget
                              .onOpenDetection,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons
                          .chat_bubble_rounded,
                      title:
                          'AI savjetnik',
                      subtitle:
                          'Pitaj nešto',
                      tint: AppColors.peach,
                      onTap:
                          widget.onOpenChat,
                    ),
                  ),
                ],
              ),

              if (widget.connectionError) ...[
                const SizedBox(height: 14),
                _WarningCard(
                  onTap:
                      widget.onRefresh,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// STATISTICS
// ============================================================

class ModernStatsScreen
    extends StatefulWidget {
  final double food;
  final double water;
  final double temp;
  final double humidity;
  final List<Cat> cats;
  final int? selectedCatId;
  final Map<int, Map<String, dynamic>>
      summaries;
  final String baseUrl;
  final void Function(int) onSelectCat;

  const ModernStatsScreen({
    super.key,
    required this.food,
    required this.water,
    required this.temp,
    required this.humidity,
    required this.cats,
    required this.selectedCatId,
    required this.summaries,
    required this.baseUrl,
    required this.onSelectCat,
  });

  @override
  State<ModernStatsScreen> createState() =>
      _ModernStatsScreenState();
}

class _ModernStatsScreenState
    extends State<ModernStatsScreen> {
  int rangeDays = 7;

  DateTimeRange? customRange;

  bool loading = true;

  List<_DayFeeding> points = [];

  CatProfile? profile;

  Map<int, Uint8List> avatars = {};

  int totalMeals = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(
    covariant ModernStatsScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedCatId !=
            widget.selectedCatId ||
        oldWidget.baseUrl != widget.baseUrl ||
        oldWidget.cats != widget.cats) {
      _load();
    }
  }

  Future<void> _load() async {
    final catId =
        widget.selectedCatId;

    if (catId == null) {
      if (mounted) {
        setState(() {
          loading = false;
          points = [];
          totalMeals = 0;
        });
      }

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      profile =
          await ProfileService
              .getCatProfile(catId);
    } catch (_) {
      profile = null;
    }

    final end = DateTime.now();

    final start =
        customRange?.start ??
            DateTime(
              end.year,
              end.month,
              end.day,
            ).subtract(
              Duration(
                days: rangeDays - 1,
              ),
            );

    final finish =
        customRange?.end ??
            DateTime(
              end.year,
              end.month,
              end.day,
            );

    try {
      final response = await http.get(
        Uri.parse(
          '${widget.baseUrl}/feedinglogs',
        ),
        headers: apiHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}',
        );
      }

      final rawLogs =
          json.decode(response.body)
              as List<dynamic>;

      final map = <String, int>{};

      for (
        DateTime day = DateTime(
          start.year,
          start.month,
          start.day,
        );
        !day.isAfter(finish);
        day = day.add(
          const Duration(days: 1),
        )
      ) {
        map[_dayKey(day)] = 0;
      }

      int meals = 0;

      for (final raw in rawLogs) {
        final rawCatId =
            _v(raw, 'catId');

        final id = rawCatId is num
            ? rawCatId.toInt()
            : int.tryParse(
                '$rawCatId',
              );

        if (id != catId) {
          continue;
        }

        final rawDate =
            _v(raw, 'timestamp') ??
            _v(raw, 'createdAt') ??
            _v(raw, 'date');

        final timestamp =
            DateTime.tryParse(
              '$rawDate',
            )?.toLocal();

        if (timestamp == null) {
          continue;
        }

        final day = DateTime(
          timestamp.year,
          timestamp.month,
          timestamp.day,
        );

        if (day.isBefore(
              DateTime(
                start.year,
                start.month,
                start.day,
              ),
            ) ||
            day.isAfter(
              DateTime(
                finish.year,
                finish.month,
                finish.day,
              ),
            )) {
          continue;
        }

        final gramsRaw =
            _v(raw, 'portionGrams') ??
            _v(raw, 'portion') ??
            _v(raw, 'grams') ??
            0;

        final grams = gramsRaw is num
            ? gramsRaw.toInt()
            : int.tryParse(
                  '$gramsRaw',
                ) ??
                0;

        map[_dayKey(day)] =
            (map[_dayKey(day)] ?? 0) +
                grams;

        meals++;
      }

      final result =
          map.entries.map((entry) {
        final parts =
            entry.key.split('-');

        return _DayFeeding(
          DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          ),
          entry.value,
        );
      }).toList()
            ..sort(
              (a, b) =>
                  a.date.compareTo(b.date),
            );

      final allAvatars =
          <int, Uint8List>{...avatars};

      for (final cat in widget.cats) {
        try {
          final bytes =
              await CatAvatarService
                  .getAvatarBytes(
            cat.id,
          );

          if (bytes != null &&
              bytes.isNotEmpty) {
            allAvatars[cat.id] = bytes;
          }
        } catch (_) {}
      }

      try {
        final avatar =
            await CatAvatarService
                .getAvatarBytes(
          catId,
        );

        if (avatar != null &&
            avatar.isNotEmpty) {
          allAvatars[catId] =
              avatar;
        }
      } catch (_) {}

      if (!mounted) {
        return;
      }

      setState(() {
        avatars = allAvatars;
        points = result;
        totalMeals = meals;
        loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        points = [];
        totalMeals = 0;
        loading = false;
      });
    }
  }

  void _selectDays(int days) {
    setState(() {
      rangeDays = days;
      customRange = null;
    });

    _load();
  }

  Future<void> _chooseCustom() async {
    final now = DateTime.now();

    final picked =
        await showDateRangePicker(
      context: context,
      firstDate: DateTime(
        now.year - 2,
      ),
      lastDate: now,
      initialDateRange:
          customRange ??
              DateTimeRange(
                start: now.subtract(
                  const Duration(days: 6),
                ),
                end: now,
              ),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      customRange = picked;
    });

    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cat = _findCat(
      widget.cats,
      widget.selectedCatId,
    );

    final total = points.fold<int>(
      0,
      (
        sum,
        item,
      ) =>
          sum + item.grams,
    );

    final average = points.isEmpty
        ? 0
        : (total / points.length)
            .round();

    final target =
        profile?.dailyGoalGrams ?? 200;

    final adherence = target <= 0
        ? 0
        : ((average / target) * 100)
            .round();

    final today =
        points.isEmpty
            ? 0
            : points.last.grams;

    final activeDays = points
        .where(
          (point) => point.grams > 0,
        )
        .length;

    return Scaffold(
      backgroundColor:
          AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color:
              AppColors.primary,
          onRefresh: _load,
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              14,
              20,
              30,
            ),
            children: [
              const Text(
                'Statistika',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      AppColors.textDark,
                  letterSpacing: -0.8,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Odaberi mačku za koju želiš pregled potrošnje hrane.',
                style: TextStyle(
                  fontSize: 11.5,
                  color:
                      AppColors.textMuted,
                ),
              ),

              const SizedBox(height: 15),

              _CatSelector(
                cats: widget.cats,
                selectedCatId:
                    widget.selectedCatId,
                avatars: avatars,
                onSelect:
                    widget.onSelectCat,
              ),

              const SizedBox(height: 15),

              _RangeTabs(
                days: rangeDays,
                custom:
                    customRange != null,
                on7: () =>
                    _selectDays(7),
                on30: () =>
                    _selectDays(30),
                onCustom:
                    _chooseCustom,
              ),

              const SizedBox(height: 14),

              if (cat == null)
                _EmptyCatCard(
                  onTap: () {},
                )
              else ...[
                _StatsHero(
                  cat: cat,
                  avatar:
                      avatars[cat.id],
                  total: total,
                  adherence:
                      adherence,
                  average: average,
                  meals: totalMeals,
                ),

                const SizedBox(
                  height: 12,
                ),

                ModernCard(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    16,
                    17,
                    16,
                    14,
                  ),
                  radius: 22,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Grafikon ishrane',
                              style: TextStyle(
                                fontSize:
                                    15,
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                          ),
                          Text(
                            '${points.length} dana',
                            style:
                                const TextStyle(
                              fontSize: 10,
                              color:
                                  AppColors
                                      .textMuted,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      if (loading)
                        const SizedBox(
                          height: 230,
                          child:
                              Center(
                            child:
                                CircularProgressIndicator(
                              color: AppColors
                                  .primary,
                            ),
                          ),
                        )
                      else if (points.isEmpty)
                        const SizedBox(
                          height: 230,
                          child: Center(
                            child: Text(
                              'Nema podataka za odabrani period',
                              style:
                                  TextStyle(
                                color:
                                    AppColors
                                        .textMuted,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        SizedBox(
                          height: 210,
                          child:
                              CustomPaint(
                            painter:
                                _FeedingChartPainter(
                              points,
                              target:
                                  target,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        _ChartLabels(
                          points: points,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Row(
                  children: [
                    _StatMetric(
                      label: 'Danas',
                      value: '$today g',
                      icon: Icons
                          .restaurant_rounded,
                      tint:
                          AppColors.lavender,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    _StatMetric(
                      label: 'Prosjek',
                      value: '$average g',
                      icon: Icons
                          .show_chart_rounded,
                      tint: AppColors.sky,
                    ),
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),

                Row(
                  children: [
                    _StatMetric(
                      label:
                          'Aktivni dani',
                      value:
                          '${activeDays}/${points.length}',
                      icon: Icons
                          .calendar_today_rounded,
                      tint: AppColors.mint,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    _StatMetric(
                      label: 'Cilj',
                      value: '$target g',
                      icon: Icons
                          .flag_rounded,
                      tint:
                          AppColors.peach,
                    ),
                  ],
                ),

                const SizedBox(
                  height: 16,
                ),

                const Text(
                  'Detalji hranilice',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 9),

                _DetailCard(
                  icon: Icons
                      .restaurant_rounded,
                  tint:
                      AppColors.lavender,
                  title: 'Hrana',
                  value: '$total g',
                  change:
                      '$adherence% prosječnog dnevnog cilja',
                ),

                const SizedBox(height: 9),

                _DetailCard(
                  icon: Icons
                      .water_drop_rounded,
                  tint: AppColors.sky,
                  title: 'Voda',
                  value:
                      '${widget.water.round()}%',
                  change:
                      'Trenutno stanje',
                ),

                const SizedBox(height: 9),

                _DetailCard(
                  icon: Icons
                      .thermostat_rounded,
                  tint:
                      AppColors.peach,
                  title:
                      'Temperatura',
                  value:
                      '${widget.temp.toStringAsFixed(1)}°C',
                  change:
                      'Senzor hranilice',
                ),

                const SizedBox(height: 9),

                _DetailCard(
                  icon: Icons
                      .opacity_rounded,
                  tint: AppColors.mint,
                  title: 'Vlažnost',
                  value:
                      '${widget.humidity.toStringAsFixed(0)}%',
                  change:
                      'Senzor hranilice',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FEEDER
// ============================================================

class ModernFeederScreen
    extends StatefulWidget {
  final double food;
  final double water;
  final List<Cat> cats;
  final int? selectedCatId;
  final Future<bool> Function(int, int)
      onFeedNow;
  final String baseUrl;
  final VoidCallback onAddCat;
  final VoidCallback onBack;
  final void Function(int) onSelectCat;

  const ModernFeederScreen({
    super.key,
    required this.food,
    required this.water,
    required this.cats,
    required this.selectedCatId,
    required this.onFeedNow,
    required this.baseUrl,
    required this.onAddCat,
    required this.onBack,
    required this.onSelectCat,
  });

  @override
  State<ModernFeederScreen> createState() =>
      _ModernFeederScreenState();
}

class _ModernFeederScreenState
    extends State<ModernFeederScreen> {
  int portion = 60;

  bool feeding = false;

  bool loadingSchedules =
      true;

  List<dynamic> schedules = [];

  @override
  void initState() {
    super.initState();

    _loadSettings();
    _loadSchedules();
  }

  @override
  void didUpdateWidget(
    covariant ModernFeederScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedCatId !=
            widget.selectedCatId ||
        oldWidget.baseUrl !=
            widget.baseUrl) {
      _loadSchedules();
    }
  }

  Future<void> _loadSettings() async {
    final prefs =
        await SharedPreferences
            .getInstance();

    final value = prefs.getInt(
          'feeder_default_portion_g',
        ) ??
        60;

    if (!mounted) {
      return;
    }

    setState(() {
      portion =
          value.clamp(5, 200).toInt();
    });
  }

  Future<void> _loadSchedules() async {
    if (mounted) {
      setState(() {
        loadingSchedules = true;
      });
    }

    try {
      final response = await http.get(
        Uri.parse(
          '${widget.baseUrl}/feedingschedules',
        ),
        headers: apiHeaders(),
      );

      if (response.statusCode == 200) {
        final all =
            json.decode(response.body)
                as List<dynamic>;

        final selected =
            widget.selectedCatId;

        final filtered =
            selected == null
                ? <dynamic>[]
                : all.where((schedule) {
                    final rawCatId =
                        _v(
                      schedule,
                      'catId',
                    );

                    final id =
                        rawCatId is num
                            ? rawCatId.toInt()
                            : int.tryParse(
                                '$rawCatId',
                              );

                    return id ==
                        selected;
                  }).toList();

        if (mounted) {
          setState(() {
            schedules =
                filtered;
            loadingSchedules =
                false;
          });
        }
      } else if (mounted) {
        setState(() {
          schedules = [];
          loadingSchedules =
              false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          schedules = [];
          loadingSchedules =
              false;
        });
      }
    }
  }

  Future<void> _savePortion(
    int value,
  ) async {
    final normalized =
        value.clamp(5, 200).toInt();

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setInt(
      'feeder_default_portion_g',
      normalized,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      portion = normalized;
    });
  }

  Future<void> _feed() async {
    final catId =
        widget.selectedCatId ??
            (widget.cats.isEmpty
                ? null
                : widget.cats.first.id);

    if (catId == null) {
      widget.onAddCat();
      return;
    }

    setState(() {
      feeding = true;
    });

    final ok =
        await widget.onFeedNow(
      catId,
      portion,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      feeding = false;
    });

    final cat =
        _findCat(
      widget.cats,
      catId,
    );

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Ispušteno $portion g za ${cat?.name ?? 'mačku'}.'
              : 'Hranjenje nije uspjelo.',
        ),
      ),
    );

    if (ok) {
      await _loadSchedules();
    }
  }

  Future<void> _editSchedule([
    dynamic existing,
  ]) async {
    final result =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ScheduleFormScreen(
          baseUrl:
              widget.baseUrl,
          cats:
              widget.cats,
          existingSchedule:
              existing is
                      Map<String, dynamic>
                  ? existing
                  : null,
          initialCatId:
              widget.selectedCatId,
        ),
      ),
    );

    if (result == true) {
      await _loadSchedules();
    }
  }

  Future<void> _openSettings() async {
    int value = portion;

    final result =
        await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder:
              (
                context,
                setSheetState,
              ) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 +
                    MediaQuery.of(
                      context,
                    ).viewInsets.bottom,
              ),
              decoration:
                  const BoxDecoration(
                color:
                    AppColors.background,
                borderRadius:
                    BorderRadius.vertical(
                  top: Radius.circular(
                    28,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration:
                            BoxDecoration(
                          color: AppColors
                              .cardBorder,
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    const Row(
                      children: [
                        Icon(
                          Icons
                              .tune_rounded,
                          color: AppColors
                              .primary,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Text(
                          'Postavke hranilice',
                          style:
                              TextStyle(
                            fontSize:
                                19,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    const Text(
                      'Ovdje postavljaš zadanu porciju za ručno hranjenje. Raspored ima svoju zasebnu porciju.',
                      style:
                          TextStyle(
                        fontSize: 11,
                        color: AppColors
                            .textMuted,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    ModernCard(
                      radius: 22,
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        16,
                        15,
                        16,
                        14,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child:
                                    Text(
                                  'Zadana porcija',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        13,
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                '$value g',
                                style:
                                    const TextStyle(
                                  fontSize:
                                      21,
                                  fontWeight:
                                      FontWeight.w900,
                                  color:
                                      AppColors
                                          .primary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          Row(
                            children: [
                              IconButton(
                                onPressed:
                                    value <=
                                            5
                                        ? null
                                        : () {
                                            setSheetState(
                                              () {
                                                value =
                                                    (value -
                                                            5)
                                                        .clamp(
                                                          5,
                                                          200,
                                                        )
                                                        .toInt();
                                              },
                                            );
                                          },
                                style:
                                    IconButton
                                        .styleFrom(
                                  backgroundColor:
                                      AppColors
                                          .lavender,
                                ),
                                icon:
                                    const Icon(
                                  Icons
                                      .remove_rounded,
                                ),
                              ),

                              Expanded(
                                child:
                                    Slider(
                                  min:
                                      5,
                                  max:
                                      200,
                                  divisions:
                                      39,
                                  value:
                                      value.toDouble(),
                                  activeColor:
                                      AppColors
                                          .primary,
                                  onChanged:
                                      (v) {
                                    setSheetState(
                                      () {
                                        value =
                                            (v / 5)
                                                    .round() *
                                                5;
                                      },
                                    );
                                  },
                                ),
                              ),

                              IconButton(
                                onPressed:
                                    value >=
                                            200
                                        ? null
                                        : () {
                                            setSheetState(
                                              () {
                                                value =
                                                    (value +
                                                            5)
                                                        .clamp(
                                                          5,
                                                          200,
                                                        )
                                                        .toInt();
                                              },
                                            );
                                          },
                                style:
                                    IconButton
                                        .styleFrom(
                                  backgroundColor:
                                      AppColors
                                          .lavender,
                                ),
                                icon:
                                    const Icon(
                                  Icons
                                      .add_rounded,
                                ),
                              ),
                            ],
                          ),

                          Wrap(
                            spacing: 8,
                            children: [
                              20,
                              40,
                              60,
                              80,
                              100,
                            ].map(
                              (preset) {
                                final active =
                                    value ==
                                        preset;

                                return ChoiceChip(
                                  label:
                                      Text(
                                    '$preset g',
                                  ),
                                  selected:
                                      active,
                                  selectedColor:
                                      AppColors
                                          .primary,
                                  labelStyle:
                                      TextStyle(
                                    color: active
                                        ? Colors
                                            .white
                                        : AppColors
                                            .textDark,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                    fontSize:
                                        11,
                                  ),
                                  onSelected:
                                      (_) {
                                    setSheetState(
                                      () {
                                        value =
                                            preset;
                                      },
                                    );
                                  },
                                );
                              },
                            ).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 13,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      height: 50,
                      child:
                          ElevatedButton(
                        onPressed:
                            () {
                          Navigator.pop(
                            sheetContext,
                            value,
                          );
                        },
                        child:
                            const Text(
                          'Sačuvaj postavke',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          TextButton.icon(
                        onPressed: () {
                          Navigator.pop(
                            sheetContext,
                          );

                          _editSchedule();
                        },
                        icon:
                            const Icon(
                          Icons
                              .calendar_month_rounded,
                        ),
                        label:
                            const Text(
                          'Uredi raspored hranjenja',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      await _savePortion(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected =
        _findCat(
      widget.cats,
      widget.selectedCatId,
    );

    final next =
        _findNextFeeding(
      schedules: schedules,
      catId:
          widget.selectedCatId,
      catName:
          selected?.name ?? '',
    );

    return Scaffold(
      backgroundColor:
          AppColors.background,
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            30,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed:
                      widget.onBack,
                  icon: const Icon(
                    Icons
                        .arrow_back_rounded,
                    color:
                        AppColors.textDark,
                  ),
                ),

                const Expanded(
                  child: Text(
                    'Hranilica',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),

                IconButton(
                  onPressed:
                      _openSettings,
                  tooltip:
                      'Postavke hranilice',
                  icon: const Icon(
                    Icons
                        .settings_outlined,
                    color:
                        AppColors.textDark,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 2,
            ),

            _CatSelector(
              cats: widget.cats,
              selectedCatId:
                  widget.selectedCatId,
              avatars: const {},
              onSelect:
                  widget.onSelectCat,
              compact: true,
            ),

            const SizedBox(
              height: 13,
            ),

            ModernCard(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                16,
                10,
                16,
                18,
              ),
              radius: 26,
              child: Column(
                children: [
                  SizedBox(
                    height: 158,
                    child: Stack(
                      alignment:
                          Alignment.center,
                      children: [
                        const Positioned(
                          left: 12,
                          top: 20,
                          child:
                              _CloudBlob(
                            width: 105,
                            height: 70,
                            color:
                                AppColors
                                    .lavender,
                          ),
                        ),
                        const Positioned(
                          right: 10,
                          top: 6,
                          child:
                              _CloudBlob(
                            width: 125,
                            height: 82,
                            color:
                                AppColors
                                    .mint,
                          ),
                        ),
                        const Positioned(
                          left: 38,
                          bottom: 0,
                          child:
                              _CloudBlob(
                            width: 235,
                            height: 76,
                            color:
                                AppColors
                                    .sky,
                          ),
                        ),
                        Container(
                          width: 122,
                          height: 122,
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape
                                    .circle,
                            color:
                                const Color(
                              0xFFF7FCF9,
                            ),
                            border:
                                Border.all(
                              color:
                                  AppColors
                                      .mintStrong,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors
                                    .mintStrong
                                    .withOpacity(
                                      .12,
                                    ),
                                blurRadius:
                                    20,
                              ),
                            ],
                          ),
                          child:
                              const Center(
                            child:
                                _FeederIcon(
                              size:
                                  62,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Text(
                    'Spremna',
                    style:
                        TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    selected == null
                        ? 'Odaberi mačku za zakazivanje obroka.'
                        : 'Hranjenje je povezano sa profilom ${selected.name}.',
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      fontSize: 11.5,
                      color: AppColors
                          .textMuted,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  SizedBox(
                    width:
                        double.infinity,
                    height: 48,
                    child:
                        ElevatedButton
                            .icon(
                      onPressed:
                          feeding
                              ? null
                              : _feed,
                      icon: feeding
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                                color:
                                    Colors
                                        .white,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .restaurant_rounded,
                              size: 18,
                            ),
                      label: Text(
                        'Hraniti odmah • $portion g',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 13,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      _FeederLevelCard(
                    icon: Icons
                        .restaurant_rounded,
                    title: 'Hrana',
                    value:
                        '${widget.food.round()}%',
                    progress:
                        widget.food /
                            100,
                    tint:
                        AppColors.lavender,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child:
                      _FeederLevelCard(
                    icon: Icons
                        .water_drop_rounded,
                    title: 'Voda',
                    value:
                        '${widget.water.round()}%',
                    progress:
                        widget.water /
                            100,
                    tint:
                        AppColors.sky,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 17,
            ),

            ModernCard(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                16,
                15,
                16,
                15,
              ),
              radius: 22,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration:
                        BoxDecoration(
                      color:
                          AppColors.mint,
                      borderRadius:
                          BorderRadius
                              .circular(
                        15,
                      ),
                    ),
                    child:
                        const Icon(
                      Icons
                          .schedule_rounded,
                      color:
                          AppColors
                              .mintStrong,
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'Sljedeće hranjenje',
                          style:
                              TextStyle(
                            fontSize: 10.5,
                            color:
                                AppColors
                                    .textMuted,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),

                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          next == null
                              ? 'Nije postavljeno'
                              : '${_formatDate(next.dateTime)} • ${_clock(next.dateTime)}',
                          style:
                              const TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),

                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          next == null
                              ? 'Dodaj termin da bi hranilica znala kada hraniti.'
                              : '${next.meal} • ${next.grams} g • ${_timeUntil(next.dateTime, DateTime.now())}',
                          style:
                              const TextStyle(
                            fontSize:
                                10.5,
                            color:
                                AppColors
                                    .textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed:
                        () => _editSchedule(
                          next?.schedule,
                        ),
                    icon:
                        const Icon(
                      Icons
                          .chevron_right_rounded,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 17,
            ),

            Row(
              children: [
                const Expanded(
                  child:
                      Text(
                    'Raspored hranjenja',
                    style:
                        TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),

                TextButton.icon(
                  onPressed:
                      () => _editSchedule(),
                  icon:
                      const Icon(
                    Icons.add_rounded,
                    size: 18,
                  ),
                  label:
                      const Text(
                    'Dodaj',
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 5,
            ),

            ModernCard(
              padding:
                  const EdgeInsets
                      .symmetric(
                vertical: 4,
              ),
              radius: 21,
              child:
                  loadingSchedules
                      ? const Padding(
                          padding:
                              EdgeInsets.all(
                            28,
                          ),
                          child:
                              Center(
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          ),
                        )
                      : schedules.isEmpty
                          ? _EmptySchedule(
                              onTap:
                                  () =>
                                      _editSchedule(),
                            )
                          : Column(
                              children: [
                                for (
                                  int i = 0;
                                  i <
                                      schedules
                                          .length;
                                  i++
                                ) ...[
                                  _ScheduleRow(
                                    schedule:
                                        schedules[
                                            i],
                                    onTap: () =>
                                        _editSchedule(
                                      schedules[
                                          i],
                                    ),
                                  ),
                                  if (i <
                                      schedules.length -
                                          1)
                                    const Divider(
                                      height:
                                          1,
                                      indent:
                                          64,
                                      endIndent:
                                          15,
                                    ),
                                ],
                              ],
                            ),
            ),

            const SizedBox(
              height: 13,
            ),

            Row(
              children: [
                _FeederStat(
                  icon: Icons
                      .water_drop_outlined,
                  title: 'Voda',
                  value:
                      '${widget.water.round()}%',
                  tint:
                      AppColors.sky,
                ),
                const SizedBox(
                  width: 10,
                ),
                _FeederStat(
                  icon: Icons
                      .restaurant_outlined,
                  title: 'Porcija',
                  value:
                      '$portion g',
                  tint:
                      AppColors.lavender,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(
    DateTime value,
  ) {
    final today =
        DateTime.now();

    if (value.year ==
            today.year &&
        value.month ==
            today.month &&
        value.day ==
            today.day) {
      return 'Danas';
    }

    final tomorrow =
        today.add(
      const Duration(days: 1),
    );

    if (value.year ==
            tomorrow.year &&
        value.month ==
            tomorrow.month &&
        value.day ==
            tomorrow.day) {
      return 'Sutra';
    }

    return '${value.day.toString().padLeft(2, '0')}.'
        '${value.month.toString().padLeft(2, '0')}.';
  }
}

// ============================================================
// PROFILE
// ============================================================

class ModernProfileScreen
    extends StatefulWidget {
  final List<Cat> cats;
  final int? selectedCatId;
  final VoidCallback onAddCat;
  final void Function(Cat) onEdit;
  final void Function(int) onSelectCat;

  const ModernProfileScreen({
    super.key,
    required this.cats,
    required this.selectedCatId,
    required this.onAddCat,
    required this.onEdit,
    required this.onSelectCat,
  });

  @override
  State<ModernProfileScreen> createState() =>
      _ModernProfileScreenState();
}

class _ModernProfileScreenState
    extends State<ModernProfileScreen> {
  Map<int, Uint8List> avatars = {};
  Map<int, CatProfile> profiles = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(
    covariant ModernProfileScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.cats !=
            widget.cats ||
        oldWidget.selectedCatId !=
            widget.selectedCatId) {
      _load();
    }
  }

  Future<void> _load() async {
    final newAvatars =
        <int, Uint8List>{};

    final newProfiles =
        <int, CatProfile>{};

    for (final cat in widget.cats) {
      try {
        final bytes =
            await CatAvatarService
                .getAvatarBytes(
          cat.id,
        );

        if (bytes != null &&
            bytes.isNotEmpty) {
          newAvatars[cat.id] =
              bytes;
        }
      } catch (_) {}

      try {
        newProfiles[cat.id] =
            await ProfileService
                    .getCatProfile(
                  cat.id,
                ) ??
                CatProfile(
                  gender:
                      cat.sex
                                  ?.toLowerCase() ==
                              'female'
                          ? 'Ženka'
                          : 'Mužjak',
                  breed:
                      cat.breed ??
                          'Mješanac',
                  ageYears: 0,
                  weightKg:
                      cat.weightKg ??
                          0,
                  dailyGoalGrams:
                      int.tryParse(
                            cat.goals ??
                                '',
                          ) ??
                          200,
                );
      } catch (_) {
        newProfiles[cat.id] =
            CatProfile(
          gender:
              cat.sex
                          ?.toLowerCase() ==
                      'female'
                  ? 'Ženka'
                  : 'Mužjak',
          breed:
              cat.breed ??
                  'Mješanac',
          ageYears: 0,
          weightKg:
              cat.weightKg ??
                  0,
          dailyGoalGrams:
              int.tryParse(
                    cat.goals ??
                        '',
                  ) ??
                  200,
        );
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      avatars = newAvatars;
      profiles = newProfiles;
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final cat = _findCat(
      widget.cats,
      widget.selectedCatId,
    );

    final profile =
        cat == null
            ? null
            : profiles[cat.id];

    if (cat == null) {
      return Scaffold(
        backgroundColor:
            AppColors.background,
        body: SafeArea(
          child:
              Center(
            child:
                _EmptyCatCard(
              onTap:
                  widget.onAddCat,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          AppColors.background,
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            14,
            20,
            30,
          ),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Profil mačke',
                    style:
                        TextStyle(
                      fontSize: 26,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),

                IconButton(
                  onPressed:
                      () => widget.onEdit(
                    cat,
                  ),
                  icon:
                      const Icon(
                    Icons
                        .edit_outlined,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 5,
            ),

            const Text(
              'Odaberi mačku čiji profil želiš pregledati ili urediti.',
              style: TextStyle(
                fontSize: 11.5,
                color:
                    AppColors
                        .textMuted,
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            _CatSelector(
              cats: widget.cats,
              selectedCatId:
                  widget.selectedCatId,
              avatars: avatars,
              onSelect:
                  widget.onSelectCat,
            ),

            const SizedBox(
              height: 15,
            ),

            ModernCard(
              padding:
                  EdgeInsets.zero,
              radius: 24,
              child: Column(
                children: [
                  SizedBox(
                    height: 225,
                    width:
                        double.infinity,
                    child:
                        ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(
                        top: Radius
                            .circular(
                          24,
                        ),
                      ),
                      child:
                          avatars[
                                      cat.id] !=
                                  null
                              ? Image.memory(
                                  avatars[
                                      cat.id]!,
                                  fit: BoxFit
                                      .cover,
                                  filterQuality:
                                      FilterQuality
                                          .high,
                                  gaplessPlayback:
                                      true,
                                )
                              : Container(
                                  color:
                                      AppColors
                                          .lavender,
                                  child:
                                      const Center(
                                    child:
                                        Text(
                                      '🐈',
                                      style:
                                          TextStyle(
                                        fontSize:
                                            74,
                                      ),
                                    ),
                                  ),
                                ),
                    ),
                  ),

                  Padding(
                    padding:
                        const EdgeInsets
                            .all(
                      17,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child:
                                  Text(
                                cat.name,
                                style:
                                    const TextStyle(
                                  fontSize:
                                      23,
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                ),
                              ),
                            ),
                            const StatusPill(
                              text:
                                  'Aktivna',
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 15,
                        ),

                        Row(
                          children: [
                            _InfoMetric(
                              icon: Icons
                                  .cake_outlined,
                              label:
                                  'Dob',
                              value:
                                  cat.ageDescription ??
                                      '${profile?.ageYears ?? 0} godine',
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            _InfoMetric(
                              icon: Icons
                                  .monitor_weight_outlined,
                              label:
                                  'Težina',
                              value:
                                  '${(profile?.weightKg ?? cat.weightKg ?? 0).toStringAsFixed(1)} kg',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            ModernCard(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detalji profila',
                    style:
                        TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  _ProfileRow(
                    label: 'Spol',
                    value:
                        profile?.gender ??
                            cat.sex ??
                            '—',
                  ),

                  _ProfileRow(
                    label: 'Pasmina',
                    value:
                        profile?.breed ??
                            cat.breed ??
                            '—',
                  ),

                  _ProfileRow(
                    label:
                        'Dnevni cilj hrane',
                    value:
                        '${profile?.dailyGoalGrams ?? 200} g',
                  ),

                  _ProfileRow(
                    label: 'RFID',
                    value:
                        cat.rfidTag
                                    ?.isNotEmpty ==
                                true
                            ? cat.rfidTag!
                            : 'Nije postavljen',
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            SizedBox(
              height: 49,
              child:
                  ElevatedButton
                      .icon(
                onPressed:
                    () => widget.onEdit(
                  cat,
                ),
                icon:
                    const Icon(
                  Icons.edit_rounded,
                  size: 18,
                ),
                label:
                    const Text(
                  'Uredi profil mačke',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SHARED UI
// ============================================================

class _SectionHeader
    extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style:
                const TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w900,
              color:
                  AppColors.textDark,
            ),
          ),
        ),
        if (action != null)
          TextButton.icon(
            onPressed:
                onAction,
            icon:
                const Icon(
              Icons.add_rounded,
              size: 18,
            ),
            label:
                Text(action!),
          ),
      ],
    );
  }
}

class _CatSelector
    extends StatelessWidget {
  final List<Cat> cats;
  final int? selectedCatId;
  final Map<int, Uint8List> avatars;
  final void Function(int)
      onSelect;
  final bool compact;

  const _CatSelector({
    required this.cats,
    required this.selectedCatId,
    required this.avatars,
    required this.onSelect,
    this.compact = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    if (cats.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder:
          (
        context,
        constraints,
      ) {
        if (cats.length <= 2 &&
            constraints
                .maxWidth
                .isFinite) {
          final width =
              (constraints.maxWidth -
                      10) /
                  cats.length;

          return Row(
            children: [
              for (
                int i = 0;
                i < cats.length;
                i++
              ) ...[
                SizedBox(
                  width: width,
                  child:
                      _CatSelectorCard(
                    cat:
                        cats[i],
                    selected:
                        cats[i].id ==
                            selectedCatId,
                    bytes:
                        avatars[
                            cats[i]
                                .id],
                    compact:
                        compact,
                    onTap: () =>
                        onSelect(
                      cats[i].id,
                    ),
                  ),
                ),
                if (i <
                    cats.length -
                        1)
                  const SizedBox(
                    width: 10,
                  ),
              ],
            ],
          );
        }

        return SizedBox(
          height:
              compact ? 84 : 112,
          child:
              ListView.separated(
            scrollDirection:
                Axis.horizontal,
            itemCount:
                cats.length,
            separatorBuilder:
                (
              _,
              __,
            ) =>
                    const SizedBox(
              width: 10,
            ),
            itemBuilder:
                (
              _,
              index,
            ) {
              final cat =
                  cats[index];

              return SizedBox(
                width:
                    compact
                        ? 160
                        : 150,
                child:
                    _CatSelectorCard(
                  cat: cat,
                  selected:
                      cat.id ==
                          selectedCatId,
                  bytes:
                      avatars[
                          cat.id],
                  compact:
                      compact,
                  onTap: () =>
                      onSelect(
                    cat.id,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CatSelectorCard
    extends StatelessWidget {
  final Cat cat;
  final bool selected;
  final Uint8List? bytes;
  final VoidCallback onTap;
  final bool compact;

  const _CatSelectorCard({
    required this.cat,
    required this.selected,
    required this.bytes,
    required this.onTap,
    required this.compact,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(
        20,
      ),
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 180,
        ),
        padding:
            EdgeInsets.all(
          compact ? 10 : 12,
        ),
        decoration:
            BoxDecoration(
          color: selected
              ? AppColors
                  .tint50
              : Colors.white,
          borderRadius:
              BorderRadius.circular(
            20,
          ),
          border:
              Border.all(
            color: selected
                ? AppColors
                    .primary
                : AppColors
                    .cardBorder,
            width:
                selected
                    ? 1.8
                    : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors
                      .primary
                      .withOpacity(
                      .09,
                    )
                  : Colors.black
                      .withOpacity(
                      .025,
                    ),
              blurRadius:
                  selected
                      ? 16
                      : 9,
              offset:
                  const Offset(
                0,
                5,
              ),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width:
                  compact
                      ? 47
                      : 55,
              height:
                  compact
                      ? 47
                      : 55,
              clipBehavior:
                  Clip.antiAlias,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color: AppColors
                    .lavender,
                border:
                    Border.all(
                  color: selected
                      ? AppColors
                          .primaryLight
                      : Colors.white,
                  width: 2,
                ),
              ),
              child:
                  bytes == null
                      ? const Center(
                          child:
                              Text(
                            '🐈',
                            style:
                                TextStyle(
                              fontSize:
                                  25,
                            ),
                          ),
                        )
                      : Image.memory(
                          bytes!,
                          fit: BoxFit
                              .cover,
                          filterQuality:
                              FilterQuality
                                  .high,
                          gaplessPlayback:
                              true,
                        ),
            ),

            const SizedBox(
              width: 10,
            ),

            Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    cat.name,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        TextStyle(
                      fontSize:
                          compact
                              ? 12
                              : 13,
                      fontWeight:
                          FontWeight
                              .w900,
                      color:
                          AppColors
                              .textDark,
                    ),
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  Text(
                    selected
                        ? 'Odabrana'
                        : 'Odaberi',
                    style:
                        TextStyle(
                      fontSize: 9.5,
                      fontWeight:
                          FontWeight
                              .w700,
                      color: selected
                          ? AppColors
                              .primary
                          : AppColors
                              .textMuted,
                    ),
                  ),
                ],
              ),
            ),

            AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 180,
              ),
              width: 24,
              height: 24,
              decoration:
                  BoxDecoration(
                color: selected
                    ? AppColors
                        .primary
                    : Colors
                        .transparent,
                shape:
                    BoxShape.circle,
                border:
                    Border.all(
                  color: selected
                      ? AppColors
                          .primary
                      : AppColors
                          .cardBorder,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons
                          .check_rounded,
                      size: 15,
                      color:
                          Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedCatSummary
    extends StatelessWidget {
  final Cat cat;
  final CatProfile? profile;
  final Uint8List? bytes;
  final int today;
  final int goal;
  final VoidCallback onTap;

  const _SelectedCatSummary({
    required this.cat,
    required this.profile,
    required this.bytes,
    required this.today,
    required this.goal,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(
        22,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(
          14,
        ),
        decoration:
            BoxDecoration(
          gradient:
              const LinearGradient(
            colors: [
              AppColors.primary,
              Color(0xFF506A91),
            ],
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,
          ),
          borderRadius:
              BorderRadius.circular(
            22,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors
                  .primary
                  .withOpacity(
                .17,
              ),
              blurRadius: 20,
              offset:
                  const Offset(
                0,
                9,
              ),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              clipBehavior:
                  Clip.antiAlias,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color: Colors.white
                    .withOpacity(
                  .16,
                ),
              ),
              child: bytes == null
                  ? const Center(
                      child:
                          Text(
                        '🐈',
                        style:
                            TextStyle(
                          fontSize:
                              30,
                        ),
                      ),
                    )
                  : Image.memory(
                      bytes!,
                      fit: BoxFit
                          .cover,
                      filterQuality:
                          FilterQuality
                              .high,
                      gaplessPlayback:
                          true,
                    ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    cat.name,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize: 17,
                      fontWeight:
                          FontWeight
                              .w900,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    '${profile?.breed ?? cat.breed ?? 'Mješanac'}  •  '
                    '${profile?.weightKg.toStringAsFixed(1) ?? (cat.weightKg ?? 0).toStringAsFixed(1)} kg',
                    style:
                        const TextStyle(
                      color:
                          Colors.white70,
                      fontSize:
                          10.5,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  ClipRRect(
                    borderRadius:
                        BorderRadius
                            .circular(
                      10,
                    ),
                    child:
                        LinearProgressIndicator(
                      value: goal <= 0
                          ? 0.0
                          : (today / goal)
                              .clamp(
                                0.0,
                                1.0,
                              )
                              .toDouble(),
                      minHeight: 6,
                      backgroundColor:
                          Colors
                              .white
                              .withOpacity(
                            .15,
                          ),
                      valueColor:
                          const AlwaysStoppedAnimation<
                              Color>(
                        Colors
                            .white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              width: 10,
            ),

            const Icon(
              Icons
                  .chevron_right_rounded,
              color:
                  Colors.white70,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeMetric
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final double? progress;

  const _HomeMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    this.progress,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ModernCard(
      padding:
          const EdgeInsets.all(
        12,
      ),
      radius: 17,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Container(
            width: 31,
            height: 31,
            decoration:
                BoxDecoration(
              color: tint,
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child:
                Icon(
              icon,
              size: 17,
              color:
                  AppColors.primary,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            label,
            style:
                const TextStyle(
              fontSize: 9.5,
              color:
                  AppColors
                      .textMuted,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            value,
            style:
                const TextStyle(
              fontSize: 12.5,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          if (progress != null) ...[
            const SizedBox(
              height: 7,
            ),
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
              child:
                  LinearProgressIndicator(
                value:
                    progress!
                        .clamp(
                          0.0,
                          1.0,
                        )
                        .toDouble(),
                minHeight: 5,
                backgroundColor:
                    AppColors
                        .background,
                color:
                    AppColors
                        .primarySoft,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeederStatusCard
    extends StatelessWidget {
  final double food;
  final double? water;
  final _NextFeeding? next;
  final Cat? selectedCat;
  final VoidCallback onTap;

  const _FeederStatusCard({
    required this.food,
    required this.water,
    required this.next,
    required this.selectedCat,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(
        22,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(
          16,
        ),
        decoration:
            BoxDecoration(
          color:
              AppColors.primary,
          borderRadius:
              BorderRadius.circular(
            22,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors
                  .primary
                  .withOpacity(
                .2,
              ),
              blurRadius: 20,
              offset:
                  const Offset(
                0,
                9,
              ),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -12,
              top: -16,
              child:
                  Icon(
                Icons.pets_rounded,
                size: 105,
                color: Colors.white
                    .withOpacity(
                  .07,
                ),
              ),
            ),

            Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration:
                          BoxDecoration(
                        color: Colors
                            .white
                            .withOpacity(
                          .15,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                      ),
                      child:
                          const Icon(
                        Icons
                            .restaurant_rounded,
                        color:
                            Colors.white,
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            'Hranilica je aktivna',
                            style:
                                TextStyle(
                              color:
                                  Colors
                                      .white,
                              fontWeight:
                                  FontWeight
                                      .w900,
                              fontSize:
                                  13,
                            ),
                          ),
                          SizedBox(
                            height: 3,
                          ),
                          Row(
                            children: [
                              _Dot(),
                              SizedBox(
                                width: 5,
                              ),
                              Text(
                                'Online',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white70,
                                  fontSize:
                                      10.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Icon(
                      Icons
                          .chevron_right_rounded,
                      color:
                          Colors.white70,
                    ),
                  ],
                ),

                const SizedBox(
                  height: 15,
                ),

                if (selectedCat != null &&
                    next != null)
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors
                          .white
                          .withOpacity(
                        .10,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons
                              .schedule_rounded,
                          size: 19,
                          color:
                              Colors.white,
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          child:
                              Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              const Text(
                                'Sljedeće hranjenje',
                                style:
                                    TextStyle(
                                  fontSize:
                                      8.5,
                                  color:
                                      Colors.white70,
                                ),
                              ),

                              const SizedBox(
                                height: 2,
                              ),

                              Text(
                                '${next!.meal} • ${_clock(next!.dateTime)} • ${next!.grams} g',
                                style:
                                    const TextStyle(
                                  fontSize:
                                      12,
                                  fontWeight:
                                      FontWeight.w900,
                                  color:
                                      Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Text(
                          _timeUntil(
                            next!.dateTime,
                            DateTime.now(),
                          ),
                          style:
                              const TextStyle(
                            fontSize:
                                9.5,
                            color:
                                Colors.white70,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors
                          .white
                          .withOpacity(
                        .10,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons
                              .schedule_rounded,
                          size: 19,
                          color:
                              Colors.white,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Text(
                            'Nema postavljenog sljedećeg hranjenja. Otvori hranilicu i dodaj raspored.',
                            style:
                                TextStyle(
                              fontSize:
                                  10.5,
                              color:
                                  Colors
                                      .white,
                              height:
                                  1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(
                  height: 9,
                ),

                Row(
                  children: [
                    _LightStat(
                      icon: Icons
                          .restaurant_outlined,
                      label: 'Hrana',
                      value:
                          '${_levelQuarters(food)}/4',
                    ),

                    const SizedBox(
                      width: 9,
                    ),

                    _LightStat(
                      icon: Icons
                          .water_drop_outlined,
                      label: 'Voda',
                      value:
                          '${(water ?? 0).round()}%',
                    ),

                    const SizedBox(
                      width: 9,
                    ),

                    _LightStat(
                      icon:
                          Icons.pets_rounded,
                      label: 'Mačka',
                      value:
                          selectedCat?.name ??
                              '—',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot
    extends StatelessWidget {
  const _Dot();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 7,
      height: 7,
      decoration:
          const BoxDecoration(
        color:
            Color(0xFF55D889),
        shape:
            BoxShape.circle,
      ),
    );
  }
}

class _LightStat
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LightStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.all(
          10,
        ),
        decoration:
            BoxDecoration(
          color: Colors
              .white
              .withOpacity(
            .10,
          ),
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color:
                  Colors.white70,
            ),

            const SizedBox(
              width: 6,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white60,
                      fontSize:
                          8.5,
                    ),
                  ),

                  Text(
                    value,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          10.5,
                      fontWeight:
                          FontWeight
                              .w900,
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

class _QuickAction
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback? onTap;
  final bool loading;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(
        19,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(
          13,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            19,
          ),
          border:
              Border.all(
            color:
                AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration:
                  BoxDecoration(
                color: tint,
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
              ),
              child: loading
                  ? const Padding(
                      padding:
                          EdgeInsets.all(
                        10,
                      ),
                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            2,
                      ),
                    )
                  : Icon(
                      icon,
                      size: 18,
                      color:
                          AppColors
                              .primary,
                    ),
            ),

            const SizedBox(
              width: 9,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize:
                          10.5,
                      fontWeight:
                          FontWeight
                              .w900,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 9,
                      color:
                          AppColors
                              .textMuted,
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

class _WarningCard
    extends StatelessWidget {
  final VoidCallback onTap;

  const _WarningCard({
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(
        18,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(
          13,
        ),
        decoration:
            BoxDecoration(
          color:
              AppColors.peach,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons
                  .wifi_off_rounded,
              color:
                  AppColors.warning,
            ),
            SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                'Veza sa hranilicom trenutno nije dostupna.',
                style:
                    TextStyle(
                  fontSize:
                      11,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      Color(
                    0xFF7A4A00,
                  ),
                ),
              ),
            ),
            Icon(
              Icons
                  .chevron_right_rounded,
              color:
                  AppColors.warning,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCatCard
    extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyCatCard({
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ModernCard(
      child: Column(
        children: [
          const AppLogo(
            size: 55,
          ),

          const SizedBox(
            height: 9,
          ),

          const Text(
            'Dodaj svoju mačku',
            style:
                TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          const Text(
            'Kreiraj profil da bi hranjenje i statistika bili personalizirani.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              fontSize: 11,
              color:
                  AppColors
                      .textMuted,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          SizedBox(
            width: 170,
            height: 42,
            child:
                ElevatedButton(
              onPressed:
                  onTap,
              child:
                  const Text(
                'Dodaj mačku',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeTabs
    extends StatelessWidget {
  final int days;
  final bool custom;
  final VoidCallback on7;
  final VoidCallback on30;
  final VoidCallback onCustom;

  const _RangeTabs({
    required this.days,
    required this.custom,
    required this.on7,
    required this.on30,
    required this.onCustom,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height: 42,
      padding:
          const EdgeInsets.all(
        4,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.card,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border:
            Border.all(
          color:
              AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          _tab(
            '7 dana',
            days == 7 &&
                !custom,
            on7,
          ),
          _tab(
            '30 dana',
            days == 30 &&
                !custom,
            on30,
          ),
          _tab(
            'Custom',
            custom,
            onCustom,
          ),
        ],
      ),
    );
  }

  Widget _tab(
    String title,
    bool selected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child:
            AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 160,
          ),
          alignment:
              Alignment.center,
          decoration:
              BoxDecoration(
            color: selected
                ? AppColors
                    .primary
                : Colors
                    .transparent,
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),
          child: Text(
            title,
            style:
                TextStyle(
              fontSize: 10.5,
              fontWeight:
                  FontWeight.w800,
              color: selected
                  ? Colors
                      .white
                  : AppColors
                      .textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsHero
    extends StatelessWidget {
  final Cat cat;
  final Uint8List? avatar;
  final int total;
  final int adherence;
  final int average;
  final int meals;

  const _StatsHero({
    required this.cat,
    required this.avatar,
    required this.total,
    required this.adherence,
    required this.average,
    required this.meals,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ModernCard(
      padding:
          const EdgeInsets.all(
        15,
      ),
      radius: 22,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            clipBehavior:
                Clip.antiAlias,
            decoration:
                const BoxDecoration(
              shape:
                  BoxShape.circle,
              color:
                  AppColors
                      .lavender,
            ),
            child: avatar == null
                ? const Center(
                    child:
                        Text(
                      '🐈',
                      style:
                          TextStyle(
                        fontSize:
                            27,
                      ),
                    ),
                  )
                : Image.memory(
                    avatar!,
                    fit: BoxFit.cover,
                    filterQuality:
                        FilterQuality.high,
                    gaplessPlayback:
                        true,
                  ),
          ),

          const SizedBox(
            width: 11,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  cat.name,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  '$meals obroka  •  prosjek $average g/dan',
                  style:
                      const TextStyle(
                    fontSize: 9.5,
                    color:
                        AppColors
                            .textMuted,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            AppColors
                                .mint,
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                      ),
                      child: Text(
                        '$adherence% cilja',
                        style:
                            const TextStyle(
                          fontSize:
                              9.5,
                          fontWeight:
                              FontWeight
                                  .w900,
                          color:
                              Color(
                            0xFF277A5C,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Text(
                      '$total g ukupno',
                      style:
                          const TextStyle(
                        fontSize:
                            9.5,
                        color:
                            AppColors
                                .textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Icon(
            Icons.insights_rounded,
            color:
                AppColors
                    .primarySoft,
          ),
        ],
      ),
    );
  }
}

class _StatMetric
    extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  const _StatMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Expanded(
      child: ModernCard(
        padding:
            const EdgeInsets.all(
          13,
        ),
        radius: 18,
        child: Row(
          children: [
            Container(
              width: 37,
              height: 37,
              decoration:
                  BoxDecoration(
                color: tint,
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
              ),
              child:
                  Icon(
                icon,
                size: 17,
                color:
                    AppColors
                        .primary,
              ),
            ),

            const SizedBox(
              width: 9,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    label,
                    style:
                        const TextStyle(
                      fontSize:
                          9.5,
                      color:
                          AppColors
                              .textMuted,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    value,
                    style:
                        const TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight
                              .w900,
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

class _DetailCard
    extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String value;
  final String change;

  const _DetailCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.value,
    required this.change,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ModernCard(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      radius: 16,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(
              color: tint,
              borderRadius:
                  BorderRadius
                      .circular(
                12,
              ),
            ),
            child:
                Icon(
              icon,
              size: 17,
              color:
                  AppColors
                      .primary,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize:
                        10.5,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                Text(
                  change,
                  style:
                      const TextStyle(
                    fontSize:
                        9,
                    color:
                        AppColors
                            .textMuted,
                  ),
                ),
              ],
            ),
          ),

          Text(
            value,
            style:
                const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w900,
              color:
                  Color(
                0xFF2C9B67,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayFeeding {
  final DateTime date;
  final int grams;

  _DayFeeding(
    this.date,
    this.grams,
  );
}

// ============================================================
// FIXED CHART PAINTER
// ============================================================

class _FeedingChartPainter
    extends CustomPainter {
  final List<_DayFeeding> data;
  final int target;

  _FeedingChartPainter(
    this.data, {
    required this.target,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final left = 28.0;
    final right =
        size.width - 8;
    final top = 10.0;
    final bottom =
        size.height - 25;

    final maxV =
        math.max<double>(
      260.0,
      data
          .map(
            (e) =>
                e.grams.toDouble(),
          )
          .fold<double>(
            0.0,
            math.max,
          ),
    );

    final grid = Paint()
      ..color =
          AppColors.cardBorder
      ..strokeWidth = 1;

    // GRID LINES
    for (int i = 0;
        i < 5;
        i++) {
      final y =
          top +
              (bottom - top) *
                  i /
                  4;

      // FIX:
      // drawLine() prima Offset, Offset, Paint.
      canvas.drawLine(
        Offset(
          0,
          y,
        ),
        Offset(
          size.width,
          y,
        ),
        grid,
      );
    }

    if (data.isEmpty) {
      return;
    }

    final points =
        <Offset>[];

    for (
      int i = 0;
      i < data.length;
      i++
    ) {
      final x = data.length ==
              1
          ? (left + right) /
              2
          : left +
              (right - left) *
                  i /
                  (data.length -
                      1);

      final y =
          bottom -
              (data[i]
                      .grams
                      .toDouble() /
                  maxV) *
                  (bottom -
                      top);

      points.add(
        Offset(
          x,
          y,
        ),
      );
    }

    // AREA UNDER CURVE
    final area =
        Path()
          ..moveTo(
            points.first.dx,
            bottom,
          )
          ..lineTo(
            points.first.dx,
            points.first.dy,
          );

    for (
      int i = 1;
      i < points.length;
      i++
    ) {
      final p0 =
          points[i - 1];

      final p1 =
          points[i];

      final mid =
          Offset(
        (p0.dx + p1.dx) /
            2,
        p0.dy,
      );

      area.cubicTo(
        mid.dx,
        mid.dy,
        mid.dx,
        p1.dy,
        p1.dx,
        p1.dy,
      );
    }

    area
      ..lineTo(
        points.last.dx,
        bottom,
      )
      ..close();

    final areaPaint =
        Paint()
          ..shader =
              LinearGradient(
            colors: [
              AppColors
                  .lavenderStrong
                  .withOpacity(
                .38,
              ),
              AppColors
                  .lavender
                  .withOpacity(
                .05,
              ),
            ],
            begin:
                Alignment.topCenter,
            end:
                Alignment.bottomCenter,
          ).createShader(
            Rect.fromLTWH(
              0,
              top,
              size.width,
              bottom - top,
            ),
          );

    canvas.drawPath(
      area,
      areaPaint,
    );

    // CURVE
    final curve =
        Path()
          ..moveTo(
            points.first.dx,
            points.first.dy,
          );

    for (
      int i = 1;
      i < points.length;
      i++
    ) {
      final p0 =
          points[i - 1];

      final p1 =
          points[i];

      final mid =
          Offset(
        (p0.dx + p1.dx) /
            2,
        (p0.dy + p1.dy) /
            2,
      );

      curve.quadraticBezierTo(
        p0.dx,
        p0.dy,
        mid.dx,
        mid.dy,
      );

      if (i ==
          points.length -
              1) {
        curve.quadraticBezierTo(
          p1.dx,
          p1.dy,
          p1.dx,
          p1.dy,
        );
      }
    }

    final curvePaint =
        Paint()
          ..color =
              AppColors
                  .primarySoft
          ..style =
              PaintingStyle
                  .stroke
          ..strokeWidth = 3
          ..strokeCap =
              StrokeCap.round;

    canvas.drawPath(
      curve,
      curvePaint,
    );

    // POINTS
    final whitePointPaint =
        Paint()
          ..color =
              Colors.white;

    final pointPaint =
        Paint()
          ..color =
              AppColors
                  .primary;

    for (
      final point in points
    ) {
      canvas.drawCircle(
        point,
        5,
        whitePointPaint,
      );

      canvas.drawCircle(
        point,
        3.1,
        pointPaint,
      );
    }

    // TARGET LINE
    final targetY =
        bottom -
            (target.toDouble() /
                maxV) *
                (bottom -
                    top);

    final dash =
        Paint()
          ..color =
              AppColors
                  .mintStrong
                  .withOpacity(
                .8,
              )
          ..strokeWidth = 1.4;

    for (
      double x = left;
      x < right;
      x += 8
    ) {
      // FIX:
      // drawLine() prima Offset, Offset, Paint.
      canvas.drawLine(
        Offset(
          x,
          targetY,
        ),
        Offset(
          math.min(
            x + 4,
            right,
          ),
          targetY,
        ),
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _FeedingChartPainter
        oldDelegate,
  ) {
    return oldDelegate.data !=
            data ||
        oldDelegate.target !=
            target;
  }
}

class _ChartLabels
    extends StatelessWidget {
  final List<_DayFeeding> points;

  const _ChartLabels({
    required this.points,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    const weekdayNames = [
      'Pon',
      'Uto',
      'Sri',
      'Čet',
      'Pet',
      'Sub',
      'Ned',
    ];

    return Row(
      children: [
        for (
          int index = 0;
          index < points.length;
          index++
        )
          Expanded(
            child: Text(
              points.length <= 7 ||
                      index == 0 ||
                      index ==
                          points.length -
                              1 ||
                      index % 5 == 0
                  ? weekdayNames[
                      points[index]
                              .date
                              .weekday -
                          1]
                  : '',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 8.5,
                color:
                    AppColors
                        .textMuted,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// FEEDER LEVEL
// ============================================================

class _FeederLevelCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final double progress;
  final Color tint;

  const _FeederLevelCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.progress,
    required this.tint,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ModernCard(
      padding:
          const EdgeInsets.all(
        13,
      ),
      radius: 18,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Container(
            width: 37,
            height: 37,
            decoration:
                BoxDecoration(
              color: tint,
              borderRadius:
                  BorderRadius
                      .circular(
                12,
              ),
            ),
            child:
                Icon(
              icon,
              size: 17,
              color:
                  AppColors
                      .primary,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            title,
            style:
                const TextStyle(
              fontSize: 9.5,
              color:
                  AppColors
                      .textMuted,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            value,
            style:
                const TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              8,
            ),
            child:
                LinearProgressIndicator(
              value:
                  progress
                      .clamp(
                        0.0,
                        1.0,
                      )
                      .toDouble(),
              minHeight: 5,
              backgroundColor:
                  AppColors
                      .background,
              color:
                  AppColors
                      .primarySoft,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PROFILE INFO
// ============================================================

class _InfoMetric
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.all(
          11,
        ),
        decoration:
            BoxDecoration(
          color:
              AppColors.background,
          borderRadius:
              BorderRadius.circular(
            15,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color:
                  AppColors.primary,
            ),

            const SizedBox(
              width: 7,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    label,
                    style:
                        const TextStyle(
                      fontSize: 9,
                      color:
                          AppColors
                              .textMuted,
                    ),
                  ),
                  Text(
                    value,
                    style:
                        const TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          FontWeight
                              .w900,
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

class _ProfileRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets
              .symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child:
                Text(
              label,
              style:
                  const TextStyle(
                fontSize: 11,
                color:
                    AppColors
                        .textMuted,
              ),
            ),
          ),

          Flexible(
            child: Text(
              value,
              textAlign:
                  TextAlign.right,
              style:
                  const TextStyle(
                fontSize: 11.5,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STATUS
// ============================================================

class StatusPill
    extends StatelessWidget {
  final String text;

  const StatusPill({
    super.key,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.mint,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          const _Dot(),

          const SizedBox(
            width: 5,
          ),

          Text(
            text,
            style:
                const TextStyle(
              fontSize: 9.5,
              fontWeight:
                  FontWeight.w800,
              color:
                  Color(
                0xFF277A5C,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FEEDER VISUALS
// ============================================================

class _CloudBlob
    extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _CloudBlob({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: width,
      height: height,
      decoration:
          BoxDecoration(
        color:
            color.withOpacity(
          .48,
        ),
        borderRadius:
            BorderRadius.circular(
          60,
        ),
      ),
    );
  }
}

class _FeederIcon
    extends StatelessWidget {
  final double size;

  const _FeederIcon({
    this.size = 54,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return CustomPaint(
      size:
          Size(
        size,
        size,
      ),
      painter:
          _FeederIconPainter(),
    );
  }
}

class _FeederIconPainter
    extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final scale =
        size.width / 60;

    final fill = Paint()
      ..color =
          const Color(
        0xFF182238,
      );

    final line = Paint()
      ..color =
          const Color(
        0xFF182238,
      )
      ..style =
          PaintingStyle.stroke
      ..strokeWidth =
          3 * scale
      ..strokeCap =
          StrokeCap.round
      ..strokeJoin =
          StrokeJoin.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          11 * scale,
          25 * scale,
          38 * scale,
          21 * scale,
        ),
        Radius.circular(
          5 * scale,
        ),
      ),
      fill,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          16 * scale,
          17 * scale,
          28 * scale,
          11 * scale,
        ),
        Radius.circular(
          4 * scale,
        ),
      ),
      fill,
    );

    canvas.drawCircle(
      Offset(
        30 * scale,
        12 * scale,
      ),
      7 * scale,
      line,
    );

    canvas.drawLine(
      Offset(
        30 * scale,
        5 * scale,
      ),
      Offset(
        30 * scale,
        2 * scale,
      ),
      line,
    );

    final white = Paint()
      ..color =
          Colors.white;

    canvas.drawCircle(
      Offset(
        22 * scale,
        36 * scale,
      ),
      2 * scale,
      white,
    );

    canvas.drawCircle(
      Offset(
        38 * scale,
        36 * scale,
      ),
      2 * scale,
      white,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          20 * scale,
          40 * scale,
          20 * scale,
          3 * scale,
        ),
        Radius.circular(
          2 * scale,
        ),
      ),
      white,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter
        oldDelegate,
  ) {
    return false;
  }
}

// ============================================================
// SCHEDULE
// ============================================================

class _ScheduleRow
    extends StatelessWidget {
  final dynamic schedule;
  final VoidCallback onTap;

  const _ScheduleRow({
    required this.schedule,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final time =
        _time(
      _v(
        schedule,
        'time',
      ),
    );

    final gramsRaw =
        _v(
          schedule,
          'portionGrams',
        ) ??
        _v(
          schedule,
          'portion',
        ) ??
        60;

    final grams =
        gramsRaw is num
            ? gramsRaw.toInt()
            : int.tryParse(
                  '$gramsRaw',
                ) ??
                60;

    final days =
        _scheduleDays(
      _v(
        schedule,
        'daysOfWeek',
      ),
    );

    final enabled =
        _isScheduleEnabled(
      schedule,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets
                .fromLTRB(
          12,
          11,
          10,
          11,
        ),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration:
                  BoxDecoration(
                color: enabled
                    ? AppColors
                        .lavender
                    : AppColors
                        .cardBorder,
                borderRadius:
                    BorderRadius
                        .circular(
                  13,
                ),
              ),
              child: Icon(
                Icons
                    .alarm_rounded,
                size: 19,
                color: enabled
                    ? AppColors
                        .primary
                    : AppColors
                        .textMuted,
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    children: [
                      Text(
                        time,
                        style:
                            const TextStyle(
                          fontSize:
                              13,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),

                      const SizedBox(
                        width: 7,
                      ),

                      if (enabled)
                        const StatusPill(
                          text:
                              'Aktivno',
                        )
                      else
                        const StatusPill(
                          text:
                              'Pauza',
                        ),
                    ],
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  Text(
                    '${_mealName(time)}  •  $grams g',
                    style:
                        const TextStyle(
                      fontSize:
                          10.5,
                      color:
                          AppColors
                              .textDark,
                      fontWeight:
                          FontWeight
                              .w700,
                    ),
                  ),

                  const SizedBox(
                    height: 2,
                  ),

                  Text(
                    days
                        .map(
                          _shortDay,
                        )
                        .join(
                          ' · ',
                        ),
                    style:
                        const TextStyle(
                      fontSize:
                          9.5,
                      color:
                          AppColors
                              .textMuted,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons
                  .chevron_right_rounded,
              color:
                  AppColors
                      .textMuted,
            ),
          ],
        ),
      ),
    );
  }

  String _shortDay(
    String value,
  ) {
    switch (_dayNumber(value)) {
      case 1:
        return 'Pon';
      case 2:
        return 'Uto';
      case 3:
        return 'Sri';
      case 4:
        return 'Čet';
      case 5:
        return 'Pet';
      case 6:
        return 'Sub';
      case 7:
        return 'Ned';
    }

    return value;
  }
}

class _EmptySchedule
    extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptySchedule({
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.all(
        18,
      ),
      child: Column(
        children: [
          const Icon(
            Icons
                .calendar_month_outlined,
            size: 30,
            color:
                AppColors
                    .textMuted,
          ),

          const SizedBox(
            height: 7,
          ),

          const Text(
            'Nema zakazanih obroka',
            style:
                TextStyle(
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          const Text(
            'Dodaj prvi termin hranjenja.',
            style:
                TextStyle(
              fontSize: 10.5,
              color:
                  AppColors
                      .textMuted,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          OutlinedButton(
            onPressed:
                onTap,
            child:
                const Text(
              'Dodaj raspored',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FEEDER STAT
// ============================================================

class _FeederStat
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color tint;

  const _FeederStat({
    required this.icon,
    required this.title,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Expanded(
      child: ModernCard(
        padding:
            const EdgeInsets.all(
          12,
        ),
        radius: 17,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration:
                  BoxDecoration(
                color: tint,
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
              ),
              child:
                  Icon(
                icon,
                size: 17,
                color:
                    AppColors
                        .primary,
              ),
            ),

            const SizedBox(
              width: 9,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontSize:
                          9.5,
                      color:
                          AppColors
                              .textMuted,
                    ),
                  ),

                  const SizedBox(
                    height: 2,
                  ),

                  Text(
                    value,
                    style:
                        const TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight
                              .w900,
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

// ============================================================
// CARD
// ============================================================

class ModernCard
    extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry
      padding;
  final double radius;

  const ModernCard({
    super.key,
    required this.child,
    this.padding =
        const EdgeInsets.all(
      16,
    ),
    this.radius = 20,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: padding,
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          radius,
        ),
        border:
            Border.all(
          color:
              AppColors.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(
              .035,
            ),
            blurRadius: 18,
            offset:
                const Offset(
              0,
              7,
            ),
          ),
        ],
      ),
      child: child,
    );
  }
}