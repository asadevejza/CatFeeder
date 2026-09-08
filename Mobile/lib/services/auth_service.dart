import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api_config.dart';

// Prijava/registracija preko backend /api/auth endpointa. Token se čuva
// lokalno (SharedPreferences) i kešira u memoriji da bi apiHeaders() mogao
// sinhrono da ga pročita na svakom pozivu ka serveru.
class AuthService {
  static const _tokenKey = 'auth_token';
  static const _usernameKey = 'auth_username';

  static String? currentToken;
  static String? currentUsername;

  static bool get isLoggedIn => currentToken != null;

  // Pozvati jednom pri pokretanju app-a, prije prvog ekrana.
  static Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    currentToken = prefs.getString(_tokenKey);
    currentUsername = prefs.getString(_usernameKey);
  }

  static Future<void> _saveSession(String token, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_usernameKey, username);
    currentToken = token;
    currentUsername = username;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    currentToken = null;
    currentUsername = null;
  }

  // Vraća null na uspjeh, ili poruku greške (na jeziku servera - bosanski)
  // ako prijava/registracija ne uspije.
  static Future<String?> register(String baseUrl, String username, String password) =>
      _authRequest(baseUrl, 'register', username, password);

  static Future<String?> login(String baseUrl, String username, String password) =>
      _authRequest(baseUrl, 'login', username, password);

  static Future<String?> _authRequest(String baseUrl, String endpoint, String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/$endpoint'),
        headers: apiHeaders(withJsonBody: true),
        body: json.encode({'username': username, 'password': password}),
      );
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        await _saveSession(decoded['token'] as String, decoded['username'] as String);
        return null;
      }
      return decoded['error'] as String? ?? 'Greška ($endpoint).';
    } catch (e) {
      return 'Ne mogu da se povežem: $e';
    }
  }
}
