import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cat_profile.dart';

// Čuva korisnički profil (ime vlasnika) i prošireni profil svake mačke
// (spol, rasa, godine, težina) lokalno na telefonu — sve sa uvodnog
// ekrana (onboarding) prilikom prvog pokretanja aplikacije.
class ProfileService {
  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _ownerNameKey = 'owner_name';
  static const _catProfilesKey = 'cat_profiles_v1';

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  static Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
  }

  static Future<String?> getOwnerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ownerNameKey);
  }

  static Future<void> saveOwnerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ownerNameKey, name);
  }

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
