import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

// Koliko grama hrane stane u spremnik — placeholder dok ESP32 ne šalje pravo
// očitavanje nivoa. Slobodno promijeni na stvarni kapacitet tvog spremnika.
const int totalCapacityGrams = 2000;

// Adresa backend servera dok se korisnik ne postavi svoju kroz Podešavanja.
// 10.0.2.2 je specijalna adresa koju Android Emulator koristi za "localhost" računara.
const String defaultBaseUrl = 'http://10.0.2.2:5103/api';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await NotificationService.init();
  runApp(const CatFeederApp());
}

// Čuva/čita adresu backend servera lokalno na telefonu, preživljava restart app-a.
class SettingsService {
  static const _baseUrlKey = 'base_url';

  static Future<String> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
  }

  static Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }
}

// Upravlja lokalnim notifikacijama — podsjetnici za zakazano hranjenje i
// upozorenja kad ponestane hrane/vode. Sve radi lokalno na telefonu, ne
// treba mu internet ni push server.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const AndroidNotificationDetails _scheduleAndroidDetails = AndroidNotificationDetails(
    'feeding_schedule_channel',
    'Podsjetnici za hranjenje',
    channelDescription: 'Podsjeća te kad je vrijeme za zakazano hranjenje',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const AndroidNotificationDetails _alertAndroidDetails = AndroidNotificationDetails(
    'low_level_channel',
    'Upozorenja o nivou',
    channelDescription: 'Upozorava kad ponestane hrane ili vode',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final locationName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(locationName));
    } catch (_) {
      // Ako ne uspije pročitati pravu vremensku zonu uređaja, podsjetnici
      // ostaju na default zoni — rijedak slučaj, ali ne blokira app.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(settings: initSettings);
    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static const Map<String, int> _dayToWeekday = {
    'Monday': DateTime.monday,
    'Tuesday': DateTime.tuesday,
    'Wednesday': DateTime.wednesday,
    'Thursday': DateTime.thursday,
    'Friday': DateTime.friday,
    'Saturday': DateTime.saturday,
    'Sunday': DateTime.sunday,
  };

  // Jedan raspored može imati notifikaciju za više dana — kodiramo scheduleId
  // i dan u sedmici zajedno u jedinstven ID notifikacije.
  static int _idForScheduleDay(int scheduleId, int weekday) => scheduleId * 10 + weekday;

  static Future<void> cancelForSchedule(int scheduleId) async {
    for (int weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(id: _idForScheduleDay(scheduleId, weekday));
    }
  }

  // timeString dolazi u formatu "07:30:00" (isto kako ga backend šalje),
  // daysOfWeekCsv je npr. "Monday,Wednesday,Friday".
  static Future<void> scheduleForFeedingSchedule({
    required int scheduleId,
    required String catName,
    required String timeString,
    required int portionGrams,
    required String daysOfWeekCsv,
  }) async {
    await cancelForSchedule(scheduleId); // prvo ukloni stare termine, pa zakaži nove

    final parts = timeString.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    final days = daysOfWeekCsv.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty);

    for (final day in days) {
      final weekday = _dayToWeekday[day];
      if (weekday == null) continue;

      final scheduledDate = _nextInstanceOfWeekdayTime(weekday, hour, minute);

await _plugin.zonedSchedule(
  id: _idForScheduleDay(scheduleId, weekday),
  notificationDetails: const NotificationDetails(android: _scheduleAndroidDetails),
  title: 'Vrijeme za hranjenje 🐾',
  body: '$catName treba $portionGrams g hrane',
  scheduledDate: scheduledDate,
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
);
    }
  }

  static tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // Fiksni ID po tipu (hrana/voda) — nova poruka zamijeni prethodnu umjesto gomilanja.
  static Future<void> showLowLevelAlert({required bool isFood, required double level}) async {
    final id = isFood ? 900001 : 900002;
    final title = isFood ? 'Ponestaje hrane! 🍽️' : 'Ponestaje vode! 💧';
    final body =
        '${isFood ? "Nivo hrane" : "Nivo vode"} je pao na ${level.toStringAsFixed(0)}%. Vrijeme je da dosuješ.';

 await _plugin.show(
  id: id,
  notificationDetails: const NotificationDetails(android: _alertAndroidDetails),
  title: title,
  body: body,
);
  }
}

