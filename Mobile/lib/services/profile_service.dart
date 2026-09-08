import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cat_profile.dart';

// Čuva prošireni profil svake mačke (spol, rasa, godine, težina, dnevni
// cilj) lokalno na telefonu — polja koja backend trenutno ne prati.
// Prijava/registracija korisnika je preseljena u AuthService (pravi
// backend nalog sa JWT-om).
class ProfileService {
  static const _catProfilesKey = 'cat_profiles_v1';

  static Future<Map<int, CatProfile>> getAllCatProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_catProfilesKey);
    if (raw == null || raw.isEmpty) return {};
    final Map<String, dynamic> decoded = json.decode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(int.parse(key), CatProfile.fromJson(value as Map<String, dynamic>)));
  }

  static Future<CatProfile?> getCatProfile(int catId) async {
    final all = await getAllCatProfiles();
    return all[catId];
  }

  static Future<void> saveCatProfile(int catId, CatProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAllCatProfiles();
    all[catId] = profile;
    final encoded = json.encode(all.map((key, value) => MapEntry(key.toString(), value.toJson())));
    await prefs.setString(_catProfilesKey, encoded);
  }

  // --- Kamera (uparivanje je samo UI simulacija — nema stvarnog video feeda) ---
  static const _cameraPairedKey = 'camera_paired';
  static const _cameraNameKey = 'camera_name';

  static Future<bool> isCameraPaired() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cameraPairedKey) ?? false;
  }

  static Future<String?> getCameraName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cameraNameKey);
  }

  static Future<void> setCameraPaired(bool paired, {String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cameraPairedKey, paired);
    if (name != null) await prefs.setString(_cameraNameKey, name);
  }

  static Future<void> deleteCatProfile(int catId) async {

    final prefs = await SharedPreferences.getInstance();
    final all = await getAllCatProfiles();
    all.remove(catId);
    final encoded = json.encode(all.map((key, value) => MapEntry(key.toString(), value.toJson())));
    await prefs.setString(_catProfilesKey, encoded);
  }
}
