import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class CatDetectionResult {
  final bool catDetected;
  final double confidence;
  final String label;

  CatDetectionResult({required this.catDetected, required this.confidence, required this.label});

  factory CatDetectionResult.fromJson(Map<String, dynamic> json) => CatDetectionResult(
        catDetected: json['catDetected'] as bool? ?? false,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        label: json['label'] as String? ?? '',
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
    } catch (_) {
      // Tiho ignorišemo — UI prikazuje generičku grešku.
    }
    return null;
  }
}