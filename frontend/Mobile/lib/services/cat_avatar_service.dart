import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class CatAvatarService {
  static String _key(int catId) => 'cat_avatar_b64_$catId';

  static Future<Uint8List?> getAvatarBytes(int catId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(catId));
    if (raw == null || raw.isEmpty) return null;
    try { return Uint8List.fromList(base64Decode(raw)); } catch (_) { return null; }
  }

  static Future<String?> getAvatarPath(int catId) async => null;

  static Future<String> setAvatar(int catId, XFile picked) async {
    final bytes = await picked.readAsBytes();
    await setAvatarBytes(catId, bytes);
    return picked.path;
  }

  static Future<void> setAvatarBytes(int catId, Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(catId), base64Encode(bytes));
  }

  static Future<void> removeAvatar(int catId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(catId));
  }
}
