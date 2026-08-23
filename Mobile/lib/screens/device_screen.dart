import 'package:flutter/material.dart';
import 'status_detail_screen.dart';
import '../theme/app_colors.dart';

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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                                decoration: BoxDecoration(color: AppColors.tint50, borderRadius: BorderRadius.circular(14)),
                                child: const Icon(Icons.icecream_rounded, color: AppColors.primary, size: 26),
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
                              Expanded(
                                child: _MiniStat(
                                  label: 'Hrana',
                                  value: '${foodLevel.toStringAsFixed(0)}%',
                                  color: foodLevel < 20 ? AppColors.danger : Colors.amber.shade700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MiniStat(
                                  label: 'Voda',
                                  value: waterLevel != null ? '${waterLevel!.toStringAsFixed(0)}%' : '--',
                                  color: AppColors.primary,
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
                  const SizedBox(height: 26),
                  const Text('Otkrij', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (context) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                                child: const Icon(Icons.videocam_off_rounded, color: Colors.black45, size: 30),
                              ),
                              const SizedBox(height: 18),
                              const Text('Kamera nije povezana', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 10),
                              const Text(
                                'Uživo snimak treba ESP32-CAM modul i streaming server, koji još nisu dio hardvera. Kad se to poveže, ovdje ćeš uparivati kameru i gledati mačku uživo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                              ),
                              const SizedBox(height: 20),
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Razumijem')),
                            ],
                          ),
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.videocam_rounded, color: Colors.black45),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Poveži kameru na hranilicu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                SizedBox(height: 3),
                                Text('Nadgledaj svoju mačku uživo, bilo gdje.', style: TextStyle(fontSize: 11, color: Colors.black45)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(100)),
                            child: const Text('Nije povezano', style: TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.w600)),
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
