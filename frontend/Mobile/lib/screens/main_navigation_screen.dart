import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/cat.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/cat_avatar_service.dart';
import '../services/locale_service.dart';
import '../services/auth_service.dart';
import '../localization/app_strings.dart';
import '../models/cat_profile.dart';
import '../theme/app_colors.dart';
import '../services/cat_api_service.dart';
import '../widgets/app_logo.dart';

import 'device_screen.dart';
import 'care_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';
import 'modern_screens.dart';
import 'add_cat_screen.dart';
import 'camera_screen.dart';
import 'chat_screen.dart';

// ================= GLAVNA NAVIGACIJA + DIJELJENO STANJE =================
class MainNavigationScreen extends StatefulWidget {
  final String initialBaseUrl;
  final VoidCallback? onLogout;
  const MainNavigationScreen({super.key, required this.initialBaseUrl, this.onLogout});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  late String baseUrl;

  // --- Dijeljeno stanje, vidljivo svim ekranima ---
  double foodLevel = 100.0;
  double? waterLevel;
  double temp = 0.0;
  double humidity = 0.0;
  bool isLoadingDashboard = true;

  List<Cat> cats = [];
  int? selectedCatId;
  bool isLoadingCats = true;

  int feedTrigger = 0;
  bool _foodAlertActive = false;
  bool _waterAlertActive = false;
  bool connectionError = false;

  @override
  void initState() {
    super.initState();
    baseUrl = widget.initialBaseUrl;
    NotificationService.requestPermissions();
    fetchSensorData();
    fetchCats();
    LocaleService.getLocale().then((code) => AppStrings.locale.value = code);
  }

  Future<void> _handleUnauthorized() async {
    await AuthService.logout();
    widget.onLogout?.call();
  }

