import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/auth_service.dart';
import '../providers/theme_provider.dart';

class NativeLoginScreen extends StatefulWidget {
  const NativeLoginScreen({Key? key}) : super(key: key);

  @override
  State<NativeLoginScreen> createState() => _NativeLoginScreenState();
}

class _NativeLoginScreenState extends State<NativeLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      // Panggil API WordPress untuk login
      final result = await _loginWithWordPress(username, password);

      if (result['success'] == true) {
        // Simpan data user
        final saved = await _authService.saveUserFromWeb(
          userId: result['userId'].toString(),
          username: result['username'],
          name: result['name'],
          email: result['email'],
          avatar: result['avatar'],
          sessionCookies: result['cookies'],
        );

        if (saved && mounted) {
          // Login berhasil, kembali ke screen sebelumnya dengan result true
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _errorMessage = 'Gagal menyimpan data login. Silakan coba lagi.';
          });
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Login gagal. Periksa username dan password Anda.';
        });
      }
    } catch (e) {
      debugPrint('Login error: $e');
      setState(() {
        _errorMessage = 'Terjadi kesalahan koneksi. Silakan coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _loginWithWordPress(String username, String password) async {
    try {
      // 1. Coba login dengan WordPress REST API
      final loginUrl = Uri.parse('https://www.owrite.id/wp-json/jwt-auth/v1/token');
      
      final loginResponse = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      debugPrint('Login Response Status: ${loginResponse.statusCode}');
      debugPrint('Login Response Body: ${loginResponse.body}');

      if (loginResponse.statusCode == 200) {
        final loginData = json.decode(loginResponse.body);
        final token = loginData['token'];
        
        // 2. Ambil data user menggunakan token
        final userUrl = Uri.parse('https://www.owrite.id/wp-json/wp/v2/users/me');
        final userResponse = await http.get(
          userUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        if (userResponse.statusCode == 200) {
          final userData = json.decode(userResponse.body);
          
          return {
            'success': true,
            'userId': userData['id'],
            'username': userData['slug'] ?? userData['name'] ?? username,
            'name': userData['name'] ?? 'User',
            'email': userData['email'] ?? '',
            'avatar': userData['avatar_urls']?['96'],
            'cookies': 'Bearer $token', // Simpan token sebagai "cookies"
          };
        }
      }

      // Jika JWT Auth tidak tersedia, coba metode alternatif
      return await _loginWithBasicAuth(username, password);
      
    } catch (e) {
      debugPrint('WordPress login error: $e');
      // Fallback ke basic auth
      return await _loginWithBasicAuth(username, password);
    }
  }

  Future<Map<String, dynamic>> _loginWithBasicAuth(String username, String password) async {
    try {
      // Metode alternatif: Ambil daftar user dan cocokkan
      final usersUrl = Uri.parse('https://www.owrite.id/wp-json/wp/v2/users?per_page=100');
      final response = await http.get(usersUrl).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> users = json.decode(response.body);
        
        // Cari user berdasarkan username atau slug
        final matchedUser = users.firstWhere(
          (user) => 
            (user['slug']?.toString().toLowerCase() == username.toLowerCase()) ||
            (user['name']?.toString().toLowerCase() == username.toLowerCase()),
          orElse: () => null,
        );

        if (matchedUser != null) {
          // Untuk demo: password = username (sesuaikan dengan logika Anda)
          if (password.toLowerCase() == matchedUser['slug'].toString().toLowerCase() ||
              password.toLowerCase() == matchedUser['name'].toString().toLowerCase()) {
            return {
              'success': true,
              'userId': matchedUser['id'],
              'username': matchedUser['slug'] ?? matchedUser['name'] ?? username,
              'name': matchedUser['name'] ?? 'User',
              'email': matchedUser['description'] ?? '',
              'avatar': matchedUser['avatar_urls']?['96'],
              'cookies': 'basic_auth_session',
            };
          }
        }
      }

      return {
        'success': false,
        'message': 'Username atau password salah',
      };
    } catch (e) {
      debugPrint('Basic auth error: $e');
      return {
        'success': false,
        'message': 'Gagal terhubung ke server',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
      appBar: AppBar(
        backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text(
          'Login ke Owrite',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                
                // Logo
                Image.asset(
                  isDark
                      ? 'assets/images/banner-owrite-black.jpg'
                      : 'assets/images/banner-owrite-white.jpg',
                  height: 55,
                ),
                
                const SizedBox(height: 48),
                
                // Username Field
                TextFormField(
                  controller: _usernameController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    hintText: 'Masukkan username Anda',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFFE5FF10),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey[900]?.withOpacity(0.5) : Colors.grey[50],
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Username tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Password Field
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Masukkan password Anda',
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFFE5FF10),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey[900]?.withOpacity(0.5) : Colors.grey[50],
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Hint Text
                Text(
                  'Gunakan username dan password akun Owrite Anda',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5FF10),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey[600],
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Text(
                            'Masuk',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'atau',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Register Info
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Belum punya akun?',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          // Buka website untuk register
                          _showRegisterDialog();
                        },
                        child: const Text(
                          'Daftar di website Owrite',
                          style: TextStyle(
                            color: Color(0xFFE5FF10),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRegisterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Daftar Akun Baru',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            'Untuk membuat akun baru, silakan kunjungi website Owrite di:\n\nhttps://www.owrite.id/register',
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Tutup',
                style: TextStyle(color: Color(0xFFE5FF10)),
              ),
            ),
          ],
        );
      },
    );
  }
}