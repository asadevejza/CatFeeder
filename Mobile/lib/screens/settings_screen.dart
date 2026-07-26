import 'package:flutter/material.dart';
import 'server_address_screen.dart';

class SettingsScreen extends StatelessWidget {
  final String currentBaseUrl;
  final Future<void> Function(String newUrl) onSave;

  const SettingsScreen({super.key, required this.currentBaseUrl, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ja')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // --- Profil zaglavlje ---
            Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.lightBlue.shade50,
                  child: const Icon(Icons.pets_rounded, color: Colors.lightBlue, size: 32),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CatFeeder', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('IoT hranilica za mačke', style: TextStyle(color: Colors.black45, fontSize: 13)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 30),
            _ProfileListItem(
              icon: Icons.wifi_tethering_rounded,
              label: 'Adresa servera',
              subtitle: currentBaseUrl,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ServerAddressScreen(currentBaseUrl: currentBaseUrl, onSave: onSave),
                ),
              ),
            ),
            _ProfileListItem(
              icon: Icons.notifications_active_outlined,
              label: 'Notifikacije',
              subtitle: 'Podsjetnici i upozorenja o niskom nivou',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Uključene u Android/iOS Settings za ovu app.')),
                );
              },
            ),
            _ProfileListItem(
              icon: Icons.info_outline_rounded,
              label: 'O aplikaciji',
              subtitle: 'Verzija, licenca, o projektu',
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'CatFeeder',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.pets_rounded, color: Colors.lightBlue, size: 32),
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('IoT projekat za automatsko i ručno hranjenje mačaka — ESP32, ASP.NET Core, SQL Server i Flutter.'),
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


class _ProfileListItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _ProfileListItem({required this.icon, required this.label, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.lightBlue.shade50, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.lightBlue, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.black45)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
