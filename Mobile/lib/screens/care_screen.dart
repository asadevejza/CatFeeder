import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cat.dart';
import '../models/cat_profile.dart';
import '../services/care_list_service.dart';
import '../services/cat_avatar_service.dart';
import '../services/profile_service.dart';
import 'add_cat_screen.dart';
import 'trend_screen.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';
import '../widgets/empty_state.dart';
import '../widgets/feedback_overlay.dart';
import '../widgets/skeleton_box.dart';
import '../services/weight_history_service.dart';
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
  final Future<int?> Function(String name, CatProfile profile) onAddCat;
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
    var profiles = await ProfileService.getAllCatProfiles();
    // Ako neka mačka (npr. dodana prije ove funkcije, ili preko drugog uređaja)
    // nema lokalni profil, napravi podrazumijevani da Dashboard nikad ne ostane prazan.
    bool seededAny = false;
    for (final cat in widget.cats) {
      if (!profiles.containsKey(cat.id)) {
        final seeded = CatProfile(gender: 'Mužjak', breed: AppStrings.t('unknown_breed'), ageYears: 0, weightKg: 0);
        await ProfileService.saveCatProfile(cat.id, seeded);
        seededAny = true;
      }
    }
    if (seededAny) profiles = await ProfileService.getAllCatProfiles();
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

  Future<void> _openAddCat() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddCatScreen(onSave: widget.onAddCat)),
    );
    _loadProfiles();
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
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.25],
              colors: [AppColors.tint100, AppColors.background],
            ),
          ),
          child: Column(
            children: [
              _CatSelectorRow(
                cats: widget.cats,
                selectedCatId: widget.selectedCatId,
                avatarPaths: _avatarPaths,
                onSelectCat: widget.onSelectCat,
                onAddCat: _openAddCat,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _DashboardTab(
                      cat: _selectedCat,
                      profile: _selectedCat == null ? null : _catProfiles[_selectedCat!.id],
                      summary: _selectedCat == null ? null : widget.feedingSummaryByCat[_selectedCat!.id],
                      baseUrl: widget.baseUrl,
                      onUpdateCat: widget.onUpdateCat,
                      onFeedNow: widget.onFeedNow,
                      onProfileChanged: _loadProfiles,
                      onAddCat: _openAddCat,
                    ),
                    _CareListTab(cat: _selectedCat, onAddCat: _openAddCat),
                  ],
                ),
              ),
            ],
          ),
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
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelectCat(cat.id);
                },
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: selected
                            ? const LinearGradient(colors: [AppColors.primaryLight, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight)
                            : null,
                        boxShadow: selected
                            ? [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))]
                            : null,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.background),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.tint50,
                          backgroundImage: avatarPath != null ? FileImage(File(avatarPath)) : null,
                          child: avatarPath == null ? const Text('🐈', style: TextStyle(fontSize: 22)) : null,
                        ),
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
  final String baseUrl;
  final Future<bool> Function(int catId, String name, CatProfile profile) onUpdateCat;
  final Future<bool> Function(int catId, int portionGrams) onFeedNow;
  final VoidCallback onProfileChanged;
  final VoidCallback onAddCat;

  const _DashboardTab({
    required this.cat,
    required this.profile,
    required this.summary,
    required this.baseUrl,
    required this.onUpdateCat,
    required this.onFeedNow,
    required this.onProfileChanged,
    required this.onAddCat,
  });

  Future<void> _openEditProfile(BuildContext context) async {
    if (cat == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCatScreen(
          onSave: (name, profile) async => null, // se ne koristi u edit modu
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
    bool isCustom = false;
    bool isFeeding = false;
    final customController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final customValue = int.tryParse(customController.text.trim());
          final canFeed = isCustom ? (customValue != null && customValue > 0) : true;

          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(sheetContext).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${AppStrings.t('feed_dialog_title')} ${cat!.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),
                Text(AppStrings.t('portion_amount'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54)),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ...[50, 100, 150].map((grams) {
                      final selected = !isCustom && selectedPortion == grams;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setSheetState(() {
                            isCustom = false;
                            selectedPortion = grams;
                          });
                        },
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
                    }),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setSheetState(() => isCustom = true);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: isCustom ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: isCustom ? AppColors.primary : AppColors.tint100, width: 2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded, size: 15, color: isCustom ? Colors.white : AppColors.textDark),
                            const SizedBox(width: 6),
                            Text(AppStrings.t('custom_amount'), style: TextStyle(color: isCustom ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (isCustom) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: customController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      hintText: AppStrings.t('custom_amount_hint'),
                      suffixText: 'g',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (isFeeding || !canFeed)
                        ? null
                        : () async {
                            final portionToFeed = isCustom ? customValue! : selectedPortion;
                            setSheetState(() => isFeeding = true);
                            final ok = await onFeedNow(cat!.id, portionToFeed);
                            if (!sheetContext.mounted) return;
                            if (ok) {
                              HapticFeedback.mediumImpact();
                            } else {
                              HapticFeedback.vibrate();
                            }
                            Navigator.pop(sheetContext);
                            FeedbackOverlay.show(
                              context,
                              success: ok,
                              title: ok ? AppStrings.t('fed_success_title') : AppStrings.t('feed_failed'),
                              subtitle: ok ? '$portionToFeed g ${AppStrings.t('fed_success_for_name')} ${cat!.name}' : null,
                            );
                          },
                    child: isFeeding
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : Text(AppStrings.t('feed_button')),
                  ),
                ),
              ],
            ),
          );
        },
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            icon: Icons.pets_rounded,
            title: AppStrings.t('no_cats_yet'),
            subtitle: AppStrings.t('no_cat_dashboard'),
            actionLabel: AppStrings.t('add_cat_title'),
            onAction: onAddCat,
          ),
        ),
      );
    }

    final todayGrams = (summary?['todayGrams'] as int?) ?? 0;
    final mealCount = (summary?['mealCount'] as int?) ?? 0;
    final dailyGoalGrams = profile?.dailyGoalGrams ?? 200;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => onProfileChanged(),
      child: ListView(
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
  child: FutureBuilder<double?>(
    future: WeightHistoryService.getLatestWeight(cat!.id, profile?.weightKg ?? 0.0),
    builder: (context, snapshot) {
      final currentWeight = snapshot.data;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            currentWeight != null ? currentWeight.toStringAsFixed(1) : '--',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 6),
            child: Text('kg', style: TextStyle(fontSize: 14, color: Colors.black45)),
          ),
          const Spacer(),
          const _MiniSparkline(color: Colors.green),
        ],
      );
    },
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
        const SizedBox(height: 20),
      ],
      ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 5))],
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

  static const List<double> _pattern = [0.35, 0.55, 0.45, 0.7, 0.9, 0.65];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 32,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(_pattern.length, (i) {
          final isLast = i == _pattern.length - 1;
          return Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Container(
              width: 6,
              height: 6 + _pattern[i] * 26,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: isLast ? [color.withOpacity(0.7), color] : [color.withOpacity(0.18), color.withOpacity(0.32)],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ================= CARE LIST PODTAB =================
class _CareListTab extends StatefulWidget {
  final Cat? cat;
  final VoidCallback onAddCat;
  const _CareListTab({required this.cat, required this.onAddCat});

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
    final customController = TextEditingController();

    final template = await showModalBottomSheet<CareTaskTemplate>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
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
                const Divider(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: customController,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            hintText: AppStrings.t('custom_task_hint'),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                        onPressed: customController.text.trim().isEmpty
                            ? null
                            : () => Navigator.pop(
                                  context,
                                  CareTaskTemplate('custom', customController.text.trim(), Icons.edit_note_rounded, CareDetailType.none),
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            icon: Icons.checklist_rounded,
            title: AppStrings.t('no_cats_yet'),
            subtitle: AppStrings.t('no_cat_care_list'),
            actionLabel: AppStrings.t('add_cat_title'),
            onAction: widget.onAddCat,
          ),
        ),
      );
    }
    if (_isLoading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [SkeletonBox(height: 18, width: 110), SkeletonBox(height: 14, width: 60)],
          ),
          const SizedBox(height: 10),
          SkeletonBox(height: 8, borderRadius: BorderRadius.circular(100)),
          const SizedBox(height: 22),
          const SkeletonBox(height: 16, width: 90),
          const SizedBox(height: 12),
          SkeletonBox(height: 66, borderRadius: BorderRadius.circular(16)),
          const SizedBox(height: 12),
          SkeletonBox(height: 66, borderRadius: BorderRadius.circular(16)),
          const SizedBox(height: 12),
          SkeletonBox(height: 66, borderRadius: BorderRadius.circular(16)),
        ],
      );
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
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: AppColors.tint50,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
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
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
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
