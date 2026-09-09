import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Čuva historiju težine (datum -> kg) po mački lokalno na telefonu.
class WeightHistoryService {
  static const _keyPrefix = 'weight_history_';

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<Map<String, double>> _load(int catId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$catId');
    if (raw == null || raw.isEmpty) return {};
    final Map<String, dynamic> decoded = json.decode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  static Future<void> _save(int catId, Map<String, double> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$catId', json.encode(data));
  }

  // Vraća zadnjih [days] dana (uključujući danas), sortirano hronološki.
  static Future<List<MapEntry<DateTime, double?>>> lastDays(int catId, int days) async {
    final data = await _load(catId);
    final today = DateTime.now();
    final result = <MapEntry<DateTime, double?>>[];
    for (int i = days - 1; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      result.add(MapEntry(day, data[_dateKey(day)]));
    }
    return result;
  }

  static Future<void> logWeight(int catId, double weightKg, {DateTime? day}) async {
    final data = await _load(catId);
    data[_dateKey(day ?? DateTime.now())] = weightKg;
    await _save(catId, data);
  }

  static Future<void> seedIfEmpty(int catId, double weightKg) async {
    final data = await _load(catId);
    if (data.isEmpty) {
      await logWeight(catId, weightKg);
    }
  }

  // Vraća najnoviju težinu:
  // 1. Ako postoji unos za danas -> vrati njega.
  // 2. Ako nema za danas, ali ima u historiji -> vrati zadnji unijeti.
  // 3. Ako je historija potpuno prazna -> zabilježi fallbackWeight (s backenda) i vrati ga.
  static Future<double?> getLatestWeight(int catId, double? fallbackWeight) async {
    final data = await _load(catId);

    final todayKey = _dateKey(DateTime.now());
    if (data.containsKey(todayKey)) {
      return data[todayKey];
    }

    if (data.isNotEmpty) {
      return data.values.last;
    }

    if (fallbackWeight != null && fallbackWeight > 0) {
      await logWeight(catId, fallbackWeight);
      return fallbackWeight;
    }

    return null;
  }
}