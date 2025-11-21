import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:convert';
import '../utils/auth_service.dart';

class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({Key? key}) : super(key: key);

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  InAppWebViewController? _webViewController;
  final CookieManager _cookieManager = CookieManager.instance();
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  double _progress = 0;
  bool _isCheckingAuth = false;
  bool _hasCompletedLogin = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _checkLoginStatus() async {
    if (_isCheckingAuth || _hasCompletedLogin) return;
    
    setState(() {
      _isCheckingAuth = true;
    });

    try {
      // Ambil cookies dari website
      final cookies = await _cookieManager.getCookies(
        url: WebUri('https://www.owrite.id'),
      );

      debugPrint('🍪 Cookies found: ${cookies.length}');
      
      // Cari cookie WordPress auth
      final authCookie = cookies.firstWhere(
        (cookie) => cookie.name.contains('wordpress_logged_in') || 
                    cookie.name.contains('wp-settings'),
        orElse: () => Cookie(name: '', value: ''),
      );

      if (authCookie.value.isNotEmpty) {
        debugPrint('✅ Auth cookie found: ${authCookie.name}');
        
        await _storeSessionCookies(cookies);
        // Ambil data user dari WordPress REST API menggunakan cookie
        await _fetchUserDataFromAPI(cookies);
      }
    } catch (e) {
      debugPrint('❌ Error checking login: $e');
    } finally {
      if (mounted && !_hasCompletedLogin) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  Future<void> _storeSessionCookies(List<Cookie> cookies) async {
    if (cookies.isEmpty) return;
    final cookieHeader = cookies
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
    if (cookieHeader.trim().isEmpty) return;
    await _authService.saveSessionCookies(cookieHeader);
  }

  Future<void> _fetchUserDataFromAPI(List<Cookie> cookies) async {
    try {
      // Format cookies untuk header
      final cookieHeader = cookies
          .map((cookie) => '${cookie.name}=${cookie.value}')
          .join('; ');

      debugPrint('🔑 Sending cookies to API...');

      // Coba ambil data user yang sedang login menggunakan /wp/v2/users/me endpoint
      final result = await _webViewController?.evaluateJavascript(source: '''
        (async function() {
          try {
            const headers = {
              'Content-Type': 'application/json'
            };
            const nonce = window?.wpApiSettings?.nonce;
            if (nonce) {
              headers['X-WP-Nonce'] = nonce;
            }
            const response = await fetch('https://www.owrite.id/wp-json/wp/v2/users/me', {
              method: 'GET',
              credentials: 'include',
              headers
            });
            
            const payload = {
              status: response.status,
            };
            
            if (response.ok) {
              payload.data = await response.json();
            } else {
              payload.error = await response.text();
            }
            
            return JSON.stringify(payload);
          } catch (error) {
            return JSON.stringify({error: error.message});
          }
        })();
      ''');

      debugPrint('📦 API Response: $result');

      if (result != null && result.toString().isNotEmpty) {
        final parsedResult = json.decode(result.toString());
        final userData = parsedResult['data'];
        
        if (userData != null && userData['id'] != null) {
          await _handleLoginSuccess(userData, cookieHeader);
        } else {
          debugPrint('⚠️ User not authenticated: ${parsedResult['error']}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching user data: $e');
    } finally {
      if (mounted && !_hasCompletedLogin) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  Future<void> _handleLoginSuccess(Map<String, dynamic> userData, String cookieHeader) async {
    if (_hasCompletedLogin) return;
    
    setState(() {
      _hasCompletedLogin = true;
      _isCheckingAuth = false;
    });

    final saved = await _authService.saveUserFromWeb(
      userId: userData['id'].toString(),
      username: userData['slug'] ?? userData['name'] ?? 'user',
      name: userData['name'] ?? 'Unknown',
      email: userData['email'] ?? '',
      avatar: userData['avatar_urls']?['96'],
      sessionCookies: cookieHeader,
    );

    if (!saved) {
      debugPrint('❌ Failed to save user data');
      if (mounted) {
        setState(() {
          _hasCompletedLogin = false;
        });
      }
      return;
    }

    debugPrint('✅ Login successful, closing screen...');

    // Tutup screen dan kirim hasil sukses
    if (mounted) {
      // Pop dengan delay singkat untuk memastikan state tersimpan
      await Future.delayed(const Duration(milliseconds: 300));
      Navigator.of(context).pop(true); // Return true untuk menandakan login berhasil
    }
  }

  bool _isLoginUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('/login') ||
        lower.contains('/wp-login.php') ||
        lower.contains('/writehere/');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        if (_isCheckingAuth) {
          return false; // Prevent back during auth check
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? Colors.black : Colors.white,
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
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: isDark ? Colors.black : Colors.white,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                if (_isLoading)
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE5FF10)),
                  ),
                Expanded(
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri('https://www.owrite.id/writehere/'),
                    ),
                    initialSettings: InAppWebViewSettings(
                      useShouldOverrideUrlLoading: true,
                      mediaPlaybackRequiresUserGesture: false,
                      javaScriptEnabled: true,
                      javaScriptCanOpenWindowsAutomatically: true,
                      useHybridComposition: true,
                      thirdPartyCookiesEnabled: true,
                      sharedCookiesEnabled: true,
                    ),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                    },
                    onLoadStart: (controller, url) {
                      setState(() {
                        _isLoading = true;
                      });
                    },
                    onLoadStop: (controller, url) async {
                      setState(() {
                        _isLoading = false;
                      });

                      final urlString = url.toString();
                      debugPrint('📍 Current URL: $urlString');

                      // Cek apakah user sudah login (redirect dari halaman login)
                      if (urlString.contains('owrite.id') &&
                          !_isLoginUrl(urlString)) {
                        
                        // Tunggu sebentar untuk memastikan cookies tersimpan
                        await Future.delayed(const Duration(seconds: 1));
                        
                        // Cek status login
                        await _checkLoginStatus();
                      }
                    },
                    onProgressChanged: (controller, progress) {
                      setState(() {
                        _progress = progress / 100;
                      });
                    },
                    onUpdateVisitedHistory: (controller, url, isReload) async {
                      final urlString = url.toString();
                      
                      // Monitor URL changes
                      if (urlString.contains('owrite.id') &&
                          !_isLoginUrl(urlString)) {
                        
                        debugPrint('🔄 Detected navigation away from login page');
                        await Future.delayed(const Duration(milliseconds: 500));
                        await _checkLoginStatus();
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_isCheckingAuth)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(32),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5FF10)),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Memverifikasi login...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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
}