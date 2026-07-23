import 'dart:io';
import 'package:flutter/material.dart';
import '../models/cat.dart';
import '../services/cat_avatar_service.dart';
import '../services/profile_service.dart';
import 'add_cat_screen.dart';
import 'server_address_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String currentBaseUrl;
  final Future<void> Function(String newUrl) onSave;
  final List<Cat> cats;
  final Future<bool> Function(String name, dynamic profile) onAddCat;

  const SettingsScreen({
    super.key,
    required this.currentBaseUrl,
    required this.onSave,
    required this.cats,
    required this.onAddCat,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _ownerName = '';
  Map<int, String> _avatarPaths = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cats.length != widget.cats.length) _load();
  }

  Future<void> _load() async {
    final name = await ProfileService.getOwnerName();
    final avatars = <int, String>{};
    for (final cat in widget.cats) {
      final path = await CatAvatarService.getAvatarPath(cat.id);
      if (path != null) avatars[cat.id] = path;
    }
    if (!mounted) return;
    setState(() {
      _ownerName = name ?? 'Korisnik';
      _avatarPaths = avatars;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ja'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.lightBlue.shade50,
                        child: const Icon(Icons.person_rounded, color: Colors.lightBlue, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_ownerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('${widget.cats.length} ${widget.cats.length == 1 ? "mačka" : "mačke"}',
                              style: const TextStyle(color: Colors.black45, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('MOJI LJUBIMCI (${widget.cats.length})',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 88,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ...widget.cats.map((cat) {
                          final avatarPath = _avatarPaths[cat.id];
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.lightBlue.shade50,
                                  backgroundImage: avatarPath != null ? FileImage(File(avatarPath)) : null,
                                  child: avatarPath == null ? const Text('🐈', style: TextStyle(fontSize: 22)) : null,
                                ),
                                const SizedBox(height: 6),
                                Text(cat.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddCatScreen(onSave: (name, profile) => widget.onAddCat(name, profile)),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)),
                                child: Icon(Icons.add_rounded, color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 6),
                              Text('Dodaj', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _ProfileListItem(
                    icon: Icons.card_membership_rounded,
                    label: 'Pretplate',
                    subtitle: 'Upravljaj planovima i pretplatama',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Uskoro dostupno.')),
                    ),
                  ),
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
                    icon: Icons.card_giftcard_rounded,
                    label: 'Promocije',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Uskoro dostupno.')),
                    ),
                  ),
                  _ProfileListItem(
                    icon: Icons.feedback_outlined,
                    label: 'Povratne informacije',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Uskoro dostupno.')),
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
