import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class LastActivity {
  final DateTime? lastFeedingAt;
  final double? hoursSinceLastFeeding;
  final bool isOverdue;

  LastActivity({this.lastFeedingAt, this.hoursSinceLastFeeding, required this.isOverdue});

  factory LastActivity.fromJson(Map<String, dynamic> json) => LastActivity(
        lastFeedingAt: json['lastFeedingAt'] != null
            ? DateTime.parse(json['lastFeedingAt'] as String).toLocal()
            : null,
        hoursSinceLastFeeding: (json['hoursSinceLastFeeding'] as num?)?.toDouble(),
        isOverdue: json['isOverdue'] as bool? ?? false,
      );
}

class ActivityCheckService {
  static Future<LastActivity?> checkLastActivity(String baseUrl, int catId, {double overdueAfterHours = 10}) async {
    try {
      final uri = Uri.parse('$baseUrl/FeedingLogs/cat/$catId/last-activity?overdueAfterHours=$overdueAfterHours');
      final response = await http.get(uri, headers: apiHeaders());

      if (response.statusCode == 200) {
        return LastActivity.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }
}