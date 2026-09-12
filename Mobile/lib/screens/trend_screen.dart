import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../services/profile_service.dart';
import '../services/weight_history_service.dart';
import '../models/cat_profile.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';

enum TrendType { weight, food, water }

const List<String> _dayLettersShortBs = ['P', 'U', 'S', 'Č', 'P', 'S', 'N']; // ponedjeljak..nedjelja
const List<String> _dayLettersShortEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class TrendScreen extends StatefulWidget {
  final TrendType type;
  final int catId;
  final String catName;
  final String baseUrl;
  final double? currentWeightKg;

  const TrendScreen({
    super.key,
    required this.type,
    required this.catId,
    required this.catName,
    required this.baseUrl,
    this.currentWeightKg,
  });

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  bool _isLoading = true;
  List<DateTime> _days = [];
  List<double?> _values = [];

  List<String> get _dayLettersShort => AppStrings.locale.value == 'en' ? _dayLettersShortEn : _dayLettersShortBs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    switch (widget.type) {
      case TrendType.weight:
        if (widget.currentWeightKg != null) {
          await WeightHistoryService.seedIfEmpty(widget.catId, widget.currentWeightKg!);
        }
        final entries = await WeightHistoryService.lastDays(widget.catId, 7);
        _days = entries.map((e) => e.key).toList();
        _values = entries.map((e) => e.value).toList();
        break;
      case TrendType.food:
        await _loadFoodTrend();
        break;
      case TrendType.water:
        await _loadWaterTrend();
        break;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadFoodTrend() async {
    final today = DateTime.now();
    final days = List.generate(7, (i) => DateTime(today.year, today.month, today.day).subtract(Duration(days: 6 - i)));
    final totals = {for (final d in days) d: 0.0};

    try {
      final response = await http.get(Uri.parse('${widget.baseUrl}/feedinglogs'), headers: apiHeaders());
      if (response.statusCode == 200) {
        final List<dynamic> logs = json.decode(response.body);
        for (final log in logs) {
          if (log['catId'] != widget.catId) continue;
          final rawTs = log['timestamp'];
          if (rawTs == null) continue;
          DateTime ts;
          try {
            ts = DateTime.parse(rawTs.toString());
          } catch (_) {
            continue;
          }
          final dayOnly = DateTime(ts.year, ts.month, ts.day);
          if (totals.containsKey(dayOnly)) {
            totals[dayOnly] = totals[dayOnly]! + ((log['portionGrams'] as num?)?.toDouble() ?? 0);
          }
        }
      }
    } catch (_) {
      // Tiho ne uspije — graf će samo prikazati nule.
    }

    _days = days;
    _values = days.map((d) => totals[d]).toList();
  }

  Future<void> _loadWaterTrend() async {
    final today = DateTime.now();
    final days = List.generate(7, (i) => DateTime(today.year, today.month, today.day).subtract(Duration(days: 6 - i)));
    final lastOfDay = <DateTime, double?>{for (final d in days) d: null};

    try {
      final response = await http.get(Uri.parse('${widget.baseUrl}/sensorreadings'), headers: apiHeaders());
      if (response.statusCode == 200) {
        final List<dynamic> readings = json.decode(response.body);
        for (final r in readings) {
          final rawTs = r['timestamp'];
          if (rawTs == null) continue;
          DateTime ts;
          try {
            ts = DateTime.parse(rawTs.toString());
          } catch (_) {
            continue;
          }
          final dayOnly = DateTime(ts.year, ts.month, ts.day);
          if (lastOfDay.containsKey(dayOnly)) {
            final level = (r['waterLevelPercent'] as num?)?.toDouble();
            if (level != null) lastOfDay[dayOnly] = level;
          }
        }
      }
    } catch (_) {
      // Tiho ne uspije.
    }

    _days = days;
    _values = days.map((d) => lastOfDay[d]).toList();
  }

  Future<void> _logWeightDialog() async {
    final controller = TextEditingController(text: widget.currentWeightKg?.toStringAsFixed(1) ?? '');
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.t('log_weight_title')),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppStrings.t('cancel'))),
          TextButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              Navigator.pop(context, parsed);
            },
            child: Text(AppStrings.t('save')),
          ),
        ],
      ),
    );
    if (result == null) return;
    await WeightHistoryService.logWeight(widget.catId, result);
    final existing = await ProfileService.getCatProfile(widget.catId);
    // Ako mačka još nema profil (npr. dodana prije uvođenja ove funkcije),
    // napravi novi umjesto da tiho odustaneš — inače težina nikad ne bi bila spašena.
    final updated = existing?.copyWith(weightKg: result) ??
        CatProfile(gender: 'Mužjak', breed: AppStrings.t('unknown_breed'), ageYears: 0, weightKg: result);
    await ProfileService.saveCatProfile(widget.catId, updated);
    _load();
  }

  String get _title {
    switch (widget.type) {
      case TrendType.weight:
        return AppStrings.t('weight');
      case TrendType.food:
        return AppStrings.t('food_intake');
      case TrendType.water:
        return AppStrings.t('water_level');
    }
  }

  String get _unit {
    switch (widget.type) {
      case TrendType.weight:
        return 'kg';
      case TrendType.food:
        return 'g';
      case TrendType.water:
        return '%';
    }
  }

  Color get _color {
    switch (widget.type) {
      case TrendType.weight:
        return Colors.green;
      case TrendType.food:
        return Colors.orange;
      case TrendType.water:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final knownValues = _values.whereType<double>().toList();
    final latest = knownValues.isNotEmpty ? _values.lastWhere((v) => v != null, orElse: () => null) : null;
    final avg = knownValues.isEmpty ? null : knownValues.reduce((a, b) => a + b) / knownValues.length;
    final maxV = knownValues.isEmpty ? null : knownValues.reduce((a, b) => a > b ? a : b);

    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.locale,
      builder: (context, _, __) => Scaffold(
      appBar: AppBar(title: Text('$_title — ${widget.catName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(latest == null ? '--' : _formatValue(latest),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 6),
                      child: Text(_unit, style: const TextStyle(fontSize: 15, color: Colors.black45)),
                    ),
                  ],
                ),
                Text(AppStrings.t('latest_entry'), style: const TextStyle(fontSize: 12, color: Colors.black45)),
                const SizedBox(height: 22),
                Container(
                  height: 220,
                  padding: const EdgeInsets.fromLTRB(8, 20, 20, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: widget.type == TrendType.food ? _buildBarChart() : _buildLineChart(),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _StatBox(label: AppStrings.t('average'), value: avg == null ? '--' : _formatValue(avg))),
                    const SizedBox(width: 10),
                    Expanded(child: _StatBox(label: AppStrings.t('maximum'), value: maxV == null ? '--' : _formatValue(maxV))),
                  ],
                ),
                if (widget.type == TrendType.weight) ...[
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _logWeightDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(AppStrings.t('log_todays_weight')),
                    ),
                  ),
                ],
                if (widget.type != TrendType.weight) ...[
                  const SizedBox(height: 14),
                  Text(
                    widget.type == TrendType.food
                        ? AppStrings.t('food_trend_note')
                        : AppStrings.t('water_trend_note'),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
    ));
  }

  String _formatValue(double v) {
    if (widget.type == TrendType.weight) return v.toStringAsFixed(1);
    return v.toStringAsFixed(0);
  }

  Widget _buildLineChart() {
    final spots = <FlSpot>[];
    for (int i = 0; i < _values.length; i++) {
      final v = _values[i];
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }
    if (spots.isEmpty) {
      return Center(child: Text(AppStrings.t('no_data_7_days'), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)));
    }
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: null,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= _days.length) return const SizedBox.shrink();
                final isToday = i == _days.length - 1;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _dayLettersShort[_days[i].weekday - 1],
                    style: TextStyle(fontSize: 11, fontWeight: isToday ? FontWeight.w800 : FontWeight.normal, color: isToday ? _color : Colors.black45),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => _color,
           tooltipBorderRadius: BorderRadius.circular(10),
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem('${s.y.toStringAsFixed(1)} $_unit', const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            gradient: LinearGradient(colors: [_color.withOpacity(0.6), _color]),
            barWidth: 3.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 4.5, color: _color, strokeWidth: 2.5, strokeColor: Colors.white),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_color.withOpacity(0.22), _color.withOpacity(0.0)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final hasAny = _values.any((v) => v != null && v > 0);
    if (!hasAny) {
      return Center(child: Text(AppStrings.t('no_data_7_days'), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)));
    }
    final maxV = _values.whereType<double>().fold(0.0, (a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => _color,
            tooltipBorderRadius: BorderRadius.circular(10),
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem('${rod.toY.toStringAsFixed(0)} $_unit', const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= _days.length) return const SizedBox.shrink();
                final isToday = i == _days.length - 1;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _dayLettersShort[_days[i].weekday - 1],
                    style: TextStyle(fontSize: 11, fontWeight: isToday ? FontWeight.w800 : FontWeight.normal, color: isToday ? _color : Colors.black45),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(_values.length, (i) {
          final v = _values[i] ?? 0;
          final isToday = i == _values.length - 1;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: v > 0 ? v : 0,
                width: 18,
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: isToday ? [_color, _color] : [_color.withOpacity(0.55), _color.withOpacity(0.75)],
                ),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxV == 0 ? 1 : maxV * 1.15, color: Colors.grey.shade50),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
