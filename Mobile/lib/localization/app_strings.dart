import 'package:flutter/foundation.dart';

class AppStrings {
  static final ValueNotifier<String> locale = ValueNotifier('bs');

  static const Map<String, Map<String, String>> _values = {
    'bs': {
      'device': 'Uređaji', 'care': 'Care', 'services': 'Servisi', 'me': 'Ja',
      'my_cats': 'Moje mačke', 'add': 'Dodaj', 'server_address': 'Adresa servera',
      'notifications': 'Notifikacije', 'notifications_sub': 'Podsjetnici i upozorenja o niskom nivou',
      'about_app': 'O aplikaciji', 'about_app_sub': 'Verzija, licenca, o projektu',
      'language': 'Jezik', 'bosnian': 'Bosanski', 'english': 'Engleski',
      'online': 'Online', 'food': 'Hrana', 'water': 'Voda', 'temperature': 'Temperatura',
      'tap_for_status': 'Dodirni za detaljan status →', 'discover': 'Otkrij',
      'connect_camera': 'Poveži kameru na hranilicu', 'connect_camera_sub': 'Nadgledaj svoju mačku uživo, bilo gdje.',
      'coming_soon': 'Uskoro', 'not_connected': 'Nije povezano',
      'feeding_schedule': 'Raspored hranjenja i evidencija', 'feeding_schedule_sub': 'Podesi automatsko hranjenje i pregledaj historiju',
      'store': 'Prodavnica', 'store_sub': 'Hrana, dodaci i oprema',
      'no_cats_yet': 'Nemaš još nijednu mačku.', 'user': 'Korisnik',
      'dashboard': 'Dashboard', 'care_list': 'Care List', 'overview': 'Pregled', 'edit': 'Uredi',
      'weight': 'Težina', 'food_intake': 'Unos hrane', 'meals': 'Obroci', 'total': 'Ukupno',
      'water_level': 'Nivo vode', 'current': 'Trenutno', 'status': 'Status', 'low': 'Nisko',
      'ok': 'U redu', 'trend_7d': '7-dnevni trend',
    },
    'en': {
      'device': 'Devices', 'care': 'Care', 'services': 'Services', 'me': 'Me',
      'my_cats': 'My Cats', 'add': 'Add', 'server_address': 'Server Address',
      'notifications': 'Notifications', 'notifications_sub': 'Reminders and low-level alerts',
      'about_app': 'About', 'about_app_sub': 'Version, license, about the project',
      'language': 'Language', 'bosnian': 'Bosnian', 'english': 'English',
      'online': 'Online', 'food': 'Food', 'water': 'Water', 'temperature': 'Temperature',
      'tap_for_status': 'Tap for detailed status →', 'discover': 'Discover',
      'connect_camera': 'Connect a camera to the feeder', 'connect_camera_sub': 'Watch your cat live, from anywhere.',
      'coming_soon': 'Coming soon', 'not_connected': 'Not connected',
      'feeding_schedule': 'Feeding schedule & history', 'feeding_schedule_sub': 'Set up automatic feeding and view history',
      'store': 'Store', 'store_sub': 'Food, accessories and equipment',
      'no_cats_yet': "You don't have any cats yet.", 'user': 'User',
      'dashboard': 'Dashboard', 'care_list': 'Care List', 'overview': 'Overview', 'edit': 'Edit',
      'weight': 'Weight', 'food_intake': 'Food intake', 'meals': 'Meals', 'total': 'Total',
      'water_level': 'Water level', 'current': 'Current', 'status': 'Status', 'low': 'Low',
      'ok': 'OK', 'trend_7d': '7-day trend',
    },
  };

  static String t(String key) => _values[locale.value]?[key] ?? _values['bs']![key] ?? key;
}
