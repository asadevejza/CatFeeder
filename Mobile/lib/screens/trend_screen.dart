import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../services/profile_service.dart';
import '../services/weight_history_service.dart';

enum TrendType { weight, food, water }

const List<String> _dayLettersShort = ['P', 'U', 'S', 'Č', 'P', 'S', 'N']; // ponedjeljak..nedjelja

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
        title: const Text('Zabilježi težinu'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Otkaži')),
          TextButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              Navigator.pop(context, parsed);
            },
            child: const Text('Sačuvaj'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await WeightHistoryService.logWeight(widget.catId, result);
    final existing = await ProfileService.getCatProfile(widget.catId);
    if (existing != null) {
      await ProfileService.saveCatProfile(widget.catId, existing.copyWith(weightKg: result));
    }
    _load();
  }

  String get _title {
    switch (widget.type) {
      case TrendType.weight:
        return 'Težina';
      case TrendType.food:
        return 'Unos hrane';
      case TrendType.water:
        return 'Nivo vode';
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
        return Colors.lightBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final knownValues = _values.whereType<double>().toList();
    final latest = knownValues.isNotEmpty ? _values.lastWhere((v) => v != null, orElse: () => null) : null;
    final avg = knownValues.isEmpty ? null : knownValues.reduce((a, b) => a + b) / knownValues.length;
    final maxV = knownValues.isEmpty ? null : knownValues.reduce((a, b) => a > b ? a : b);

    return Scaffold(
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
                const Text('Zadnji unos', style: TextStyle(fontSize: 12, color: Colors.black45)),
                const SizedBox(height: 22),
                Container(
                  height: 220,
                  padding: const EdgeInsets.fromLTRB(8, 20, 20, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: widget.type == TrendType.food ? _buildBarChart() : _buildLineChart(),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _StatBox(label: 'Prosjek', value: avg == null ? '--' : _formatValue(avg))),
                    const SizedBox(width: 10),
                    Expanded(child: _StatBox(label: 'Maksimum', value: maxV == null ? '--' : _formatValue(maxV))),
                  ],
                ),
                if (widget.type == TrendType.weight) ...[
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _logWeightDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Zabilježi današnju težinu'),
                    ),
                  ),
                ],
                if (widget.type != TrendType.weight) ...[
                  const SizedBox(height: 14),
                  Text(
                    widget.type == TrendType.food
                        ? 'Zbir grama nahranjenih po danu, iz evidencije hranjenja.'
                        : 'Nivo vode u spremniku prema zadnjem senzorskom očitavanju tog dana.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
    );
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
      return Center(child: Text('Nema podataka za posljednjih 7 dana', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)));
    }
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
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
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_dayLettersShort[_days[i].weekday - 1], style: const TextStyle(fontSize: 11, color: Colors.black45)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _color,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: _color.withOpacity(0.12)),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final hasAny = _values.any((v) => v != null && v > 0);
    if (!hasAny) {
      return Center(child: Text('Nema podataka za posljednjih 7 dana', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)));
    }
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
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
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_dayLettersShort[_days[i].weekday - 1], style: const TextStyle(fontSize: 11, color: Colors.black45)),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(_values.length, (i) {
          final v = _values[i] ?? 0;
          return BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(toY: v, color: _color, width: 16, borderRadius: BorderRadius.circular(4))],
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
        border: Border.all(color: Colors.grey.shade100),
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
