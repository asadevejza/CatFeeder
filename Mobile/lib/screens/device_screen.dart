import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';
import '../models/cat.dart';
import '../services/profile_service.dart';
import 'status_detail_screen.dart';
import 'camera_screen.dart';

class DeviceScreen extends StatefulWidget {
  final double foodLevel;
  final double? waterLevel;
  final double temp;
  final double humidity;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final List<Cat> cats;

  const DeviceScreen({
    super.key,
    required this.foodLevel,
    required this.waterLevel,
    required this.temp,
    required this.humidity,
    required this.isLoading,
    required this.onRefresh,
    required this.cats,
  });

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  bool _isCameraPaired = false;

  @override
  void initState() {
    super.initState();
    _loadCameraState();
  }

  Future<void> _loadCameraState() async {
    final paired = await ProfileService.isCameraPaired();
    if (!mounted) return;
    setState(() => _isCameraPaired = paired);
  }

  Future<void> _openCamera() async {
    final catName = widget.cats.isNotEmpty ? widget.cats.first.name : AppStrings.t('feeder_name');
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CameraScreen(catName: catName)),
    );
    _loadCameraState();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.locale,
      builder: (context, _, __) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: widget.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: widget.onRefresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 28, 18, 24),
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StatusDetailScreen(
                              foodLevel: widget.foodLevel,
                              waterLevel: widget.waterLevel,
                              temp: widget.temp,
                              humidity: widget.humidity,
                              isLoading: widget.isLoading,
                              onRefresh: widget.onRefresh,
                            ),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.primary, AppColors.primaryDark],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.28), blurRadius: 22, offset: const Offset(0, 10))],
                          ),
                          child: Stack(
                            children: [
                              // Dekorativna šapa u pozadini, samo za "wow" efekat
                              Positioned(
                                right: -18,
                                top: -14,
                                child: Icon(Icons.pets_rounded, size: 110, color: Colors.white.withOpacity(0.08)),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(14)),
                                        child: const Icon(Icons.icecream_rounded, color: Colors.white, size: 26),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(AppStrings.t('feeder_name'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF7ED957), shape: BoxShape.circle)),
                                                const SizedBox(width: 6),
                                                Text(AppStrings.t('online'), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MiniStatLight(
                                          icon: Icons.icecream_outlined,
                                          label: AppStrings.t('food'),
                                          value: '${widget.foodLevel.toStringAsFixed(0)}%',
                                          accentColor: widget.foodLevel < 20 ? const Color(0xFFFF8A65) : const Color(0xFFFFD54F),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MiniStatLight(
                                          icon: Icons.water_drop_rounded,
                                          label: AppStrings.t('water'),
                                          value: widget.waterLevel != null ? '${widget.waterLevel!.toStringAsFixed(0)}%' : '--',
                                          accentColor: (widget.waterLevel != null && widget.waterLevel! < 20) ? const Color(0xFFFF8A65) : const Color(0xFF81D4FA),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _MiniStatLight(
                                          icon: Icons.thermostat_rounded,
                                          label: AppStrings.t('temperature'),
                                          value: '${widget.temp.toStringAsFixed(0)}°C',
                                          accentColor: const Color(0xFFFF8A80),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(AppStrings.t('tap_for_status'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(AppStrings.t('discover'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _openCamera,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              // Upareno: puna boja + kamera ikonica. Nije upareno: "okvir" - jasno pokazuje da nije aktivno/povezano.
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _isCameraPaired ? AppColors.tint50 : null,
                                  borderRadius: BorderRadius.circular(14),
                                  border: _isCameraPaired ? null : Border.all(color: Colors.grey.shade300, width: 1.6),
                                ),
                                child: Icon(
                                  _isCameraPaired ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                                  color: _isCameraPaired ? AppColors.primary : Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isCameraPaired ? AppStrings.t('camera_connected') : AppStrings.t('connect_camera'),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _isCameraPaired ? AppStrings.t('paired_online') : AppStrings.t('connect_camera_sub'),
                                      style: TextStyle(fontSize: 11, color: _isCameraPaired ? Colors.green : AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_isCameraPaired)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: AppColors.tint50, borderRadius: BorderRadius.circular(100)),
                                  child: Text(AppStrings.t('not_connected'), style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
                                )
                              else
                                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _MiniStatLight extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  const _MiniStatLight({required this.icon, required this.label, required this.value, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }
}
