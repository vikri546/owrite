import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class AuthService {
  static const String _baseUrl = 'https://www.owrite.id/wp-json/wp/v2';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUsername = 'username';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserAvatar = 'user_avatar';
  static const String _keySessionCookies = 'session_cookies';

  // Fetch users from WordPress API
  Future<List<Map<String, dynamic>>> fetchWordPressUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users?per_page=100'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((user) {
          return {
            'id': user['id'].toString(),
            'username': user['slug'] ?? user['name'] ?? 'user',
            'name': user['name'] ?? 'Unknown',
            'email': user['description'] ?? '',
            'avatar': user['avatar_urls'] != null ? user['avatar_urls']['96'] : null,
          };
        }).toList();
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching WordPress users: $e');
      rethrow;
    }
  }

  // Login dengan username yang ada di WordPress API
  Future<bool> login(String username, String password) async {
    try {
      final users = await fetchWordPressUsers();
      
      final user = users.firstWhere(
        (u) => u['username'].toString().toLowerCase() == username.toLowerCase(),
        orElse: () => {},
      );

      if (user.isEmpty) {
        return false;
      }

      if (password.toLowerCase() != user['username'].toString().toLowerCase()) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUsername, user['username']);
      await prefs.setString(_keyUserId, user['id']);
      await prefs.setString(_keyUserEmail, user['email']);
      if (user['avatar'] != null) {
        await prefs.setString(_keyUserAvatar, user['avatar']);
      }
      await prefs.remove(_keySessionCookies);

      return true;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  // Login as Guest
  Future<void> loginAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.setString(_keyUsername, 'Guest');
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserAvatar);
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLogged = prefs.getBool(_keyIsLoggedIn) ?? false;
    final username = prefs.getString(_keyUsername);
    
    // Jika ada username dan bukan Guest, berarti logged in
    return isLogged && username != null && username != 'Guest';
  }

  // Get current user
  Future<Map<String, String>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_keyUsername);
    final userId = prefs.getString(_keyUserId);
    final email = prefs.getString(_keyUserEmail);
    final avatar = prefs.getString(_keyUserAvatar);

    if (username != null && username != 'Guest') {
      return {
        'username': username,
        'userId': userId ?? '',
        'email': email ?? '',
        'avatar': avatar ?? '',
      };
    }
    return null;
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.setString(_keyUsername, 'Guest');
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserAvatar);
    await prefs.remove(_keySessionCookies);
  }

  /// Save user data yang didapat dari web login
  Future<bool> saveUserFromWeb({
    required String userId,
    required String username,
    required String name,
    required String email,
    String? avatar,
    String? sessionCookies,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Simpan semua data secara berurutan
      final results = await Future.wait([
        prefs.setBool(_keyIsLoggedIn, true),
        prefs.setString(_keyUsername, username),
        prefs.setString(_keyUserId, userId),
        prefs.setString(_keyUserEmail, email),
      ]);

      // Cek apakah semua penyimpanan berhasil
      if (!results.every((r) => r == true)) {
        debugPrint('❌ Some preferences failed to save');
        return false;
      }

      // Simpan avatar jika ada
      if (avatar != null && avatar.isNotEmpty) {
        await prefs.setString(_keyUserAvatar, avatar);
      }

      // Simpan session cookies jika ada
      if (sessionCookies != null && sessionCookies.isNotEmpty) {
        await prefs.setString(_keySessionCookies, sessionCookies);
      }
      
      // Verifikasi data tersimpan
      final savedUsername = prefs.getString(_keyUsername);
      final savedIsLoggedIn = prefs.getBool(_keyIsLoggedIn);
      
      debugPrint('✅ User saved: $username (ID: $userId)');
      debugPrint('   Verification - Username: $savedUsername, LoggedIn: $savedIsLoggedIn');
      
      return savedUsername == username && savedIsLoggedIn == true;
    } catch (e) {
      debugPrint('❌ Error saving user: $e');
      return false;
    }
  }

  Future<void> saveSessionCookies(String cookies) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySessionCookies, cookies);
      debugPrint('✅ Session cookies saved');
    } catch (e) {
      debugPrint('❌ Error saving session cookies: $e');
    }
  }

  Future<String?> getSessionCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keySessionCookies);
    } catch (e) {
      debugPrint('❌ Error getting session cookies: $e');
      return null;
    }
  }
}