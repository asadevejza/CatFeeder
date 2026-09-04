import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';
import 'status_detail_screen.dart';

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
    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.locale,
      builder: (context, _, __) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: onRefresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 28, 18, 24),
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
                                        Text(AppStrings.t('feeder_name'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                            const SizedBox(width: 6),
                                            Text(AppStrings.t('online'), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
                                  Expanded(
                                    child: _MiniStat(
                                      label: AppStrings.t('food'),
                                      value: '${foodLevel.toStringAsFixed(0)}%',
                                      color: foodLevel < 20 ? AppColors.danger : Colors.amber.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _MiniStat(
                                      label: AppStrings.t('water'),
                                      value: waterLevel != null ? '${waterLevel!.toStringAsFixed(0)}%' : '--',
                                      color: (waterLevel != null && waterLevel! < 20) ? AppColors.danger : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: _MiniStat(label: AppStrings.t('temperature'), value: '${temp.toStringAsFixed(0)}°C', color: Colors.redAccent)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(AppStrings.t('tap_for_status'), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
                                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 1.6)),
                                    child: const Icon(Icons.videocam_off_rounded, color: AppColors.primary, size: 30),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(AppStrings.t('camera_not_connected'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 10),
                                  Text(AppStrings.t('camera_explain'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4)),
                                  const SizedBox(height: 20),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                    child: Text(AppStrings.t('understand')),
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
                              // "Okvir" umjesto pune boje - jasno pokazuje da nije aktivno/povezano
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.shade300, width: 1.6),
                                ),
                                child: Icon(Icons.videocam_off_rounded, color: Colors.grey.shade500),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(AppStrings.t('connect_camera'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
                                    const SizedBox(height: 3),
                                    Text(AppStrings.t('connect_camera_sub'), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: AppColors.tint50, borderRadius: BorderRadius.circular(100)),
                                child: Text(AppStrings.t('coming_soon'), style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
                              ),
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
