import 'package:flutter/material.dart';
import '../models/cat.dart';
import 'camera_screen.dart';
import 'manual_feeding_screen.dart';

// Prvi tab: "Device" — lista uređaja (hranilica + kamera), u stilu Petlibro app-a.
class DeviceScreen extends StatelessWidget {
  final double foodLevel;
  final double? waterLevel;
  final double temp;
  final double humidity;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final List<Cat> cats;
  final int? selectedCatId;
  final String baseUrl;
  final int feedTrigger;
  final Future<bool> Function(String name) onAddCat;
  final Future<bool> Function(int id, String newName) onEditCat;
  final Future<bool> Function(int id) onDeleteCat;
  final void Function(int catId) onSelectCat;
  final void Function(int grams) onFedSuccess;

  const DeviceScreen({
    super.key,
    required this.foodLevel,
    required this.waterLevel,
    required this.temp,
    required this.humidity,
    required this.isLoading,
    required this.onRefresh,
    required this.cats,
    required this.selectedCatId,
    required this.baseUrl,
    required this.feedTrigger,
    required this.onAddCat,
    required this.onEditCat,
    required this.onDeleteCat,
    required this.onSelectCat,
    required this.onFedSuccess,
  });

  String get _catName {
    final match = cats.where((c) => c.id == selectedCatId);
    return match.isNotEmpty ? match.first.name : (cats.isNotEmpty ? cats.first.name : 'tvoju mačku');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Uređaji', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  Icon(Icons.notifications_none_rounded, color: Colors.grey.shade500),
                ],
              ),
              const SizedBox(height: 18),
              _FeederDeviceCard(
                isLoading: isLoading,
                foodLevel: foodLevel,
                waterLevel: waterLevel,
                temp: temp,
                humidity: humidity,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManualFeedingScreen(
                      baseUrl: baseUrl,
                      cats: cats,
                      isLoadingCats: false,
                      selectedCatId: selectedCatId,
                      feedTrigger: feedTrigger,
                      onSelectCat: onSelectCat,
                      onAddCat: onAddCat,
                      onEditCat: onEditCat,
                      onDeleteCat: onDeleteCat,
                      onFedSuccess: onFedSuccess,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text('Otkrij', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _CameraDiscoverCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CameraScreen(catName: _catName)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeederDeviceCard extends StatelessWidget {
  final bool isLoading;
  final double foodLevel;
  final double? waterLevel;
  final double temp;
  final double humidity;
  final VoidCallback onTap;

  const _FeederDeviceCard({
    required this.isLoading,
    required this.foodLevel,
    required this.waterLevel,
    required this.temp,
    required this.humidity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = foodLevel < 20 || (waterLevel != null && waterLevel! < 20);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.lightBlue.shade50, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.icecream_rounded, color: Colors.lightBlue, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CatFeeder Hranilica', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: isLoading ? Colors.grey : Colors.green, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Text(isLoading ? 'Povezivanje...' : 'Online',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
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
                Expanded(child: _MiniLevel(label: 'Hrana', value: foodLevel, color: Colors.amber.shade700)),
                const SizedBox(width: 10),
                Expanded(child: _MiniLevel(label: 'Voda', value: waterLevel, color: Colors.lightBlue)),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniStat(icon: Icons.thermostat_rounded, value: '${temp.toStringAsFixed(0)}°C', color: Colors.redAccent),
                ),
              ],
            ),
            if (isLow) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                    SizedBox(width: 6),
                    Text('Nizak nivo — dopuni hranu ili vodu', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Dodirni za ručno hranjenje →', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniLevel extends StatelessWidget {
  final String label;
  final double? value;
  final Color color;
  const _MiniLevel({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(value == null ? '--' : '${value!.toStringAsFixed(0)}%',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _MiniStat({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _CameraDiscoverCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CameraDiscoverCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: const Color(0xFF13202B), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.videocam_rounded, color: Colors.white70, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Poveži kameru na hranilicu', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('Nadgledaj svoju mačku uživo, bilo gdje.', style: TextStyle(fontSize: 12, color: Colors.black45)),
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      Text('Uparivanje', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.w700, fontSize: 13)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, color: Colors.lightBlue, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
