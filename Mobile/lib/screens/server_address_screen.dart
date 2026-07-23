import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class ServerAddressScreen extends StatefulWidget {
  final String currentBaseUrl;
  final Future<void> Function(String newUrl) onSave;

  const ServerAddressScreen({super.key, required this.currentBaseUrl, required this.onSave});

  @override
  State<ServerAddressScreen> createState() => _ServerAddressScreenState();
}


class _ServerAddressScreenState extends State<ServerAddressScreen> {
  late final TextEditingController _controller;
  bool isSaving = false;
  bool isTesting = false;
  String? testResultMessage;
  bool? testResultSuccess;
  bool showHelp = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentBaseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _cleanedUrl {
    var url = _controller.text.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  Future<void> testConnection() async {
    setState(() {
      isTesting = true;
      testResultMessage = null;
    });
    try {
      final response = await http
          .get(Uri.parse('$_cleanedUrl/cats'), headers: apiHeaders())
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        testResultSuccess = response.statusCode == 200;
        testResultMessage = response.statusCode == 200
            ? 'Konekcija uspješna! Server odgovara.'
            : 'Server je odgovorio, ali sa greškom (${response.statusCode}).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        testResultSuccess = false;
        testResultMessage = 'Ne mogu da se povežem: $e';
      });
    } finally {
      if (mounted) setState(() => isTesting = false);
    }
  }

  Future<void> save() async {
    if (_cleanedUrl.isEmpty || !_cleanedUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresa mora početi sa http:// ili https://')),
      );
      return;
    }
    setState(() => isSaving = true);
    await widget.onSave(_cleanedUrl);
    if (!mounted) return;
    setState(() => isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Adresa sačuvana i podaci osvježeni. 🐾')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adresa servera')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Adresa backend servera', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Ovdje app zna gdje da traži tvoj .NET backend.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'http://10.0.2.2:5103/api',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.lightBlue.shade100, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.lightBlue.shade100, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.lightBlue, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isTesting ? null : testConnection,
                      icon: isTesting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.lightBlue),
                            )
                          : const Icon(Icons.wifi_tethering_rounded, color: Colors.lightBlue),
                      label: const Text('Testiraj konekciju'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.lightBlue,
                        side: const BorderSide(color: Colors.lightBlue),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),

              if (testResultMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: testResultSuccess == true ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        testResultSuccess == true ? Icons.check_circle : Icons.error_outline,
                        color: testResultSuccess == true ? Colors.green : Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          testResultMessage!,
                          style: TextStyle(
                            color: testResultSuccess == true ? Colors.green.shade800 : Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: isSaving ? null : save,
                child: isSaving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Sačuvaj'),
              ),

              const SizedBox(height: 20),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => showHelp = !showHelp),
                  icon: Icon(showHelp ? Icons.expand_less_rounded : Icons.help_outline_rounded, size: 18),
                  label: Text(showHelp ? 'Sakrij pomoć' : 'Koju adresu staviti?'),
                  style: TextButton.styleFrom(foregroundColor: Colors.black54),
                ),
              ),

              if (showHelp) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.lightBlue.shade50, borderRadius: BorderRadius.circular(14)),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• Android Emulator (testiranje na računaru):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('  http://10.0.2.2:5103/api', style: TextStyle(fontFamily: 'monospace', fontSize: 13)),
                      SizedBox(height: 10),
                      Text('• Pravi telefon, ista WiFi mreža kao računar:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('  http://[LAN IP računara]:5103/api', style: TextStyle(fontFamily: 'monospace', fontSize: 13)),
                      SizedBox(height: 4),
                      Text('  (LAN IP nađeš sa "ipconfig" u terminalu, na primjer 192.168.1.50)',
                          style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                ),
              ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
