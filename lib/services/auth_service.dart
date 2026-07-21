import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  static const _tokenKey = 'navuli_token';
  static const _userKey = 'navuli_user';

  String? _token;
  NavuliUser? _user;
  bool _initialized = false;

  String? get token => _token;
  NavuliUser? get user => _user;
  bool get isLoggedIn => _token != null && _user != null;
  bool get initialized => _initialized;

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _user = NavuliUser.fromJson(jsonDecode(userJson));
    }
    _initialized = true;
    notifyListeners();
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> login(String identifier, String password) async {
    try {
      final res = await http
          .post(
            Uri.parse(ApiConfig.loginUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'identifier': identifier, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode != 200 || body['success'] != true) {
        return body['message']?.toString() ?? 'Login failed. Please try again.';
      }

      _token = body['token'] as String;
      _user = NavuliUser.fromJson(body['user']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);
      await prefs.setString(_userKey, jsonEncode(_user!.toJson()));

      notifyListeners();
      return null;
    } catch (e) {
      return 'Could not reach the server. Please check your connection and try again.';
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }

  Map<String, String> get authHeaders =>
      _token == null ? {} : {'Authorization': 'Bearer $_token'};

  bool hasPermission(String code) => _user?.hasPermission(code) ?? false;

  /// Re-fetches the profile (permissions/children included) from /api/auth/me.
  Future<void> refreshMe() async {
    if (_token == null) return;
    try {
      final res = await http
          .get(Uri.parse(ApiConfig.meUrl), headers: authHeaders)
          .timeout(const Duration(seconds: 20));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        _user = NavuliUser.fromJson(body['user']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(_user!.toJson()));
        notifyListeners();
      }
    } catch (_) {
      // Silently keep the cached profile if the refresh fails.
    }
  }
}
