import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class AiInsight {
  final int catId;
  final String catName;
  final DateTime generatedAt;
  final double? averageDailyPortionGrams;
  final double? recommendedDailyPortionGrams;
  final double? lastDayPortionGrams;
  final double? deviationFromAveragePercent;
  final String regularity;
  final List<String> alerts;
  final String summary;

  AiInsight({
    required this.catId, 
    required this.catName,
    required this.generatedAt,
    this.averageDailyPortionGrams,
    this.recommendedDailyPortionGrams,
    this.lastDayPortionGrams,
    this.deviationFromAveragePercent,
    required this.regularity,
    required this.alerts,
    required this.summary,
  });

  factory AiInsight.fromJson(Map<String, dynamic> json) => AiInsight(
        catId: json['catId'] as int,
        catName: json['catName'] as String? ?? '',
        generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ?? DateTime.now(),
        averageDailyPortionGrams: (json['averageDailyPortionGrams'] as num?)?.toDouble(),
        recommendedDailyPortionGrams: (json['recommendedDailyPortionGrams'] as num?)?.toDouble(),
        lastDayPortionGrams: (json['lastDayPortionGrams'] as num?)?.toDouble(),
        deviationFromAveragePercent: (json['deviationFromAveragePercent'] as num?)?.toDouble(),
        regularity: json['regularity'] as String? ?? '',
        alerts: (json['alerts'] as List?)?.map((e) => e.toString()).toList() ?? [],
        summary: json['summary'] as String? ?? '',
      );
}

class AiInsightService {
  static Future<AiInsight?> fetch(String baseUrl, int catId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cats/$catId/insights'),
        headers: apiHeaders(),
      );
      if (response.statusCode == 200) {
        return AiInsight.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {
      // Tiho ignorišemo grešku — kartica se jednostavno ne prikazuje.
    }
    return null;
  }
}