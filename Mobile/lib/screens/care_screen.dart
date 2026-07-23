import 'dart:io';
import 'package:flutter/material.dart';
import '../models/cat.dart';
import '../models/cat_profile.dart';
import '../services/care_list_service.dart';
import '../services/cat_avatar_service.dart';
import '../services/profile_service.dart';
import 'add_cat_screen.dart';
import 'trend_screen.dart';

const List<String> _mjeseci = [
  'jan', 'feb', 'mar', 'apr', 'maj', 'jun', 'jul', 'avg', 'sep', 'okt', 'nov', 'dec',
];
const List<String> _dayLetters = ['N', 'P', 'U', 'S', 'Č', 'P', 'S']; // 0=Sunday

class _CareTask {
  final String id;
  final String title;
  final IconData icon;
  const _CareTask(this.id, this.title, this.icon);
}

const List<_CareTask> _defaultTasks = [
  _CareTask('play', 'Vrijeme igre', Icons.sports_baseball_rounded),
  _CareTask('feed', 'Nahrani suhom hranom', Icons.icecream_rounded),
  _CareTask('litter', 'Provjeri WC posudu', Icons.cleaning_services_rounded),
  _CareTask('groom', 'Očetkaj krzno', Icons.brush_rounded),
  _CareTask('water', 'Provjeri svježu vodu', Icons.water_drop_rounded),
];

class CareScreen extends StatefulWidget {
  final List<Cat> cats;
  final int? selectedCatId;
  final void Function(int catId) onSelectCat;
  final Map<int, Map<String, dynamic>> feedingSummaryByCat;
  final double? waterLevel;
  final Future<bool> Function(String name, CatProfile profile) onAddCat;
  final String baseUrl;

  const CareScreen({
    super.key,
    required this.cats,
    required this.selectedCatId,
    required this.onSelectCat,
    required this.feedingSummaryByCat,
    required this.waterLevel,
    required this.onAddCat,
    required this.baseUrl,
  });

