import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';

class FeedingCommandService {
  Future<bool> feedNow({int durationSeconds = 2}) async {
    final response = await http.post(
      Uri.parse('$defaultBaseUrl/FeedingCommands'),
      headers: apiHeaders(withJsonBody: true),
      body: jsonEncode({
        "durationSeconds": durationSeconds,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    }

    throw Exception(
      'Greška ${response.statusCode}: ${response.body}',
    );
  }
}