// Čuva sliku svake mačke lokalno na telefonu (Documents folder), van cache-a
// koji sistem može da obriše. Slika se ne šalje na backend — ostaje samo na
// ovom uređaju, isto kao adresa servera u Podešavanjima.
class CatAvatarService {
  static Future<Directory> _avatarDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/cat_avatars');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String?> getAvatarPath(int catId) async {
    final dir = await _avatarDir();
    final file = File('${dir.path}/cat_$catId.jpg');
    if (await file.exists()) return file.path;
    return null;
  }

  static Future<String> setAvatar(int catId, XFile picked) async {
    final dir = await _avatarDir();
    final destPath = '${dir.path}/cat_$catId.jpg';
    final bytes = await picked.readAsBytes();
    await File(destPath).writeAsBytes(bytes, flush: true);
    return destPath;
  }

  static Future<void> removeAvatar(int catId) async {
    final dir = await _avatarDir();
    final file = File('${dir.path}/cat_$catId.jpg');
    if (await file.exists()) await file.delete();
  }
}

// ================= MODEL =================
class Cat {
  final int id;
  final String name;
  const Cat({required this.id, required this.name});

  factory Cat.fromJson(Map<String, dynamic> json) =>
      Cat(id: json['id'] as int, name: (json['name'] as String?) ?? 'Mačka');
}

// ================= APP + TEMA =================
class CatFeederApp extends StatelessWidget {
  const CatFeederApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CatFeeder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8F2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        cardTheme: CardThemeData(
          elevation: 3,
          shadowColor: Colors.deepOrange.withOpacity(0.15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: FutureBuilder<String>(
        future: SettingsService.loadBaseUrl(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: Color(0xFFFFF8F2),
              body: Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
            );
          }
          return MainNavigationScreen(initialBaseUrl: snapshot.data!);
        },
      ),
    );
  }
}

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
  double? waterLevel; // null dok ESP32 ne počne slati očitavanja (hardver za vodu još nije spojen)
  double temp = 0.0;
  double humidity = 0.0;
  bool isLoadingDashboard = true;

  List<Cat> cats = [];
  int? selectedCatId;
  bool isLoadingCats = true;

  // Svaki uspješan feed povećava ovaj brojač — animirana mačka to koristi
  // kao okidač da odigra animaciju, čak i ako je "raspoloženje" isto kao prije.
  int feedTrigger = 0;

  // Prati da li je upozorenje o niskom nivou već prikazano, da se ne ponavlja
  // na svaki fetch dok je nivo i dalje nizak — resetuje se kad nivo ponovo poraste.
  bool _foodAlertActive = false;
  bool _waterAlertActive = false;

  @override
  void initState() {
    super.initState();
    baseUrl = widget.initialBaseUrl;
    NotificationService.requestPermissions();
    fetchSensorData();
    fetchCats();
  }

  Future<void> fetchSensorData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/sensorreadings'));
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

  // Prikazuje notifikaciju kad nivo padne ispod 20%, ali samo jednom dok god
  // ostane nizak — čim se popuni iznad 25%, "otključava" se za sljedeći put.
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
      final response = await http.get(Uri.parse('$baseUrl/cats'));
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
      } else {
        setState(() => isLoadingCats = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoadingCats = false);
    }
  }

  Future<bool> addCat(String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cats'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name}),
      );
      if (!mounted) return false;
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchCats();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> editCat(int id, String newName) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/cats/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': id, 'name': newName}),
      );
      if (!mounted) return false;
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchCats();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCat(int id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/cats/$id'));
      if (!mounted) return false;
      if (response.statusCode == 200 || response.statusCode == 204) {
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

  // Poziva se iz ManualFeedingScreen nakon uspješnog POST-a ka /feedinglogs.
  // Lokalno spušta nivo hrane (dok ESP32 ne bude sam slao stvarna očitavanja)
  // i pokreće animaciju sretne mačke.
  void applyLocalFeedEffect(int grams) {
    setState(() {
      final drop = (grams / totalCapacityGrams) * 100;
      foodLevel = (foodLevel - drop).clamp(0, 100);
      feedTrigger++;
    });
  }

  void selectCat(int catId) {
    setState(() => selectedCatId = catId);
  }

  // Poziva se sa Settings ekrana kad korisnik sačuva novu adresu servera.
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
    final screens = [
      DashboardScreen(
        foodLevel: foodLevel,
        waterLevel: waterLevel,
        temp: temp,
        humidity: humidity,
        isLoading: isLoadingDashboard,
        onRefresh: fetchSensorData,
      ),
      ManualFeedingScreen(
        baseUrl: baseUrl,
        cats: cats,
        isLoadingCats: isLoadingCats,
        selectedCatId: selectedCatId,
        feedTrigger: feedTrigger,
        onSelectCat: selectCat,
        onAddCat: addCat,
        onEditCat: editCat,
        onDeleteCat: deleteCat,
        onFedSuccess: applyLocalFeedEffect,
      ),
      SchedulesAndLogsScreen(baseUrl: baseUrl, cats: cats),
      SettingsScreen(currentBaseUrl: baseUrl, onSave: updateBaseUrl),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -3))],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            selectedItemColor: Colors.deepOrange,
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Status'),
              BottomNavigationBarItem(icon: Icon(Icons.pets_rounded), label: 'Hrani'),
              BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Aktivnosti'),
              BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Podešavanja'),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= EKRAN 1: DASHBOARD (SENZORI) =================
