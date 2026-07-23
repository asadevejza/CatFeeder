import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Čuva koje stavke na "Care List" (Play Time, Check Litter Box, itd) su
// obilježene kao završene za određeni dan i određenu mačku. Ključ je
// 'catId_yyyy-MM-dd_taskId'.
class CareListService {
  static const _key = 'care_list_done_v1';

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<Set<String>> _loadDone() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    return raw?.toSet() ?? <String>{};
  }

  static Future<void> _saveDone(Set<String> done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, done.toList());
  }

  static Future<bool> isDone(int catId, DateTime day, String taskId) async {
    final done = await _loadDone();
    return done.contains('${catId}_${_dateKey(day)}_$taskId');
  }

  static Future<Set<String>> doneTasksFor(int catId, DateTime day) async {
    final done = await _loadDone();
    final prefix = '${catId}_${_dateKey(day)}_';
    return done.where((e) => e.startsWith(prefix)).map((e) => e.substring(prefix.length)).toSet();
  }

  static Future<void> setDone(int catId, DateTime day, String taskId, bool value) async {
    final done = await _loadDone();
    final entry = '${catId}_${_dateKey(day)}_$taskId';
    if (value) {
      done.add(entry);
    } else {
      done.remove(entry);
    }
    await _saveDone(done);
  }
}
