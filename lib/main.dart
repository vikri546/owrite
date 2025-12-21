import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/bookmark_screen.dart';
import 'screens/link_screen.dart';
import 'screens/search_screen.dart';
import 'screens/users_screen.dart';
import 'screens/quick_screen.dart';
// Ini sudah mengimpor TrashManager
import 'screens/notifications_screen.dart'; // Impor file yang sudah dimodifikasi
import 'screens/display_settings_screen.dart';
import 'screens/web_login_screen.dart';
import 'screens/watch_screen.dart';
import 'screens/article_detail_screen.dart';
import 'screens/youtube_player_screen.dart';
import 'screens/shorts_player_screen.dart';

// Models & Utils
import 'models/article.dart';
import 'utils/custom_page_transitions.dart';
import 'utils/theme_config.dart';
import 'utils/auth_service.dart';
import 'utils/font_cache.dart';
import 'utils/strings.dart';
import 'repositories/article_repository.dart';

// Providers
import 'providers/theme_provider.dart';
import 'providers/article_provider.dart';
import 'providers/language_provider.dart';
import 'providers/video_provider.dart';

// Services
import 'services/notification_service.dart';
import 'services/background_notification_service.dart';
import 'services/bookmark_service.dart';
import 'services/notification_manager.dart';

// Widgets
import 'widgets/theme_transition_builder.dart';
import 'widgets/theme_toggle_button.dart';

// Warna background bottom bar untuk terang dan gelap
const Color kBottomNavLightColor = Color(0xFFF5F5F5);
const Color kBottomNavDarkColor = Color(0xFF1A1A1A);

// Global navigator key untuk navigasi dari notifikasi
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


/// Handle notification tap dan navigasi
void _handleNotificationTap(String? payload) {
  if (payload == null || payload.isEmpty) return;
  
  try {
    final data = json.decode(payload) as Map<String, dynamic>;
    final type = data['type'] as String?;
    
    if (type == 'article') {
      final articleId = data['id'] as String?;
      final articleUrl = data['url'] as String?;
      
      if (articleId != null || articleUrl != null) {
        _navigateToArticle(articleId, articleUrl);
      }
    } else if (type == 'video') {
      final videoId = data['id'] as String?;
      final isShorts = data['isShorts'] as bool? ?? false;
      
      if (videoId != null) {
        _navigateToVideo(videoId, isShorts);
      }
    } else if (type == 'articles_24h') {
      // Navigate to home screen
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen(initialTab: 0)),
        (route) => false,
      );
    }
  } catch (e) {
    debugPrint('Error handling notification tap: $e');
  }
}

/// Navigate to article detail
Future<void> _navigateToArticle(String? articleId, String? articleUrl) async {
  try {
    if (articleId == null && articleUrl == null) return;
    
    // Fetch article by ID or URL
    final articleRepository = ArticleRepository();
    Article? article;
    
    if (articleId != null) {
      // Try to get article by ID from all articles
      final articles = await articleRepository.getArticlesByCategory(null, page: 1, pageSize: 100);
      article = articles.firstWhere(
        (a) => a.id == articleId,
        orElse: () => articles.first,
      );
    } else if (articleUrl != null) {
      // Try to find article by URL
      final articles = await articleRepository.getArticlesByCategory(null, page: 1, pageSize: 100);
      article = articles.firstWhere(
        (a) => a.url == articleUrl,
        orElse: () => articles.first,
      );
    }
    
    if (article != null && navigatorKey.currentState != null) {
      // Check if article is bookmarked
      final bookmarkService = BookmarkService();
      final isBookmarked = await bookmarkService.isBookmarked(article!);
      
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => ArticleDetailScreen(
            article: article!,
            isBookmarked: isBookmarked,
            heroTag: 'notification-${article.id}',
            onBookmarkToggle: () {
              // Handle bookmark toggle if needed
              // The screen will handle the actual toggle
            },
          ),
        ),
      );
    }
  } catch (e) {
    debugPrint('Error navigating to article: $e');
    // Fallback: navigate to home
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen(initialTab: 0)),
      (route) => false,
    );
  }
}

