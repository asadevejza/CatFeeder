import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class ChatService {
  static Future<String?> sendMessage(String baseUrl, int catId, String message, {String? catName}) async {
    try {
      final uri = Uri.parse('$baseUrl/cats/$catId/chat');
      final response = await http.post(
        uri,
        headers: {...apiHeaders(), 'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'catName': catName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['reply'] as String?;
      }
    } catch (_) {}
    return null;
  }
}