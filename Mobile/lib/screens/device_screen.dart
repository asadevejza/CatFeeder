import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'status_detail_screen.dart';

// "Uređaji" tab - lista povezanih uređaja. CatFeeder hranilica na vrhu
// (klik vodi na detaljan status), kamera ispod (još nije povezana - hardver
// za to ne postoji, pa je jasno označeno umjesto da lažno glumi da radi).
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: onRefresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: [
                    // --- Header: naslov + zvono + dodaj ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Uređaji', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        Row(
                          children: [
                            _HeaderIconButton(
                              icon: Icons.notifications_none_rounded,
                              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nema novih obavještenja.')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _HeaderIconButton(
                              icon: Icons.add_rounded,
                              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Trenutno je podržana jedna hranilica po nalogu.')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // --- CatFeeder Hranilica ---
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
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.cardBorder),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 6))],
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
                                      const Text('CatFeeder Hranilica', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text('Online', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
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
                              child: Text('Dodirni za detaljan status →', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),
                    const Text('Otkrij', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 10),

                    // --- Kamera (nije povezana - iskreno stanje, čeka hardver) ---
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
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
                                  decoration: BoxDecoration(color: AppColors.tint50, shape: BoxShape.circle),
                                  child: const Icon(Icons.videocam_off_rounded, color: AppColors.primary, size: 30),
                                ),
                                const SizedBox(height: 18),
                                const Text('Kamera nije povezana', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 10),
                                const Text(
                                  'Uživo snimak treba ESP32-CAM modul i streaming server, koji još nisu dio hardvera. Kad se to poveže, ovdje ćeš uparivati kameru i gledati mačku uživo.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                                ),
                                const SizedBox(height: 20),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                  child: const Text('Razumijem'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: AppColors.tint50, borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.videocam_rounded, color: AppColors.primary),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Poveži kameru na hranilicu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
                                  SizedBox(height: 3),
                                  Text('Nadgledaj svoju mačku uživo, bilo gdje.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: AppColors.tint50, borderRadius: BorderRadius.circular(100)),
                              child: const Text('Uskoro', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(icon, color: AppColors.textDark, size: 20),
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
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