/// Navigate to video player
void _navigateToVideo(String videoId, bool isShorts) {
  if (navigatorKey.currentState == null) return;
  
  if (isShorts) {
    // For shorts, we need to get the video list first
    // For now, navigate to watch screen
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (context) => YouTubePlayerScreen(
          videoId: videoId,
          isShorts: true,
        ),
      ),
    );
  } else {
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (context) => YouTubePlayerScreen(
          videoId: videoId,
          isShorts: false,
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Jalankan hanya di perangkat mobile (Android/iOS), jika web tampilkan warning.
  if (kIsWeb) {
    // --- PERBAIKAN ---
    // Jika web, jalankan WebWarningApp
    runApp(const WebWarningApp());
  } else {
    // --- PERBAIKAN ---
    // Jika bukan web (mobile), lakukan inisialisasi penuh dan jalankan MyApp
    try {
      await Firebase.initializeApp();
      debugPrint("✅ Firebase initialized successfully");
      FirebaseAnalytics analytics = FirebaseAnalytics.instance;
      await analytics.logEvent(name: 'app_start');
      debugPrint("✅ Firebase Analytics event logged");
    } catch (e) {
      debugPrint("⚠️ Firebase initialization error: $e");
    }

    try {
      await dotenv.load(fileName: ".env");
      debugPrint("✅ dotenv loaded");
    } catch (e) {
      debugPrint("⚠️ dotenv load error: $e");
    }

    try {
      await NotificationService().init(onTap: _handleNotificationTap);
      await NotificationManager().initialize();
      BackgroundNotificationService().initialize();
      debugPrint("✅ Notification services initialized");
    } catch (e) {
      debugPrint("⚠️ Notification initialization error: $e");
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => ArticleProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()..loadLocale()),
          ChangeNotifierProvider(create: (_) => TrashManager()),
          ChangeNotifierProvider(create: (_) => VideoProvider()),
        ],
        child: const MyAppWithSplash(),
      ),
    );
  }
}

// ========== WEB WARNING APP ==========
class WebWarningApp extends StatelessWidget {
  const WebWarningApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Owrite - Not supported on Web',
      debugShowCheckedModeBanner: false,
      home: const WebWarningScreen(),
    );
  }
}

class WebWarningScreen extends StatelessWidget {
  const WebWarningScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.yellow[700], size: 60),
              const SizedBox(height: 24),
              const Text(
                "Aplikasi Owrite tidak tersedia untuk versi browser/web.",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              const Text(
                "Silakan buka Owrite hanya di perangkat handphone (Android/iOS).",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.smartphone_rounded, color: Colors.yellow),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.yellow.shade700, width: 2),
                    foregroundColor: Colors.yellow[700],
                    minimumSize: const Size(200, 44),
                    backgroundColor: Colors.transparent),
                label: const Text('OK'),
                onPressed: () {},
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
// =====================================

// ==== SPLASH ANIMATION AND WRAPPER ====
// NOTE: Pastikan file @icon-app.png ada di assets/images, dan sudah di pubspec.yaml assets

class MyAppWithSplash extends StatefulWidget {
  const MyAppWithSplash({Key? key}) : super(key: key);

  @override
  State<MyAppWithSplash> createState() => _MyAppWithSplashState();
}

