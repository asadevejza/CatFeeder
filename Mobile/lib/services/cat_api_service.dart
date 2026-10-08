import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/cat.dart';
import '../models/cat_profile.dart';
import '../api_config.dart';

class CatApiService {
  
  // 1. Dobavljanje svih mačaka
  static Future<List<Cat>> getCats(String baseUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/Cats'),
        headers: apiHeaders(),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List list = decoded is List ? decoded : (decoded['items'] ?? decoded['data'] ?? const []);
        return list.map((jsonItem) => Cat.fromJson(Map<String, dynamic>.from(jsonItem as Map))).toList();
      } else {
        debugPrint('Greška pri učitavanju mačaka: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Izuzetak pri učitavanju mačaka: $e');
      return [];
    }
  }

  // Pomoćna funkcija za pretvaranje godina u približan BirthDate za C# backend
static DateTime _calculateBirthDate(int ageYears) {
  final now = DateTime.now().toUtc();
  return DateTime.utc(now.year - (ageYears > 0 ? ageYears : 0), now.month, now.day);
}

  // Pomoćna funkcija za izračunavanje godina iz BirthDate stringa
  static int _calculateAgeFromBirthDate(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return 0;
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final now = DateTime.now();
      int age = now.year - birthDate.year;
      if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      return age < 0 ? 0 : age;
    } catch (_) {
      return 0;
    }
  }

  static String _apiGender(String gender) => gender.toLowerCase().contains('žen') || gender.toLowerCase().contains('female') ? 'Female' : 'Male';

static String _localGender(dynamic gender) {
  final str = gender?.toString().toLowerCase();
  if (str != null && (str.contains('female') || str.contains('žen'))) {
    return 'Ženka';
  }
  return 'Mužjak';
}

  // 2. Kreiranje nove mačke
  static Future<int?> createCat(String baseUrl, String name, CatProfile profile) async {
    try {
      final bodyData = {
        'name': name,
        'sex': _apiGender(profile.gender),
        'breed': profile.breed,
        'weightKg': profile.weightKg,
        'goals': profile.dailyGoalGrams.toString(),
        'birthDate': _calculateBirthDate(profile.ageYears).toIso8601String(),
        'isNeutered': false,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/Cats'),
        headers: apiHeaders(withJsonBody: true),
        body: json.encode(bodyData),
      );

      debugPrint('CREATE CAT Response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.isNotEmpty) {
          final decoded = json.decode(response.body);
          if (decoded is Map && decoded.containsKey('id')) {
            return decoded['id'];
          }
        }
        return -1;
      }
      return null;
    } catch (e) {
      debugPrint('Izuzetak pri kreiranju mačke: $e');
      return null;
    }
  }

  // 3. Ažuriranje postojeće mačke
 static Future<bool> updateCat(
  String baseUrl,
  int catId,
  String name,
  CatProfile profile,
) async {
  try {
    final bodyData = {
      'name': name,
      'rfidTag': null,
      'sex': _apiGender(profile.gender),
      'birthDate': _calculateBirthDate(profile.ageYears).toIso8601String(),
      'breed': profile.breed,
      'isNeutered': false,
      'weightKg': profile.weightKg,
      'personality': null,
      'goals': profile.dailyGoalGrams.toString(),
    };

    final response = await http.put(
      Uri.parse('$baseUrl/Cats/$catId'),
      headers: apiHeaders(withJsonBody: true),
      body: json.encode(bodyData),
    );

    debugPrint('UPDATE CAT URL: ${response.request?.url}');
    debugPrint('UPDATE CAT BODY: ${json.encode(bodyData)}');
    debugPrint('UPDATE CAT STATUS: ${response.statusCode}');
    debugPrint('UPDATE CAT RESPONSE: ${response.body}');

    return response.statusCode == 200 || response.statusCode == 204;
  } catch (e) {
    debugPrint('UPDATE CAT EXCEPTION: $e');
    return false;
  }
}
  // 4. Dobavljanje profila mačke
  static Future<CatProfile?> getCatProfile(String baseUrl, int catId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/Cats/$catId'), headers: apiHeaders());
      if (response.statusCode != 200) return null;
      final raw = json.decode(response.body);
      final data = Map<String, dynamic>.from(raw is Map && raw['data'] is Map ? raw['data'] : raw as Map);
      dynamic v(String key) => data[key] ?? data[key[0].toUpperCase() + key.substring(1)];
      final birth = v('birthDate')?.toString();
      final weight = (v('weightKg') as num?)?.toDouble() ?? 0.0;
      final goalsRaw = v('goals') ?? v('dailyGoalGrams') ?? v('dailyGoal');
      final goals = goalsRaw is num ? goalsRaw.toInt() : int.tryParse(goalsRaw?.toString() ?? '') ?? 0;
      return CatProfile(
        gender: _localGender(v('sex') ?? v('gender')),
        breed: v('breed')?.toString() ?? '',
        weightKg: weight,
        dailyGoalGrams: goals,
        ageYears: _calculateAgeFromBirthDate(birth),
      );
    } catch (e) {
      debugPrint('Izuzetak pri dobavljanju profila: $e');
      return null;
    }
  }

  // 5. Brisanje mačke
  static Future<bool> deleteCat(String baseUrl, int catId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/Cats/$catId'),
        headers: apiHeaders(),
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Izuzetak pri brisanju mačke: $e');
      return false;
    }
  }
}