class DashboardScreen extends StatelessWidget {
  final double foodLevel;
  final double? waterLevel;
  final double temp;
  final double humidity;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const DashboardScreen({
    super.key,
    required this.foodLevel,
    required this.waterLevel,
    required this.temp,
    required this.humidity,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Status hranilice')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                padding: const EdgeInsets.all(18.0),
                children: [
                  _LevelCard(
                    title: 'Nivo hrane u spremniku',
                    level: foodLevel,
                    color: Colors.deepOrange,
                    lowWarningText: 'Vrijeme je da uspeš hranu u spremnik',
                  ),
                  const SizedBox(height: 16),
                  _LevelCard(
                    title: 'Nivo vode u posudi',
                    level: waterLevel,
                    color: Colors.blue,
                    lowWarningText: 'Vrijeme je da uspeš vodu',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _SensorCard(icon: Icons.thermostat_rounded, color: Colors.redAccent, label: 'Temperatura', value: '${temp.toStringAsFixed(1)}°C')),
                      const SizedBox(width: 14),
                      Expanded(child: _SensorCard(icon: Icons.water_drop_rounded, color: Colors.blue, label: 'Vlažnost zraka', value: '${humidity.toStringAsFixed(1)}%')),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

// Kružna kartica za nivo hrane ili vode. Kad level==null (senzor još nije spojen/ne šalje
// podatke), prikazuje neutralno stanje umjesto lažnog 0%.
class _LevelCard extends StatelessWidget {
  final String title;
  final double? level;
  final Color color;
  final String lowWarningText;

  const _LevelCard({
    required this.title,
    required this.level,
    required this.color,
    required this.lowWarningText,
  });

  @override
  Widget build(BuildContext context) {
    if (level == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Icon(Icons.sensors_off_rounded, color: Colors.grey.shade400, size: 40),
              const SizedBox(height: 8),
              Text('Nema još podataka sa senzora', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final currentLevel = level!;
    final isLow = currentLevel < 20;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: currentLevel / 100),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, _) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 14,
                      strokeCap: StrokeCap.round,
                      backgroundColor: color.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(isLow ? Colors.redAccent : color),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${currentLevel.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(isLow ? 'Ponestaje!' : 'U redu',
                          style: TextStyle(
                            fontSize: 12,
                            color: isLow ? Colors.redAccent : Colors.green,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ],
              ),
            ),
            if (isLow) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 6),
                    Text(lowWarningText,
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _SensorCard({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ================= EKRAN 2: RUČNO HRANJENJE =================
class ManualFeedingScreen extends StatefulWidget {
  final String baseUrl;
  final List<Cat> cats;
  final bool isLoadingCats;
  final int? selectedCatId;
  final int feedTrigger;
  final void Function(int catId) onSelectCat;
  final Future<bool> Function(String name) onAddCat;
  final Future<bool> Function(int id, String newName) onEditCat;
  final Future<bool> Function(int id) onDeleteCat;
  final void Function(int grams) onFedSuccess;

  const ManualFeedingScreen({
    super.key,
    required this.baseUrl,
    required this.cats,
    required this.isLoadingCats,
    required this.selectedCatId,
    required this.feedTrigger,
    required this.onSelectCat,
    required this.onAddCat,
    required this.onEditCat,
    required this.onDeleteCat,
    required this.onFedSuccess,
  });

  @override
  State<ManualFeedingScreen> createState() => _ManualFeedingScreenState();
}

class _ManualFeedingScreenState extends State<ManualFeedingScreen> {
  int selectedPortion = 50;
  bool isFeeding = false;

  // catId -> lokalna putanja do slike na telefonu (samo za mačke koje je imaju)
  Map<int, String> avatarPaths = {};

  @override
  void initState() {
    super.initState();
    loadAvatars();
  }

  @override
  void didUpdateWidget(covariant ManualFeedingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cats.length != widget.cats.length) {
      loadAvatars();
    }
  }

  Future<void> loadAvatars() async {
    final Map<int, String> loaded = {};
    for (final cat in widget.cats) {
      final path = await CatAvatarService.getAvatarPath(cat.id);
      if (path != null) loaded[cat.id] = path;
    }
    if (!mounted) return;
    setState(() => avatarPaths = loaded);
  }

  Future<void> pickAndSetAvatar(Cat cat, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (picked == null) return;

      final path = await CatAvatarService.setAvatar(cat.id, picked);
      if (!mounted) return;
      setState(() => avatarPaths[cat.id] = path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greška pri biranju slike: $e')));
    }
  }

  Future<void> feedCat() async {
    if (widget.selectedCatId == null) return;
    setState(() => isFeeding = true);
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/feedinglogs'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'catId': widget.selectedCatId,
          'portionGrams': selectedPortion,
          'triggeredBy': 'Manual (App)',
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 201 || response.statusCode == 200) {
        widget.onFedSuccess(selectedPortion);
        final catName = widget.cats.firstWhere((c) => c.id == widget.selectedCatId).name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uspješno ispušteno $selectedPortion g hrane za $catName! 🐾')),
        );
      } else {
        throw Exception('Greška na serveru');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Neuspješno povezivanje: $e')),
      );
    } finally {
      if (mounted) setState(() => isFeeding = false);
    }
  }

  Future<void> showAddCatDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nova mačka'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ime mačke, npr. Bella'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Otkaži')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final success = await widget.onAddCat(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '$result je dodana! 🐱' : 'Nije uspjelo dodavanje mačke')),
      );
    }
  }

  Future<void> showManageCatDialog(Cat cat) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(cat.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.deepOrange),
              title: const Text('Slikaj'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.deepOrange),
              title: const Text('Izaberi iz galerije'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.deepOrange),
              title: const Text('Preimenuj'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Obriši mačku'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == 'camera') {
      await pickAndSetAvatar(cat, ImageSource.camera);
      return;
    }
    if (action == 'gallery') {
      await pickAndSetAvatar(cat, ImageSource.gallery);
      return;
    }

    if (!mounted || action == null) return;

    if (action == 'edit') {
      final controller = TextEditingController(text: cat.name);
      final newName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Preimenuj mačku'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Otkaži')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Sačuvaj'),
            ),
          ],
        ),
      );
      if (newName != null && newName.isNotEmpty && mounted) {
        final success = await widget.onEditCat(cat.id, newName);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'Ime promijenjeno! ✏️' : 'Nije uspjelo preimenovanje')),
        );
      }
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Obrisati ${cat.name}?'),
          content: const Text('Ovo će trajno obrisati i cijelu njenu historiju hranjenja i sve rasporede. Ne može se poništiti.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Otkaži')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Obriši', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (confirm == true && mounted) {
        await CatAvatarService.removeAvatar(cat.id);
        final success = await widget.onDeleteCat(cat.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? '${cat.name} je obrisana.' : 'Brisanje nije uspjelo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCats = widget.cats.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Ručno hranjenje')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CatMoodWidget(feedTrigger: widget.feedTrigger),
              const SizedBox(height: 24),

              Row(
                children: [
                  const Text('Izaberi mačku', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: showAddCatDialog,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Dodaj'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (widget.isLoadingCats)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
              else if (!hasCats)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(14)),
                  child: const Text(
                    'Nemaš nijednu mačku još. Klikni "Dodaj" da dodaš prvu.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.cats.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final cat = widget.cats[index];
                      final selected = cat.id == widget.selectedCatId;
                      final avatarPath = avatarPaths[cat.id];
                      return GestureDetector(
                        onTap: () => widget.onSelectCat(cat.id),
                        onLongPress: () => showManageCatDialog(cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 84,
                          decoration: BoxDecoration(
                            color: selected ? Colors.deepOrange : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: selected ? Colors.deepOrange : Colors.orange.shade100, width: 2),
                            boxShadow: selected
                                ? [BoxShadow(color: Colors.deepOrange.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              avatarPath != null
                                  ? CircleAvatar(
                                      radius: 16,
                                      backgroundColor: selected ? Colors.white : Colors.orange.shade50,
                                      backgroundImage: FileImage(File(avatarPath)),
                                    )
                                  : const Text('🐈', style: TextStyle(fontSize: 26)),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  cat.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              if (hasCats) ...[
                const SizedBox(height: 6),
                const Text(
                  'Drži prst na mački za uređivanje ili brisanje',
                  style: TextStyle(color: Colors.black38, fontSize: 11),
                ),
              ],

              const SizedBox(height: 28),
              const Text('Količina obroka', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [50, 100, 150].map((grams) {
                  final selected = selectedPortion == grams;
                  return GestureDetector(
                    onTap: () => setState(() => selectedPortion = grams),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? Colors.deepOrange : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? Colors.deepOrange : Colors.orange.shade100, width: 2),
                      ),
                      child: Text('$grams g',
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: (isFeeding || !hasCats) ? null : feedCat,
                child: isFeeding
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('NAHRANI ODMAH 🐾'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= ANIMIRANA MAČKA =================
class CatMoodWidget extends StatefulWidget {
  final int feedTrigger;
  const CatMoodWidget({super.key, required this.feedTrigger});

  @override
  State<CatMoodWidget> createState() => _CatMoodWidgetState();
}

class _CatMoodWidgetState extends State<CatMoodWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _showHappy = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 0.94).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant CatMoodWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feedTrigger != oldWidget.feedTrigger) {
      _playHappyAnimation();
    }
  }

  void _playHappyAnimation() {
    setState(() => _showHappy = true);
    _controller.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _showHappy = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
        child: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _showHappy
                        ? [Colors.orange.shade300, Colors.orange.shade100]
                        : [Colors.orange.shade100, Colors.orange.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: Colors.deepOrange.withOpacity(0.2), blurRadius: 24, spreadRadius: 2)],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Text(
                      _showHappy ? '😻' : '🐱',
                      key: ValueKey(_showHappy),
                      style: const TextStyle(fontSize: 86),
                    ),
                  ),
                ),
              ),
              if (_showHappy)
                ...List.generate(3, (i) {
                  final interval = Interval((i * 0.15).clamp(0.0, 1.0), (0.75 + i * 0.1).clamp(0.0, 1.0), curve: Curves.easeOut);
                  final anim = CurvedAnimation(parent: _controller, curve: interval);
                  return AnimatedBuilder(
                    animation: anim,
                    builder: (context, _) {
                      final t = anim.value;
                      return Positioned(
                        bottom: 120 + 70 * t,
                        left: 85 + (i - 1) * 34,
                        child: Opacity(
                          opacity: (1 - t).clamp(0.0, 1.0),
                          child: Text('❤️', style: TextStyle(fontSize: 18 - i.toDouble())),
                        ),
                      );
                    },
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= EKRAN 3: RASPORED I LOGOVI =================
class SchedulesAndLogsScreen extends StatefulWidget {
  final String baseUrl;
  final List<Cat> cats;
  const SchedulesAndLogsScreen({super.key, required this.baseUrl, required this.cats});

  @override
  State<SchedulesAndLogsScreen> createState() => _SchedulesAndLogsScreenState();
}

class _SchedulesAndLogsScreenState extends State<SchedulesAndLogsScreen> with SingleTickerProviderStateMixin {
  List<dynamic> logs = [];
  List<dynamic> schedules = [];
  bool isLoading = true;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {})); // za prikaz/skrivanje FAB-a
    loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String catName(dynamic catId) {
    final match = widget.cats.where((c) => c.id == catId);
    return match.isNotEmpty ? match.first.name : 'Nepoznata mačka';
  }

  // Zbraja ukupne grame hrane po danu, za posljednjih 7 dana (uključujući danas).
  // Vraća mapu gdje je ključ ponoć tog dana, poredanu od najstarijeg ka najnovijem.
  Map<DateTime, double> last7DaysTotals() {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(today.year, today.month, today.day).subtract(Duration(days: 6 - i)),
    );
    final totals = {for (final d in days) d: 0.0};

    for (final log in logs) {
      final rawTimestamp = log['timestamp'];
      if (rawTimestamp == null) continue;
      DateTime parsed;
      try {
        parsed = DateTime.parse(rawTimestamp.toString());
      } catch (_) {
        continue;
      }
      final dayKey = DateTime(parsed.year, parsed.month, parsed.day);
      if (totals.containsKey(dayKey)) {
        final grams = (log['portionGrams'] as num?)?.toDouble() ?? 0.0;
        totals[dayKey] = totals[dayKey]! + grams;
      }
    }
    return totals;
  }

  static const Map<String, String> _daysBosanski = {
    'monday': 'Ponedjeljak',
    'mon': 'Pon',
    'tuesday': 'Utorak',
    'tue': 'Uto',
    'tues': 'Uto',
    'wednesday': 'Srijeda',
    'wed': 'Sri',
    'thursday': 'Četvrtak',
    'thu': 'Čet',
    'thurs': 'Čet',
    'friday': 'Petak',
    'fri': 'Pet',
    'saturday': 'Subota',
    'sat': 'Sub',
    'sunday': 'Nedjelja',
    'sun': 'Ned',
  };

  // Prima npr. "Monday,Wednesday,Friday" i vraća "Ponedjeljak, Srijeda, Petak".
  // Ako naiđe na dan koji ne prepozna, samo ga ostavi kako jeste.
  String translateDays(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw
        .split(',')
        .map((d) => d.trim())
        .map((d) => _daysBosanski[d.toLowerCase()] ?? d)
        .join(', ');
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);
    try {
      final logsResponse = await http.get(Uri.parse('${widget.baseUrl}/feedinglogs'));
      final schedulesResponse = await http.get(Uri.parse('${widget.baseUrl}/feedingschedules'));
      if (!mounted) return;

      if (logsResponse.statusCode == 200 && schedulesResponse.statusCode == 200) {
        setState(() {
          logs = json.decode(logsResponse.body).reversed.toList();
          schedules = json.decode(schedulesResponse.body);
          isLoading = false;
        });
        _syncScheduleNotifications();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri čitanju istorije: $e')),
      );
    }
  }

  // Ponovo zakazuje notifikacije za sve trenutne rasporede — poziva se nakon
  // svakog učitavanja da podsjetnici uvijek odgovaraju stanju u bazi (npr. i
  // nakon reinstalacije app-a, kad bi lokalno zakazani alarmi bili izgubljeni).
  Future<void> _syncScheduleNotifications() async {
    for (final schedule in schedules) {
      final id = schedule['id'] as int?;
      if (id == null) continue;
      await NotificationService.scheduleForFeedingSchedule(
        scheduleId: id,
        catName: catName(schedule['catId']),
        timeString: (schedule['time'] as String?) ?? '08:00:00',
        portionGrams: (schedule['portionGrams'] as num?)?.toInt() ?? 0,
        daysOfWeekCsv: (schedule['daysOfWeek'] as String?) ?? '',
      );
    }
  }

  // "07:30:00" -> "07:30"
  String formatTime(dynamic raw) {
    if (raw == null) return '';
    final parts = raw.toString().split(':');
    if (parts.length < 2) return raw.toString();
    return '${parts[0]}:${parts[1]}';
  }

  Future<void> deleteSchedule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Obriši raspored?'),
        content: const Text('Ova akcija se ne može poništiti.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Otkaži')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final response = await http.delete(Uri.parse('${widget.baseUrl}/feedingschedules/$id'));
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        await NotificationService.cancelForSchedule(id);
        loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brisanje nije uspjelo.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greška: $e')));
    }
  }

  Future<void> openScheduleForm({Map<String, dynamic>? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleFormScreen(
          baseUrl: widget.baseUrl,
          cats: widget.cats,
          existingSchedule: existing,
        ),
      ),
    );
    if (saved == true) loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Aktivnosti'),
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(text: 'Historija hranjenja'),
              Tab(text: 'Rasporedi'),
            ],
          ),
        ),
        floatingActionButton: _tabController.index == 1
            ? FloatingActionButton.extended(
                onPressed: () => openScheduleForm(),
                backgroundColor: Colors.deepOrange,
                icon: const Icon(Icons.add),
                label: const Text('Novi raspored'),
              )
            : null,
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  RefreshIndicator(
                    onRefresh: loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: logs.isEmpty ? 2 : logs.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _WeeklyFeedingChart(dailyTotals: last7DaysTotals());
                        }
                        if (logs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: Text('Nema zabilježenih hranjenja.')),
                          );
                        }
                        final log = logs[index - 1];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE8F5E9),
                              child: Icon(Icons.check_circle, color: Colors.green),
                            ),
                            title: Text('${catName(log['catId'])} • ${log['portionGrams']}g',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Pokretač: ${log['triggeredBy']}'),
                            trailing: Text(
                              log['timestamp'] != null ? log['timestamp'].toString().substring(11, 16) : '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: loadData,
                    child: schedules.isEmpty
                        ? ListView(children: const [
                            Padding(padding: EdgeInsets.all(40), child: Center(child: Text('Nema aktivnih rasporeda.')))
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 90),
                            itemCount: schedules.length,
                            itemBuilder: (context, index) {
                              final schedule = schedules[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  onTap: () => openScheduleForm(existing: schedule as Map<String, dynamic>),
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFFFF3E0),
                                    child: Icon(Icons.alarm, color: Colors.deepOrange),
                                  ),
                                  title: Text('${catName(schedule['catId'])} • ${formatTime(schedule['time'])}',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('Količina: ${schedule['portionGrams']}g (${translateDays(schedule['daysOfWeek'] as String?)})'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => deleteSchedule(schedule['id'] as int),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
    );
  }
}

// ================= FORMA ZA DODAVANJE / UREĐIVANJE RASPOREDA =================
class ScheduleFormScreen extends StatefulWidget {
  final String baseUrl;
  final List<Cat> cats;
  final Map<String, dynamic>? existingSchedule; // null = dodavanje novog

  const ScheduleFormScreen({
    super.key,
    required this.baseUrl,
    required this.cats,
    this.existingSchedule,
  });

  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  static const List<Map<String, String>> _dayOptions = [
    {'en': 'Monday', 'bs': 'Pon'},
    {'en': 'Tuesday', 'bs': 'Uto'},
    {'en': 'Wednesday', 'bs': 'Sri'},
    {'en': 'Thursday', 'bs': 'Čet'},
    {'en': 'Friday', 'bs': 'Pet'},
    {'en': 'Saturday', 'bs': 'Sub'},
    {'en': 'Sunday', 'bs': 'Ned'},
  ];

  int? selectedCatId;
  TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
  int selectedPortion = 50;
  final Set<String> selectedDays = {};
  bool isSaving = false;

  bool get isEditMode => widget.existingSchedule != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      final s = widget.existingSchedule!;
      selectedCatId = s['catId'] as int?;
      selectedPortion = (s['portionGrams'] as num?)?.toInt() ?? 50;

      final timeStr = (s['time'] as String?) ?? '08:00:00';
      final parts = timeStr.split(':');
      selectedTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
      );

      final daysStr = (s['daysOfWeek'] as String?) ?? '';
      selectedDays.addAll(daysStr.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty));
    } else if (widget.cats.isNotEmpty) {
      selectedCatId = widget.cats.first.id;
    }
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: selectedTime);
    if (picked != null) setState(() => selectedTime = picked);
  }

  String get _timeAsString {
    final h = selectedTime.hour.toString().padLeft(2, '0');
    final m = selectedTime.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  Future<void> save() async {
    if (selectedCatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izaberi mačku.')));
      return;
    }
    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izaberi bar jedan dan u sedmici.')));
      return;
    }

    setState(() => isSaving = true);

    final body = {
      'catId': selectedCatId,
      'time': _timeAsString,
      'portionGrams': selectedPortion,
      'daysOfWeek': selectedDays.join(','),
      if (isEditMode) 'id': widget.existingSchedule!['id'],
    };

    try {
      final http.Response response;
      if (isEditMode) {
        final id = widget.existingSchedule!['id'];
        response = await http.put(
          Uri.parse('${widget.baseUrl}/feedingschedules/$id'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        );
      } else {
        response = await http.post(
          Uri.parse('${widget.baseUrl}/feedingschedules'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        );
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        Navigator.pop(context, true);
      } else {
        String message = 'Greška pri čuvanju rasporeda.';
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map && decoded['error'] != null) message = decoded['error'].toString();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greška pri povezivanju: $e')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditMode ? 'Uredi raspored' : 'Novi raspored')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Mačka', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (widget.cats.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Nemaš nijednu mačku — dodaj je prvo na ekranu za hranjenje.'),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: widget.cats.map((cat) {
                    final selected = cat.id == selectedCatId;
                    return ChoiceChip(
                      label: Text(cat.name),
                      selected: selected,
                      selectedColor: Colors.deepOrange,
                      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: selected ? Colors.deepOrange : Colors.orange.shade100),
                      ),
                      onSelected: (_) => setState(() => selectedCatId = cat.id),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 26),
              const Text('Vrijeme hranjenja', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              InkWell(
                onTap: pickTime,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.shade100, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: Colors.deepOrange),
                      const SizedBox(width: 12),
                      Text(selectedTime.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 26),
              const Text('Količina obroka', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [50, 100, 150].map((grams) {
                  final selected = selectedPortion == grams;
                  return GestureDetector(
                    onTap: () => setState(() => selectedPortion = grams),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? Colors.deepOrange : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? Colors.deepOrange : Colors.orange.shade100, width: 2),
                      ),
                      child: Text('$grams g',
                          style: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w700)),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 26),
              const Text('Dani u sedmici', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _dayOptions.map((day) {
                  final selected = selectedDays.contains(day['en']);
                  return FilterChip(
                    label: Text(day['bs']!),
                    selected: selected,
                    selectedColor: Colors.deepOrange,
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: selected ? Colors.deepOrange : Colors.orange.shade100),
                    ),
                    onSelected: (isSelected) => setState(() {
                      if (isSelected) {
                        selectedDays.add(day['en']!);
                      } else {
                        selectedDays.remove(day['en']!);
                      }
                    }),
                  );
                }).toList(),
              ),

              const SizedBox(height: 34),
              ElevatedButton(
                onPressed: isSaving ? null : save,
                child: isSaving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(isEditMode ? 'Sačuvaj izmjene' : 'Dodaj raspored'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= EKRAN 4: PODEŠAVANJA =================
class SettingsScreen extends StatefulWidget {
  final String currentBaseUrl;
  final Future<void> Function(String newUrl) onSave;

  const SettingsScreen({super.key, required this.currentBaseUrl, required this.onSave});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;
  bool isSaving = false;
  bool isTesting = false;
  String? testResultMessage;
  bool? testResultSuccess;

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
          .get(Uri.parse('$_cleanedUrl/cats'))
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        testResultSuccess = response.statusCode == 200;
        testResultMessage = response.statusCode == 200
            ? 'Konekcija uspješna! Server odgovara.'
            : 'Server je odgovorio, ali sa greškom (${response.statusCode}).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        testResultSuccess = false;
        testResultMessage = 'Ne mogu da se povežem: $e';
      });
    } finally {
      if (mounted) setState(() => isTesting = false);
    }
  }

  Future<void> save() async {
    if (_cleanedUrl.isEmpty || !_cleanedUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresa mora početi sa http:// ili https://')),
      );
      return;
    }
    setState(() => isSaving = true);
    await widget.onSave(_cleanedUrl);
    if (!mounted) return;
    setState(() => isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Adresa sačuvana i podaci osvježeni. 🐾')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Podešavanja')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Adresa backend servera', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Ovdje app zna gdje da traži tvoj .NET backend.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
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
                    borderSide: BorderSide(color: Colors.orange.shade100, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.orange.shade100, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrange),
                            )
                          : const Icon(Icons.wifi_tethering_rounded, color: Colors.deepOrange),
                      label: const Text('Testiraj konekciju'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepOrange,
                        side: const BorderSide(color: Colors.deepOrange),
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
                    : const Text('Sačuvaj'),
              ),

              const SizedBox(height: 34),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(14)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Koju adresu staviti?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    SizedBox(height: 10),
                    Text('• Android Emulator (testiranje na računaru):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('  http://10.0.2.2:5103/api', style: TextStyle(fontFamily: 'monospace', fontSize: 13)),
                    SizedBox(height: 10),
                    Text('• Pravi telefon, ista WiFi mreža kao računar:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('  http://[LAN IP računara]:5103/api', style: TextStyle(fontFamily: 'monospace', fontSize: 13)),
                    SizedBox(height: 4),
                    Text('  (LAN IP nađeš sa "ipconfig" u terminalu, na primjer 192.168.1.50)',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= GRAFIKON — HRANA POJEDENA PO DANU (7 DANA) =================
class _WeeklyFeedingChart extends StatelessWidget {
  final Map<DateTime, double> dailyTotals;
  const _WeeklyFeedingChart({required this.dailyTotals});

  static const List<String> _dayLabels = ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'];

  @override
  Widget build(BuildContext context) {
    final entries = dailyTotals.entries.toList();
    final maxValue = entries.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b);
    final chartMaxY = maxValue <= 0 ? 100.0 : maxValue * 1.35;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 10, bottom: 18),
              child: Text('Poslednjih 7 dana', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            SizedBox(
              height: 170,
              child: BarChart(
                BarChartData(
                  maxY: chartMaxY,
                  minY: 0,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.deepOrange,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                        '${rod.toY.toStringAsFixed(0)}g',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                          final weekday = entries[index].key.weekday; // 1 = ponedjeljak ... 7 = nedjelja
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_dayLabels[weekday - 1], style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < entries.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: entries[i].value,
                            color: entries[i].value > 0 ? Colors.deepOrange : Colors.orange.shade100,
                            width: 20,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}