  Future<void> fetchSensorData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/sensorreadings'), headers: apiHeaders());
      if (!mounted) return;
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lastReading = data.last;
          setState(() {
            foodLevel = (lastReading['foodLevelPercent'] as num).toDouble();
            waterLevel = (lastReading['waterLevelPercent'] as num?)?.toDouble();
            temp = (lastReading['temperature'] as num?)?.toDouble() ?? 0.0;
            humidity = (lastReading['humidity'] as num?)?.toDouble() ?? 0.0;
            isLoadingDashboard = false;
            connectionError = false;
          });
          _checkLowLevelAlerts();
        } else {
          setState(() {
            isLoadingDashboard = false;
            connectionError = false;
          });
        }
      } else {
        setState(() {
          isLoadingDashboard = false;
          connectionError = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoadingDashboard = false;
        connectionError = true;
      });
    }
  }

  void _checkLowLevelAlerts() {
    if (foodLevel < 20 && !_foodAlertActive) {
      _foodAlertActive = true;
      NotificationService.showLowLevelAlert(isFood: true, level: foodLevel);
    } else if (foodLevel >= 25) {
      _foodAlertActive = false;
    }

    final water = waterLevel;
    if (water != null) {
      if (water < 20 && !_waterAlertActive) {
        _waterAlertActive = true;
        NotificationService.showLowLevelAlert(isFood: false, level: water);
      } else if (water >= 25) {
        _waterAlertActive = false;
      }
    }
  }

  Future<void> fetchCats() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/cats'), headers: apiHeaders());
      if (!mounted) return;
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final loaded = data.map((c) => Cat.fromJson(c as Map<String, dynamic>)).toList();
        setState(() {
          cats = loaded;
          isLoadingCats = false;
          connectionError = false;
          if (selectedCatId == null && loaded.isNotEmpty) {
            selectedCatId = loaded.first.id;
          }
        });
        await _hydrateCatProfiles(loaded);
        fetchFeedingSummary();
      } else {
        setState(() {
          isLoadingCats = false;
          connectionError = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoadingCats = false;
        connectionError = true;
      });
    }
  }

  Future<void> _hydrateCatProfiles(List<Cat> loaded) async {
    for (final cat in loaded) {
      final local = await ProfileService.getCatProfile(cat.id);
      final backend = await CatApiService.getCatProfile(baseUrl, cat.id);
      if (backend != null && (local == null || backend.weightKg > 0 || backend.dailyGoalGrams > 0 || backend.breed.isNotEmpty)) {
        await ProfileService.saveCatProfile(cat.id, backend);
      }
    }
  }

  Map<int, Map<String, dynamic>> feedingSummaryByCat = {};

  Future<void> fetchFeedingSummary() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/feedinglogs'), headers: apiHeaders());
      if (!mounted) return;
      if (response.statusCode != 200) return;

      final List<dynamic> allLogs = json.decode(response.body);
      final today = DateTime.now();
      final summary = <int, Map<String, dynamic>>{};

      for (final cat in cats) {
        DateTime? lastFed;
        int todayGrams = 0;
        int mealCount = 0;

        for (final log in allLogs) {
          if (log['catId'] != cat.id) continue;
          final rawTs = log['timestamp'];
          if (rawTs == null) continue;
          DateTime ts;
          try {
            ts = DateTime.parse(rawTs.toString());
          } catch (_) {
            continue;
          }

          if (lastFed == null || ts.isAfter(lastFed)) lastFed = ts;
          if (ts.year == today.year && ts.month == today.month && ts.day == today.day) {
            todayGrams += (log['portionGrams'] as num?)?.toInt() ?? 0;
            mealCount++;
          }
        }

        summary[cat.id] = {'lastFed': lastFed, 'todayGrams': todayGrams, 'mealCount': mealCount};
      }

      if (!mounted) return;
      setState(() => feedingSummaryByCat = summary);
    } catch (_) {}
  }

  Future<bool> feedCatNow(int catId, int portionGrams) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/feedinglogs'),
        headers: apiHeaders(withJsonBody: true),
        body: json.encode({
          'catId': catId,
          'portionGrams': portionGrams,
          'triggeredBy': 'Manual (App)',
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) return false;
      await fetchFeedingSummary();
      await fetchSensorData();
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- KORIŠTENJE CAT API SERVISA ZA ČUVANJE NA SERVER ---
Future<int?> addCat(
  String name,
  CatProfile catProfile,
) async {
  try {
    final newCatId = await CatApiService.createCat(
      baseUrl,
      name,
      catProfile,
    );

    if (newCatId != null) {
      await fetchCats();
      var resolvedId = newCatId > 0 ? newCatId : null;
      if (resolvedId == null) {
        for (final cat in cats) {
          if (cat.name.trim().toLowerCase() == name.trim().toLowerCase()) {
            resolvedId = cat.id;
            break;
          }
        }
      }
      if (resolvedId != null) {
        await ProfileService.saveCatProfile(resolvedId, catProfile);
        return resolvedId;
      }
    }

    return null;
  } catch (e) {
    debugPrint('Greška pri dodavanju mačke: $e');
    return null;
  }
}

 Future<bool> updateCat(
  int catId,
  String name,
  CatProfile catProfile,
) async {
  try {
    final success = await CatApiService.updateCat(
      baseUrl,
      catId,
      name,
      catProfile,
    );

    if (success) {
      // Sačuvaj i lokalni profil
      await ProfileService.saveCatProfile(
        catId,
        catProfile,
      );

      // Osvježi listu mačaka
      await fetchCats();
    }

    return success;
  } catch (e) {
    debugPrint('Greška pri ažuriranju mačke: $e');
    return false;
  }
}

  Future<bool> deleteCat(int id) async {
    try {
      final success = await CatApiService.deleteCat(baseUrl, id);
      if (!mounted) return false;
      if (success) {
        await CatAvatarService.removeAvatar(id);
        await ProfileService.deleteCatProfile(id);
        setState(() {
          if (selectedCatId == id) selectedCatId = null;
        });
        await fetchCats();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // --- HELPER FUNKCIJE ZA OTVARANJE EKRANA ZA DODAVANJE / UREĐIVANJE ---
  void _openAddCatScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCatScreen(
          onSave: (name, profile) async {
            return await addCat(name, profile);
          },
        ),
      ),
    );
    if (result == true || result != null) {
      fetchCats();
    }
  }

  void _openUpdateCatScreen(Cat cat) async {
    // Koristimo ProfileService da pročita lokalno sačuvane podatke za formu
    final catProfileData = await ProfileService.getCatProfile(cat.id);
    
    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCatScreen(
          existingCat: cat,
          existingProfile: catProfileData,
          onSave: (name, profile) async {
            return await addCat(name, profile);
          },
          onUpdate: (catId, name, profile) async {
            return await updateCat(catId, name, profile);
          },
          onDelete: () async {
            return await deleteCat(cat.id);
          },
        ),
      ),
    );
    if (result == true || result != null) {
      fetchCats();
    }
  }

  void selectCat(int catId) {
    setState(() => selectedCatId = catId);
  }

  Future<void> updateBaseUrl(String newUrl) async {
    await SettingsService.saveBaseUrl(newUrl);
    if (!mounted) return;
    setState(() {
      baseUrl = newUrl;
      isLoadingDashboard = true;
      isLoadingCats = true;
    });
    fetchSensorData();
    fetchCats();
  }

  Future<void> _openAiDetection() async {
    if (cats.isEmpty) {
      _openAddCatScreen();
      return;
    }
    final cat = cats.firstWhere((c) => c.id == selectedCatId, orElse: () => cats.first);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CameraScreen(catId: cat.id, catName: cat.name, baseUrl: baseUrl)));
  }

  Future<void> _openAiChat() async {
    if (cats.isEmpty) {
      _openAddCatScreen();
      return;
    }
    final cat = cats.firstWhere((c) => c.id == selectedCatId, orElse: () => cats.first);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(baseUrl: baseUrl, catId: cat.id, catName: cat.name)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedCat = cats.where((c) => c.id == selectedCatId).isNotEmpty
        ? cats.firstWhere((c) => c.id == selectedCatId)
        : (cats.isEmpty ? null : cats.first);

    final screens = [
      ModernHomeScreen(
        foodLevel: foodLevel,
        waterLevel: waterLevel ?? 0,
        temp: temp,
        humidity: humidity,
        loading: isLoadingDashboard,
        connectionError: connectionError,
        cats: cats,
        selectedCatId: selectedCatId,
        summaries: feedingSummaryByCat,
        baseUrl: baseUrl,
        onRefresh: () async {
          await fetchSensorData();
          await fetchFeedingSummary();
        },
        onFeedNow: feedCatNow,
        onProfile: () => setState(() => _selectedIndex = 3),
        onAddCat: _openAddCatScreen,
        onOpenFeeder: () => setState(() => _selectedIndex = 2),
        onOpenDetection: _openAiDetection,
        onOpenChat: _openAiChat,
        onSelectCat: selectCat,
      ),
      ModernStatsScreen(
        food: foodLevel,
        water: waterLevel ?? 0,
        temp: temp,
        humidity: humidity,
        cats: cats,
        selectedCatId: selectedCatId,
        summaries: feedingSummaryByCat,
        baseUrl: baseUrl,
        onSelectCat: selectCat,
      ),
      ModernFeederScreen(
        food: foodLevel,
        water: waterLevel ?? 0,
        cats: cats,
        selectedCatId: selectedCatId,
        onFeedNow: feedCatNow,
        baseUrl: baseUrl,
        onAddCat: _openAddCatScreen,
        onBack: () => setState(() => _selectedIndex = 0),
        onSelectCat: selectCat,
      ),
      ModernProfileScreen(
        cats: cats,
        selectedCatId: selectedCatId,
        onAddCat: _openAddCatScreen,
        onEdit: _openUpdateCatScreen,
        onSelectCat: selectCat,
      ),
      SettingsScreen(
        baseUrl: baseUrl,
        cats: cats,
        onCatsChanged: fetchCats,
        onAddCat: _openAddCatScreen,
        onUpdateCat: (cat) {
          if (cat is Cat) {
            _openUpdateCatScreen(cat);
          } else if (cat is Map<String, dynamic>) {
            _openUpdateCatScreen(Cat.fromJson(cat));
          }
        },
        onDeleteCat: deleteCat,
        onSaveBaseUrl: updateBaseUrl,
        onLogout: widget.onLogout,
      ),
    ];

    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.locale,
      builder: (context, _, __) => Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _selectedIndex, children: screens),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: AppColors.navBackground,
              border: const Border(top: BorderSide(color: AppColors.cardBorder)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.045), blurRadius: 22, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Početna', selected: _selectedIndex == 0, onTap: () => setState(() => _selectedIndex = 0)),
                _NavItem(icon: Icons.insights_rounded, label: 'Statistika', selected: _selectedIndex == 1, onTap: () => setState(() => _selectedIndex = 1)),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = 2),
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: Container(
                        height: 62,
                        width: 62,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.navBackground, width: 5),
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(.22), blurRadius: 18, offset: const Offset(0, 8))],
                        ),
                        child: const Center(child: AppLogo(size: 36, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
                _NavItem(icon: Icons.pets_rounded, label: 'Profil', selected: _selectedIndex == 3, onTap: () => setState(() => _selectedIndex = 3)),
                _NavItem(icon: Icons.settings_rounded, label: 'Postavke', selected: _selectedIndex == 4, onTap: () => setState(() => _selectedIndex = 4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 21, color: selected ? AppColors.primary : AppColors.textMuted),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, fontWeight: selected ? FontWeight.w900 : FontWeight.w600, color: selected ? AppColors.primary : AppColors.textMuted)),
        ]),
      ),
    ),
  );
}