  @override
  State<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends State<CareScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<int, CatProfile> _catProfiles = {};
  Map<int, String> _avatarPaths = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfiles();
  }

  @override
  void didUpdateWidget(covariant CareScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cats.length != widget.cats.length) _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await ProfileService.getAllCatProfiles();
    final avatars = <int, String>{};
    for (final cat in widget.cats) {
      final path = await CatAvatarService.getAvatarPath(cat.id);
      if (path != null) avatars[cat.id] = path;
    }
    if (!mounted) return;
    setState(() {
      _catProfiles = profiles;
      _avatarPaths = avatars;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Cat? get _selectedCat {
    final match = widget.cats.where((c) => c.id == widget.selectedCatId);
    return match.isNotEmpty ? match.first : (widget.cats.isNotEmpty ? widget.cats.first : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1A2B3C),
          unselectedLabelColor: Colors.black38,
          indicatorColor: Colors.lightBlue,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          tabs: const [Tab(text: 'Dashboard'), Tab(text: 'Care List')],
        ),
      ),
      body: Column(
        children: [
          _CatSelectorRow(
            cats: widget.cats,
            selectedCatId: widget.selectedCatId,
            avatarPaths: _avatarPaths,
            onSelectCat: widget.onSelectCat,
            onAddCat: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddCatScreen(onSave: widget.onAddCat)),
              );
              _loadProfiles();
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _DashboardTab(
                  cat: _selectedCat,
                  profile: _selectedCat == null ? null : _catProfiles[_selectedCat!.id],
                  summary: _selectedCat == null ? null : widget.feedingSummaryByCat[_selectedCat!.id],
                  waterLevel: widget.waterLevel,
                  baseUrl: widget.baseUrl,
                ),
                _CareListTab(cat: _selectedCat),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= SELEKTOR MAČAKA =================
class _CatSelectorRow extends StatelessWidget {
  final List<Cat> cats;
  final int? selectedCatId;
  final Map<int, String> avatarPaths;
  final void Function(int catId) onSelectCat;
  final VoidCallback onAddCat;

  const _CatSelectorRow({
    required this.cats,
    required this.selectedCatId,
    required this.avatarPaths,
    required this.onSelectCat,
    required this.onAddCat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 106,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...cats.map((cat) {
            final selected = cat.id == selectedCatId;
            final avatarPath = avatarPaths[cat.id];
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () => onSelectCat(cat.id),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: selected ? Colors.lightBlue : Colors.transparent, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.lightBlue.shade50,
                        backgroundImage: avatarPath != null ? FileImage(File(avatarPath)) : null,
                        child: avatarPath == null ? const Text('🐈', style: TextStyle(fontSize: 22)) : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(cat.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? Colors.black87 : Colors.black45,
                        )),
                  ],
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: onAddCat,
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: Icon(Icons.add_rounded, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 6),
                Text('Dodaj', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= DASHBOARD PODTAB =================
class _DashboardTab extends StatelessWidget {
  final Cat? cat;
  final CatProfile? profile;
  final Map<String, dynamic>? summary;
  final double? waterLevel;
  final String baseUrl;

  const _DashboardTab({
    required this.cat,
    required this.profile,
    required this.summary,
    required this.waterLevel,
    required this.baseUrl,
  });

  void _openTrend(BuildContext context, TrendType type) {
    if (cat == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrendScreen(
          type: type,
          catId: cat!.id,
          catName: cat!.name,
          baseUrl: baseUrl,
          currentWeightKg: profile?.weightKg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cat == null) {
      return const Center(child: Text('Dodaj svoju prvu mačku da vidiš dashboard.'));
    }

    final todayGrams = (summary?['todayGrams'] as int?) ?? 0;
    final mealCount = (summary?['mealCount'] as int?) ?? 0;
    const dailyGoalGrams = 200;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Pregled', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Uskoro dostupno.')),
              ),
              child: const Text('Uredi'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _OverviewCard(
          title: 'Težina',
          trailing: '7-dnevni trend',
          onTrailingTap: () => _openTrend(context, TrendType.weight),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(profile == null ? '--' : profile!.weightKg.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              const Padding(
                padding: EdgeInsets.only(left: 6, bottom: 6),
                child: Text('kg', style: TextStyle(fontSize: 14, color: Colors.black45)),
              ),
              const Spacer(),
              _MiniSparkline(color: Colors.green),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _OverviewCard(
          title: 'Unos hrane',
          trailing: '7-dnevni trend',
          onTrailingTap: () => _openTrend(context, TrendType.food),
          child: Row(
            children: [
              Expanded(
                child: _StatColumn(label: 'Obroci', value: '$mealCount puta'),
              ),
              Expanded(
                child: _StatColumn(label: 'Ukupno', value: '$todayGrams/$dailyGoalGrams g'),
              ),
              _MiniSparkline(color: Colors.orange),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _OverviewCard(
          title: 'Nivo vode',
          trailing: '7-dnevni trend',
          onTrailingTap: () => _openTrend(context, TrendType.water),
          child: Row(
            children: [
              Expanded(
                child: _StatColumn(label: 'Trenutno', value: waterLevel == null ? '--' : '${waterLevel!.toStringAsFixed(0)}%'),
              ),
              Expanded(
                child: _StatColumn(label: 'Status', value: (waterLevel ?? 100) < 20 ? 'Nisko' : 'U redu'),
              ),
              _MiniSparkline(color: Colors.lightBlue),
            ],
          ),
        ),
        const SizedBox(height: 18),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uskoro dostupno.')),
          ),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.grey.shade900, Colors.grey.shade800]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text('Otključaj uvide za ${cat!.name}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                const Text('Besplatno 7 dana', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),
        if (profile != null) ...[
          const SizedBox(height: 18),
          Text('O mački', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _InfoChip(icon: Icons.cake_rounded, label: '${profile!.ageYears} god.')),
              const SizedBox(width: 10),
              Expanded(child: _InfoChip(icon: profile!.gender == 'Ženka' ? Icons.female_rounded : Icons.male_rounded, label: profile!.gender)),
            ],
          ),
          const SizedBox(height: 10),
          _InfoChip(icon: Icons.pets_rounded, label: profile!.breed, fullWidth: true),
        ],
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String trailing;
  final Widget child;
  final VoidCallback? onTrailingTap;
  const _OverviewCard({required this.title, required this.trailing, required this.child, this.onTrailingTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              InkWell(
                onTap: onTrailingTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Text(trailing, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey.shade500),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  final Color color;
  const _MiniSparkline({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 32,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(6, (i) {
          final h = 8.0 + (i % 4) * 6.0;
          return Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Container(width: 6, height: h, decoration: BoxDecoration(color: color.withOpacity(0.35), borderRadius: BorderRadius.circular(3))),
          );
        }),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool fullWidth;
  const _InfoChip({required this.icon, required this.label, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

// ================= CARE LIST PODTAB =================
class _CareListTab extends StatefulWidget {
  final Cat? cat;
  const _CareListTab({required this.cat});

  @override
  State<_CareListTab> createState() => _CareListTabState();
}

class _CareListTabState extends State<_CareListTab> {
  DateTime _selectedDay = DateTime.now();
  Set<String> _doneTaskIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDone();
  }

  @override
  void didUpdateWidget(covariant _CareListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cat?.id != widget.cat?.id) _loadDone();
  }

  Future<void> _loadDone() async {
    if (widget.cat == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    final done = await CareListService.doneTasksFor(widget.cat!.id, _selectedDay);
    if (!mounted) return;
    setState(() {
      _doneTaskIds = done;
      _isLoading = false;
    });
  }

  Future<void> _toggle(String taskId, bool value) async {
    if (widget.cat == null) return;
    setState(() {
      if (value) {
        _doneTaskIds.add(taskId);
      } else {
        _doneTaskIds.remove(taskId);
      }
    });
    await CareListService.setDone(widget.cat!.id, _selectedDay, taskId, value);
  }

  List<DateTime> get _weekDays {
    final startOfWeek = _selectedDay.subtract(Duration(days: _selectedDay.weekday % 7));
    return List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cat == null) {
      return const Center(child: Text('Dodaj svoju prvu mačku da vidiš listu njege.'));
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final progress = _doneTaskIds.length / _defaultTasks.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_mjeseci[_selectedDay.month - 1]} ${_selectedDay.year}.',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Row(
              children: [
                const Text('Dnevni napredak ', style: TextStyle(fontSize: 12, color: Colors.black54)),
                Text('${(progress * 100).round()}%',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.lightBlue)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: _weekDays.map((day) {
            final isSelected = day.year == _selectedDay.year && day.month == _selectedDay.month && day.day == _selectedDay.day;
            final isToday = _isSameDay(day, DateTime.now());
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedDay = day);
                  _loadDone();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.lightBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: isToday && !isSelected ? Border.all(color: Colors.lightBlue) : null,
                  ),
                  child: Column(
                    children: [
                      Text(_dayLetters[day.weekday % 7],
                          style: TextStyle(fontSize: 11, color: isSelected ? Colors.white70 : Colors.black45)),
                      const SizedBox(height: 4),
                      Text('${day.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : Colors.black87,
                          )),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        const Text('Zadaci', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ..._defaultTasks.map((task) {
          final done = _doneTaskIds.contains(task.id);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: CheckboxListTile(
              value: done,
              onChanged: (v) => _toggle(task.id, v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: Colors.lightBlue,
              secondary: Icon(task.icon, color: Colors.lightBlue),
              title: Text(task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? Colors.black38 : Colors.black87,
                  )),
            ),
          );
        }),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
