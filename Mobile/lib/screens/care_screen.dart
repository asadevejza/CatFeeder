import 'dart:io';
import 'package:flutter/material.dart';
import '../models/cat.dart';
import '../models/cat_profile.dart';
import '../services/care_list_service.dart';
import '../services/cat_avatar_service.dart';
import '../services/profile_service.dart';
import 'add_cat_screen.dart';
import 'trend_screen.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';

const List<String> _mjeseciBs = [
  'jan', 'feb', 'mar', 'apr', 'maj', 'jun', 'jul', 'avg', 'sep', 'okt', 'nov', 'dec',
];
const List<String> _mjeseciEn = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
List<String> get _mjeseci => AppStrings.locale.value == 'en' ? _mjeseciEn : _mjeseciBs;
const List<String> _dayLettersBs = ['N', 'P', 'U', 'S', 'Č', 'P', 'S']; // 0=Sunday
const List<String> _dayLettersEn = ['S', 'M', 'T', 'W', 'T', 'F', 'S']; // 0=Sunday
List<String> get _dayLetters => AppStrings.locale.value == 'en' ? _dayLettersEn : _dayLettersBs;

class CareScreen extends StatefulWidget {
  final List<Cat> cats;
  final int? selectedCatId;
  final void Function(int catId) onSelectCat;
  final Map<int, Map<String, dynamic>> feedingSummaryByCat;
  final double? waterLevel;
  final Future<bool> Function(String name, CatProfile profile) onAddCat;
  final Future<bool> Function(int catId, String name, CatProfile profile) onUpdateCat;
  final Future<bool> Function(int catId, int portionGrams) onFeedNow;
  final String baseUrl;

