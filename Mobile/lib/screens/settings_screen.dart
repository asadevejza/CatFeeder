import 'dart:io';
import 'package:flutter/material.dart';
import '../models/cat.dart';
import '../services/cat_avatar_service.dart';
import 'server_address_screen.dart';
import 'cat_profile_screen.dart';
import '../theme/app_colors.dart';

// ================= EKRAN 4: "JA" (PROFIL / ME TAB) =================
class SettingsScreen extends StatefulWidget {
  final String currentBaseUrl;
  final Future<void> Function(String newUrl) onSave;
  final List<Cat> cats;
  final VoidCallback onCatsChanged;

  const SettingsScreen({
    super.key,
    required this.currentBaseUrl,
    required this.onSave,
    required this.cats,
    required this.onCatsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<int, String> avatarPaths = {};

  @override
  void initState() {
    super.initState();
    _loadAvatars();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cats.length != widget.cats.length) _loadAvatars();
  }

  Future<void> _loadAvatars() async {
    final Map<int, String> loaded = {};
    for (final cat in widget.cats) {
      final path = await CatAvatarService.getAvatarPath(cat.id);
      if (path != null) loaded[cat.id] = path;
    }
    if (!mounted) return;
    setState(() => avatarPaths = loaded);
  }

  void _openProfile({Cat? cat}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CatProfileScreen(
          baseUrl: widget.currentBaseUrl,
          existingCat: cat,
          onSaved: widget.onCatsChanged,
        ),
      ),
    );
    _loadAvatars();
  }

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
                  backgroundColor: AppColors.tint50,
                  child: const Icon(Icons.pets_rounded, color: AppColors.primary, size: 32),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Moje mačke', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                TextButton.icon(
                  onPressed: () => _openProfile(),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Dodaj'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (widget.cats.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                child: const Text('Nemaš još nijednu mačku.', style: TextStyle(color: Colors.black45)),
              )
            else
              ...widget.cats.map((cat) {
                final avatarPath = avatarPaths[cat.id];
                final age = cat.ageDescription;
                return InkWell(
                  onTap: () => _openProfile(cat: cat),
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
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.tint50,
                          backgroundImage: avatarPath != null ? FileImage(File(avatarPath)) : null,
                          child: avatarPath == null ? const Text('🐈', style: TextStyle(fontSize: 20)) : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              if (age != null || cat.breed != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  [if (age != null) age, if (cat.breed != null) cat.breed!].join(' • '),
                                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 26),
            _ProfileListItem(
              icon: Icons.wifi_tethering_rounded,
              label: 'Adresa servera',
              subtitle: widget.currentBaseUrl,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ServerAddressScreen(currentBaseUrl: widget.currentBaseUrl, onSave: widget.onSave),
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
                applicationIcon: const Icon(Icons.pets_rounded, color: AppColors.primary, size: 32),
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
              decoration: BoxDecoration(color: AppColors.tint50, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.primary, size: 20),
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
