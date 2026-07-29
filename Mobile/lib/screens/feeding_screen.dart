import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../api_config.dart';
import '../models/cat.dart';
import '../services/cat_avatar_service.dart';
import '../widgets/empty_state.dart';
import 'schedule_form_screen.dart';
import '../theme/app_colors.dart';
import 'add_cat_screen.dart';
import '../models/cat_profile.dart';

// "Hrani" tab - kombinuje Dashboard (izbor mačke + ručno hranjenje) i
// Care List (sedmični checklist rasporeda, filtriran po IZABRANOJ mački).
class FeedingScreen extends StatefulWidget {
  final String baseUrl;
  final List<Cat> cats;
  final bool isLoadingCats;
  final int? selectedCatId;
  final int feedTrigger;
  final void Function(int catId) onSelectCat;
  final Future<bool> Function(int id) onDeleteCat;
  final void Function(int grams) onFedSuccess;
  final Map<int, Map<String, dynamic>> feedingSummaryByCat;
  final VoidCallback onCatsChanged;
final Future<bool> Function(String name, CatProfile profile) onAddCat;

  const FeedingScreen({
    super.key,
    required this.baseUrl,
    required this.cats,
    required this.isLoadingCats,
    required this.selectedCatId,
    required this.feedTrigger,
    required this.onSelectCat,
    required this.onDeleteCat,
    required this.onFedSuccess,
    required this.feedingSummaryByCat,
    required this.onCatsChanged,
    required this.onAddCat
  });

  @override
  State<FeedingScreen> createState() => _FeedingScreenState();
}

