import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api_config.dart';

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

  // Sinhronizacija sa backendom pri pokretanju ili učitavanju
  static Future<void> syncWithServer(int catId, String baseUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/Weights/cat/$catId'),
        headers: apiHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> serverLogs = json.decode(response.body);
        final Map<String, double> localData = {};
        for (var log in serverLogs) {
          final dateStr = log['date'].toString().substring(0, 10); // YYYY-MM-DD
          final weight = (log['weightKg'] as num).toDouble();
          localData[dateStr] = weight;
        }
        await _save(catId, localData);
      }
    } catch (_) {
      // Ako nema konekcije, oslanjamo se na lokalni keš
    }
  }

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

  static Future<void> logWeight(int catId, double weightKg, {DateTime? day, String? baseUrl}) async {
    final targetDate = day ?? DateTime.now();
    final data = await _load(catId);
    data[_dateKey(targetDate)] = weightKg;
    await _save(catId, data);

    // Pošalji i na backend ako je proslijeđen baseUrl
    if (baseUrl != null) {
      try {
        await http.post(
          Uri.parse('$baseUrl/Weights'),
          headers: apiHeaders(withJsonBody: true),
          body: json.encode({'catId': catId, 'weightKg': weightKg}),
        );
      } catch (_) {
        // Ignoriši grešku u mreži, sačuvano je lokalno
      }
    }
  }
static Future<void> seedIfEmpty(int catId, double weightKg) async {
    final data = await _load(catId);
    if (data.isEmpty) {
      await logWeight(catId, weightKg);
    }
  }
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