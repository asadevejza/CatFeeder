import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';

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
            ? AppStrings.t('connection_success')
            : '${AppStrings.t('connection_error_status')} (${response.statusCode}).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        testResultSuccess = false;
        testResultMessage = '${AppStrings.t('connection_failed_prefix')}$e';
      });
    } finally {
      if (mounted) setState(() => isTesting = false);
    }
  }

  Future<void> save() async {
    if (_cleanedUrl.isEmpty || !_cleanedUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('server_url_invalid'))),
      );
      return;
    }
    setState(() => isSaving = true);
    await widget.onSave(_cleanedUrl);
    if (!mounted) return;
    setState(() => isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.t('address_saved'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.locale,
      builder: (context, _, __) => Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('server_address'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppStrings.t('backend_address_title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                AppStrings.t('backend_address_sub'),
                style: const TextStyle(color: Colors.black54, fontSize: 13),
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
                    borderSide: BorderSide(color: AppColors.tint100, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.tint100, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.wifi_tethering_rounded, color: AppColors.primary),
                      label: Text(AppStrings.t('test_connection')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
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
                    : Text(AppStrings.t('save')),
              ),

              const SizedBox(height: 20),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => showHelp = !showHelp),
                  icon: Icon(showHelp ? Icons.expand_less_rounded : Icons.help_outline_rounded, size: 18),
                  label: Text(showHelp ? AppStrings.t('hide_help') : AppStrings.t('which_address')),
                  style: TextButton.styleFrom(foregroundColor: Colors.black54),
                ),
              ),

              if (showHelp) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.tint50, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.t('help_emulator_label'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const Text('  http://10.0.2.2:5103/api', style: TextStyle(fontFamily: 'monospace', fontSize: 13)),
                      const SizedBox(height: 10),
                      Text(AppStrings.t('help_real_phone_label'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const Text('  http://[LAN IP računara]:5103/api', style: TextStyle(fontFamily: 'monospace', fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('  ${AppStrings.t('help_lan_ip_note')}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                ),
              ),
              ],
            ],
          ),
        ),
      ),
    ));
  }
}
