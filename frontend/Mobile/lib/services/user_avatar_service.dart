import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class UserAvatarService {
  static const _key = 'user_avatar_b64';

  static Future<Uint8List?> getAvatarBytes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try { return Uint8List.fromList(base64Decode(raw)); } catch (_) { return null; }
  }

  static Future<String?> getAvatarPath() async => null;

  static Future<String> setAvatar(XFile picked) async {
    final bytes = await picked.readAsBytes();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, base64Encode(bytes));
    return picked.path;
  }

  static Future<void> removeAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