class _MyAppWithSplashState extends State<MyAppWithSplash> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Jalankan timer sesuai lama animasi splash
    Future.delayed(const Duration(milliseconds: 2700), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showSplash
        ? const SplashScreen()
        : const MyApp();
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isAnimationDone = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2700),
      vsync: this,
    );

    // Konfigurasi:
    // - Fade in cepat (0-14%)
    // - Tahan penuh (14-70%)
    // - Fade out full lebih lama (70-100%)
    // - Zoom in lebih lama (14-99%) baru dorong lebih cepat sampai 100%
    // - Tidak ada zoom out; logo zoom hingga menutupi layar.

    _fadeAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 14, // 0-14%
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 56, // 14-70%
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 30, // 70-100% (lebih panjang, sehingga hilangnya smooth sampai alpha=0)
      ),
    ]).animate(_controller);

    // Scale:
    // - 0-14%: 1.0 tetap (hold)
    // - 14%-99%: 1.0 -> maxScale (zoom ke lebar layar/layar penuh)
    // - 99%-100%: akselerasi sedikit ke maxScale*1.12
    // NOTE: maxScale diukur dinamis di build() untuk supaya logo zoom menutupi layar.

    // Tetap perlu inisialisasi awal agar tidak null.
    _scaleAnimation = AlwaysStoppedAnimation(1.0);

    _controller.forward().whenComplete(() {
      if (mounted) {
        setState(() {
          _isAnimationDone = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const logoSize = 132.0;
    final size = MediaQuery.of(context).size;
    final maxDim = max(size.width, size.height);

    // Agar menutupi semua sisi: ukuran logo dibesarkan min lebar/lantai layar * X
    // Rasio = ukuran layar / logoSize, diberi buffer supaya benar2 menutupi
    // Ubah: KURANGI sedikit scale (awalnya *1.28 dan *1.16 di bawah, jadi lebih kecil)
    final double targetScaleFullScreen = (maxDim / logoSize) * 0.4; // sebelumnya 1.28

    final Animation<double> scaleAnim = TweenSequence([
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 14, // 0-14% tahan
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: targetScaleFullScreen)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 80, // 14-99% zoom in besar, lebih pelan, lebih lama
      ),
      TweenSequenceItem(
        tween: Tween(begin: targetScaleFullScreen, end: targetScaleFullScreen * 0.4)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 1, // 99-100% akselerasi cepat (hanya di ujung, biar efek dorong)
      ),
    ]).animate(_controller);

    return Material(
      color: const Color(0xFFE5FF10), // Ubah background luar menjadi warna #e5ff10
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value.clamp(0.0, 1.0), // pastikan 0..1
              child: Transform.scale(
                scale: scaleAnim.value,
                child: Padding(
                  padding: const EdgeInsets.all(36.0),
                  child: Image.asset(
                    'assets/images/banner-owrite-white.jpg',
                    width: logoSize,
                    height: logoSize,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
// =====================================

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FontCache.preloadFonts(context);
    });

    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, _) {
        final strings = AppStrings(languageProvider.locale.languageCode);

        // Tema Terang
        final lightThemeData = AppTheme.lightTheme.copyWith(
          scaffoldBackgroundColor: ThemeProvider.lightColor,
          canvasColor: ThemeProvider.lightColor,
          bottomAppBarTheme: AppTheme.lightTheme.bottomAppBarTheme?.copyWith(
            color: kBottomNavLightColor,
          ),
          brightness: Brightness.light,
        );

        // Tema Gelap
        final darkThemeData = AppTheme.darkTheme.copyWith(
          scaffoldBackgroundColor: ThemeProvider.darkColor,
          canvasColor: ThemeProvider.darkColor,
          bottomAppBarTheme: AppTheme.darkTheme.bottomAppBarTheme?.copyWith(
            color: kBottomNavDarkColor,
          ),
          brightness: Brightness.dark,
        );

        return ThemeTransitionBuilder(
          themeController: themeProvider,
          builder: (context, theme) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: strings.appTitle,
              debugShowCheckedModeBanner: false,
              theme: lightThemeData.copyWith(
                pageTransitionsTheme: PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: CustomPageTransitionBuilder(),
                    TargetPlatform.iOS: CustomPageTransitionBuilder(),
                  },
                ),
              ),
              darkTheme: darkThemeData,
              themeMode: themeProvider.themeMode,
              locale: languageProvider.locale,
              supportedLocales: const [Locale('id', '')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              // GANTI: Tampilkan MainScreen saja di awal (bukan AuthWrapper/Stack WebLogin)
              home: const MainScreen(),
            );
          },
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final int initialTab; // >>> TAMBAHKAN PARAMETER INI >>>
  
  const MainScreen({
    Key? key,
    this.initialTab = 0, // >>> DEFAULT ke tab 0 (OWRITE) >>>
  }) : super(key: key);
  
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;

  final BookmarkService _bookmarkService = BookmarkService();
  List<Article> _allBookmarkedArticles = [];
  bool _isLoadingBookmarks = true;
  bool _isHandlingBookmark = false;

  DateTime? _lastPressedAt;

  @override
  void initState() {
    super.initState();

    // >>> INISIALISASI INDEX DARI PARAMETER >>>
    _selectedIndex = widget.initialTab;

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() => _selectedIndex = _tabController.index);
      }
    });

    // >>> ANIMASI KE TAB YANG DIPILIH >>>
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.initialTab != 0) {
        _tabController.animateTo(widget.initialTab);
      }
      if (!mounted) return;
      Provider.of<ArticleProvider>(context, listen: false)
          .loadArticles(refresh: true);
      _maybeAskNotificationPermission();
      _maybeAskLocationPermission();
    });

    _loadAllBookmarks();
  }

  @override
  void dispose() {
    _removeToast();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllBookmarks() async {
    if (mounted) setState(() => _isLoadingBookmarks = true);
    try {
      final bookmarks =
          await _bookmarkService.getAllBookmarkedArticlesSimple();
      if (mounted) {
        if (!listEquals(_allBookmarkedArticles.map((e) => e.id).toList(),
            bookmarks.map((e) => e.id).toList())) {
          setState(() {
            _allBookmarkedArticles = bookmarks;
          });
          debugPrint("Reloaded simple bookmarks. Count: ${bookmarks.length}");
        }
        setState(() => _isLoadingBookmarks = false);
      }
    } catch (e) {
      debugPrint("Error loading all simple bookmarks in MainScreen: $e");
      if (mounted) {
        setState(() => _isLoadingBookmarks = false);
        _showErrorSnackBar('Gagal memuat daftar bookmark');
      }
    }
  }

  Future<void> _handleBookmarkToggle(
      BuildContext context, Article article) async {
    if (_isHandlingBookmark) {
      debugPrint("Bookmark action in progress...");
      return;
    }
    if (mounted) setState(() => _isHandlingBookmark = true);
    debugPrint("Handling simple bookmark toggle for: ${article.id}");

    final bool isCurrentlyBookmarked =
        _allBookmarkedArticles.any((a) => a.id == article.id);
    final authService = AuthService();
    final user = await authService.getCurrentUser();
    // Commented out: Original guest check with login redirect
    // final bool isGuest = user == null || user['username'] == 'Guest';
    // if (isGuest) {
    //   _showLoginRequiredSnackBar("Masuk untuk menyimpan artikel ini");
    //   if (mounted) setState(() => _isHandlingBookmark = false);
    //   return;
    // }

    // New: Show notification instead of redirecting to login
    _showBookmarkDisabledSnackBar("Tidak bisa menyimpan artikel untuk saat ini");
    if (mounted) setState(() => _isHandlingBookmark = false);
    return;

    // Commented out: Original bookmark functionality
    // try {
    //   if (isCurrentlyBookmarked) {
    //     debugPrint("Attempting to remove simple bookmark...");
    //     bool removed = await _bookmarkService.removeBookmark(article);
    //     if (removed && mounted) {
    //       debugPrint("Bookmark removed, reloading state...");
    //       await _loadAllBookmarks();
    //       _showSuccessSnackBar('Artikel dihapus dari bookmark');
    //     } else {
    //       debugPrint("Bookmark remove reported false.");
    //       if (mounted) await _loadAllBookmarks();
    //     }
    //   } else {
    //     debugPrint("Attempting to add simple bookmark...");
    //     bool added = await _bookmarkService.addSimpleBookmark(article);
    //     if (added && mounted) {
    //       debugPrint("Bookmark added, reloading state...");
    //       await _loadAllBookmarks();
    //       _showSuccessSnackBar('Artikel disimpan ke bookmark');
    //     } else if (!added && mounted) {
    //       await _loadAllBookmarks();
    //       _showSuccessSnackBar('Artikel sudah ada di bookmark');
    //     }
    //   }
    // } catch (e) {
    //   debugPrint("Error during simple bookmark toggle: $e");
    //   if (mounted) {
    //     _showErrorSnackBar('Terjadi kesalahan bookmark: ${e.toString()}');
    //   }
    // } finally {
    //   debugPrint("Resetting bookmark handling flag.");
    //   if (mounted) setState(() => _isHandlingBookmark = false);
    // }
  }

  void _showBookmarkDisabledSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.yellow[700]),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    setState(() => _selectedIndex = index);
    _tabController.animateTo(index);
  }

  Future<void> _maybeAskNotificationPermission() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false)
        .locale
        .languageCode;
    final strings = AppStrings(lang);

    // Hanya jalankan permission di HP, bukan di web.
    if (kIsWeb) {
      return;
    }

    PermissionStatus status = await Permission.notification.status;
    debugPrint("Notification permission status: $status");

    if (status.isDenied || status.isLimited) {
      PermissionStatus requestedStatus =
          await Permission.notification.request();
      debugPrint(
          "Notification permission requested, new status: $requestedStatus");
      if (requestedStatus.isGranted || requestedStatus.isLimited) {
        final bgService = BackgroundNotificationService();
        await bgService.setNotificationsEnabled(true);
        debugPrint("✅ Notification permission granted, background service enabled");
      } else if (requestedStatus.isPermanentlyDenied && mounted) {
        _showPermissionPermanentlyDeniedDialog(
          title: 'Notifikasi Dinonaktifkan',
          content:
              'Untuk menerima rekomendasi artikel, silakan aktifkan notifikasi di pengaturan perangkat Anda.',
          strings: strings,
        );
      }
    } else if (status.isPermanentlyDenied && mounted) {
      _showPermissionPermanentlyDeniedDialog(
        title: 'Notifikasi Dinonaktifkan',
        content:
            'Untuk menerima rekomendasi artikel, silakan aktifkan notifikasi di pengaturan perangkat Anda.',
        strings: strings,
      );
    } else if (status.isGranted || status.isProvisional) {
      final bgService = BackgroundNotificationService();
      await bgService.setNotificationsEnabled(true);
      debugPrint("✅ Notification permission already granted, background service enabled");
    }
  }

  Future<void> _maybeAskLocationPermission() async {
    if (!mounted) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false)
        .locale
        .languageCode;
    final strings = AppStrings(lang);

    // Hanya jalankan permission di HP, bukan di web.
    if (kIsWeb) {
      return;
    }

    PermissionStatus status = await Permission.locationWhenInUse.status;
    debugPrint("Location permission status: $status");

    if (status.isDenied || status.isLimited) {
      PermissionStatus requestedStatus =
          await Permission.locationWhenInUse.request();
      debugPrint(
          "Location permission requested, new status: $requestedStatus");
      if (requestedStatus.isPermanentlyDenied && mounted) {
        _showPermissionPermanentlyDeniedDialog(
          title: 'Lokasi Dinonaktifkan',
          content:
              'Untuk menyesuaikan berita dengan wilayah Anda, silakan aktifkan akses lokasi di pengaturan perangkat Anda.',
          strings: strings,
        );
      }
    } else if (status.isPermanentlyDenied && mounted) {
      _showPermissionPermanentlyDeniedDialog(
        title: 'Lokasi Dinonaktifkan',
        content:
            'Untuk menyesuaikan berita dengan wilayah Anda, silakan aktifkan akses lokasi di pengaturan perangkat Anda.',
        strings: strings,
      );
    } else if (status.isGranted) {
      debugPrint("Location permission already granted.");
    }
  }

  Future<void> _showPermissionPermanentlyDeniedDialog({
    required String title,
    required String content,
    required AppStrings strings,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              strings.cancel,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: Text(
              'Pengaturan',
              style: TextStyle(
                color: Colors.yellow[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          bookmarkedArticles: _allBookmarkedArticles,
          onBookmarkToggle: (article) =>
              _handleBookmarkToggle(context, article),
        );
      case 1:
        return QuickScreen(
          bookmarkedArticles: _allBookmarkedArticles,
          onBookmarkToggle: (article) =>
              _handleBookmarkToggle(context, article),
        );
      case 2:
        return const WatchScreen();
      case 3:
        return LinkScreen(
          onNavigateToHome: () => _onItemTapped(0),
        );
      default:
        return Container(color: Colors.grey);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'TUTUP',
          textColor: Colors.white,
          onPressed: () =>
              ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              message.toLowerCase().contains("hapus")
                  ? Icons.bookmark_remove_rounded
                  : Icons.bookmark_add_rounded,
              color: message.toLowerCase().contains("hapus")
                  ? Colors.red[300]
                  : const Color(0xFFE5FF10),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF333333),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showLoginRequiredSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Colors.yellow[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'LOGIN',
          textColor: Colors.yellow[700],
          onPressed: () => _onItemTapped(3),
        ),
      ),
    );
  }

  OverlayEntry? _toastOverlayEntry;
  
  void _showExitConfirmationToast() {
    if (!mounted) return;
    
    // Hapus toast sebelumnya jika ada
    _removeToast();
    
    final overlay = Overlay.of(context);
    _toastOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/icon-app.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Tekan sekali lagi untuk keluar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(_toastOverlayEntry!);
    
    // Hapus overlay setelah 2 detik
    Future.delayed(const Duration(seconds: 2), () {
      _removeToast();
    });
  }
  
  void _removeToast() {
    if (_toastOverlayEntry != null) {
      _toastOverlayEntry!.remove();
      _toastOverlayEntry = null;
    }
  }

  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      _onItemTapped(0);
      return false;
    }

    final now = DateTime.now();
    final maxDuration = const Duration(seconds: 2);
    final isWarning =
        _lastPressedAt == null || now.difference(_lastPressedAt!) > maxDuration;

    if (isWarning) {
      _lastPressedAt = now;
      _showExitConfirmationToast();
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final hideBottomNav = _selectedIndex == 1;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(4, (index) => _buildPage(index)),
        ),
        bottomNavigationBar: hideBottomNav ? null : _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color background =
        isDark ? kBottomNavDarkColor : kBottomNavLightColor;

    final Color activeColor = isDark ? const Color(0xFFE5FF10) : Colors.black;
    final Color inactiveColor =
        isDark ? Colors.grey[700]! : Colors.grey[500]!;

    // Helper: Convert Color to hex (for SVG fill)
    String colorToHex(Color color) {
      return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    }

    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[400]!,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Custom SVG Home icon + "OWRITE"
              Expanded(
                child: InkWell(
                  onTap: () => _onItemTapped(0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: Center(
                            child: SvgPicture.string(
                              '''
                              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
                                <path fill="${_selectedIndex == 0 ? colorToHex(activeColor) : colorToHex(inactiveColor)}" d="M12.581 2.686a1 1 0 0 0-1.162 0l-9.5 6.786l1.162 1.627L12 4.73l8.919 6.37l1.162-1.627zm7 10l-7-5a1 1 0 0 0-1.162 0l-7 5a1 1 0 0 0-.42.814V20a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-6.5a1 1 0 0 0-.418-.814M6 19v-4.985l6-4.286l6 4.286V19z"/>
                              </svg>
                              ''',
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'OWRITE',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              _selectedIndex == 0 ? activeColor : inactiveColor,
                          fontWeight: _selectedIndex == 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Custom item for "QUICK"
              Expanded(
                child: InkWell(
                  onTap: () => _onItemTapped(1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: Center(
                            child: SvgPicture.string(
                              '''
                              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
                                <path fill="${_selectedIndex == 1 ? colorToHex(activeColor) : colorToHex(inactiveColor)}" d="M12.5 4.252a.75.75 0 0 0-1.005-.705l-6.84 2.475A1.75 1.75 0 0 0 3.5 7.667v6.082a.75.75 0 0 0 1.005.705L5 14.275v1.595a2.25 2.25 0 0 1-3-2.12V7.666A3.25 3.25 0 0 1 4.144 4.61l6.84-2.475A2.25 2.25 0 0 1 14 4.252v.177l-1.5.543zm4 3a.75.75 0 0 0-1.005-.705L8.325 9.14a1.25 1.25 0 0 0-.825 1.176v6.432a.75.75 0 0 0 1.005.705L9 17.275v1.596a2.25 2.25 0 0 1-3-2.122v-6.432A2.75 2.75 0 0 1 7.814 7.73l7.17-2.595A2.25 2.25 0 0 1 18 7.252v.177l-1.5.543zm2.995 2.295a.75.75 0 0 1 1.005.705v6.783a.75.75 0 0 1-.495.705l-7.5 2.714a.75.75 0 0 1-1.005-.705v-6.783a.75.75 0 0 1 .495-.705zm2.505.705a2.25 2.25 0 0 0-3.016-2.116l-7.5 2.714A2.25 2.25 0 0 0 10 12.966v6.783a2.25 2.25 0 0 0 3.016 2.116l7.5-2.714A2.25 2.25 0 0 0 22 17.035z"/>
                              </svg>
                              ''',
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'QUICK',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              _selectedIndex == 1 ? activeColor : inactiveColor,
                          fontWeight: _selectedIndex == 1
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Custom item for "WATCH"
              Expanded(
                child: InkWell(
                  onTap: () => _onItemTapped(2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: Center(
                            child: SvgPicture.string(
                              '''
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 16 16"><g fill="none"><g clip-path="url(#gravityUiPlay0)"><path fill="${_selectedIndex == 2 ? colorToHex(activeColor) : colorToHex(inactiveColor)}" fill-rule="evenodd" d="M14.005 7.134L5.5 2.217a1 1 0 0 0-1.5.866v9.834a1 1 0 0 0 1.5.866l8.505-4.917a1 1 0 0 0 0-1.732m.751 3.03c1.665-.962 1.665-3.366 0-4.329L6.251.918C4.585-.045 2.5 1.158 2.5 3.083v9.834c0 1.925 2.085 3.128 3.751 2.164z" clip-rule="evenodd"/></g><defs><clipPath id="gravityUiPlay0"><path fill="#000000" d="M0 0h16v16H0z"/></clipPath></defs></g></svg>
                              ''',
                              width: 20,
                              height: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'WATCH',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              _selectedIndex == 2 ? activeColor : inactiveColor,
                          fontWeight: _selectedIndex == 2
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Custom Link SVG icon + "LINK"
              Expanded(
                child: InkWell(
                  onTap: () => _onItemTapped(3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: Center(
                            child: SvgPicture.string(
                              '''
                              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
                                <path fill="${_selectedIndex == 3 ? colorToHex(activeColor) : colorToHex(inactiveColor)}" d="M3.9 12c0-1.71 1.39-3.1 3.1-3.1h4V7H7c-2.76 0-5 2.24-5 5s2.24 5 5 5h4v-1.9H7c-1.71 0-3.1-1.39-3.1-3.1M8 13h8v-2H8v2m9-6h-4v1.9h4c1.71 0 3.1 1.39 3.1 3.1s-1.39 3.1-3.1 3.1h-4V17h4c2.76 0 5-2.24 5-5s-2.24-5-5-5Z"/>
                              </svg>
                              ''',
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'LINK',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              _selectedIndex == 3 ? activeColor : inactiveColor,
                          fontWeight: _selectedIndex == 3
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 26,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? activeColor : inactiveColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}