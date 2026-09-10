import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cat.dart';
import '../models/cat_profile.dart';
import '../api_config.dart'; // Ovdje su ti defaultBaseUrl i apiHeaders

class CatApiService {
  
  // 1. Dobavljanje svih mačaka sa backenda (Railway)
  static Future<List<Cat>> getCats() async {
    final response = await http.get(
      Uri.parse('$defaultBaseUrl/Cats'),
      headers: apiHeaders(),
    );

    if (response.statusCode == 200) {
      final List decoded = json.decode(response.body);
      return decoded.map((jsonItem) => Cat.fromJson(jsonItem)).toList();
    } else {
      throw Exception('Greška pri učitavanju mačaka sa servera.');
    }
  }

  // 2. Kreiranje nove mačke na backendu (šalje sva polja u bazu)
  static Future<int?> createCat(String name, CatProfile profile) async {
    final response = await http.post(
      Uri.parse('$defaultBaseUrl/Cats'),
      headers: apiHeaders(withJsonBody: true),
      body: json.encode({
        'name': name,
        'sex': profile.gender,
        'breed': profile.breed,
        'weightKg': profile.weightKg,
        'goals': profile.dailyGoalGrams.toString(),
        'isNeutered': false, // Možeš dodati u formu ako želiš
      }),
    );

    if (response.statusCode == 201) {
      final decoded = json.decode(response.body);
      return decoded['id']; // Vraća ID generisan na bazi
    }
    return null;
  }

  // 3. Ažuriranje postojeće mačke (KLJUČNO: čuva težinu, rasu i pol u bazu!)
  static Future<bool> updateCat(int catId, String name, CatProfile profile) async {
    final response = await http.put(
      Uri.parse('$defaultBaseUrl/Cats/$catId'),
      headers: apiHeaders(withJsonBody: true),
      body: json.encode({
        'name': name,
        'sex': profile.gender,
        'breed': profile.breed,
        'weightKg': profile.weightKg,
        'goals': profile.dailyGoalGrams.toString(),
        'isNeutered': false,
      }),
    );

    // Backend vraća 204 NoContent kada je update uspješan
    return response.statusCode == 204;
  }

  // 4. Brisanje mačke sa backenda
  static Future<bool> deleteCat(int catId) async {
    final response = await http.delete(
      Uri.parse('$defaultBaseUrl/Cats/$catId'),
      headers: apiHeaders(),
    );

    return response.statusCode == 204;
  }
}