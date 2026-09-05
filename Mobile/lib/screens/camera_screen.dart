import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';

// NAPOMENA: hranilica (ESP32 firmver u ovom projektu) trenutno nema kameru
// niti video stream. Ovaj ekran je UI za uparivanje i prikaz kamere u istom
// stilu kao Petlibro app; kad zaista dodaš kameru na hardver, "Uživo" dio
// treba zamijeniti pravim video widget-om (npr. RTSP/WebRTC stream).
class CameraScreen extends StatefulWidget {
  final String catName;
  const CameraScreen({super.key, required this.catName});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isLoading = true;
  bool _isPaired = false;
  bool _isPairing = false;
  String? _cameraName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final paired = await ProfileService.isCameraPaired();
    final name = await ProfileService.getCameraName();
    if (!mounted) return;
    setState(() {
      _isPaired = paired;
      _cameraName = name;
      _isLoading = false;
    });
  }

  Future<void> _startPairing() async {
    setState(() => _isPairing = true);
    // Simulacija traženja i povezivanja na kameru preko WiFi-ja.
    await Future.delayed(const Duration(seconds: 2));
    final name = AppStrings.t('default_camera_name');
    await ProfileService.setCameraPaired(true, name: name);
    if (!mounted) return;
    setState(() {
      _isPairing = false;
      _isPaired = true;
      _cameraName = name;
    });
  }

  Future<void> _unpair() async {
    await ProfileService.setCameraPaired(false);
    if (!mounted) return;
    setState(() {
      _isPaired = false;
      _cameraName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.locale,
      builder: (context, _, __) => Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('camera_title'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isPaired
              ? _LiveView(catName: widget.catName, cameraName: _cameraName ?? AppStrings.t('default_camera_name'), onUnpair: _unpair)
              : _PairingPrompt(isPairing: _isPairing, onStart: _startPairing),
    ));
  }
}

class _PairingPrompt extends StatelessWidget {
  final bool isPairing;
  final VoidCallback onStart;
  const _PairingPrompt({required this.isPairing, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.tint50, shape: BoxShape.circle),
              child: Icon(
                isPairing ? Icons.wifi_tethering_rounded : Icons.videocam_rounded,
                color: AppColors.primary,
                size: 44,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              isPairing ? AppStrings.t('connecting_camera') : AppStrings.t('pair_camera'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isPairing
                  ? AppStrings.t('check_wifi_range')
                  : AppStrings.t('pair_camera_explain'),
              style: const TextStyle(color: Colors.black54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 26),
            if (isPairing)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: onStart, child: Text(AppStrings.t('start_pairing'))),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveView extends StatelessWidget {
  final String catName;
  final String cameraName;
  final VoidCallback onUnpair;
  const _LiveView({required this.catName, required this.cameraName, required this.onUnpair});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              color: const Color(0xFF13202B),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(Icons.pets_rounded, color: Colors.white24, size: 64),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(AppStrings.t('live_label'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 14,
                    left: 14,
                    child: Text('${AppStrings.t('monitoring_prefix')}$catName', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            AppStrings.t('video_simulation_note'),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.tint50, shape: BoxShape.circle),
                  child: const Icon(Icons.videocam_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cameraName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(AppStrings.t('paired_online'), style: const TextStyle(color: Colors.green, fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(onPressed: onUnpair, child: Text(AppStrings.t('remove'))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
