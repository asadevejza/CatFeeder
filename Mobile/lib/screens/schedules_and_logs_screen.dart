import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/cat.dart';
import '../services/notification_service.dart';
import '../widgets/empty_state.dart';
import 'schedule_form_screen.dart';

class SchedulesAndLogsScreen extends StatefulWidget {
  final String baseUrl;
  final List<Cat> cats;
  const SchedulesAndLogsScreen({super.key, required this.baseUrl, required this.cats});

  @override
  State<SchedulesAndLogsScreen> createState() => _SchedulesAndLogsScreenState();
}


class _SchedulesAndLogsScreenState extends State<SchedulesAndLogsScreen> with SingleTickerProviderStateMixin {
  List<dynamic> logs = [];
  List<dynamic> schedules = [];
  bool isLoading = true;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {})); // za prikaz/skrivanje FAB-a
    loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String catName(dynamic catId) {
    final match = widget.cats.where((c) => c.id == catId);
    return match.isNotEmpty ? match.first.name : 'Nepoznata mačka';
  }

  // Zbraja ukupne grame hrane po danu, za posljednjih 7 dana (uključujući danas).
  // Vraća mapu gdje je ključ ponoć tog dana, poredanu od najstarijeg ka najnovijem.
  Map<DateTime, double> last7DaysTotals() {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(today.year, today.month, today.day).subtract(Duration(days: 6 - i)),
    );
    final totals = {for (final d in days) d: 0.0};

    for (final log in logs) {
      final rawTimestamp = log['timestamp'];
      if (rawTimestamp == null) continue;
      DateTime parsed;
      try {
        parsed = DateTime.parse(rawTimestamp.toString());
      } catch (_) {
        continue;
      }
      final dayKey = DateTime(parsed.year, parsed.month, parsed.day);
      if (totals.containsKey(dayKey)) {
        final grams = (log['portionGrams'] as num?)?.toDouble() ?? 0.0;
        totals[dayKey] = totals[dayKey]! + grams;
      }
    }
    return totals;
  }

  static const Map<String, String> _daysBosanski = {
    'monday': 'Ponedjeljak',
    'mon': 'Pon',
    'tuesday': 'Utorak',
    'tue': 'Uto',
    'tues': 'Uto',
    'wednesday': 'Srijeda',
    'wed': 'Sri',
    'thursday': 'Četvrtak',
    'thu': 'Čet',
    'thurs': 'Čet',
    'friday': 'Petak',
    'fri': 'Pet',
    'saturday': 'Subota',
    'sat': 'Sub',
    'sunday': 'Nedjelja',
    'sun': 'Ned',
  };

  // Prima npr. "Monday,Wednesday,Friday" i vraća "Ponedjeljak, Srijeda, Petak".
  // Ako naiđe na dan koji ne prepozna, samo ga ostavi kako jeste.
  String translateDays(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw
        .split(',')
        .map((d) => d.trim())
        .map((d) => _daysBosanski[d.toLowerCase()] ?? d)
        .join(', ');
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);
    try {
      final logsResponse = await http.get(Uri.parse('${widget.baseUrl}/feedinglogs'), headers: apiHeaders());
      final schedulesResponse = await http.get(Uri.parse('${widget.baseUrl}/feedingschedules'), headers: apiHeaders());
      if (!mounted) return;

      if (logsResponse.statusCode == 200 && schedulesResponse.statusCode == 200) {
        setState(() {
          logs = json.decode(logsResponse.body).reversed.toList();
          schedules = json.decode(schedulesResponse.body);
          isLoading = false;
        });
        _syncScheduleNotifications();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri čitanju istorije: $e')),
      );
    }
  }

  // Ponovo zakazuje notifikacije za sve trenutne rasporede — poziva se nakon
  // svakog učitavanja da podsjetnici uvijek odgovaraju stanju u bazi (npr. i
  // nakon reinstalacije app-a, kad bi lokalno zakazani alarmi bili izgubljeni).
  Future<void> _syncScheduleNotifications() async {
    for (final schedule in schedules) {
      final id = schedule['id'] as int?;
      if (id == null) continue;
      await NotificationService.scheduleForFeedingSchedule(
        scheduleId: id,
        catName: catName(schedule['catId']),
        timeString: (schedule['time'] as String?) ?? '08:00:00',
        portionGrams: (schedule['portionGrams'] as num?)?.toInt() ?? 0,
        daysOfWeekCsv: (schedule['daysOfWeek'] as String?) ?? '',
      );
    }
  }

  // "07:30:00" -> "07:30"
  String formatTime(dynamic raw) {
    if (raw == null) return '';
    final parts = raw.toString().split(':');
    if (parts.length < 2) return raw.toString();
    return '${parts[0]}:${parts[1]}';
  }

  Future<void> deleteSchedule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Obriši raspored?'),
        content: const Text('Ova akcija se ne može poništiti.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Otkaži')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final response = await http.delete(Uri.parse('${widget.baseUrl}/feedingschedules/$id'), headers: apiHeaders());
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        await NotificationService.cancelForSchedule(id);
        loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brisanje nije uspjelo.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greška: $e')));
    }
  }

  Future<void> openScheduleForm({Map<String, dynamic>? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleFormScreen(
          baseUrl: widget.baseUrl,
          cats: widget.cats,
          existingSchedule: existing,
        ),
      ),
    );
    if (saved == true) loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Aktivnosti'),
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.lightBlue,
            unselectedLabelColor: Colors.black45,
            indicatorColor: Colors.lightBlue,
            tabs: const [
              Tab(text: 'Historija'),
              Tab(text: 'Rasporedi'),
            ],
          ),
        ),
        floatingActionButton: _tabController.index == 1
            ? FloatingActionButton.extended(
                onPressed: () => openScheduleForm(),
                backgroundColor: Colors.lightBlue,
                icon: const Icon(Icons.add),
                label: const Text('Novi raspored'),
              )
            : null,
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  RefreshIndicator(
                    onRefresh: loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: logs.isEmpty ? 2 : logs.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _WeeklyFeedingChart(dailyTotals: last7DaysTotals());
                        }
                        if (logs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: EmptyState(
                              icon: Icons.restaurant_rounded,
                              title: 'Nema zabilježenih hranjenja',
                              subtitle: 'Čim nahraniš mačku (ručno ili preko rasporeda), pojaviće se ovdje.',
                            ),
                          );
                        }
                        final log = logs[index - 1];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE8F5E9),
                              child: Icon(Icons.check_circle, color: Colors.green),
                            ),
                            title: Text('${catName(log['catId'])} • ${log['portionGrams']}g',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Pokretač: ${log['triggeredBy']}'),
                            trailing: Text(
                              log['timestamp'] != null ? log['timestamp'].toString().substring(11, 16) : '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: loadData,
                    child: schedules.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(18),
                            children: [
                              EmptyState(
                                icon: Icons.alarm_add_rounded,
                                title: 'Nema rasporeda',
                                subtitle: 'Zakaži automatsko hranjenje po danima u sedmici i tačnom vremenu.',
                                actionLabel: 'Novi raspored',
                                onAction: () => openScheduleForm(),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 90),
                            itemCount: schedules.length,
                            itemBuilder: (context, index) {
                              final schedule = schedules[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  onTap: () => openScheduleForm(existing: schedule as Map<String, dynamic>),
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFFFF3E0),
                                    child: Icon(Icons.alarm, color: Colors.lightBlue),
                                  ),
                                  title: Text('${catName(schedule['catId'])} • ${formatTime(schedule['time'])}',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('Količina: ${schedule['portionGrams']}g (${translateDays(schedule['daysOfWeek'] as String?)})'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => deleteSchedule(schedule['id'] as int),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
    );
  }
}


// ================= GRAFIKON — HRANA POJEDENA PO DANU (7 DANA) =================
class _WeeklyFeedingChart extends StatelessWidget {
  final Map<DateTime, double> dailyTotals;
  const _WeeklyFeedingChart({required this.dailyTotals});

  static const List<String> _dayLabels = ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'];

  @override
  Widget build(BuildContext context) {
    final entries = dailyTotals.entries.toList();
    final maxValue = entries.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b);
    final chartMaxY = maxValue <= 0 ? 100.0 : maxValue * 1.35;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 10, bottom: 18),
              child: Text('Poslednjih 7 dana', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            SizedBox(
              height: 170,
              child: BarChart(
                BarChartData(
                  maxY: chartMaxY,
                  minY: 0,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.lightBlue,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                        '${rod.toY.toStringAsFixed(0)}g',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                          final weekday = entries[index].key.weekday; // 1 = ponedjeljak ... 7 = nedjelja
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_dayLabels[weekday - 1], style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < entries.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: entries[i].value,
                            color: entries[i].value > 0 ? Colors.lightBlue : Colors.lightBlue.shade100,
                            width: 20,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
