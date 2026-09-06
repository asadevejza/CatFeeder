import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../localization/app_strings.dart';

// Upravlja lokalnim notifikacijama — podsjetnici za zakazano hranjenje i
// upozorenja kad ponestane hrane/vode. Sve radi lokalno na telefonu, ne
// treba mu internet ni push server.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static AndroidNotificationDetails get _scheduleAndroidDetails => AndroidNotificationDetails(
        'feeding_schedule_channel',
        AppStrings.t('notif_schedule_channel_name'),
        channelDescription: AppStrings.t('notif_schedule_channel_desc'),
        importance: Importance.high,
        priority: Priority.high,
      );

  static AndroidNotificationDetails get _alertAndroidDetails => AndroidNotificationDetails(
        'low_level_channel',
        AppStrings.t('notif_alert_channel_name'),
        channelDescription: AppStrings.t('notif_alert_channel_desc'),
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
        title: AppStrings.t('notif_feeding_title'),
        body: '$catName ${AppStrings.t('notif_feeding_body_needs')} $portionGrams g',
        scheduledDate: scheduledDate,
        notificationDetails: NotificationDetails(android: _scheduleAndroidDetails),
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
    final title = isFood ? AppStrings.t('notif_food_low_title') : AppStrings.t('notif_water_low_title');
    final levelWord = isFood ? AppStrings.t('notif_level_food_word') : AppStrings.t('notif_level_water_word');
    final body = '$levelWord ${AppStrings.t('notif_level_body_suffix')} ${level.toStringAsFixed(0)}%. ${AppStrings.t('notif_level_body_action')}';

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: _alertAndroidDetails),
    );
  }
}
