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
import '../localization/app_strings.dart';
import '../models/cat_profile.dart';
import '../theme/app_colors.dart';

import 'device_screen.dart';
import 'care_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';

// ================= GLAVNA NAVIGACIJA + DIJELJENO STANJE =================
class MainNavigationScreen extends StatefulWidget {
  final String initialBaseUrl;
  const MainNavigationScreen({super.key, required this.initialBaseUrl});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  late String baseUrl;

  // --- Dijeljeno stanje, vidljivo svim ekranima ---
  double foodLevel = 100.0;
  double? waterLevel; // null dok ESP32 ne počne slati očitavanja
  double temp = 0.0;
  double humidity = 0.0;
  bool isLoadingDashboard = true;

  List<Cat> cats = [];
  int? selectedCatId;
  bool isLoadingCats = true;

  // Svaki uspješan feed povećava ovaj brojač — animirana mačka to koristi kao okidač
  int feedTrigger = 0;

  // Prati da li je upozorenje o niskom nivou već prikazano
  bool _foodAlertActive = false;
  bool _waterAlertActive = false;

  @override
  void initState() {
    super.initState();
    baseUrl = widget.initialBaseUrl;
    NotificationService.requestPermissions();
    fetchSensorData();
    fetchCats();
    LocaleService.getLocale().then((code) => AppStrings.locale.value = code);
  }

  Future<void> fetchSensorData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/sensorreadings'), headers: apiHeaders());
      if (!mounted) return;
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
          });
          _checkLowLevelAlerts();
        } else {
          setState(() => isLoadingDashboard = false);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoadingDashboard = false);
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
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final loaded = data.map((c) => Cat.fromJson(c as Map<String, dynamic>)).toList();
        setState(() {
          cats = loaded;
          isLoadingCats = false;
          if (selectedCatId == null && loaded.isNotEmpty) {
            selectedCatId = loaded.first.id;
          }
        });
        fetchFeedingSummary();
      } else {
        setState(() => isLoadingCats = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoadingCats = false);
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
          }
        }

        summary[cat.id] = {'lastFed': lastFed, 'todayGrams': todayGrams};
      }

      if (!mounted) return;
      setState(() => feedingSummaryByCat = summary);
    } catch (_) {
      // Tiho ne uspije
    }
  }

  Future<bool> addCat(String name, CatProfile catProfile) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cats'),
        headers: apiHeaders(withJsonBody: true),
        body: json.encode({'name': name}),
      );
      if (response.statusCode != 200 && response.statusCode != 201) return false;
      final created = json.decode(response.body) as Map<String, dynamic>;
      final newCatId = created['id'] as int;
      await ProfileService.saveCatProfile(newCatId, catProfile);
      await fetchCats();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateCat(int catId, String name, CatProfile catProfile) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/cats/$catId'),
        headers: apiHeaders(withJsonBody: true),
        body: json.encode({'name': name}),
      );
      if (response.statusCode != 200 && response.statusCode != 204) return false;
      await ProfileService.saveCatProfile(catId, catProfile);
      await fetchCats();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCat(int id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/cats/$id'), headers: apiHeaders());
      if (!mounted) return false;
      if (response.statusCode == 200 || response.statusCode == 204) {
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

  void applyLocalFeedEffect(int grams) {
    setState(() {
      final drop = (grams / totalCapacityGrams) * 100;
      foodLevel = (foodLevel - drop).clamp(0, 100);
      feedTrigger++;
    });
    fetchFeedingSummary();
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
      ),

      // 3. Services Tab
      ServicesScreen(
        baseUrl: baseUrl,
        cats: cats,
      ),

      // 4. Me Tab
      SettingsScreen(
        baseUrl: baseUrl,
        cats: cats,
        onCatsChanged: fetchCats,
        onAddCat: addCat,
        onUpdateCat: updateCat,
        onDeleteCat: deleteCat,
        onSaveBaseUrl: updateBaseUrl,
      ),
    ];

    return Scaffold(
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
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.devices_rounded),
                label: 'Device',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite_rounded),
                label: 'Care',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded),
                label: 'Services',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Me',
              ),
            ],
          ),
        ),
      ),
    );
  }
}