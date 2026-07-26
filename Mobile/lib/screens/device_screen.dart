import 'package:flutter/material.dart';
import 'status_detail_screen.dart';

// "Uređaji" tab - lista povezanih uređaja (trenutno samo jedna hranilica).
// Klik na karticu vodi na detaljan status (nivo hrane/vode, temperatura, vlažnost).
class DeviceScreen extends StatelessWidget {
  final double foodLevel;
  final double? waterLevel;
  final double temp;
  final double humidity;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const DeviceScreen({
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
    return Scaffold(
      appBar: AppBar(title: const Text('Uređaji')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                padding: const EdgeInsets.all(18.0),
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StatusDetailScreen(
                          foodLevel: foodLevel,
                          waterLevel: waterLevel,
                          temp: temp,
                          humidity: humidity,
                          isLoading: isLoading,
                          onRefresh: onRefresh,
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(color: Colors.lightBlue.shade50, borderRadius: BorderRadius.circular(14)),
                                child: const Icon(Icons.icecream_rounded, color: Colors.lightBlue, size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('CatFeeder Hranilica', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text('Online', style: TextStyle(fontSize: 12, color: Colors.black45)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _MiniStat(label: 'Hrana', value: '${foodLevel.toStringAsFixed(0)}%', color: Colors.amber.shade700)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MiniStat(
                                  label: 'Voda',
                                  value: waterLevel != null ? '${waterLevel!.toStringAsFixed(0)}%' : '--',
                                  color: Colors.lightBlue,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: _MiniStat(label: 'Temperatura', value: '${temp.toStringAsFixed(0)}°C', color: Colors.redAccent)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text('Dodirni za detaljan status →', style: TextStyle(fontSize: 11, color: Colors.black38)),
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black45)),
        ],
      ),
    );
  }
}
