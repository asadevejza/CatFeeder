import 'package:flutter/material.dart';
import '../services/profile_service.dart';

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
    await ProfileService.setCameraPaired(true, name: 'Kamera hranilice');
    if (!mounted) return;
    setState(() {
      _isPairing = false;
      _isPaired = true;
      _cameraName = 'Kamera hranilice';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Kamera')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isPaired
              ? _LiveView(catName: widget.catName, cameraName: _cameraName ?? 'Kamera hranilice', onUnpair: _unpair)
              : _PairingPrompt(isPairing: _isPairing, onStart: _startPairing),
    );
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
              decoration: BoxDecoration(color: Colors.lightBlue.shade50, shape: BoxShape.circle),
              child: Icon(
                isPairing ? Icons.wifi_tethering_rounded : Icons.videocam_rounded,
                color: Colors.lightBlue,
                size: 44,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              isPairing ? 'Povezivanje sa kamerom...' : 'Poveži kameru na hranilicu',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isPairing
                  ? 'Provjeri da je kamera u dometu WiFi mreže.'
                  : 'Uključi kameru na hranilici i pritisni dugme ispod da je upariš i počneš da nadgledaš svoju mačku uživo.',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 26),
            if (isPairing)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: onStart, child: const Text('Započni uparivanje')),
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
                        const Text('UŽIVO', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 14,
                    left: 14,
                    child: Text('Nadgledanje: $catName', style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
            'Video prikaz je trenutno simulacija — poveži pravi video stream kad hardver kamere bude spreman.',
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
                  decoration: BoxDecoration(color: Colors.lightBlue.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.videocam_rounded, color: Colors.lightBlue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cameraName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Text('Upareno • Online', style: TextStyle(color: Colors.green, fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(onPressed: onUnpair, child: const Text('Ukloni')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
