import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/auth_service.dart';
import '../providers/theme_provider.dart';

class CookieLoginScreen extends StatefulWidget {
  const CookieLoginScreen({Key? key}) : super(key: key);

  @override
  State<CookieLoginScreen> createState() => _CookieLoginScreenState();
}

class _CookieLoginScreenState extends State<CookieLoginScreen> {
  InAppWebViewController? _webViewController;
  final CookieManager _cookieManager = CookieManager.instance();
  final AuthService _authService = AuthService();
  
  bool _isLoading = true;
  double _progress = 0;
  bool _isCheckingAuth = false;
  bool _hasCompletedLogin = false;
  String? _errorMessage;

  // URL Login WordPress
  static const String _loginUrl = 'https://www.owrite.id/writehere/';
  static const String _baseUrl = 'https://www.owrite.id';
  static const String _userMeEndpoint = 'https://www.owrite.id/wp-json/wp/v2/users/me';

  @override
  void initState() {
    super.initState();
    // Clear cookies lama saat pertama kali buka
    _clearOldCookies();
  }

  Future<void> _clearOldCookies() async {
    try {
      await _cookieManager.deleteAllCookies();
      debugPrint('🧹 Old cookies cleared');
    } catch (e) {
      debugPrint('⚠️ Failed to clear old cookies: $e');
    }
  }

  /// Cek apakah URL adalah halaman login
  bool _isLoginPage(String url) {
    final lower = url.toLowerCase();
    return lower.contains('/wp-login.php') ||
        lower.contains('/writehere/') ||
        lower.contains('/login') ||
        lower.contains('action=login');
  }

  /// Cek apakah URL menandakan login berhasil (redirect ke dashboard/home)
  bool _isLoggedInPage(String url) {
    final lower = url.toLowerCase();
    // Sudah di domain owrite.id DAN bukan halaman login
    return lower.contains('owrite.id') && !_isLoginPage(lower);
  }