class _FeedingScreenState extends State<FeedingScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  int selectedPortion = 50;
  bool isFeeding = false;
  Map<int, String> avatarPaths = {};

  List<dynamic> schedules = [];
  List<dynamic> logs = [];
  bool isLoadingSchedules = true;
  DateTime selectedDay = DateTime.now();

  static const List<String> _weekdayEnglish = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  static const List<String> _dayLetters = ['P', 'U', 'S', 'Č', 'P', 'S', 'N'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadAvatars();
    loadSchedulesAndLogs();
  }

  @override
  void didUpdateWidget(covariant FeedingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cats.length != widget.cats.length) {
      loadAvatars();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============ AVATARI ============

  Future<void> loadAvatars() async {
    final Map<int, String> loaded = {};
    for (final cat in widget.cats) {
      final path = await CatAvatarService.getAvatarPath(cat.id);
      if (path != null) loaded[cat.id] = path;
    }
    if (!mounted) return;
    setState(() => avatarPaths = loaded);
  }

  Future<void> pickAndSetAvatar(Cat cat, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (picked == null) return;

      final path = await CatAvatarService.setAvatar(cat.id, picked);
      if (!mounted) return;
      setState(() => avatarPaths[cat.id] = path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greška pri biranju slike: $e')));
    }
  }

  // ============ HRANJENJE ============

  Future<void> feedCat() async {
    if (widget.selectedCatId == null) return;
    setState(() => isFeeding = true);
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/feedinglogs'),
        headers: apiHeaders(withJsonBody: true),
        body: json.encode({
          'catId': widget.selectedCatId,
          'portionGrams': selectedPortion,
          'triggeredBy': 'Manual (App)',
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 201 || response.statusCode == 200) {
        widget.onFedSuccess(selectedPortion);
        final catName = widget.cats.firstWhere((c) => c.id == widget.selectedCatId).name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uspješno ispušteno $selectedPortion g hrane za $catName! 🐾')),
        );
        loadSchedulesAndLogs(); // da se Care List odmah ažurira (checkmark)
      } else {
        throw Exception('Greška na serveru');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Neuspješno povezivanje: $e')),
      );
    } finally {
      if (mounted) setState(() => isFeeding = false);
    }
  }

  // ============ MAČKE (dodaj/uredi/obriši) ============

  void openAddCatProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
       builder: (context) => AddCatScreen(onSave: widget.onAddCat),
      ),
    );
  }

  void openEditCatProfile(Cat cat) {
    Navigator.push(
      context,
      MaterialPageRoute(
      builder: (context) => AddCatScreen(
        onSave: widget.onAddCat,
        existingCat: cat,
        // dodaj onUpdate ili onDelete ako ih prolaziš sa parenta
      ),
      ),
    );
  }

  Future<void> showManageCatDialog(Cat cat) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(cat.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('Slikaj'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Izaberi iz galerije'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined, color: AppColors.primary),
              title: const Text('Uredi profil'),
              onTap: () => Navigator.pop(context, 'profile'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Obriši mačku'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == 'camera') {
      await pickAndSetAvatar(cat, ImageSource.camera);
      return;
    }
    if (action == 'gallery') {
      await pickAndSetAvatar(cat, ImageSource.gallery);
      return;
    }

    if (!mounted || action == null) return;

    if (action == 'profile') {
      openEditCatProfile(cat);
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Obrisati ${cat.name}?'),
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
      if (confirm == true && mounted) {
        await CatAvatarService.removeAvatar(cat.id);
        final success = await widget.onDeleteCat(cat.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? '${cat.name} je obrisana.' : 'Brisanje nije uspjelo.')),
        );
      }
    }
  }

  // ============ CARE LIST (rasporedi + historija, filtrirano po mački) ============

  Future<void> loadSchedulesAndLogs() async {
    setState(() => isLoadingSchedules = true);
    try {
      final logsResponse = await http.get(Uri.parse('${widget.baseUrl}/feedinglogs'), headers: apiHeaders());
      final schedulesResponse = await http.get(Uri.parse('${widget.baseUrl}/feedingschedules'), headers: apiHeaders());
      if (!mounted) return;
      if (logsResponse.statusCode == 200 && schedulesResponse.statusCode == 200) {
        setState(() {
          logs = json.decode(logsResponse.body);
          schedules = json.decode(schedulesResponse.body);
          isLoadingSchedules = false;
        });
      } else {
        setState(() => isLoadingSchedules = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoadingSchedules = false);
    }
  }

  bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<DateTime> _currentWeekDates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
  }

  // Samo rasporedi IZABRANE mačke za dati dan.
  List<Map<String, dynamic>> _scheduleItemsForDay(DateTime day) {
    if (widget.selectedCatId == null) return [];
    final dayName = _weekdayEnglish[day.weekday - 1];
    final items = <Map<String, dynamic>>[];

    for (final schedule in schedules) {
      if (schedule['catId'] != widget.selectedCatId) continue;
      final daysCsv = (schedule['daysOfWeek'] as String?) ?? '';
      final scheduleDays = daysCsv.split(',').map((d) => d.trim());
      if (!scheduleDays.contains(dayName)) continue;

      final done = logs.any((log) {
        if (log['catId'] != widget.selectedCatId) return false;
        final rawTimestamp = log['timestamp'];
        if (rawTimestamp == null) return false;
        try {
          final logDate = DateTime.parse(rawTimestamp.toString());
          return _isSameDate(logDate, day);
        } catch (_) {
          return false;
        }
      });

      items.add({'schedule': schedule, 'done': done});
    }
    return items;
  }

  String formatTime(dynamic raw) {
    if (raw == null) return '';
    final parts = raw.toString().split(':');
    if (parts.length < 2) return raw.toString();
    return '${parts[0]}:${parts[1]}';
  }

  Future<void> openScheduleForm() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleFormScreen(baseUrl: widget.baseUrl, cats: widget.cats),
      ),
    );
    if (saved == true) loadSchedulesAndLogs();
  }

  // ============ UI ============

  @override
  Widget build(BuildContext context) {
    final hasCats = widget.cats.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hrani'),
        bottom: hasCats
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.black45,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'Dashboard'),
                  Tab(text: 'Care List'),
                ],
              )
            : null,
      ),
      body: widget.isLoadingCats
          ? const Center(child: CircularProgressIndicator())
          : !hasCats
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: EmptyState(
                      icon: Icons.pets_rounded,
                      title: 'Nemaš nijednu mačku',
                      subtitle: 'Dodaj svoju prvu mačku da počneš sa hranjenjem.',
                      actionLabel: 'Dodaj mačku',
                      onAction: openAddCatProfile,
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboardTab(),
                    _buildCareListTab(),
                  ],
                ),
    );
  }

  Widget _buildCatSelectorRow() {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final cat = widget.cats[index];
          final selected = cat.id == widget.selectedCatId;
          final avatarPath = avatarPaths[cat.id];
          final fedToday = ((widget.feedingSummaryByCat[cat.id]?['todayGrams'] as int?) ?? 0) > 0;
          return GestureDetector(
            onTap: () => widget.onSelectCat(cat.id),
            onLongPress: () => showManageCatDialog(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 84,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? AppColors.primary : AppColors.tint100, width: 2),
                boxShadow: selected
                    ? [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      avatarPath != null
                          ? CircleAvatar(
                              radius: 16,
                              backgroundColor: selected ? Colors.white : AppColors.tint50,
                              backgroundImage: FileImage(File(avatarPath)),
                            )
                          : const Text('🐈', style: TextStyle(fontSize: 26)),
                      if (fedToday)
                        Positioned(
                          bottom: -2,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primary : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.check_circle, size: 13, color: Colors.green),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      cat.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return 'Još nije hranjena';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Upravo sad';
    if (diff.inMinutes < 60) return 'Prije ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Prije ${diff.inHours}h';
    return 'Prije ${diff.inDays} dana';
  }

  Widget _buildDashboardTab() {
    final summary = widget.feedingSummaryByCat[widget.selectedCatId];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CatMoodWidget(feedTrigger: widget.feedTrigger),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Zadnje hranjenje', style: TextStyle(fontSize: 11, color: Colors.black45)),
                      const SizedBox(height: 2),
                      Text(_timeAgo(summary?['lastFed'] as DateTime?),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                  Container(width: 1, height: 30, color: Colors.grey.shade100),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Danas pojela', style: TextStyle(fontSize: 11, color: Colors.black45)),
                      const SizedBox(height: 2),
                      Text('${summary?['todayGrams'] ?? 0} g',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Izaberi mačku', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: openAddCatProfile,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Dodaj'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildCatSelectorRow(),
            const SizedBox(height: 6),
            const Text(
              'Drži prst na mački za uređivanje ili brisanje',
              style: TextStyle(color: Colors.black38, fontSize: 11),
            ),
            const SizedBox(height: 28),
            const Text('Količina obroka', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
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
                      color: selected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: selected ? AppColors.primary : AppColors.tint100, width: 2),
                    ),
                    child: Text('$grams g',
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: isFeeding ? null : feedCat,
              child: isFeeding
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('NAHRANI ODMAH 🐾'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCareListTab() {
    if (isLoadingSchedules) {
      return const Center(child: CircularProgressIndicator());
    }

    final week = _currentWeekDates();
    final items = _scheduleItemsForDay(selectedDay);
    final doneCount = items.where((i) => i['done'] == true).length;
    final progress = items.isEmpty ? 0 : (doneCount / items.length * 100).round();
    final selectedCatName = widget.cats.where((c) => c.id == widget.selectedCatId).isNotEmpty
        ? widget.cats.firstWhere((c) => c.id == widget.selectedCatId).name
        : '';

    return RefreshIndicator(
      onRefresh: loadSchedulesAndLogs,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (selectedCatName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text('Raspored za: $selectedCatName',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: week.map((date) {
              final selected = _isSameDate(date, selectedDay);
              final isToday = _isSameDate(date, DateTime.now());
              return GestureDetector(
                onTap: () => setState(() => selectedDay = date),
                child: Column(
                  children: [
                    Text(_dayLetters[date.weekday - 1],
                        style: const TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? AppColors.primary : (isToday ? AppColors.tint50 : Colors.transparent),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Zadaci za taj dan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              if (items.isNotEmpty)
                Text('Napredak $progress%',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            EmptyState(
              icon: Icons.calendar_today_rounded,
              title: 'Nema zakazanih hranjenja',
              subtitle: '$selectedCatName nema raspored za ovaj dan.',
              actionLabel: 'Novi raspored',
              onAction: openScheduleForm,
            )
          else
            ...items.map((item) {
              final schedule = item['schedule'];
              final done = item['done'] as bool;
              final time = formatTime(schedule['time']);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: done ? AppColors.tint100 : Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      done ? Icons.check_circle : Icons.circle_outlined,
                      color: done ? AppColors.primary : Colors.grey.shade300,
                      size: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              decoration: done ? TextDecoration.lineThrough : null,
                              color: done ? Colors.black38 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('${schedule['portionGrams']}g', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ================= ANIMIRANA MAČKA =================
class CatMoodWidget extends StatefulWidget {
  final int feedTrigger;
  const CatMoodWidget({super.key, required this.feedTrigger});

  @override
  State<CatMoodWidget> createState() => _CatMoodWidgetState();
}

class _CatMoodWidgetState extends State<CatMoodWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _showHappy = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 0.94).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant CatMoodWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feedTrigger != oldWidget.feedTrigger) {
      _playHappyAnimation();
    }
  }

  void _playHappyAnimation() {
    setState(() => _showHappy = true);
    _controller.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _showHappy = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
        child: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _showHappy
                        ? [AppColors.primaryLight, AppColors.tint100]
                        : [AppColors.tint100, AppColors.tint50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 24, spreadRadius: 2)],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Text(
                      _showHappy ? '😻' : '🐱',
                      key: ValueKey(_showHappy),
                      style: const TextStyle(fontSize: 86),
                    ),
                  ),
                ),
              ),
              if (_showHappy)
                ...List.generate(3, (i) {
                  final interval = Interval((i * 0.15).clamp(0.0, 1.0), (0.75 + i * 0.1).clamp(0.0, 1.0), curve: Curves.easeOut);
                  final anim = CurvedAnimation(parent: _controller, curve: interval);
                  return AnimatedBuilder(
                    animation: anim,
                    builder: (context, _) {
                      final t = anim.value;
                      return Positioned(
                        bottom: 120 + 70 * t,
                        left: 85 + (i - 1) * 34,
                        child: Opacity(
                          opacity: (1 - t).clamp(0.0, 1.0),
                          child: Text('❤️', style: TextStyle(fontSize: 18 - i.toDouble())),
                        ),
                      );
                    },
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