  const CareScreen({
    super.key,
    required this.cats,
    required this.selectedCatId,
    required this.onSelectCat,
    required this.feedingSummaryByCat,
    required this.waterLevel,
    required this.onAddCat,
    required this.onUpdateCat,
    required this.onFeedNow,
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
    _loadProfiles();
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
    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.locale,
      builder: (context, _, __) => Scaffold(
        appBar: AppBar(
          title: TabBar(
            controller: _tabController,
            labelColor: AppColors.textDark,
            unselectedLabelColor: Colors.black38,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            tabs: [Tab(text: AppStrings.t('dashboard')), Tab(text: AppStrings.t('care_list'))],
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
                    onUpdateCat: widget.onUpdateCat,
                    onFeedNow: widget.onFeedNow,
                    onProfileChanged: _loadProfiles,
                  ),
                  _CareListTab(cat: _selectedCat),
                ],
              ),
            ),
          ],
        ),
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
                        border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.tint50,
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
                Text(AppStrings.t('add'), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
  final Future<bool> Function(int catId, String name, CatProfile profile) onUpdateCat;
  final Future<bool> Function(int catId, int portionGrams) onFeedNow;
  final VoidCallback onProfileChanged;

  const _DashboardTab({
    required this.cat,
    required this.profile,
    required this.summary,
    required this.waterLevel,
    required this.baseUrl,
    required this.onUpdateCat,
    required this.onFeedNow,
    required this.onProfileChanged,
  });

  Future<void> _openEditProfile(BuildContext context) async {
    if (cat == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCatScreen(
          onSave: (name, profile) async => false, // se ne koristi u edit modu
          existingCat: cat,
          existingProfile: profile,
          onUpdate: onUpdateCat,
        ),
      ),
    );
    onProfileChanged();
  }

  Future<void> _openFeedSheet(BuildContext context) async {
    if (cat == null) return;
    int selectedPortion = 50;
    bool isFeeding = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${AppStrings.t('feed_dialog_title')} — ${cat!.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              Text(AppStrings.t('portion_amount'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [50, 100, 150].map((grams) {
                  final selected = selectedPortion == grams;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedPortion = grams),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: selected ? AppColors.primary : AppColors.tint100, width: 2),
                      ),
                      child: Text('${grams}g', style: TextStyle(color: selected ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w700)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isFeeding
                      ? null
                      : () async {
                          setSheetState(() => isFeeding = true);
                          final ok = await onFeedNow(cat!.id, selectedPortion);
                          if (!sheetContext.mounted) return;
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? '${AppStrings.t('fed_success_prefix')}$selectedPortion${AppStrings.t('fed_success_for')}${cat!.name}! 🐾'
                                    : AppStrings.t('feed_failed'),
                              ),
                            ),
                          );
                        },
                  child: isFeeding
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : Text(AppStrings.t('feed_button')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
      return Center(child: Text(AppStrings.t('no_cat_dashboard')));
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
            Text(AppStrings.t('overview'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            TextButton(
              onPressed: () => _openEditProfile(context),
              child: Text(AppStrings.t('edit')),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openFeedSheet(context),
            icon: const Icon(Icons.restaurant_rounded, size: 18),
            label: Text(AppStrings.t('feed_now')),
          ),
        ),
        const SizedBox(height: 10),
        _OverviewCard(
          title: AppStrings.t('weight'),
          trailing: AppStrings.t('trend_7d'),
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
          title: AppStrings.t('food_intake'),
          trailing: AppStrings.t('trend_7d'),
          onTrailingTap: () => _openTrend(context, TrendType.food),
          child: Row(
            children: [
              Expanded(
                child: _StatColumn(label: AppStrings.t('meals'), value: '$mealCount ${AppStrings.t('times_suffix')}'),
              ),
              Expanded(
                child: _StatColumn(label: AppStrings.t('total'), value: '$todayGrams/$dailyGoalGrams g'),
              ),
              _MiniSparkline(color: Colors.orange),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _OverviewCard(
          title: AppStrings.t('water_level'),
          trailing: AppStrings.t('trend_7d'),
          onTrailingTap: () => _openTrend(context, TrendType.water),
          child: Row(
            children: [
              Expanded(
                child: _StatColumn(label: AppStrings.t('current'), value: waterLevel == null ? '--' : '${waterLevel!.toStringAsFixed(0)}%'),
              ),
              Expanded(
                child: _StatColumn(
                  label: AppStrings.t('status'),
                  value: (waterLevel ?? 100) < 20 ? AppStrings.t('low') : AppStrings.t('ok'),
                  valueColor: (waterLevel ?? 100) < 20 ? AppColors.danger : Colors.green,
                ),
              ),
              _MiniSparkline(color: AppColors.primary),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (profile != null) ...[
          const SizedBox(height: 18),
          Text(AppStrings.t('about_cat'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _InfoChip(icon: Icons.cake_rounded, label: '${profile!.ageYears} ${AppStrings.t('years_suffix')}')),
              const SizedBox(width: 10),
              Expanded(child: _InfoChip(icon: profile!.gender == 'Ženka' ? Icons.female_rounded : Icons.male_rounded, label: AppStrings.t(profile!.gender == 'Ženka' ? 'female' : 'male'))),
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
  final Color? valueColor;
  const _StatColumn({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: valueColor ?? AppColors.textDark)),
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
  List<CareItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _CareListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cat?.id != widget.cat?.id) _load();
  }

  Future<void> _load() async {
    if (widget.cat == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    final items = await CareListService.itemsFor(widget.cat!.id, _selectedDay);
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _toggle(CareItem item, bool value) async {
    if (widget.cat == null) return;
    setState(() => item.done = value);
    final items = await CareListService.setDone(widget.cat!.id, _selectedDay, item.instanceId, value);
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _editDetail(CareItem item) async {
    if (widget.cat == null || item.detailType == CareDetailType.none) return;

    String? newDetail;
    if (item.detailType == CareDetailType.time) {
      final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (picked == null) return;
      newDetail = picked.format(context);
    } else {
      final controller = TextEditingController(text: item.detail ?? '');
      newDetail = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(item.title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: AppStrings.t('eg_half_cup')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(AppStrings.t('cancel'))),
            TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(AppStrings.t('save'))),
          ],
        ),
      );
      if (newDetail == null || newDetail.isEmpty) return;
    }

    setState(() => item.detail = newDetail);
    final items = await CareListService.setDetail(widget.cat!.id, _selectedDay, item.instanceId, newDetail);
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _removeItem(CareItem item) async {
    if (widget.cat == null) return;
    final items = await CareListService.removeItem(widget.cat!.id, _selectedDay, item.instanceId);
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _addTask() async {
    if (widget.cat == null) return;
    final template = await showModalBottomSheet<CareTaskTemplate>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(AppStrings.t('add_task'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            ...careTaskTemplates.map((t) => ListTile(
                  leading: Icon(t.icon, color: AppColors.primary),
                  title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(context, t),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (template == null) return;

    final items = await CareListService.addItem(widget.cat!.id, _selectedDay, template);
    if (!mounted) return;
    setState(() => _items = items);
  }

  List<DateTime> get _weekDays {
    final startOfWeek = _selectedDay.subtract(Duration(days: _selectedDay.weekday % 7));
    return List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cat == null) {
      return Center(child: Text(AppStrings.t('no_cat_care_list')));
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final doneCount = _items.where((e) => e.done).length;
    final progress = _items.isEmpty ? 0.0 : doneCount / _items.length;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 90),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_mjeseci[_selectedDay.month - 1]} ${_selectedDay.year}.',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    Text('${AppStrings.t('daily_progress')} ', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    Text('${(progress * 100).round()}%',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
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
                      _load();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: isToday && !isSelected ? Border.all(color: AppColors.primary) : null,
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
            Text(AppStrings.t('todo'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ..._items.map((item) {
              return Dismissible(
                key: ValueKey(item.instanceId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                ),
                onDismissed: (_) => _removeItem(item),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      _CircleCheck(done: item.done, onChanged: (v) => _toggle(item, v)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _editDetail(item),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    decoration: item.done ? TextDecoration.lineThrough : null,
                                    color: item.done ? Colors.black38 : AppColors.textDark,
                                  )),
                              if (item.detailType != CareDetailType.none) ...[
                                const SizedBox(height: 3),
                                Text(
                                  (item.detail?.isNotEmpty ?? false) ? item.detail! : item.detailHint,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: (item.detail?.isNotEmpty ?? false) ? AppColors.primary : Colors.black38,
                                    fontWeight: (item.detail?.isNotEmpty ?? false) ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        Positioned(
          right: 4,
          bottom: 20,
          child: FloatingActionButton(
            heroTag: 'care_add_task',
            onPressed: _addTask,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

// Kružni checkbox (prazan krug sa zlatnim rubom -> ispunjen zelenom bojom
// sa kvačicom kad je zadatak završen), po uzoru na referentni dizajn.
class _CircleCheck extends StatelessWidget {
  final bool done;
  final void Function(bool value) onChanged;
  const _CircleCheck({required this.done, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!done),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? AppColors.primary : Colors.transparent,
          border: Border.all(color: done ? AppColors.primary : AppColors.gold, width: 1.6),
        ),
        child: done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
      ),
    );
  }
}
