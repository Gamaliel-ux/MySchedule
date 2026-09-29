import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthUser {
  final String id;
  final String name;
  final String email;
  final String password;
  final String? token;
  final String? username;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.token,
    this.username,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'password': password,
    'token': token,
    'username': username,
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id']?.toString() ?? '',
    name: (json['name'] ?? json['firstName'] ?? json['username'] ?? '')
        .toString(),
    email: (json['email'] ?? '').toString(),
    password: (json['password'] ?? '').toString(),
    token: json['token']?.toString(),
    username: json['username']?.toString(),
  );
}

class AuthService {
  static const String _usersKey = 'schedule_planner_users';
  static const String _loggedInKey = 'schedule_planner_logged_in';
  static const String _currentUserKey = 'schedule_planner_current_user';
  static const String _tokenKey = 'schedule_planner_token';
  static const String _customApiUrlKey = 'schedule_planner_custom_api_url';

  static String get defaultApiBaseUrl {
    if (kIsWeb) return 'http://localhost:3000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    if (Platform.isIOS) return 'http://127.0.0.1:3000/api';
    return 'http://localhost:3000/api';
  }

  static Future<String> getApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString(_customApiUrlKey);
    if (custom != null && custom.trim().isNotEmpty) {
      return custom.trim();
    }
    return defaultApiBaseUrl;
  }

  static Future<void> setCustomApiUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_customApiUrlKey);
    } else {
      await prefs.setString(_customApiUrlKey, url.trim());
    }
  }

  static bool isValidEmail(String value) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(value.trim());
  }

  static bool isStrongPassword(String value) {
    if (value.length < 8) return false;
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)');
    return regex.hasMatch(value);
  }

  static String buildUsernameFromName(String name) {
    final sanitized = name.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return sanitized.isEmpty ? 'planner' : sanitized;
  }

  static Future<List<AuthUser>> getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUsers = prefs.getStringList(_usersKey) ?? const [];
    return rawUsers.map((user) => AuthUser.fromJson(jsonDecode(user))).toList();
  }

  static Future<void> _saveUsers(List<AuthUser> users) async {
    final prefs = await SharedPreferences.getInstance();
    final mapped = users.map((user) => jsonEncode(user.toJson())).toList();
    await prefs.setStringList(_usersKey, mapped);
  }

  static Future<void> _saveCurrentUser(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
    await prefs.setString(_tokenKey, user.token ?? '');
    await prefs.setBool(_loggedInKey, true);
  }

  static Future<AuthUser?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_currentUserKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    return AuthUser.fromJson(jsonDecode(raw));
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedInFlag = prefs.getBool(_loggedInKey) ?? false;
    final currentUserData = prefs.getString(_currentUserKey);

    if (!isLoggedInFlag || currentUserData == null || currentUserData.isEmpty) {
      if (isLoggedInFlag) {
        await prefs.setBool(_loggedInKey, false);
      }
      return false;
    }

    try {
      final user = AuthUser.fromJson(jsonDecode(currentUserData));
      if (user.email.trim().isEmpty) {
        await prefs.setBool(_loggedInKey, false);
        return false;
      }
      return true;
    } catch (_) {
      await prefs.setBool(_loggedInKey, false);
      return false;
    }
  }

  static Future<void> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (cleanName.isEmpty) {
      throw Exception('Nama tidak boleh kosong');
    }
    if (cleanName.length < 2) {
      throw Exception('Nama minimal 2 karakter');
    }
    if (!isValidEmail(cleanEmail)) {
      throw Exception('Format email tidak valid');
    }
    if (!isStrongPassword(cleanPassword)) {
      throw Exception(
        'Password minimal 8 karakter dengan huruf besar, huruf kecil, dan angka',
      );
    }

    final baseUrl = await getApiBaseUrl();

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'name': cleanName,
              'email': cleanEmail,
              'password': cleanPassword,
            }),
          )
          .timeout(const Duration(seconds: 2));

      final body = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final user = AuthUser(
          id:
              body['user']?['id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          name: body['user']?['name'] ?? cleanName,
          email: body['user']?['email'] ?? cleanEmail,
          password: cleanPassword,
          token: body['token']?.toString(),
          username:
              body['user']?['username'] ?? buildUsernameFromName(cleanName),
        );

        await _saveCurrentUser(user);
        final users = await getUsers();
        if (!users.any((u) => u.email.toLowerCase() == cleanEmail.toLowerCase())) {
          users.add(user);
          await _saveUsers(users);
        }
        return;
      }

      throw Exception(body['message'] ?? 'Registrasi gagal');
    } catch (error) {
      final errorStr = error.toString();
      final isNetworkError =
          errorStr.contains('TimeoutException') ||
          errorStr.contains('SocketException') ||
          errorStr.contains('ClientException') ||
          errorStr.contains('Connection refused') ||
          errorStr.contains('Failed host lookup') ||
          error is TimeoutException ||
          error is SocketException;

      if (!isNetworkError) {
        rethrow;
      }

      final users = await getUsers();
      final exists = users.any(
        (user) => user.email.toLowerCase() == cleanEmail.toLowerCase(),
      );

      if (exists) {
        throw Exception('Email sudah terdaftar');
      }

      final newUser = AuthUser(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: cleanName,
        email: cleanEmail,
        password: cleanPassword,
        username: buildUsernameFromName(cleanName),
        token: 'local_${DateTime.now().millisecondsSinceEpoch}',
      );

      users.add(newUser);
      await _saveUsers(users);
      await _saveCurrentUser(newUser);
    }
  }

  static Future<bool> login({
    required String email,
    required String password,
    bool useApi = true,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      return false;
    }

    // 1. Instant Fast-Path: Check local users database first (0 ms response)
    final users = await getUsers();
    for (final user in users) {
      if (user.email.toLowerCase() == cleanEmail.toLowerCase() &&
          user.password == cleanPassword) {
        await _saveCurrentUser(user);
        if (useApi) {
          unawaited(
            loginWithApi(
              email: cleanEmail,
              password: cleanPassword,
            ).catchError((_) => false),
          );
        }
        return true;
      }
    }

    // 2. If not found locally, try API authentication with a snappy 2s timeout
    if (useApi) {
      final apiLoggedIn = await loginWithApi(
        email: cleanEmail,
        password: cleanPassword,
      );
      if (apiLoggedIn) {
        return true;
      }
    }

    return false;
  }

  static Future<bool> loginWithApi({
    required String email,
    required String password,
  }) async {
    final baseUrl = await getApiBaseUrl();
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 2));

      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        return false;
      }

      final user = AuthUser(
        id:
            body['user']?['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: body['user']?['name'] ?? email.split('@').first,
        email: body['user']?['email'] ?? email.trim(),
        password: password,
        token: body['token']?.toString(),
        username:
            body['user']?['username'] ??
            buildUsernameFromName(
              body['user']?['name'] ?? email.split('@').first,
            ),
      );

      await _saveCurrentUser(user);
      final users = await getUsers();
      if (!users.any((u) => u.email.toLowerCase() == email.trim().toLowerCase())) {
        users.add(user);
        await _saveUsers(users);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    await prefs.remove(_tokenKey);
    await prefs.setBool(_loggedInKey, false);
  }
}
