import 'dart:io';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/cat_avatar_service.dart';
import '../services/profile_service.dart';
import '../models/cat.dart';
import '../models/cat_profile.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';
import 'server_address_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String baseUrl;
  final List<dynamic> cats;
  final VoidCallback onCatsChanged;
  final VoidCallback onAddCat;
  final Function(dynamic) onUpdateCat;
  final Function onDeleteCat;
  final Function(String) onSaveBaseUrl;
  final VoidCallback? onLogout;

  const SettingsScreen({
    super.key,
    required this.baseUrl,
    required this.cats,
    required this.onCatsChanged,
    required this.onAddCat,
    required this.onUpdateCat,
    required this.onDeleteCat,
    required this.onSaveBaseUrl,
    this.onLogout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<int, String> avatarPaths = {};
  Map<int, CatProfile> profiles = {};

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    final avatars = <int, String>{};
    final loadedProfiles = await ProfileService.getAllCatProfiles();
    for (final cat in widget.cats) {
      final id = cat is Cat ? cat.id : (cat is Map ? cat['id'] as int : null);
      if (id == null) continue;
      final path = await CatAvatarService.getAvatarPath(id);
      if (path != null) avatars[id] = path;
    }
    if (!mounted) return;
    setState(() {
      avatarPaths = avatars;
      profiles = loadedProfiles;
    });
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.t('logout_confirm_title')),
        content: Text(AppStrings.t('logout_confirm_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.t('logout'), style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService.logout();
      widget.onLogout?.call();
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primaryLight, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.pets_rounded, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 18),
              const Text('CatFeeder', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${AppStrings.t('version_label')} 1.0.0', style: const TextStyle(fontSize: 12, color: Colors.black45)),
              const SizedBox(height: 16),
              Text(AppStrings.t('about_app_body'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: Colors.black54, height: 1.4)),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppStrings.t('close_button')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(AppStrings.t('notifications')),
          ],
        ),
        content: Text(AppStrings.t('notifications_info')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppStrings.t('close_button'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.locale,
      builder: (context, _, __) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            children: [
              const SizedBox(height: 12),
              // ================= HERO HEADER =================
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.28), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AuthService.currentUsername?.trim().isNotEmpty == true ? AuthService.currentUsername! : AppStrings.t('user'),
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(AppStrings.t('welcome_back'), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // ================= MOJE MAČKE =================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppStrings.t('my_cats'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  TextButton.icon(
                    onPressed: widget.onAddCat,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(AppStrings.t('add')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (widget.cats.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(AppStrings.t('no_cats_yet'), style: const TextStyle(color: Colors.black45)),
                )
              else
                ...widget.cats.map((cat) {
                  final id = cat is Cat ? cat.id : (cat is Map ? cat['id'] as int : 0);
                  final name = cat is Cat ? cat.name : (cat is Map ? (cat['name']?.toString() ?? '') : '');
                  final avatarPath = avatarPaths[id];
                  final profile = profiles[id];
                  final subtitleParts = <String>[
                    if (profile != null) '${profile.ageYears} ${AppStrings.t('years_suffix')}',
                    if (profile != null) profile.breed,
                  ];
                  return InkWell(
                    onTap: () => widget.onUpdateCat(cat),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [AppColors.gold.withOpacity(0.7), AppColors.gold], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            ),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.tint50,
                              backgroundImage: avatarPath != null ? FileImage(File(avatarPath)) : null,
                              child: avatarPath == null ? const Text('🐈', style: TextStyle(fontSize: 20)) : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                if (subtitleParts.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(subtitleParts.join(' · '), style: const TextStyle(fontSize: 12, color: Colors.black45)),
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
              const SizedBox(height: 24),

              // ================= SERVER / NOTIFIKACIJE / JEZIK / O APLIKACIJI =================
              _ProfileListItem(
                icon: Icons.wifi_tethering_rounded,
                label: AppStrings.t('server_address'),
                subtitle: widget.baseUrl,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ServerAddressScreen(
                      currentBaseUrl: widget.baseUrl,
                      onSave: (newUrl) async => widget.onSaveBaseUrl(newUrl),
                    ),
                  ),
                ),
              ),
              _ProfileListItem(
                icon: Icons.notifications_outlined,
                label: AppStrings.t('notifications'),
                subtitle: AppStrings.t('notifications_sub'),
                onTap: _showNotificationsDialog,
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.primaryLight, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.language_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(AppStrings.t('language'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                    _LangPill(label: 'BS', selected: AppStrings.locale.value == 'bs', onTap: () => AppStrings.locale.value = 'bs'),
                    const SizedBox(width: 8),
                    _LangPill(label: 'EN', selected: AppStrings.locale.value == 'en', onTap: () => AppStrings.locale.value = 'en'),
                  ],
                ),
              ),
              _ProfileListItem(
                icon: Icons.info_outline_rounded,
                label: AppStrings.t('about_app'),
                subtitle: AppStrings.t('about_app_sub'),
                onTap: _showAboutDialog,
              ),
              if (widget.onLogout != null) ...[
                const SizedBox(height: 10),
                _ProfileListItem(
                  icon: Icons.logout_rounded,
                  label: AppStrings.t('logout'),
                  iconColor: Colors.redAccent,
                  onTap: _confirmLogout,
                ),
              ],
            ],
          ),
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
  final Color? iconColor;
  const _ProfileListItem({required this.icon, required this.label, this.subtitle, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withOpacity(0.85), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
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

class _LangPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.tint50,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    );
  }
}
