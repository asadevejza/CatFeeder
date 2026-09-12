import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../localization/app_strings.dart';

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
  void _showAboutDialog(bool isEn) {
    showAboutDialog(
      context: context,
      applicationName: 'CatFeeder',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.pets, size: 40, color: AppColors.primary),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 15.0),
          child: Text(
            isEn
                ? 'Smart cat feeder management application.'
                : 'Aplikacija za upravljanje pametnom hranilicom za mačke.',
          ),
        ),
      ],
    );
  }

  void _showNotificationsDialog(bool isEn) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(isEn ? 'Notifications' : 'Notifikacije'),
          ],
        ),
        content: Text(
          isEn
              ? 'Notification settings are enabled. You will receive alerts when food level is low.'
              : 'Notifikacije su uključene. Primat ćete upozorenja kada nivo hrane bude nizak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.locale,
      builder: (context, currentLang, __) {
        final isEn = currentLang == 'en';

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Korisnički profil
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.person, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AuthService.currentUsername ?? 'Korisnik',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              isEn ? 'Welcome back! 👋' : 'Dobrodošao nazad! 👋',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sekcija: Moje mačke
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEn ? 'My Cats' : 'Moje mačke',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      TextButton.icon(
                        onPressed: widget.onAddCat,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(isEn ? 'Add' : 'Dodaj'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ...widget.cats.map((cat) {
                    final catName = (cat is Map) ? (cat['name'] ?? 'Mačka') : (cat.name ?? 'Mačka');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _buildCardTile(
                        icon: Icons.pets,
                        title: catName.toString(),
                        onTap: () => widget.onUpdateCat(cat),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Notifikacije
                  _buildCardTile(
                    icon: Icons.notifications_outlined,
                    title: isEn ? 'Notifications' : 'Notifikacije',
                    subtitle: isEn ? 'Reminders and low level alerts' : 'Podsjetnici i upozorenja o niskom nivou',
                    onTap: () => _showNotificationsDialog(isEn),
                  ),
                  const SizedBox(height: 8),

                  // Promjena jezika
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.language, color: AppColors.primary),
                        const SizedBox(width: 16),
                        Text(
                          isEn ? 'Language' : 'Jezik',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const Spacer(),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'bs', label: Text('BS')),
                            ButtonSegment(value: 'en', label: Text('EN')),
                          ],
                          selected: {AppStrings.locale.value},
                          onSelectionChanged: (Set<String> newSelection) {
                            AppStrings.locale.value = newSelection.first;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // O aplikaciji
                  _buildCardTile(
                    icon: Icons.info_outline,
                    title: isEn ? 'About' : 'O aplikaciji',
                    subtitle: isEn ? 'Version, license, about project' : 'Verzija, licenca, o projektu',
                    onTap: () => _showAboutDialog(isEn),
                  ),
                  const SizedBox(height: 8),

                  // Odjava
                  _buildCardTile(
                    icon: Icons.logout,
                    iconColor: Colors.red,
                    title: isEn ? 'Logout' : 'Odjava',
                    titleColor: Colors.red,
                    onTap: widget.onLogout ?? () {},
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color iconColor = AppColors.primary,
    Color titleColor = Colors.black87,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: titleColor),
        ),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.black26),
        onTap: onTap,
      ),
    );
  }
}