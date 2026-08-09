import 'dart:io';
import 'package:flutter/material.dart';
import '../models/cat.dart';
import '../models/cat_profile.dart';
import '../services/cat_avatar_service.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import 'server_address_screen.dart';
import 'add_cat_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String baseUrl;
  final List<Cat> cats;
  final VoidCallback onCatsChanged;
  final Future<bool> Function(String name, CatProfile profile) onAddCat;
  final Future<bool> Function(int catId, String name, CatProfile profile) onUpdateCat;
  final Future<bool> Function(int catId) onDeleteCat;
  final Future<void> Function(String newUrl) onSaveBaseUrl;

  const SettingsScreen({
    super.key,
    required this.baseUrl,
    required this.cats,
    required this.onCatsChanged,
    required this.onAddCat,
    required this.onUpdateCat,
    required this.onDeleteCat,
    required this.onSaveBaseUrl,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<int, String> avatarPaths = {};
  Map<int, CatProfile> profiles = {};
  String? ownerName;

  @override
  void initState() {
    super.initState();
    _loadAvatars();
    _loadProfiles();
    _loadOwnerName();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadAvatars();
    _loadProfiles();
  }

  Future<void> _loadOwnerName() async {
    final name = await ProfileService.getOwnerName();
    if (!mounted) return;
    setState(() => ownerName = name);
  }

  Future<void> _loadAvatars() async {
    final loaded = <int, String>{};
    for (final cat in widget.cats) {
      final path = await CatAvatarService.getAvatarPath(cat.id);
      if (path != null) loaded[cat.id] = path;
    }
    if (!mounted) return;
    setState(() => avatarPaths = loaded);
  }

  Future<void> _loadProfiles() async {
    final loaded = await ProfileService.getAllCatProfiles();
    if (!mounted) return;
    setState(() => profiles = loaded);
  }

  void _openAddCat() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => AddCatScreen(onSave: widget.onAddCat)));
    _loadAvatars();
    _loadProfiles();
    widget.onCatsChanged();
  }

  void _openEditCat(Cat cat) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCatScreen(
          onSave: widget.onAddCat,
          existingCat: cat,
          existingProfile: profiles[cat.id],
          onUpdate: widget.onUpdateCat,
          onDelete: () => widget.onDeleteCat(cat.id),
        ),
      ),
    );
    _loadAvatars();
    _loadProfiles();
    widget.onCatsChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 20),
              child: Text('Ja', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: -0.5)),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.tint50,
                  child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 32),
                ),
                const SizedBox(width: 16),
                Text(ownerName?.trim().isNotEmpty == true ? ownerName! : 'Korisnik',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Moje mačke', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                TextButton.icon(
                  onPressed: _openAddCat,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Dodaj'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.cats.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
                child: const Text('Nemaš još nijednu mačku.', style: TextStyle(color: Colors.black45)),
              )
            else
              ...widget.cats.map((cat) {
                final avatarPath = avatarPaths[cat.id];
                final profile = profiles[cat.id];
                final subtitleParts = <String>[
                  if (profile != null) '${profile.ageYears} god.',
                  if (profile != null) profile.breed,
                ];
                return InkWell(
                  onTap: () => _openEditCat(cat),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.cardBorder)),
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
                              if (subtitleParts.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(subtitleParts.join(' • '), style: const TextStyle(fontSize: 12, color: Colors.black45)),
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
              subtitle: widget.baseUrl,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ServerAddressScreen(currentBaseUrl: widget.baseUrl, onSave: widget.onSaveBaseUrl)),
              ),
            ),
            _ProfileListItem(
              icon: Icons.notifications_active_outlined,
              label: 'Notifikacije',
              subtitle: 'Podsjetnici i upozorenja o niskom nivou',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Uključene u Android/iOS Settings za ovu app.')),
              ),
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
                children: const [Padding(padding: EdgeInsets.only(top: 12), child: Text('IoT projekat za automatsko i ručno hranjenje mačaka.'))],
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.cardBorder)),
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
                    Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black45)),
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
