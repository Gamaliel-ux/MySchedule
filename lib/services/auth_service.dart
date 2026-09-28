import 'dart:convert';

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
  static const String _apiBaseUrl = 'http://10.0.2.2:3000/api';

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

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': cleanName,
          'email': cleanEmail,
          'password': cleanPassword,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final user = AuthUser(
          id:
              body['user']['id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          name: body['user']['name'] ?? cleanName,
          email: body['user']['email'] ?? cleanEmail,
          password: cleanPassword,
          token: body['token']?.toString(),
          username:
              body['user']['username'] ?? buildUsernameFromName(cleanName),
        );

        await _saveCurrentUser(user);
        return;
      }

      throw Exception(body['message'] ?? 'Registrasi gagal');
    } catch (error) {
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
    bool useApi = false,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      return false;
    }

    if (useApi) {
      final apiLoggedIn = await loginWithApi(
        email: cleanEmail,
        password: cleanPassword,
      );
      if (apiLoggedIn) {
        return true;
      }
    }

    final users = await getUsers();
    for (final user in users) {
      if (user.email.toLowerCase() == cleanEmail.toLowerCase() &&
          user.password == cleanPassword) {
        await _saveCurrentUser(user);
        return true;
      }
    }

    return false;
  }

  static Future<bool> loginWithApi({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(body['message'] ?? 'Login gagal');
      }

      final user = AuthUser(
        id:
            body['user']['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: body['user']['name'] ?? email.split('@').first,
        email: body['user']['email'] ?? email.trim(),
        password: password,
        token: body['token']?.toString(),
        username:
            body['user']['username'] ??
            buildUsernameFromName(
              body['user']['name'] ?? email.split('@').first,
            ),
      );

      await _saveCurrentUser(user);
      return true;
    } catch (_) {
      final users = await getUsers();
      for (final user in users) {
        if (user.email.toLowerCase() == email.toLowerCase() &&
            user.password == password) {
          await _saveCurrentUser(user);
          return true;
        }
      }
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
