import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

// Čuva sliku svake mačke lokalno na telefonu (Documents folder), van cache-a
// koji sistem može da obriše. Slika se ne šalje na backend — ostaje samo na
// ovom uređaju, isto kao adresa servera u Podešavanjima.
class CatAvatarService {
  static Future<Directory> _avatarDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/cat_avatars');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String?> getAvatarPath(int catId) async {
    final dir = await _avatarDir();
    final file = File('${dir.path}/cat_$catId.jpg');
    if (await file.exists()) return file.path;
    return null;
  }

  static Future<String> setAvatar(int catId, XFile picked) async {
    final dir = await _avatarDir();
    final destPath = '${dir.path}/cat_$catId.jpg';
    final bytes = await picked.readAsBytes();
    await File(destPath).writeAsBytes(bytes, flush: true);
    return destPath;
  }

  static Future<void> removeAvatar(int catId) async {
    final dir = await _avatarDir();
    final file = File('${dir.path}/cat_$catId.jpg');
    if (await file.exists()) await file.delete();
  }
}
