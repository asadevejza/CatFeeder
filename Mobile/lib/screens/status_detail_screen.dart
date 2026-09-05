import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';

// Detaljan status hranilice - otvara se klikom na uređaj na "Uređaji" tabu.
class StatusDetailScreen extends StatelessWidget {
  final double foodLevel;
  final double? waterLevel;
  final double temp;
  final double humidity;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const StatusDetailScreen({
    super.key,
    required this.foodLevel,
    required this.waterLevel,
    required this.temp,
    required this.humidity,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.locale,
      builder: (context, _, __) => Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('feeder_status_title'))),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                padding: const EdgeInsets.all(18.0),
                children: [
                  _LevelCard(
                    title: AppStrings.t('food_level_title'),
                    level: foodLevel,
                    color: Colors.amber.shade700,
                    lowWarningText: AppStrings.t('food_low_warning'),
                  ),
                  const SizedBox(height: 16),
                  _LevelCard(
                    title: AppStrings.t('water_level_title'),
                    level: waterLevel,
                    color: AppColors.primary,
                    lowWarningText: AppStrings.t('water_low_warning'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _SensorCard(icon: Icons.thermostat_rounded, color: Colors.redAccent, label: AppStrings.t('temperature'), value: '${temp.toStringAsFixed(1)}°C')),
                      const SizedBox(width: 14),
                      Expanded(child: _SensorCard(icon: Icons.water_drop_rounded, color: Colors.blue, label: AppStrings.t('humidity'), value: '${humidity.toStringAsFixed(1)}%')),
                    ],
                  ),
                ],
              ),
            ),
    ));
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
              Text(AppStrings.t('no_sensor_data'), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
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
                      Text(isLow ? AppStrings.t('running_low') : AppStrings.t('ok'),
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
