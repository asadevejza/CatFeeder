import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class CatDetectionResult {
  final bool catDetected;
  final double confidence;
  final String label;
  final bool autoFed;
  final double? portionGrams;

  CatDetectionResult({
    required this.catDetected,
    required this.confidence,
    required this.label,
    this.autoFed = false,
    this.portionGrams,
  });

  factory CatDetectionResult.fromJson(Map<String, dynamic> json) => CatDetectionResult(
        catDetected: json['catDetected'] as bool? ?? false,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        label: json['label'] as String? ?? '',
        autoFed: json['autoFed'] as bool? ?? false,
        portionGrams: (json['portionGrams'] as num?)?.toDouble(),
      );
}

class DetectionLogEntry {
  final int id;
  final bool catDetected;
  final double confidence;
  final String label;
  final DateTime detectedAt;

  DetectionLogEntry({
    required this.id,
    required this.catDetected,
    required this.confidence,
    required this.label,
    required this.detectedAt,
  });

  factory DetectionLogEntry.fromJson(Map<String, dynamic> json) => DetectionLogEntry(
        id: json['id'] as int? ?? 0,
        catDetected: json['catDetected'] as bool? ?? false,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        label: json['label'] as String? ?? '',
        detectedAt: DateTime.parse(json['detectedAt'] as String).toLocal(),
      );
}

class CatDetectionService {
  static Future<CatDetectionResult?> detect(String baseUrl, int catId, Uint8List imageBytes, String fileName) async {
    try {
      final uri = Uri.parse('$baseUrl/cats/$catId/detect');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(apiHeaders());
      request.files.add(http.MultipartFile.fromBytes('photo', imageBytes, filename: fileName));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return CatDetectionResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  static Future<List<DetectionLogEntry>> getHistory(String baseUrl, int catId) async {
    try {
      final uri = Uri.parse('$baseUrl/cats/$catId/detections');
      final response = await http.get(uri, headers: apiHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((e) => DetectionLogEntry.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }
}