  /// Ambil semua cookies dan cek apakah ada wordpress_logged_in
  Future<void> _checkLoginCookies() async {
    if (_isCheckingAuth || _hasCompletedLogin) return;

    setState(() {
      _isCheckingAuth = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🔍 Checking login cookies...');

      // Ambil semua cookies dari domain owrite.id
      final cookies = await _cookieManager.getCookies(
        url: WebUri(_baseUrl),
      );

      debugPrint('🍪 Total cookies found: ${cookies.length}');

      // Debug: tampilkan semua cookies
      for (var cookie in cookies) {
        debugPrint('   Cookie: ${cookie.name}');
      }

      // Cari cookie wordpress_logged_in_xxx
      final loginCookie = cookies.firstWhere(
        (cookie) => cookie.name.startsWith('wordpress_logged_in_'),
        orElse: () => Cookie(name: '', value: ''),
      );

      if (loginCookie.name.isEmpty || loginCookie.value.isEmpty) {
        debugPrint('❌ No wordpress_logged_in cookie found');
        setState(() {
          _isCheckingAuth = false;
        });
        return;
      }

      debugPrint('✅ Login cookie found: ${loginCookie.name}');

      // Gabungkan semua cookies menjadi string
      final cookieString = cookies
          .map((c) => '${c.name}=${c.value}')
          .join('; ');

      debugPrint('📦 Cookie string length: ${cookieString.length}');

      // Simpan cookies ke SharedPreferences
      await _authService.saveSessionCookies(cookieString);

      // Ambil data user menggunakan cookies
      await _fetchUserData(cookieString);

    } catch (e) {
      debugPrint('❌ Error checking login cookies: $e');
      setState(() {
        _errorMessage = 'Terjadi kesalahan saat memverifikasi login';
        _isCheckingAuth = false;
      });
    }
  }

  /// Ambil data user dari /wp-json/wp/v2/users/me menggunakan cookie
  Future<void> _fetchUserData(String cookieString) async {
    try {
      debugPrint('📡 Fetching user data from API...');

      final response = await http.get(
        Uri.parse(_userMeEndpoint),
        headers: {
          'Cookie': cookieString,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        
        debugPrint('👤 User data received: ${userData['name']}');

        // Validasi user data
        if (userData['id'] != null) {
          await _handleLoginSuccess(userData, cookieString);
        } else {
          debugPrint('❌ Invalid user data: no ID');
          setState(() {
            _errorMessage = 'Data user tidak valid';
            _isCheckingAuth = false;
          });
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ Unauthorized - cookies may be invalid');
        setState(() {
          _errorMessage = 'Session tidak valid. Silakan login ulang.';
          _isCheckingAuth = false;
        });
      } else {
        debugPrint('❌ API error: ${response.statusCode} - ${response.body}');
        setState(() {
          _errorMessage = 'Gagal mengambil data user (${response.statusCode})';
          _isCheckingAuth = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching user data: $e');
      setState(() {
        _errorMessage = 'Gagal terhubung ke server';
        _isCheckingAuth = false;
      });
    }
  }

  /// Handle login sukses - simpan data dan tutup screen
  Future<void> _handleLoginSuccess(Map<String, dynamic> userData, String cookieString) async {
    if (_hasCompletedLogin) return;

    debugPrint('🎉 Processing successful login...');

    // Set flag agar tidak double process
    setState(() {
      _hasCompletedLogin = true;
    });

    // Simpan data user
    final saved = await _authService.saveUserFromWeb(
      userId: userData['id'].toString(),
      username: userData['slug'] ?? userData['name'] ?? 'user',
      name: userData['name'] ?? 'Unknown',
      email: userData['email'] ?? '',
      avatar: userData['avatar_urls']?['96'],
      sessionCookies: cookieString,
    );

    if (!saved) {
      debugPrint('❌ Failed to save user data');
      setState(() {
        _hasCompletedLogin = false;
        _isCheckingAuth = false;
        _errorMessage = 'Gagal menyimpan data login';
      });
      return;
    }

    debugPrint('✅ Login complete! Closing screen...');

    // Tutup screen dengan hasil sukses
    if (mounted) {
      // Delay singkat untuk memastikan data tersimpan
      await Future.delayed(const Duration(milliseconds: 300));
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        // Cegah back saat sedang proses auth
        if (_isCheckingAuth) return false;
        return true;
      },
      child: Scaffold(
        backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
        appBar: AppBar(
          backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.close,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: _isCheckingAuth ? null : () => Navigator.pop(context, false),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Login ke Owrite',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                'www.owrite.id',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            // Tombol refresh
            IconButton(
              icon: Icon(
                Icons.refresh,
                color: isDark ? Colors.white : Colors.black,
              ),
              onPressed: _isCheckingAuth
                  ? null
                  : () {
                      _webViewController?.reload();
                    },
            ),
          ],
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Progress bar
                if (_isLoading)
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE5FF10)),
                  ),

                // Error message
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.withOpacity(0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red, size: 18),
                          onPressed: () {
                            setState(() {
                              _errorMessage = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                // WebView
                Expanded(
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(_loginUrl),
                    ),
                    initialSettings: InAppWebViewSettings(
                      useShouldOverrideUrlLoading: true,
                      mediaPlaybackRequiresUserGesture: false,
                      javaScriptEnabled: true,
                      javaScriptCanOpenWindowsAutomatically: true,
                      useHybridComposition: true,
                      // Penting untuk cookies
                      thirdPartyCookiesEnabled: true,
                      sharedCookiesEnabled: true,
                      // Allow mixed content
                      mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    ),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                      debugPrint('🌐 WebView created');
                    },
                    onLoadStart: (controller, url) {
                      debugPrint('📍 Loading: $url');
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                      });
                    },
                    onLoadStop: (controller, url) async {
                      setState(() {
                        _isLoading = false;
                      });

                      final urlString = url?.toString() ?? '';
                      debugPrint('✅ Page loaded: $urlString');

                      // Cek apakah sudah di halaman setelah login
                      if (_isLoggedInPage(urlString) && !_hasCompletedLogin) {
                        debugPrint('🔄 Detected post-login page, checking cookies...');
                        
                        // Tunggu sebentar agar cookies tersimpan sempurna
                        await Future.delayed(const Duration(milliseconds: 500));
                        
                        // Cek cookies
                        await _checkLoginCookies();
                      }
                    },
                    onProgressChanged: (controller, progress) {
                      setState(() {
                        _progress = progress / 100;
                      });
                    },
                    onUpdateVisitedHistory: (controller, url, isReload) async {
                      final urlString = url?.toString() ?? '';
                      debugPrint('📜 History updated: $urlString');

                      // Monitor perubahan URL
                      if (_isLoggedInPage(urlString) && !_hasCompletedLogin && !_isCheckingAuth) {
                        debugPrint('🔄 URL change detected, checking login status...');
                        
                        await Future.delayed(const Duration(milliseconds: 800));
                        await _checkLoginCookies();
                      }
                    },
                    onReceivedServerTrustAuthRequest: (controller, challenge) async {
                      // Allow self-signed certificates (untuk development)
                      return ServerTrustAuthResponse(
                        action: ServerTrustAuthResponseAction.PROCEED,
                      );
                    },
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      final url = navigationAction.request.url?.toString() ?? '';
                      debugPrint('🔗 Navigation request: $url');

                      // Allow semua navigasi dalam domain owrite.id
                      if (url.contains('owrite.id')) {
                        return NavigationActionPolicy.ALLOW;
                      }

                      // Allow Google OAuth jika diperlukan
                      if (url.contains('accounts.google.com') ||
                          url.contains('facebook.com') ||
                          url.contains('twitter.com')) {
                        return NavigationActionPolicy.ALLOW;
                      }

                      return NavigationActionPolicy.ALLOW;
                    },
                  ),
                ),
              ],
            ),

            // Loading overlay saat checking auth
            if (_isCheckingAuth)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5FF10)),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Memverifikasi login...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Mohon tunggu sebentar',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('🧹 CookieLoginScreen disposed');
    super.dispose();
  }
}