import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CareDetailType { none, time, amount }

// Jedna stavka na "Care List" za određenu mačku i dan (npr. "Vrijeme igre"
// u 18:00, ili "Nahrani suhom hranom" - 1/2 šolje). instanceId je jedinstven
// po stavci, tako da isti tip zadatka (npr. hranjenje) može biti dodan
// više puta u istom danu (ujutro i uveče).
class CareItem {
  final String instanceId;
  final String taskId;
  final String title;
  final IconData icon;
  final CareDetailType detailType;
  bool done;
  String? detail;

  CareItem({
    required this.instanceId,
    required this.taskId,
    required this.title,
    required this.icon,
    required this.detailType,
    this.done = false,
    this.detail,
  });

  String get detailHint {
    switch (detailType) {
      case CareDetailType.time:
        return 'Dodirni da dodaš vrijeme';
      case CareDetailType.amount:
        return 'Dodirni da dodaš količinu';
      case CareDetailType.none:
        return '';
    }
  }

  Map<String, dynamic> toJson() => {
        'instanceId': instanceId,
        'taskId': taskId,
        'title': title,
        'icon': icon.codePoint,
        'detailType': detailType.index,
        'done': done,
        'detail': detail,
      };

  factory CareItem.fromJson(Map<String, dynamic> j) => CareItem(
        instanceId: j['instanceId'] as String,
        taskId: j['taskId'] as String,
        title: j['title'] as String,
        icon: IconData(j['icon'] as int, fontFamily: 'MaterialIcons'),
        detailType: CareDetailType.values[(j['detailType'] as int?) ?? 0],
        done: j['done'] as bool? ?? false,
        detail: j['detail'] as String?,
      );
}

class CareTaskTemplate {
  final String taskId;
  final String title;
  final IconData icon;
  final CareDetailType detailType;
  const CareTaskTemplate(this.taskId, this.title, this.icon, this.detailType);
}

// Ponuđeni tipovi zadataka u "+" pikeru za dodavanje nove stavke.
const List<CareTaskTemplate> careTaskTemplates = [
  CareTaskTemplate('play', 'Vrijeme igre', Icons.sports_baseball_rounded, CareDetailType.time),
  CareTaskTemplate('feed', 'Nahrani suhom hranom', Icons.icecream_rounded, CareDetailType.amount),
  CareTaskTemplate('litter', 'Provjeri WC posudu', Icons.cleaning_services_rounded, CareDetailType.none),
  CareTaskTemplate('groom', 'Očetkaj krzno', Icons.brush_rounded, CareDetailType.none),
  CareTaskTemplate('water', 'Provjeri svježu vodu', Icons.water_drop_rounded, CareDetailType.amount),
];

class CareListService {
  static const _prefix = 'care_items_v2';

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _storageKey(int catId, DateTime day) => '${_prefix}_${catId}_${_dateKey(day)}';

  // Vraća stavke za dati dan. Ako ne postoji ništa sačuvano za taj dan,
  // automatski se popuni podrazumijevanom listom zadataka (jednom).
  static Future<List<CareItem>> itemsFor(int catId, DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(catId, day);
    final raw = prefs.getString(key);

    if (raw == null) {
      final defaults = careTaskTemplates
          .map((t) => CareItem(
                instanceId: '${t.taskId}_default',
                taskId: t.taskId,
                title: t.title,
                icon: t.icon,
                detailType: t.detailType,
              ))
          .toList();
      await _save(catId, day, defaults);
      return defaults;
    }

    final List<dynamic> decoded = json.decode(raw);
    return decoded.map((e) => CareItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> _save(int catId, DateTime day, List<CareItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(catId, day);
    await prefs.setString(key, json.encode(items.map((e) => e.toJson()).toList()));
  }

  static Future<List<CareItem>> addItem(int catId, DateTime day, CareTaskTemplate template) async {
    final items = await itemsFor(catId, day);
    items.add(CareItem(
      instanceId: '${template.taskId}_${DateTime.now().microsecondsSinceEpoch}',
      taskId: template.taskId,
      title: template.title,
      icon: template.icon,
      detailType: template.detailType,
    ));
    await _save(catId, day, items);
    return items;
  }

  static Future<List<CareItem>> setDone(int catId, DateTime day, String instanceId, bool value) async {
    final items = await itemsFor(catId, day);
    for (final item in items) {
      if (item.instanceId == instanceId) item.done = value;
    }
    await _save(catId, day, items);
    return items;
  }

  static Future<List<CareItem>> setDetail(int catId, DateTime day, String instanceId, String detail) async {
    final items = await itemsFor(catId, day);
    for (final item in items) {
      if (item.instanceId == instanceId) item.detail = detail;
    }
    await _save(catId, day, items);
    return items;
  }

  static Future<List<CareItem>> removeItem(int catId, DateTime day, String instanceId) async {
    final items = await itemsFor(catId, day);
    items.removeWhere((e) => e.instanceId == instanceId);
    await _save(catId, day, items);
    return items;
  }
}
