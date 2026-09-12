import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/cat.dart';
import '../models/cat_profile.dart';
import '../api_config.dart';

class CatApiService {
  
  // 1. Dobavljanje svih mačaka
  static Future<List<Cat>> getCats() async {
    try {
      final response = await http.get(
        Uri.parse('$defaultBaseUrl/Cats'),
        headers: apiHeaders(),
      );

      if (response.statusCode == 200) {
        final List decoded = json.decode(response.body);
        return decoded.map((jsonItem) => Cat.fromJson(jsonItem)).toList();
      } else {
        debugPrint('Greška pri učitavanju mačaka: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Izuzetak pri učitavanju mačaka: $e');
      return [];
    }
  }

  // 2. Kreiranje nove mačke
  static Future<int?> createCat(String name, CatProfile profile) async {
    try {
      final bodyData = {
        'name': name,
        'sex': profile.gender,
        'breed': profile.breed,
        'weightKg': profile.weightKg,
        'goals': profile.dailyGoalGrams.toString(),
        'age': profile.ageYears,
        'isNeutered': false,
      };

      final response = await http.post(
        Uri.parse('$defaultBaseUrl/Cats'),
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
        return -1; // Uspješno, ali nema ID-ja u odgovoru
      }
      return null;
    } catch (e) {
      debugPrint('Izuzetak pri kreiranju mačke: $e');
      return null;
    }
  }

  // 3. Ažuriranje postojeće mačke
  static Future<bool> updateCat(int catId, String name, CatProfile profile) async {
    try {
      final bodyData = {
        'id': catId,
        'name': name,
        'sex': profile.gender,
        'breed': profile.breed,
        'weightKg': profile.weightKg,
        'goals': profile.dailyGoalGrams.toString(),
        'age': profile.ageYears,
        'isNeutered': false,
      };

      final response = await http.put(
        Uri.parse('$defaultBaseUrl/Cats/$catId'),
        headers: apiHeaders(withJsonBody: true),
        body: json.encode(bodyData),
      );

      debugPrint('UPDATE CAT Response (${response.statusCode}): ${response.body}');

      // Backend obično vraća 204 NoContent ili 200 OK za uspješan update
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Izuzetak pri ažuriranju mačke: $e');
      return false;
    }
  }

  // 4. Dobavljanje profila mačke
  static Future<CatProfile?> getCatProfile(int catId) async {
    try {
      final response = await http.get(
        Uri.parse('$defaultBaseUrl/Cats/$catId'),
        headers: apiHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return CatProfile(
          gender: data['sex'] ?? data['gender'] ?? '',
          breed: data['breed'] ?? '',
          weightKg: (data['weightKg'] as num?)?.toDouble() ?? 0.0,
          dailyGoalGrams: int.tryParse(data['goals']?.toString() ?? '0') ?? 0,
          ageYears: int.tryParse(data['age']?.toString() ?? data['ageYears']?.toString() ?? '0') ?? 0,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Izuzetak pri dobavljanju profila: $e');
      return null;
    }
  }

  // 5. Brisanje mačke
  static Future<bool> deleteCat(int catId) async {
    try {
      final response = await http.delete(
        Uri.parse('$defaultBaseUrl/Cats/$catId'),
        headers: apiHeaders(),
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Izuzetak pri brisanju mačke: $e');
      return false;
    }
  }
}