import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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
        title: 'Vrijeme za hranjenje 🐾',
        body: '$catName treba $portionGrams g hrane',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(android: _scheduleAndroidDetails),
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
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: _alertAndroidDetails),
    );
  }
}
