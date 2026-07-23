import 'package:flutter/material.dart';
import '../models/cat.dart';

class DashboardScreen extends StatelessWidget {
  final double foodLevel;
  final double? waterLevel;
  final double temp;
  final double humidity;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final List<Cat> cats;
  final int? selectedCatId;
  final void Function(int catId) onSelectCat;
  final Map<int, Map<String, dynamic>> feedingSummaryByCat;

  const DashboardScreen({
    super.key,
    required this.foodLevel,
    required this.waterLevel,
    required this.temp,
    required this.humidity,
    required this.isLoading,
    required this.onRefresh,
    required this.cats,
    required this.selectedCatId,
    required this.onSelectCat,
    required this.feedingSummaryByCat,
  });

  String _timeAgo(DateTime? dt) {
    if (dt == null) return 'Još nije hranjena';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Upravo sad';
    if (diff.inMinutes < 60) return 'Prije ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Prije ${diff.inHours}h';
    return 'Prije ${diff.inDays} dana';
  }

  @override
  Widget build(BuildContext context) {
    final selectedCat = cats.where((c) => c.id == selectedCatId);
    final summary = feedingSummaryByCat[selectedCatId];

    return Scaffold(
      appBar: AppBar(title: const Text('Status hranilice')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                padding: const EdgeInsets.all(18.0),
                children: [
                  if (cats.isNotEmpty) ...[
                    SizedBox(
                      height: 74,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: cats.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final cat = cats[index];
                          final selected = cat.id == selectedCatId;
                          return GestureDetector(
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
                                    radius: 22,
                                    backgroundColor: Colors.lightBlue.shade50,
                                    child: const Text('🐈', style: TextStyle(fontSize: 20)),
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
                          );
                        },
                      ),
                    ),
                    if (selectedCat.isNotEmpty) ...[
                      const SizedBox(height: 14),
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
                    ],
                    const SizedBox(height: 20),
                  ],
                  _LevelCard(
                    title: 'Nivo hrane u spremniku',
                    level: foodLevel,
                    color: Colors.amber.shade700,
                    lowWarningText: 'Vrijeme je da dosuješ hranu u spremnik',
                  ),
                  const SizedBox(height: 16),
                  _LevelCard(
                    title: 'Nivo vode u posudi',
                    level: waterLevel,
                    color: Colors.lightBlue,
                    lowWarningText: 'Vrijeme je da dosuješ vodu',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _SensorCard(icon: Icons.thermostat_rounded, color: Colors.redAccent, label: 'Temperatura', value: '${temp.toStringAsFixed(1)}°C')),
                      const SizedBox(width: 14),
                      Expanded(child: _SensorCard(icon: Icons.water_drop_rounded, color: Colors.blue, label: 'Vlažnost zraka', value: '${humidity.toStringAsFixed(1)}%')),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}


class _LevelCard extends StatelessWidget {
  final String title;
  final double? level;
  final Color color;
  final String lowWarningText;

  const _LevelCard({
    required this.title,
    required this.level,
    required this.color,
    required this.lowWarningText,
  });

  @override
  Widget build(BuildContext context) {
    if (level == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Icon(Icons.sensors_off_rounded, color: Colors.grey.shade400, size: 40),
              const SizedBox(height: 8),
              Text('Nema još podataka sa senzora', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final currentLevel = level!;
    final isLow = currentLevel < 20;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: currentLevel / 100),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, _) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 14,
                      strokeCap: StrokeCap.round,
                      backgroundColor: color.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(isLow ? Colors.redAccent : color),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${currentLevel.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(isLow ? 'Ponestaje!' : 'U redu',
                          style: TextStyle(
                            fontSize: 12,
                            color: isLow ? Colors.redAccent : Colors.green,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ],
              ),
            ),
            if (isLow) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 6),
                    Text(lowWarningText,
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class _SensorCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _SensorCard({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
