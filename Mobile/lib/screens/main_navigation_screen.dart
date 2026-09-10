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

import 'device_screen.dart';
import 'care_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';
import 'add_cat_screen.dart';

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
  Future<int?> addCat(String name, CatProfile catProfile) async {
    try {
      final newCatId = await CatApiService.createCat(name, catProfile);
      if (newCatId != null) {
        await fetchCats();
      }
      return newCatId;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateCat(int catId, String name, CatProfile catProfile) async {
    try {
      final success = await CatApiService.updateCat(catId, name, catProfile);
      if (success) {
        await fetchCats();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCat(int id) async {
    try {
      final success = await CatApiService.deleteCat(id);
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      // 1. Device Tab
      DeviceScreen(
        foodLevel: foodLevel,
        waterLevel: waterLevel,
        temp: temp,
        humidity: humidity,
        isLoading: isLoadingDashboard,
        cats: cats,
        connectionError: connectionError,
        baseUrl: baseUrl,
        onSaveBaseUrl: updateBaseUrl,
        onRefresh: () async {
          await fetchSensorData();
          await fetchFeedingSummary();
        },
      ),

      // 2. Care Tab
      CareScreen(
        baseUrl: baseUrl,
        cats: cats,
        waterLevel: waterLevel,
        selectedCatId: selectedCatId,
        onSelectCat: selectCat,
        feedingSummaryByCat: feedingSummaryByCat,
        onAddCat: addCat,
        onUpdateCat: updateCat,
        onFeedNow: feedCatNow,
      ),

      // 3. Services Tab
      ServicesScreen(
        baseUrl: baseUrl,
        cats: cats,
      ),

      // 4. Me Tab (SettingsScreen)
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
        body: screens[_selectedIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              selectedItemColor: AppColors.primary,
              unselectedItemColor: Colors.grey,
              backgroundColor: Colors.white,
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.devices_rounded),
                  activeIcon: const _ActiveNavIcon(icon: Icons.devices_rounded),
                  label: AppStrings.t('device'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.favorite_rounded),
                  activeIcon: const _ActiveNavIcon(icon: Icons.favorite_rounded),
                  label: AppStrings.t('care'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.grid_view_rounded),
                  activeIcon: const _ActiveNavIcon(icon: Icons.grid_view_rounded),
                  label: AppStrings.t('services'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_rounded),
                  activeIcon: const _ActiveNavIcon(icon: Icons.person_rounded),
                  label: AppStrings.t('me'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveNavIcon extends StatelessWidget {
  final IconData icon;
  const _ActiveNavIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: AppColors.tint50, borderRadius: BorderRadius.circular(100)),
      child: Icon(icon, color: AppColors.primary),
    );
  }
}