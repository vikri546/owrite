import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math'; // <-- BARU: Diperlukan untuk Random
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/parser.dart' show parse;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:flutter_tts/flutter_tts.dart'; // <-- HAPUS
import 'package:flutter/services.dart'; // Import untuk SystemUiOverlayStyle

// --- Impor flutter_html ---
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_video/flutter_html_video.dart'; // Untuk embed video
// --- Akhir Impor ---

import '../services/api_service.dart';
import '../models/article.dart';
import '../services/history_service.dart';
import '../main.dart';
import '../utils/auth_service.dart'; // Import AuthService
import '../services/audio_player_service.dart';
import '../widgets/snackbar_toggle.dart'; // <-- BARU: Impor snackbar kustom
import 'login_screen.dart'; // Import LoginScreen
import 'quick_screen.dart';
import 'in_app_browser_screen.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  final String heroTag;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;

  const ArticleDetailScreen({
    Key? key,
    required this.article,
    required this.heroTag,
    required this.isBookmarked,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

// HAPUS: Enum untuk ukuran font
// enum FontSize { small, medium, big }

class _ArticleDetailScreenState extends State<ArticleDetailScreen>
    with TickerProviderStateMixin {
  final String _geminiApiKey = dotenv.env['GOOGLE_TTS_API_KEY'] ?? '';
  final ApiService _apiService = ApiService();
  late ScrollController _scrollController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;

  // --- BARU: Variabel untuk animasi header ---
  late AnimationController _headerAnimController;
  late AnimationController _bottomBarAnimController;
  // late Animation<Offset> _headerSlideAnimation; // <-- MODIFIKASI: Dihapus
  double _lastScrollOffset = 0.0;
  bool _isHeaderVisible = true;
  bool _isBottomBarVisible = true;
  // --- AKHIR BARU ---

  final HistoryService _historyService = HistoryService();
  final AuthService _authService = AuthService();
  bool _isLoggedIn = false;

  // --- HAPUS Variabel FlutterTts ---
  // late FlutterTts _flutterTts;
  // bool _isTtsInitialized = false;
  // --- AKHIR HAPUS ---

  AudioPlayerService get _audioService => AudioPlayerService.instance;
  AudioPlayer get _audioPlayer => _audioService.player;

  // --- BARU: State untuk Topik Terkait ---
  List<Article> _relatedArticles = [];
  bool _isLoadingRelated = true;
  String? _relatedError;
  // --- AKHIR BARU ---

  // --- BARU: Variabel untuk loading swipe ---
  bool _isSwiping = false;
  // --- AKHIR BARU ---

  void _navigateToQuickScreen() async {
    // Hentikan TTS jika sedang berjalan
    if (_isSpeaking || _isLoading) {
      await _stopSpeaking();
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuickScreen(
          bookmarkedArticles: [],
          onBookmarkToggle: (article) {
            if (article.id == widget.article.id) {
              widget.onBookmarkToggle();
            }
          },
          initialArticle: widget.article,
          hideFullPageButton: true,
          blockScroll: true, // >>> TAMBAHKAN INI >>>
        ),
      ),
    );
  }

  // Fungsi untuk navigasi ke Quick Screen asli (halaman Quick normal)
  void _navigateToQuickScreenOriginal() async {
    // Hentikan TTS jika sedang berjalan
    if (_isSpeaking || _isLoading) {
      await _stopSpeaking();
    }

    // >>> MODIFIKASI: Gunakan Navigator.push (bukan popUntil) >>>
    // Ini akan membuat Quick Screen ditambahkan ke stack navigasi
    // Sehingga saat back, akan kembali ke Article Detail
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuickScreen(
          bookmarkedArticles: [], // List bookmark kosong atau bisa di-pass dari widget
          onBookmarkToggle: (article) {
            // Handle bookmark toggle jika diperlukan
            // Bisa kosongkan atau sesuaikan dengan kebutuhan
          },
          // >>> TIDAK ADA initialArticle, hideFullPageButton, dan blockScroll >>>
          // Ini akan membuat Quick Screen berjalan normal seperti di MainScreen
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _addToHistory();
    _scrollController = ScrollController();
    _isBookmarkedLocal = widget.isBookmarked;

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _slideController, curve: Curves.decelerate));

    // --- BARU: Inisialisasi animasi header ---
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    /* <-- MODIFIKASI: Dihapus
    _headerSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1), // Slide ke atas untuk sembunyi
    ).animate(CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.fastOutSlowIn,
    ));
    */
    _headerAnimController.value = 0.0; // Mulai dengan header terlihat
    // --- AKHIR BARU ---
    _bottomBarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _bottomBarAnimController.value = 0.0;

    // PERBAIKAN: Setup listener dengan cleanup otomatis
    _setupAudioPlayerListener();

    // _initializeFlutterTts(); // <-- HAPUS

    // --- BARU: Tambahkan listener ke scroll controller ---
    _scrollController.addListener(_scrollListener);
    // --- AKHIR BARU ---

    // --- BARU: Panggil fungsi untuk fetch data terkait ---
    _fetchRelatedArticles();
    // --- AKHIR BARU ---

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeController.forward();
      _slideController.forward();
    });
  }

  // TAMBAHKAN method baru ini
  void _setupAudioPlayerListener() {
    // Remove listener lama jika ada (penting untuk hot restart)
    debugPrint("🎧 Setting up audio player listener");
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      debugPrint("AudioPlayer state: $state");
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _isLoading = false;
            // _isPaused = false; // <-- HAPUS
            // _currentTtsMode = ""; // <-- HAPUS
          });
        }
      }
    });
  }

  // TAMBAHKAN method ini untuk hot restart
  @override
  void reassemble() {
    super.reassemble();
    debugPrint("🔥 Hot restart detected - resetting audio");
    
    // Force reset audio player
    AudioPlayerService.forceReset();
    
    // Reset state
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isLoading = false;
        // _isPaused = false; // <-- HAPUS
        // _currentTtsMode = ""; // <-- HAPUS
      });
    }
    
    // Setup listener lagi
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _setupAudioPlayerListener();
      }
    });
  }

  // --- BARU: Scroll Listener untuk Header ---
  void _scrollListener() {
    final currentOffset = _scrollController.offset;
    final direction = currentOffset - _lastScrollOffset;

    // Jangan lakukan apa-apa jika scroll kecil (debounce) atau di paling atas
    if (direction.abs() < 10 || currentOffset < 0) return;

    if (direction > 0 && currentOffset > kToolbarHeight) {
      // Scrolling Down -> Hide both header and bottom bar
      if (_isHeaderVisible) {
        _headerAnimController.forward();
        if (mounted) {
          setState(() {
            _isHeaderVisible = false;
          });
        }
      }
      if (_isBottomBarVisible) {
        _bottomBarAnimController.forward();
        if (mounted) {
          setState(() {
            _isBottomBarVisible = false;
          });
        }
      }
    } else if (direction < 0) {
      // Scrolling Up -> Show both header and bottom bar
      if (!_isHeaderVisible) {
        _headerAnimController.reverse();
        if (mounted) {
          setState(() {
            _isHeaderVisible = true;
          });
        }
      }
      if (!_isBottomBarVisible) {
        _bottomBarAnimController.reverse();
        if (mounted) {
          setState(() {
            _isBottomBarVisible = true;
          });
        }
      }
    }

    _lastScrollOffset = currentOffset.clamp(0, _scrollController.position.maxScrollExtent);
  }
  // --- AKHIR BARU ---

  @override
  void dispose() {
    debugPrint("🗑️ Disposing ArticleDetailScreen");
    
    // --- BARU: Hapus listener dan dispose controller ---
    _scrollController.removeListener(_scrollListener);
    _headerAnimController.dispose();
    _bottomBarAnimController.dispose();
    // --- AKHIR BARU ---

    _scrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    
    // --- HAPUS Pengecekan FlutterTts ---
    // if (_isTtsInitialized) {
    //    _flutterTts.stop();
    // }
    // --- AKHIR HAPUS ---
    
    // GANTI dengan service reset
    _audioService.reset();
    
    super.dispose();
  }

  bool _isSpeaking = false;
  bool _isLoading = false;
  // bool _isPaused = false; // <-- HAPUS
  String _fullTextForSpeech = "";

  // --- HAPUS Variabel Word Highlight ---
  // int _currentWordStart = -1;
  // int _currentWordEnd = -1;
  // final GlobalKey _richTextKey = GlobalKey();
  // --- AKHIR HAPUS ---

  // String _currentTtsMode = ""; // <-- HAPUS
  late bool _isBookmarkedLocal;

  // --- MODIFIKASI: State untuk ukuran font ---
  // HAPUS: State untuk ukuran font
  // FontSize _currentFontSize = FontSize.medium;
  // final Map<FontSize, double> _fontSizeMap = {
  //   FontSize.small: 15.0,
  //   FontSize.medium: 18.0,
  //   FontSize.big: 21.0,
  // };
  
  // BARU: State untuk 5 ukuran font
  final List<double> _fontSizes = [14.0, 16.0, 18.0, 20.0, 22.0];
  int _currentFontSizeIndex = 2; // Default ke index 2 (18.0)
  // --- AKHIR MODIFIKASI ---

  Future<void> _checkLoginStatus() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _isLoggedIn = user != null && user['username'] != 'Guest';
      });
    }
  }

  Future<void> _addToHistory() async {
    try {
      await _historyService.addToHistory(widget.article);
      debugPrint('Article added to history: ${widget.article.title}');
    } catch (e) {
      debugPrint('Error adding to history: $e');
    }
  }

  // --- FUNGSI BARU UNTUK MEMETAKAN KODE BAHASA ---
  /// Memetakan kode bahasa ISO 639-1 (misal "id") ke locale BCP 47 (misal "id-ID")
  /// Ini memberikan petunjuk yang lebih baik untuk engine TTS.
  String _getTtsLocale(String? articleLanguage) {
    if (articleLanguage == null || articleLanguage.isEmpty) {
      return 'id-ID'; // Default ke Indonesia jika tidak ada info
    }

    final Map<String, String> commonLocales = {
      'id': 'id-ID', // Indonesia
      'en': 'en-US', // Inggris (US)
      'es': 'es-ES', // Spanyol (Spanyol)
      'fr': 'fr-FR', // Perancis (Perancis)
      'de': 'de-DE', // Jerman (Jerman)
      'ja': 'ja-JP', // Jepang
      'ko': 'ko-KR', // Korea
      'zh': 'zh-CN', // Mandarin (China)
      'ru': 'ru-RU', // Rusia
      'ar': 'ar-SA', // Arab (Saudi)
      'pt': 'pt-BR', // Portugis (Brazil)
      'it': 'it-IT', // Italia
      'nl': 'nl-NL', // Belanda
      'tr': 'tr-TR', // Turki
      'vi': 'vi-VN', // Vietnam
      'th': 'th-TH', // Thailand
      'hi': 'hi-IN', // Hindi
      'sv': 'sv-SE', // Swedia
      'pl': 'pl-PL', // Polandia
      'el': 'el-GR', // Yunani
    };

    // 1. Cek apakah kode bahasa (misal "en") ada di peta umum
    if (commonLocales.containsKey(articleLanguage)) {
      return commonLocales[articleLanguage]!;
    }

    // 2. Cek apakah kodenya sudah merupakan locale (misal "en-GB")
    if (articleLanguage.contains('-') || articleLanguage.contains('_')) {
      return articleLanguage;
    }

    // 3. Jika hanya 2 huruf (misal "uk" untuk Ukraina), coba gunakan itu secara langsung
    if (articleLanguage.length == 2) {
      return articleLanguage;
    }

    // 4. Fallback default
    return 'id-ID';
  }

  // --- HAPUS SELURUH FUNGSI _initializeFlutterTts ---
  // Future<void> _initializeFlutterTts() async { ... }
  // --- AKHIR HAPUS ---

  // --- BARU: Fungsi untuk mengambil artikel terkait ---
  Future<void> _fetchRelatedArticles() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRelated = true;
      _relatedError = null;
    });

    try {
      // Ambil artikel dari kategori yang sama
      // Minta 5 artikel, untuk difilter 1 (jika artikel saat ini muncul) dan diambil 4
      final articles = await _apiService.getArticlesByCategory(
        widget.article.category,
        page: 1,
        pageSize: 5, // Ambil 5 untuk jaga-jaga
      );

      // Filter artikel saat ini dari daftar, lalu ambil 4 sisanya
      final related = articles
          .where((a) => a.id != widget.article.id)
          .take(4) // Ambil 4 artikel
          .toList();

      if (!mounted) return;
      setState(() {
        _relatedArticles = related;
        _isLoadingRelated = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingRelated = false;
        _relatedError = "Gagal memuat topik terkait.";
        debugPrint("Error fetching related articles: $e");
      });
    }
  }
  // --- AKHIR BARU ---


  // --- BARU: Method untuk fetch artikel random ---
  Future<void> _fetchAndNavigateToRandomArticle() async {
    if (_isSwiping) return; // Jangan swipe jika sedang memuat

    // Hanya jalankan di mobile
    if (kIsWeb) return;
    // Platform.isAndroid || Platform.isIOS
    if (!Platform.isAndroid && !Platform.isIOS) return;

    if (mounted) {
      setState(() {
        _isSwiping = true;
      });
    }

    // Tampilkan overlay loading sederhana
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Mencari artikel lain..."),
          ],
        ),
        duration: const Duration(seconds: 10), // Durasi panjang, akan ditutup manual
      ),
    );

    try {
      // Ambil 50 artikel terbaru dari kategori APAPUN (null)
      // Ambil dari halaman random antara 1-3
      final randomPage = Random().nextInt(3) + 1;
      final articles = await _apiService.getArticlesByCategory(
        null, // Kategori apapun
        page: randomPage,
        pageSize: 50,
      );

      // Filter artikel saat ini
      final otherArticles = articles.where((a) => a.id != widget.article.id).toList();

      if (otherArticles.isEmpty) {
        throw Exception("Tidak menemukan artikel lain.");
      }

      // Ambil satu secara acak
      final randomArticle = otherArticles[Random().nextInt(otherArticles.length)];
      final String heroTag = 'swipe_${randomArticle.id}_${UniqueKey().toString()}';

      // Hentikan TTS jika sedang berjalan
      if (_isSpeaking || _isLoading) {
        await _stopSpeaking();
      }

      // Tutup snackbar loading
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Navigasi GANTI layar saat ini
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ArticleDetailScreen(
            article: randomArticle,
            heroTag: heroTag,
            // Asumsikan artikel baru belum di-bookmark
            isBookmarked: false, 
            // Teruskan callback bookmark
            onBookmarkToggle: widget.onBookmarkToggle, 
          ),
        ),
      );

    } catch (e) {
      debugPrint("Error swiping to random article: $e");
      // Tutup snackbar loading
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // Tampilkan error
      if (mounted) {
        _showErrorSnackBar("Gagal memuat artikel lain.");
      }
      if (mounted) {
        setState(() {
          _isSwiping = false;
        });
      }
    }
  }
  // --- AKHIR BARU ---

  // --- BARU: Handler untuk gesture swipe ---
  void _handleHorizontalSwipe(DragEndDetails details) {
    // Hanya di mobile
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    // Cek velocity
    final double velocity = details.primaryVelocity ?? 0;

    // Swipe ke kiri (velocity < 0) atau kanan (velocity > 0)
    if (velocity.abs() > 300) { // Butuh swipe yang cukup kencang
      _fetchAndNavigateToRandomArticle();
    }
  }
  // --- AKHIR BARU ---

  void _popWithResult(BuildContext context) {
    final result = {'isBookmarked': _isBookmarkedLocal};
    Navigator.pop(context, result);
  }

  void _showFocusedImage(BuildContext context, String? imageUrl, String heroTag,
      String title, String category) {
    if (imageUrl == null || imageUrl.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.9),
      useSafeArea: false,
      builder: (BuildContext context) {
        return _FocusedImageView(
            imageUrl: imageUrl, heroTag: heroTag, title: title, category: category);
      },
    );
  }

  String _stripHtml(String htmlString) {
    final document = parse(htmlString);
    final String? text = document.body?.text;
    return text != null ? parse(text).documentElement!.text.trim() : '';
  }

  String _formatDateRelative(DateTime dateTime) {
    try {
      final Duration difference = DateTime.now().difference(dateTime);
      if (difference.inDays > 7)
        return DateFormat('d MMM y', 'id_ID').format(dateTime);
      if (difference.inDays >= 1) return '${difference.inDays} hari lalu';
      if (difference.inHours >= 1) return '${difference.inHours} jam lalu';
      if (difference.inMinutes >= 1) return '${difference.inMinutes} mnt lalu';
      return 'Baru saja';
    } catch (e) {
      return DateFormat('d MMM y', 'id_ID').format(dateTime);
    }
  }

  Future<void> _launchURL(String urlString) async {
    try {
      // Cek apakah berjalan di platform mobile (Android/iOS)
      if (Theme.of(context).platform == TargetPlatform.android ||
          Theme.of(context).platform == TargetPlatform.iOS) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => InAppBrowserScreen(
              url: urlString,
              title: widget.article.title,
            ),
          ),
        );
      } else {
        // Jika tidak di handphone, tampilkan notifikasi/snackbar
        _showErrorSnackBar(
          'Fitur ini hanya bisa dibuka di handphone (Android atau iOS).'
        );
      }
    } catch (e) {
      _showErrorSnackBar('Gagal membuka browser:\n$urlString');
    }
  }

  // --- HAPUS FUNGSI MODAL TTS ---
  // Future<void> _showTtsModeSelection() async { ... }
  // Widget _buildTtsModeOption({ ... }) { ... }
  // --- AKHIR HAPUS ---

  // --- PERBAIKAN: Logika _toggleSpeech diubah total ---
  Future<void> _toggleSpeech() async {
    if (_isLoading) return; // Jangan lakukan apa-apa saat loading

    if (_isSpeaking) {
      // --- MODIFIKASI: Jika sedang play, panggil stop ---
      await _stopSpeaking();
    } else {
      // --- MODIFIKASI: Jika berhenti total, MULAI DARI AWAL ---
      _fullTextForSpeech = _prepareTextForSpeech();
      await _startGeminiTts();
    }
  }

  // --- HAPUS FUNGSI _pauseSpeech ---
  // Future<void> _pauseSpeech() async { ... }
  // --- AKHIR HAPUS ---


  // --- HAPUS FUNGSI _resumeSpeech ---
  // Future<void> _resumeSpeech() async { ... }
  // --- AKHIR HAPUS ---

  // --- HAPUS FUNGSI _startNormalTts ---
  // Future<void> _startNormalTts() async { ... }
  // --- AKHIR HAPUS ---

  Future<void> _startGeminiTts() async {
    if (_geminiApiKey == "AIzaSyDa3Fo_obfSV_DTUo8OmaSUiR7U7KllYEs" || _geminiApiKey.isEmpty) {
      _showDetailedErrorDialog("API Key Belum Dikonfigurasi",
          "Gunakan 'Suara Normal' untuk saat ini.");
      return;
    }

    if (!mounted) return;
    setState(() {
      // _currentTtsMode = "gemini"; // <-- HAPUS
      _isLoading = true;  
      // _isPaused = false; // <-- HAPUS
    });

    await _fetchAndPlayGeminiTts();
  }

  // --- HAPUS FUNGSI _speakWithFlutterTts ---
  // Future<void> _speakWithFlutterTts() async { ... }
  // --- AKHIR HAPUS ---

  // GANTI SELURUH FUNGSI _fetchAndPlayGeminiTts DENGAN INI:
  Future<void> _fetchAndPlayGeminiTts() async {
    if (_fullTextForSpeech.isEmpty) {
      _showErrorSnackBar("Tidak ada teks untuk dibacakan");
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    final String? apiKey = dotenv.env['GOOGLE_TTS_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      _showDetailedErrorDialog("API Key Belum Dikonfigurasi",
          "Gunakan 'Suara Normal' untuk saat ini.");
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    // Gunakan endpoint v1 (production-ready)
    final String apiUrl = "https://texttospeech.googleapis.com/v1/text:synthesize";

    // Untuk Gemini TTS, gunakan voice name dengan format: {languageCode}-{voiceType}-{variant}
    // Contoh: id-ID-Neural2-A, en-US-Neural2-C
    // Pilih suara secara acak dari daftar 3 karakter
    final voiceCharacters = [
      "id-ID-Chirp3-HD-Zephyr",
      "id-ID-Chirp3-HD-Charon",
      "id-ID-Chirp3-HD-Leda"
    ];
    voiceCharacters.shuffle();
    final selectedVoice = voiceCharacters.first;

    final payload = jsonEncode({
      "input": { "text": _fullTextForSpeech },
      "voice": {
        "languageCode": "id-ID",
        "name": selectedVoice
      },
      "audioConfig": {
        "audioEncoding": "MP3",
        "speakingRate": 1.04,      // Sedikit lebih cepat dari default (1.0) agar terdengar lebih natural
        // "pitch": -1.0, // Voice does not support pitch, so we remove it
        "volumeGainDb": 0.5        // Sedikit meningkatkan volume agar lebih terdengar
      }
    });
    // final payload = jsonEncode({
    //  "input": { "text": _fullTextForSpeech },
    //  "voice": {
    //    "languageCode": "id-ID",
    //    "name": "Leda",        // 🔑 gunakan nama voice dari Gemini TTS
    //    "modelName": "gemini-2.5-pro-tts" // atau "gemini-2.5-flash-tts"
    //  },
    //  "audioConfig": {
    //    "audioEncoding": "MP3",
    //    "speakingRate": 1.0,
    //    "pitch": 0.0
    //  }
    // });

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint("Mengirim request ke Cloud TTS API (Gemini)...");
      debugPrint("URL: $apiUrl?key=***");

      final response = await http
          .post(
            Uri.parse("$apiUrl?key=$apiKey"),
            headers: {
              'Content-Type': 'application/json',
            },
            body: payload,
          )
          .timeout(const Duration(seconds: 60));

      debugPrint("Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final String? audioData = result['audioContent'];

        if (audioData != null) {
          debugPrint("Audio MP3 diterima, ukuran: ${audioData.length} bytes (base64)");
          
          final audioBytes = base64Decode(audioData);
          debugPrint("Audio decoded, ukuran: ${audioBytes.length} bytes");

          await _audioPlayer.play(BytesSource(audioBytes));

          if (mounted) {
            setState(() {
              _isLoading = false;
              _isSpeaking = true;
              // _isPaused = false; // <-- HAPUS
            });
          }
        } else {
          throw Exception("Tidak ada data audio dalam respons");
        }
      } else {
        debugPrint("Error ${response.statusCode}: ${response.body}");
        
        String errorMessage = "Error tidak diketahui";
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['error']['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = response.body;
        }
        
        throw Exception("HTTP ${response.statusCode}: $errorMessage");
      }
    } on TimeoutException {
      _showErrorSnackBar("Request timeout. Periksa koneksi internet Anda.");
      if (mounted) {
        setState(() {  
          _isLoading = false;  
          _isSpeaking = false;  
          // _isPaused = false; // <-- HAPUS
          // _currentTtsMode = ""; // <-- HAPUS  
        });
      }
    } catch (e) {
      debugPrint("Error fetching Cloud TTS: $e");
      _showErrorSnackBar("Gagal memuat audio: ${e.toString()}");
      if (mounted) {
        setState(() {  
          _isLoading = false;  
          _isSpeaking = false;  
          // _isPaused = false; // <-- HAPUS
          // _currentTtsMode = ""; // <-- HAPUS  
        });
      }
    }
  }

  // --- PERUBAHAN DI SINI ---
  Future<void> _stopSpeaking() async {
    try {
      // --- HAPUS Pengecekan Mode ---
      // if (_currentTtsMode == "normal") {
      //    await _flutterTts.stop();
      // } else if (_currentTtsMode == "gemini") {
      //    await _audioPlayer.stop();
      // }
      await _audioPlayer.stop();
      // --- AKHIR HAPUS ---

      // BLOK INI DIHAPUS:
      // State akan di-reset oleh listener (onPlayerStateChanged untuk gemini)
      // atau cancel handler (setCancelHandler untuk normal) secara otomatis.
      // --- PERBAIKAN: Tetap lakukan reset manual untuk memastikan ---
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isLoading = false;
          // _isPaused = false; // <-- HAPUS
          // _currentTtsMode = ""; // <-- HAPUS
          // _currentWordStart = -1; // <-- HAPUS
          // _currentWordEnd = -1; // <-- HAPUS
        });
      }
    } catch (e) {
      debugPrint("Error stopping TTS: $e");
      // Biarkan reset state di blok catch, ini untuk keamanan jika stop() gagal
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isLoading = false;
          // _isPaused = false; // <-- HAPUS
          // _currentTtsMode = ""; // <-- HAPUS
          // _currentWordStart = -1; // <-- HAPUS
          // _currentWordEnd = -1; // <-- HAPUS
        });
      }
    }
  }
  // --- AKHIR PERUBAHAN ---

  // --- HAPUS FUNGSI _scrollTo ---
  // void _scrollTo(int startOffset) { ... }
  // --- AKHIR HAPUS ---

  String _prepareTextForSpeech() {
    StringBuffer buffer = StringBuffer();
    // Set default locale untuk pemformatan, tapi TTS akan menggunakan bahasanya sendiri
    Intl.defaultLocale = 'id_ID';

    buffer.writeln(widget.article.title);
    buffer.writeln();

    final String? authorString = widget.article.author?.replaceAll(' / ', ', ');
    final String? penulisString = widget.article.penulis;
    final bool hasAuthor = authorString != null &&
        authorString.isNotEmpty &&
        authorString != 'Unknown Author';
    final bool hasPenulis =
        penulisString != null && penulisString.isNotEmpty;

    if (hasAuthor) buffer.write("Author $authorString. ");
    if (hasAuthor && hasPenulis) buffer.write(" | ");
    if (hasPenulis) buffer.write("Penulis $penulisString. ");
    if (hasAuthor || hasPenulis) buffer.writeln();

    // -- PERUBAHAN: Jangan paksakan format tanggal 'WIB' jika artikel internasional --
    // Gunakan format yang lebih netral jika bahasa bukan 'id'
    /* KODE YANG DIHAPUS KARENA ERROR
    final bool isIndonesian = (widget.article.language ?? 'id') == 'id';
    
    final DateFormat updateDateFormat = isIndonesian
        ? DateFormat('MMMM d, yyyy, h:mm a', 'id_ID')
        : DateFormat('MMMM d, yyyy, h:mm a', 'en_US'); // Fallback ke format EN

    String updateString = "Update ${updateDateFormat.format(widget.article.modifiedAt)}";
    if (isIndonesian) updateString += " WIB";
    */ // --- AKHIR KODE YANG DIHAPUS ---

    // --- KODE BARU (MENGEMBALIKAN KE LOGIKA AWAL) ---
    final DateFormat updateDateFormat = DateFormat('MMMM d, yyyy, h:mm a');
    final String updateString =
        "Update ${updateDateFormat.format(widget.article.modifiedAt)} WIB";
    // --- AKHIR KODE BARU ---

    buffer.writeln(updateString);
    buffer.writeln();

    String? content = widget.article.content ?? widget.article.description;
    if (content != null && content.isNotEmpty) {
      String cleanContent = _stripHtml(content);
      
      // Hanya lakukan penggantian spesifik bahasa jika kita yakin ini bahasa Indonesia
      /* KODE YANG DIHAPUS KARENA ERROR
      if (isIndonesian) {
        cleanContent = cleanContent
            .replaceAll("dll.", "dan lain-lain")
            .replaceAll("dsb.", "dan sebagainya")
            .replaceAll("Yth.", "Yang terhormat");
      }
      buffer.write(cleanContent);
      */ // --- AKHIR KODE YANG DIHAPUS ---

      // --- KODE BARU (MENGEMBALIKAN KE LOGIKA AWAL) ---
      cleanContent = cleanContent
          .replaceAll("dll.", "dan lain-lain")
          .replaceAll("dsb.", "dan sebagainya")
          .replaceAll("Yth.", "Yang terhormat");
      buffer.write(cleanContent);
      // --- AKHIR KODE BARU ---
    } else {
      buffer.write("Konten tidak tersedia.");
    }

    return buffer.toString();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message))
        ]),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
            label: 'TUTUP',
            textColor: Colors.white,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar())));
  }

  // --- FUNGSI INI DIHAPUS ---
  /*
  void _showBookmarkSnackbar(bool isBookmarked) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isBookmarked ? 'Artikel disimpan ke bookmark' : 'Bookmark dihapus',
          style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFE0E0E0)
            : const Color(0xFF333333),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.fixed,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }
  */
  // --- AKHIR FUNGSI YANG DIHAPUS ---

  void _showLoginRequiredPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const Color customGreen = Color(0xFF39e011);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.black,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20)
              .copyWith(
            bottom: MediaQuery.of(context).viewPadding.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Buat akun untuk menyimpan artikel ini',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  ).then((_) => _checkLoginStatus());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: customGreen,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Lanjutkan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDetailedErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('TUTUP'),
          ),
        ],
      ),
    );
  }

  void _shareArticle() {
    final String title = widget.article.title;
    String description = _stripHtml(widget.article.description ?? "");
    if (description.isNotEmpty) {
      const int maxLength = 200;
      if (description.length > maxLength) {
        description = description.substring(0, maxLength) + "...";
      }
    } else {
      description = "Tidak ada deskripsi.";
    }
    final String author = (widget.article.author != null &&
            widget.article.author!.isNotEmpty &&
            widget.article.author != "Unknown Author")
        ? widget.article.author!
        : "Tidak diketahui";
    final String publishDate =
        DateFormat('d MMM y, HH:mm', 'id_ID').format(widget.article.publishedAt);
    final String tag = "#${widget.article.category.toLowerCase()}";
    final String link = widget.article.url;
    final String shareContent = """
  Judul: $title

  Deskripsi: $description

  Author: $author
  Tanggal: $publishDate
  Tag: $tag

  Baca selengkapnya disini:
  $link
  """;

    Share.share(shareContent, subject: title);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Intl.defaultLocale = 'id_ID';

    return WillPopScope(
      onWillPop: () async {
        // --- MODIFIKASI: Hapus pengecekan _isPaused ---
        if (_isSpeaking || _isLoading) await _stopSpeaking();
        _popWithResult(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          toolbarHeight: 0,
          elevation: 0,
          backgroundColor: isDark ? Colors.black : Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: isDark ? Colors.black : Colors.white,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        // --- MODIFIKASI: `body` sekarang dibungkus GestureDetector ---
        body: GestureDetector( // <-- DITAMBAHKAN
          onHorizontalDragEnd: _handleHorizontalSwipe, // <-- DITAMBAHKAN
          child: Column(
            children: [
              // --- MODIFIKASI: Header Bar ditambahkan di sini & dibungkus animasi ---
              SizeTransition( // <-- MODIFIKASI: Diganti dari SlideTransition
                axis: Axis.vertical,
                axisAlignment: -1.0, // Kolaps ke arah atas
                sizeFactor: CurvedAnimation(
                  parent: _headerAnimController,
                  curve: Curves.fastOutSlowIn,
                ).drive(Tween<double>(begin: 1.0, end: 0.0)), // Animasikan ukuran dari 1.0 ke 0.0
                child: _buildHeaderBar(context),
              ),
              // --- MODIFIKASI: CustomScrollView dibungkus di dalam Expanded ---
              Expanded(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: AnimatedBuilder(
                        animation: _slideController,
                        builder: (context, child) => FadeTransition(
                            opacity: _fadeInAnimation,
                            child: SlideTransition(position: _slideAnimation, child: child)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // --- MODIFIKASI BARU: Kategori, Waktu, dan Judul ---
                            Padding(
                              padding: const EdgeInsets.fromLTRB(23.0, 16.0, 23.0, 20.0), // Beri padding bawah
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 1. Kategori (DIPINDAH DARI BAWAH)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // --- MODIFIKASI: ClipPath untuk Jajar Genjang ---
                                      ClipPath(
                                        clipper: ParallelogramClipper(skew: 10.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 4), // Padding disesuaikan
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE5FF10),
                                            // borderRadius: BorderRadius.circular(5), // <-- HAPUS
                                          ),
                                          child: Text(
                                            widget.article.category.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // --- MODIFIKASI: Waktu publish dan separator dihapus dari sini ---
                                      // const SizedBox(width: 8),
                                      // Text(
                                      //    '•',
                                      // ...
                                      // ),
                                      // const SizedBox(width: 8),
                                      // Text(
                                      //    _formatDateRelative(widget.article.publishedAt),
                                      // ...
                                      // ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // 2. Title (DIPINDAH DARI _buildStandardView)
                                  Text(
                                    widget.article.title,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Domine',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 28,
                                      letterSpacing: 0.3,
                                      height: 1.3,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // --- AKHIR MODIFIKASI BARU ---

                            // 3. Gambar (Posisi setelah header baru)
                            if (widget.article.urlToImage != null)
                              Column(
                                children: [
                                  // --- MODIFIKASI DIMULAI ---
                                  // Menambahkan Padding untuk 'jarak' horizontal 23.0
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 23.0),
                                    child: GestureDetector(
                                      onTap: () => _showFocusedImage(
                                          context,
                                          widget.article.urlToImage,
                                          widget.heroTag,
                                          widget.article.title,
                                          widget.article.category),
                                      child: Hero(
                                        tag: widget.heroTag,
                                        // Menambahkan ClipRRect untuk 'radius 5'
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(5.0),
                                          child: CachedNetworkImage(
                                            imageUrl: widget.article.urlToImage!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 250,
                                            placeholder: (c, u) => Container(
                                                color: Colors.grey[300],
                                                height: 250,
                                                child: const Center(
                                                    child: CircularProgressIndicator())),
                                            errorWidget: (c, u, e) => Container(
                                                color: Colors.grey[300],
                                                height: 250,
                                                child: const Center(
                                                    child: Icon(Icons.image_not_supported,
                                                        color: Colors.grey, size: 50))),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // --- MODIFIKASI SELESAI ---

                                  if (widget.article.imageCaption != null &&
                                      widget.article.imageCaption!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12.0, left: 24.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 2,
                                            margin: const EdgeInsets.only(right: 8, top: 8),
                                            decoration: BoxDecoration(
                                              color: Color(0xFFE5FF10),
                                              borderRadius: BorderRadius.circular(0),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              widget.article.imageCaption!,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontStyle: FontStyle.italic,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  
                                  // <<<===== MODIFIKASI: TAMBAHKAN TOMBOL TTS BARU DI SINI =====>>>
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _buildTtsPlayBar(context),
                                  ),
                                  // <<<===== AKHIR MODIFIKASI =====>>>

                                  Padding(
                                    // Beri jarak dari tombol TTS baru, dan beri jarak horizontal 23
                                    padding: const EdgeInsets.only(top: 20.0, bottom: 8.0, left: 23.0, right: 23.0),  
                                    child: Container(
                                      width: double.infinity,
                                      height: 1,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF888888),
                                        borderRadius: BorderRadius.zero,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            
                            // 4. Author, Update, Konten, dll.
                            Padding(
                              padding: const EdgeInsets.all(23.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // --- KATEGORI & WAKTU DIHAPUS DARI SINI ---
                                  // --- SIZEDBOX DIHAPUS DARI SINI ---

                                  // _buildStandardView sekarang HANYA berisi Author/Update & Konten
                                  // --- MODIFIKASI: Hapus pengecekan mode TTS ---
                                  // if (_isSpeaking && _currentTtsMode == "normal")
                                  //    _buildReadingView(context)
                                  // else
                                  //    _buildStandardView(context),
                                  _buildStandardView(context),
                                  // --- AKHIR MODIFIKASI ---

                                  if (widget.article.tags.isNotEmpty) ...[
                                    const SizedBox(height: 24),
                                    _buildTagsSection(context),
                                    const SizedBox(height: 24),
                                  ] else ...[
                                    const SizedBox(height: 24),
                                  ],
                                  Center(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _launchURL(widget.article.url),
                                      icon: Icon(
                                        _getPlatformIcon(),
                                        size: 20,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFFE5FF10)
                                            : Colors.black,
                                      ),
                                      label: Text(
                                        _getPlatformButtonText(),
                                        style: TextStyle(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFFE5FF10)
                                              : Colors.black,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20)),
                                        side: BorderSide(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFFE5FF10)
                                              : Colors.black,
                                        ),
                                        foregroundColor: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFFE5FF10)
                                            : Colors.black, // Icon & text color
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Center(
                                  //   child: Row(
                                  //     mainAxisSize: MainAxisSize.min,
                                  //     mainAxisAlignment: MainAxisAlignment.center,
                                  //     children: [
                                  //       Icon(_getPlatformInfoIcon(),
                                  //           size: 14, color: Colors.grey[600]),
                                  //       const SizedBox(width: 6),
                                  //       Text(
                                  //         _getPlatformInfoText(),
                                  //         style: TextStyle(
                                  //             color: Colors.grey[600],
                                  //             fontSize: 12,
                                  //             fontWeight: FontWeight.w500),
                                  //       ),
                                  //     ],
                                  //   ),
                                  // ),
                                  
                                  // <<<===== MODIFIKASI DI SINI =====>>>
                                  // Ganti SizedBox(height: 80) dengan prompt swipe
                                  const SizedBox(height: 20), // <-- DIHAPUS
                                  _buildSwipePrompt(context), // <-- DITAMBAHKAN
                                  
                                  // Beri jarak sisa
                                  const SizedBox(height: 30), // <-- Ganti 80 jadi (padding 24 + ~26 + sisa 30)
                                  // <<<===== AKHIR MODIFIKASI =====>>>
                                ],
                              ),
                            ),

                            // --- BARU: Tambahkan widget topik terkait di sini ---
                            _buildRelatedTopicsSection(),
                            const SizedBox(height: 24), // Padding di bagian paling bawah
                            // --- AKHIR BARU ---
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // --- MODIFIKASI: bottomNavigationBar dihapus ---
        // bottomNavigationBar: _buildMainBottomBar(context),
        bottomNavigationBar: SizeTransition(
          axis: Axis.vertical,
          axisAlignment: 1.0, // Kolaps ke arah bawah
          sizeFactor: CurvedAnimation(
            parent: _bottomBarAnimController,
            curve: Curves.fastOutSlowIn,
          ).drive(Tween<double>(begin: 1.0, end: 0.0)),
          child: _buildBottomNavBar(context),
        ),
      ),
    );
  }

  // --- BARU: Widget untuk petunjuk swipe ---
  Widget _buildSwipePrompt(BuildContext context) {
    // Hanya tampilkan di mobile (Android/iOS)
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return const SizedBox.shrink(); // Jangan tampilkan di web
    }

    final Color hintColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[600]!
        : Colors.grey[500]!;

    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 24.0), // Beri jarak
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_back_ios_new, size: 14, color: hintColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              "Geser untuk artikel lainnya",
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: hintColor,
              ),
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 14, color: hintColor),
        ],
      ),
    );
  }
  // --- AKHIR BARU ---

  // --- MODIFIKASI: Fungsi ini diubah dari _buildMainBottomBar menjadi _buildHeaderBar ---
  Widget _buildHeaderBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Ambil padding atas (status bar)
    final double topPadding = MediaQuery.of(context).viewPadding.top;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(
          // --- MODIFIKASI: Border diubah dari 'top' ke 'bottom' ---
          bottom: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1),
        ),
      ),
      // --- MODIFIKASI: SafeArea(top: false) dihapus ---
      child: Padding(
        // --- MODIFIKASI: Padding disesuaikan untuk status bar ---
        padding: EdgeInsets.only(
          left: 4.0,
          right: 4.0,
          bottom: 4.0,
          top: topPadding + 4.0, // Menambahkan padding status bar + padding asli
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Kiri: Kembali
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: isDark ? Colors.white : Colors.black,
                    size: 24,
                  ),
                  onPressed: () async {
                    if (_isSpeaking || _isLoading) await _stopSpeaking();
                    _popWithResult(context);
                  },
                  padding: const EdgeInsets.all(12),
                ),
                // --- MODIFIKASI: Tombol font lama dihapus dari sini ---
                // _buildFontMenuButton(), // BARU: Tombol menu font
              ],
            ),

            // Kanan: Font, Bookmark, Share
            Row(
              children: [
                // --- MODIFIKASI: Tombol font BARU ditambahkan di sini ---
                _buildNewFontMenuButton(),
                // Bookmark icon muncul dulu baru share
                BookmarkIconButton(
                  isBookmarked: _isBookmarkedLocal,
                  onToggle: () {
                    if (_isLoggedIn) {
                      widget.onBookmarkToggle();
                      final newBookmarkState = !_isBookmarkedLocal;
                      setState(() {
                        _isBookmarkedLocal = newBookmarkState;
                      });
                      // --- PERUBAHAN DI SINI ---
                      // Memanggil fungsi snackbar dari file utilitas
                      showBookmarkSnackbar(context, newBookmarkState);
                      // --- AKHIR PERUBAHAN ---
                    } else {
                      _showLoginRequiredPanel();
                    }
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.share,
                    color: isDark ? Colors.white : Colors.black,
                    size: 22,
                  ),
                  onPressed: _shareArticle,
                  padding: const EdgeInsets.all(12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- MODIFIKASI: FUNGSI _buildFontMenuButton LAMA DIHAPUS ---
  // Widget _buildFontMenuButton() { ... }
  // --- AKHIR FUNGSI YANG DIHAPUS ---

  // --- MODIFIKASI: FUNGSI BARU UNTUK TOMBOL FONT "aA" ---
  /// Widget untuk tombol menu font "aA" yang baru dan popup style mirip gambar UI
  Widget _buildNewFontMenuButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;
    final popupBorderColor = isDark
        ? Colors.grey[500]!
        : Colors.grey[600]!.withOpacity(0.35);

    return PopupMenuButton<int>(
      onSelected: (int index) {
        setState(() {
          _currentFontSizeIndex = index;
        });
      },
      offset: const Offset(0, 44),
      padding: EdgeInsets.zero,
      color: isDark ? const Color(0xFF161616) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: popupBorderColor, width: 1.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem<int>(
            value: -1,
            enabled: false,
            padding: EdgeInsets.zero,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setPopupState) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 18.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161616) : Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_fontSizes.length, (index) {
                      final size = _fontSizes[index];
                      final bool isSelected = _currentFontSizeIndex == index;
                      final Color color = isSelected
                          ? Colors.red
                          : (isDark ? Colors.white70 : Colors.black54);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentFontSizeIndex = index;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          width: 47,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: index < _fontSizes.length - 1
                                ? Border(
                                    right: BorderSide(
                                      color: isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[300]!,
                                      width: 1,
                                    ),
                                  )
                                : null,
                          ),
                          child: Text(
                            "A",
                            style: TextStyle(
                              fontFamily: 'Domine',
                              fontSize: size,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
        ];
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 11.0, left: 12, right: 12, bottom: 7),
        child: SizedBox(
          width: 26,
          height: 26,
          child: SvgPicture.string(
            '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="none" stroke="${iconColor is Color ? '#${iconColor.value.toRadixString(16).substring(2)}' : '#000000'}" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 15.5a3.5 3.5 0 1 0 7 0a3.5 3.5 0 1 0-7 0M14 19V8.5a3.5 3.5 0 0 1 7 0V19m-7-6h7m-11-1v7"/>
</svg>
            ''',
            color: iconColor,
            width: 24,
            height: 24,
          ),
        ),
      ),
    );
  }
  // --- AKHIR FUNGSI BARU ---


  // --- MODIFIKASI: Judul (Text) dihapus dari fungsi ini ---
  Widget _buildStandardView(BuildContext context) {
    // final isDark = Theme.of(context).brightness == Brightness.dark; // Tidak terpakai lagi
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Text(widget.article.title, ...) <-- DIPINDAHKAN KE ATAS
        // const SizedBox(height: 16), <-- DIHAPUS
        _buildMetaInfoSection(context),
        const SizedBox(height: 16),
        
        // >>> TAMBAHKAN TOMBOL QUICK DI SINI >>>
        _buildQuickButton(context),
        const SizedBox(height: 24),
        // --- PERUBAHAN: Hapus "..." (spread operator) ---
        _buildContentWithBlockquotes(widget.article.content),
        // --- AKHIR PERUBAHAN ---
      ],
    );
  }

  // --- HAPUS FUNGSI _buildReadingView ---
  // Widget _buildReadingView(BuildContext context) { ... }
  // --- AKHIR HAPUS ---

  Widget _buildMetaInfoSection(BuildContext context) {
    final String? penulisString = widget.article.penulis;
    final bool hasPenulis = penulisString != null && penulisString.isNotEmpty;

    // --- MODIFIKASI: Format tanggal digabungkan ---
    final DateFormat consistentFormat = DateFormat('d MMM y, HH:mm', 'id_ID');
    
    final String publishString = consistentFormat.format(widget.article.publishedAt);
    final String updateString = "Update ${consistentFormat.format(widget.article.modifiedAt)} WIB";

    final String combinedDateString = "$publishString | $updateString";
    // --- AKHIR MODIFIKASI ---

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.article.authorList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                "Author: ${widget.article.authorList.map((a) => a['name']).join(', ')}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withOpacity(0.9),
                    ),
              ),
            ),
          if (hasPenulis)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                "Penulis: $penulisString",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withOpacity(0.9),
                    ),
              ),
            ),
          // --- MODIFIKASI: Tampilkan string tanggal gabungan ---
          Text(
            combinedDateString,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.local_offer,
          size: 16,
          color: isDark ? Colors.grey[400] : Colors.grey[700],
        ),
        const SizedBox(width: 4),
        Text(
          "Tag: ",
          style: TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        Flexible(
          child: Text(
            widget.article.tags.map((tag) => "#$tag").join(", "),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // --- HAPUS FUNGSI _buildTtsIconButton ---
  // Widget _buildTtsIconButton() { ... }
  // --- AKHIR HAPUS ---

  // <<<===== MODIFIKASI: FUNGSI BARU UNTUK TOMBOL TTS =====>>>
  /// Widget untuk tombol Play/Pause/Continue TTS yang lebar di bawah gambar
  Widget _buildTtsPlayBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // State baru untuk support "Paused"
    // _isSpeaking: sedang berjalan, _isPaused: sedang pause
    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.black.withOpacity(0.13);
    final Color bgColor = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.05);

    late Color iconColor;
    if (_isLoading) {
      iconColor = isDark ? Colors.white54 : Colors.black54;
    // --- HAPUS LOGIKA WARNA _isPaused ---
    // } else if (_isPaused) {
    //    iconColor = Colors.amber;
    } else if (_isSpeaking) {
      iconColor = Colors.redAccent;
    } else {
      iconColor = isDark ? Colors.white : Colors.black87;
    }

    late Color textColor;
    if (isDark) {
      // --- HAPUS LOGIKA WARNA _isPaused ---
      // if (_isPaused) {
      //    textColor = Colors.amber;
      // } else 
      if (_isSpeaking) {
        textColor = Colors.redAccent;
      } else {
        textColor = Colors.white;
      }
    } else {
      // --- HAPUS LOGIKA WARNA _isPaused ---
      // if (_isPaused) {
      //    textColor = Colors.amber[900]!;
      // } else 
      if (_isSpeaking) {
        textColor = Colors.red;
      } else {
        textColor = Colors.black87;
      }
    }

    // --- PERBAIKAN: _onTtsPlayBarTap disederhanakan ---
    void _onTtsPlayBarTap() {
      if (_isLoading) return;
      _toggleSpeech(); // _toggleSpeech sekarang menangani semua state
    }

    IconData getIcon() {
      if (_isLoading) {
        return Icons.hourglass_empty;
      // --- MODIFIKASI: Hapus _isPaused, ubah ikon _isSpeaking ---
      } else if (_isSpeaking) {
        return Icons.stop_rounded; // Tampilkan 'Stop' saat jalan
      } else {
        return Icons.play_arrow_rounded; // Tampilkan 'Play' saat berhenti
      }
    }

    String getButtonText() {
      if (_isLoading) {
        return "Process...";
      // --- MODIFIKASI: Hapus _isPaused, ubah teks _isSpeaking ---
      } else if (_isSpeaking) {
        return "Berhenti";
      } else {
        return "Dengarkan";
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18.0, 16.0, 18.0, 0.0), // PERBAIKAN: Tambah padding kanan
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: _onTtsPlayBarTap,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 1.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min, // Buat agar tombol tidak selebar layar
              mainAxisAlignment: MainAxisAlignment.center, // Pusatkan isi tombol
              children: [
                _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(iconColor.withOpacity(0.7)),
                        ),
                      )
                    : Icon(
                        getIcon(),
                        color: iconColor,
                        size: 24,
                      ),
                const SizedBox(width: 12),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  child: Text(
                    getButtonText(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // <<<===== AKHIR FUNGSI BARU =====>>>

  Widget _buildQuickButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0), // jarak kiri + kanan sama
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToQuickScreen(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity, // agar lebar ikut parent (padding sudah mengatur batas)
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    "Read a summary of this article on",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFFE5FF10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        "QUICK",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.bolt,
                        size: 16,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16), // padding kanan biar sama dengan kiri
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- PERUBAHAN BESAR: FUNGSI INI DIGANTI TOTAL ---
  /// Fungsi ini sekarang mengembalikan satu Widget (Html) bukan List<Widget>
  /// dan menggunakan flutter_html untuk me-render semua blok Gutenberg.
  Widget _buildContentWithBlockquotes(String? content) {
    // --- MODIFIKASI: Menggunakan state font size baru ---
    final currentFontSize = _fontSizes[_currentFontSizeIndex];
    // --- AKHIR MODIFIKASI ---
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String? htmlData = (content != null && content.isNotEmpty)
        ? content
        : widget.article.description;

    if (htmlData == null || htmlData.isEmpty) {
      return const Text(
        "Konten lengkap tidak tersedia.",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontStyle: FontStyle.italic,
          fontFamily: 'SourceSerif4',
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
      );
    }

    // Gaya dasar untuk semua teks
    final baseTextStyle = TextStyle(
      fontFamily: 'SourceSerif4',
      fontWeight: FontWeight.w400,
      fontSize: currentFontSize, // <-- Diganti dari _fontSizeMap
      height: 1.6,
      color: isDark ? Colors.white70 : Colors.black87,
    );

    return Html(
      data: htmlData,
      extensions: [
        VideoHtmlExtension(), // <video> and <iframe>
        TagExtension(
          tagsToExtend: {"img"},
          builder: (context) {
            final src = context.attributes['src'];
            final imageHeroTag = src ?? UniqueKey().toString();
            if (src == null) return const SizedBox.shrink();
            return GestureDetector(
              onTap: () {
                _showFocusedImage(
                  context.buildContext!,
                  src,
                  imageHeroTag,
                  widget.article.title,
                  widget.article.category,
                );
              },
              child: Image.network(src, fit: BoxFit.contain),
            );
          },
        ),
        TagExtension(
          tagsToExtend: {"blockquote"},
          builder: (context) {
            // Detect if blockquote memiliki class wp-block-quote agar tetap backward compatible
            final el = context.element;
            final classes = el?.classes ?? {};
            if (el == null || (!classes.contains("wp-block-quote") && el.localName != "blockquote")) {
              return const SizedBox.shrink();
            }

            final pTags = el.getElementsByTagName('p');
            final citeTags = el.getElementsByTagName('cite');

            final String mainQuote =
                pTags.map((p) => p.text.trim()).join('\n').trim();
            final String? authorQuote = citeTags.isNotEmpty
                ? citeTags.first.text.trim()
                : null;

            final isDark = Theme.of(context.buildContext!).brightness == Brightness.dark;
            // --- MODIFIKASI: Menggunakan state font size baru ---
            final currentFontSize = _fontSizes[_currentFontSizeIndex];
            // --- AKHIR MODIFIKASI ---

            if (mainQuote.isEmpty) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 16, top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850]?.withOpacity(0.5) : Colors.grey[100],
                borderRadius: BorderRadius.vertical(top: Radius.circular(16), bottom: Radius.circular(10)),
                border: Border(
                  left: BorderSide(
                    color: const Color(0xFFE5FF10),
                    width: 4,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.format_quote,
                    color: const Color(0xFFE5FF10),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mainQuote,
                          style: TextStyle(
                            fontFamily: 'SourceSerif4',
                            fontWeight: FontWeight.w300,
                            fontSize: currentFontSize - 1,
                            height: 1.6,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.grey[200] : Colors.grey[900],
                          ),
                        ),
                        if (authorQuote != null && authorQuote.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 0.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28,
                                  height: 1.2,
                                  margin: const EdgeInsets.only(top: 11, right: 8),
                                  color: const Color(0xFFE5FF10),
                                ),
                                Expanded(
                                  child: Text(
                                    authorQuote,
                                    style: TextStyle(
                                      fontFamily: 'SourceSerif4',
                                      fontWeight: FontWeight.normal,
                                      fontSize: currentFontSize - 2,
                                      height: 1.5,
                                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
      onLinkTap: (url, _, __) {
        if (url != null) _launchURL(url);
      },
      style: {
        "body": Style.fromTextStyle(baseTextStyle).copyWith(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
        ),
        "p": Style.fromTextStyle(baseTextStyle).copyWith(
          margin: Margins.only(bottom: 16),
        ),
        "h1": Style.fromTextStyle(baseTextStyle.copyWith(
          fontFamily: 'Domine',
          fontWeight: FontWeight.bold,
          fontSize: currentFontSize * 1.6,
          height: 1.4,
          color: isDark ? Colors.white : Colors.black,
        )).copyWith(
          margin: Margins.only(top: 28, bottom: 12),
        ),
        "h2": Style.fromTextStyle(baseTextStyle.copyWith(
          fontFamily: 'Domine',
          fontWeight: FontWeight.bold,
          fontSize: currentFontSize * 1.4,
          height: 1.4,
          color: isDark ? Colors.white : Colors.black,
        )).copyWith(
          margin: Margins.only(top: 24, bottom: 12),
        ),
        "h3": Style.fromTextStyle(baseTextStyle.copyWith(
          fontFamily: 'Domine',
          fontWeight: FontWeight.bold,
          fontSize: currentFontSize * 1.25,
          height: 1.4,
          color: isDark ? Colors.white : Colors.black,
        )).copyWith(
          margin: Margins.only(top: 20, bottom: 10),
        ),
        "h4, h5, h6": Style.fromTextStyle(baseTextStyle.copyWith(
          fontFamily: 'Domine',
          fontWeight: FontWeight.w600,
          fontSize: currentFontSize * 1.1,
          height: 1.4,
          color: isDark ? Colors.white : Colors.black,
        )).copyWith(
          margin: Margins.only(top: 18, bottom: 10),
        ),
        "ul, ol": Style(
          margin: Margins.only(bottom: 16),
          padding: HtmlPaddings.only(left: 24),
        ),
        "li": Style.fromTextStyle(baseTextStyle).copyWith(
          lineHeight: LineHeight(1.7),
        ),
        "figure.wp-block-image": Style(
          margin: Margins.only(top: 8, bottom: 16),
          padding: HtmlPaddings.zero,
        ),
        "figure.wp-block-image img": Style(
          width: Width.auto(),
        ),
        "figure.wp-block-image figcaption": Style.fromTextStyle(TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: Colors.grey[600],
        )).copyWith(
          textAlign: TextAlign.center,
          padding: HtmlPaddings.only(top: 8),
        ),
        "iframe": Style(
          margin: Margins.only(top: 8, bottom: 16),
        ),
        "video": Style(
          margin: Margins.only(top: 8, bottom: 16),
        ),
      },
    );
  }
  // --- AKHIR FUNGSI YANG DIGANTI ---

  String _getPlatformButtonText() {
    return 'Baca di Browser';
  }

  IconData _getPlatformIcon() {
    if (kIsWeb) return Icons.open_in_new;
    if (Platform.isWindows) return Icons.desktop_windows_outlined;
    if (Platform.isAndroid) return Icons.android;
    if (Platform.isIOS) return Icons.apple;
    return Icons.open_in_browser;
  }

  String _getPlatformInfoText() {
    if (kIsWeb) return 'Membuka tab baru';
    if (Platform.isWindows) return 'Membuka di browser desktop';
    if (Platform.isAndroid || Platform.isIOS)
      return 'Membuka di browser eksternal';
    return 'Membuka di browser';
  }

  IconData _getPlatformInfoIcon() {
    if (kIsWeb) return Icons.web_asset_outlined;
    if (Platform.isWindows) return Icons.desktop_windows;
    if (Platform.isAndroid) return Icons.phone_android;
    if (Platform.isIOS) return Icons.phone_iphone;
    return Icons.devices_other;
  }

  // --- BARU: Widget untuk membangun bagian "Topik Terkait" ---
  Widget _buildRelatedTopicsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Handle loading
    if (_isLoadingRelated) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Handle error
    if (_relatedError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
          child: Text(
            _relatedError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    // Handle tidak ada artikel terkait
    if (_relatedArticles.isEmpty) {
      // Jangan tampilkan apa-apa jika tidak ada artikel terkait
      return const SizedBox.shrink();
    }

    // --- Build UI utama ---
    // Membuat padding horizontal pada border top agar sejajar dengan konten
    return Column(
      children: [
        // Garis pemisah dengan padding kiri-kanan mengikuti konten
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22.0),
          child: Divider(
            color: Color(0xFF888888),
            thickness: 1.0,
            height: 0, // Biar tidak menambah vertical spacing
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 23.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Judul Bagian
              const Text(
                "Topik yang Berhubungan",
                style: TextStyle(
                  fontFamily: 'Domine',
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),

              // 2. Grid 2x2
              GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 kolom
                  crossAxisSpacing: 16.0, // Jarak horizontal antar item
                  mainAxisSpacing: 16.0, // Jarak vertikal antar item
                  childAspectRatio: 0.9, // <-- MODIFIKASI: Diubah dari 0.7 ke 0.9
                ),
                itemCount: _relatedArticles.length, // Maksimal 4 (dari _fetchRelatedArticles)
                shrinkWrap: true, // Penting di dalam CustomScrollView
                physics: const NeverScrollableScrollPhysics(), // Penting di dalam CustomScrollView
                itemBuilder: (context, index) {
                  final article = _relatedArticles[index];
                  // Panggil widget card kustom
                  return _buildRelatedArticleCard(article);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
  // --- AKHIR BARU ---

  // --- BARU: Widget untuk 1 card di "Topik Terkait" ---
  Widget _buildRelatedArticleCard(Article article) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Buat hero tag unik untuk artikel terkait
    final String heroTag = 'related_${article.id}_${UniqueKey().toString()}';

    return GestureDetector(
      onTap: () {
        // Hentikan TTS jika sedang berjalan sebelum pindah halaman
        if (_isSpeaking || _isLoading) {
          _stopSpeaking();
        }

        // Navigasi ke layar detail baru untuk artikel yang diklik
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailScreen(
              article: article,
              heroTag: heroTag,
              isBookmarked: false,
              onBookmarkToggle: widget.onBookmarkToggle,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 1. Gambar
          Hero(
            tag: heroTag,
            child: CachedNetworkImage(
              imageUrl: article.urlToImage ?? 'https://placehold.co/300x200/e0e0e0/9e9e9e?text=No+Image',
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 120,
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, url, error) => Container(
                height: 120,
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: Center(child: Icon(Icons.image_not_supported, color: Colors.grey[600])),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Judul
          Expanded(
            child: Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Domine',
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.4,
                color: isDark
                    ? Colors.white.withOpacity(0.9)
                    : Colors.black.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // --- AKHIR BARU ---
  Widget _buildBottomNavBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color background = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final Color activeColor = isDark ? const Color(0xFFE5FF10) : Colors.black;
    final Color inactiveColor = isDark ? Colors.grey[700]! : Colors.grey[500]!;
    final Color borderTopColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    // Helper: Convert Color to hex (for SVG fill)
    String colorToHex(Color color) {
      return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    }

    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: BorderSide(
            color: borderTopColor, // Clearly visible border on top depending on theme
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // OWRITE (Home)
              Expanded(
                child: InkWell(
                  onTap: () {
                    // Kembali ke home (pop semua sampai first route)
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
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
                                <path fill="${colorToHex(inactiveColor)}" d="M12.581 2.686a1 1 0 0 0-1.162 0l-9.5 6.786l1.162 1.627L12 4.73l8.919 6.37l1.162-1.627zm7 10l-7-5a1 1 0 0 0-1.162 0l-7 5a1 1 0 0 0-.42.814V20a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-6.5a1 1 0 0 0-.418-.814M6 19v-4.985l6-4.286l6 4.286V19z"/>
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
                          color: inactiveColor,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // QUICK
              Expanded(
                child: InkWell(
                  onTap: () => _navigateToQuickScreenOriginal(),
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
                                <path fill="${colorToHex(inactiveColor)}" d="M12.5 4.252a.75.75 0 0 0-1.005-.705l-6.84 2.475A1.75 1.75 0 0 0 3.5 7.667v6.082a.75.75 0 0 0 1.005.705L5 14.275v1.595a2.25 2.25 0 0 1-3-2.12V7.666A3.25 3.25 0 0 1 4.144 4.61l6.84-2.475A2.25 2.25 0 0 1 14 4.252v.177l-1.5.543zm4 3a.75.75 0 0 0-1.005-.705L8.325 9.14a1.25 1.25 0 0 0-.825 1.176v6.432a.75.75 0 0 0 1.005.705L9 17.275v1.596a2.25 2.25 0 0 1-3-2.122v-6.432A2.75 2.75 0 0 1 7.814 7.73l7.17-2.595A2.25 2.25 0 0 1 18 7.252v.177l-1.5.543zm2.995 2.295a.75.75 0 0 1 1.005.705v6.783a.75.75 0 0 1-.495.705l-7.5 2.714a.75.75 0 0 1-1.005-.705v-6.783a.75.75 0 0 1 .495-.705zm2.505.705a2.25 2.25 0 0 0-3.016-2.116l-7.5 2.714A2.25 2.25 0 0 0 10 12.966v6.783a2.25 2.25 0 0 0 3.016 2.116l7.5-2.714A2.25 2.25 0 0 0 22 17.035z"/>
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
                          color: inactiveColor,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // WATCH
              Expanded(
                child: InkWell(
                  onTap: () {
                    // Navigasi langsung ke WATCH tab tanpa berhenti di home
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const MainScreen(initialTab: 2),
                      ),
                      (route) => false, // Hapus semua route sebelumnya
                    );
                  },
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
  <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 16 16"><g fill="none"><g clip-path="url(#gravityUiPlay0)"><path fill="${colorToHex(inactiveColor)}" fill-rule="evenodd" d="M14.005 7.134L5.5 2.217a1 1 0 0 0-1.5.866v9.834a1 1 0 0 0 1.5.866l8.505-4.917a1 1 0 0 0 0-1.732m.751 3.03c1.665-.962 1.665-3.366 0-4.329L6.251.918C4.585-.045 2.5 1.158 2.5 3.083v9.834c0 1.925 2.085 3.128 3.751 2.164z" clip-rule="evenodd"/></g><defs><clipPath id="gravityUiPlay0"><path fill="#000000" d="M0 0h16v16H0z"/></clipPath></defs></g></svg>
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
                          color: inactiveColor,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // ACCOUNT
              Expanded(
                child: InkWell(
                  onTap: () {
                    // Navigasi langsung ke ACCOUNT tab tanpa berhenti di home
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const MainScreen(initialTab: 3),
                      ),
                      (route) => false, // Hapus semua route sebelumnya
                    );
                  },
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
                                <path fill="${colorToHex(inactiveColor)}" d="M12 4a4 4 0 0 1 4 4a4 4 0 0 1-4 4a4 4 0 0 1-4-4a4 4 0 0 1 4-4m0 2a2 2 0 0 0-2 2a2 2 0 0 0 2 2a2 2 0 0 0 2-2a2 2 0 0 0-2-2m0 7c2.67 0 8 1.33 8 4v3H4v-3c0-2.67 5.33-4 8-4m0 1.9c-2.97 0-6.1 1.46-6.1 2.1v1.1h12.2V17c0-.64-3.13-2.1-6.1-2.1Z"/>
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
                        'ACCOUNT',
                        style: TextStyle(
                          fontSize: 12,
                          color: inactiveColor,
                          fontWeight: FontWeight.normal,
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
}

class BookmarkIconButton extends StatefulWidget {
  final bool isBookmarked;
  final VoidCallback onToggle;
  const BookmarkIconButton(
      {Key? key, required this.isBookmarked, required this.onToggle})
      : super(key: key);
  @override
  State<BookmarkIconButton> createState() => _BookmarkIconButtonState();
}

class _BookmarkIconButtonState extends State<BookmarkIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late bool _isBookmarkedLocalAnim;

  @override
  void initState() {
    super.initState();
    _isBookmarkedLocalAnim = widget.isBookmarked;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.5)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.5, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant BookmarkIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBookmarked != _isBookmarkedLocalAnim) {
      _isBookmarkedLocalAnim = widget.isBookmarked;
      if (_isBookmarkedLocalAnim) {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Tentukan warna ikon default berdasarkan tema
    final defaultIconColor = isDark ? Colors.white : Colors.black;

    return IconButton(
      icon: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.scale(
                scale: _scaleAnimation.value,
                child: Icon(
                  _isBookmarkedLocalAnim ? Icons.bookmark : Icons.bookmark_border,
                  color: _isBookmarkedLocalAnim
                      ? Theme.of(context).colorScheme.primary
                      : defaultIconColor,
                  size: 24,
                ))),
      onPressed: widget.onToggle,
      tooltip:
          widget.isBookmarked ? 'Hapus dari koleksi' : 'Simpan ke koleksi',
      padding: const EdgeInsets.all(12), // Samakan padding
    );
  }
}

class _FocusedImageView extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  final String title;
  final String category;
  const _FocusedImageView(
      {Key? key,
      required this.imageUrl,
      required this.heroTag,
      required this.title,
      required this.category})
      : super(key: key);
  @override
  State<_FocusedImageView> createState() => _FocusedImageViewState();
}

class _FocusedImageViewState extends State<_FocusedImageView> {
  // bool _showOverlayText = true; // <-- DIHAPUS
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.pop(context), // Tap di background untuk menutup
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
                child: Hero(
                    tag: widget.heroTag,
                    // --- TAMBAHAN WRAPPER INI ---
                    // Ini memperbaiki bug "blank screen" di HP saat Hero
                    // beranimasi ke dalam Dialog.
                    child: Material(
                      type: MaterialType.transparency,
                      child: InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          // GestureDetector di dalam sini dihapus
                          child: CachedNetworkImage(
                              imageUrl: widget.imageUrl,
                              fit: BoxFit.contain,
                              placeholder: (c, u) => const Center(
                                  child: CircularProgressIndicator()),
                              errorWidget: (c, u, e) => const Center(
                                  child: Icon(Icons.broken_image,
                                      color: Colors.white)))),
                    ))),
            
            // --- SEMUA BLOK "AnimatedOpacity" DIHAPUS ---
            // Ini adalah "efek" (overlay teks) yang Anda minta hilangkan.
            /*
            AnimatedOpacity(
              opacity: _showOverlayText ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_showOverlayText,
                child: Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(24).copyWith(top: 48),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent
                        ])),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration:
                                  const BoxDecoration(color: Colors.yellow),
                              child: Text(widget.category,
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold))),
                          const SizedBox(height: 8),
                          Text(widget.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4)
                                  ]),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis)
                        ]),
                  ),
                ),
              ),
            ),
            */
            // --- AKHIR BLOK YANG DIHAPUS ---
          ],
        ),
      ),
    );
  }
}

// --- BARU: CustomClipper untuk Kategori ---
/// Membuat bentuk jajar genjang (parallelogram) shape
class ParallelogramClipper extends CustomClipper<Path> {
  /// Seberapa miring (skew) bentuknya. Nilai lebih besar = lebih miring.
  final double skew;

  ParallelogramClipper({this.skew = 20.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    // Kiri atas (start di x=skew, y=0)
    path.moveTo(skew, 0.0);
    // Kanan atas (x=size.width, y=0)
    path.lineTo(size.width, 0.0);
    // Kanan bawah (x=size.width - skew, y=size.height)
    path.lineTo(size.width - skew, size.height);
    // Kiri bawah (x=0, y=size.height)
    path.lineTo(0.0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant ParallelogramClipper oldClipper) {
    return oldClipper.skew != skew;
  }
}
// --- AKHIR BARU ---


// --- HAPUS FUNGSI pcmToWav ---
// Fungsi ini tidak diperlukan karena API Google TTS dikonfigurasi
// untuk mengembalikan MP3, dan audioplayers dapat memutar MP3
// dari bytes (BytesSource) secara langsung.
/*
/// Mengonversi data audio PCM mentah (dari Gemini) menjadi format WAV
Uint8List pcmToWav(Uint8List pcmData, int sampleRate, int channels, int bitDepth) {
  int pcmSize = pcmData.lengthInBytes;
  int wavSize = pcmSize + 44; // 44 byte untuk header WAV
  int byteRate = (sampleRate * channels * bitDepth) ~/ 8;
  int blockAlign = (channels * bitDepth) ~/ 8;

  final header = ByteData(44);
  final data = Uint8List(wavSize);

  // RIFF chunk
  header.setUint32(0, 0x52494646, Endian.little); // "RIFF"
  header.setUint32(4, wavSize - 8, Endian.little); // Ukuran file - 8
  header.setUint32(8, 0x57415645, Endian.little); // "WAVE"

  // "fmt " sub-chunk
  header.setUint32(12, 0x666D7420, Endian.little); // "fmt "
  header.setUint32(16, 16, Endian.little); // Ukuran sub-chunk fmt (16 untuk PCM)
  header.setUint16(20, 1, Endian.little); // Format audio (1 untuk PCM)
  header.setUint16(22, channels.toUnsigned(16), Endian.little); // Jumlah channel
  header.setUint32(24, sampleRate.toUnsigned(32), Endian.little); // Sample rate
  header.setUint32(28, byteRate.toUnsigned(32), Endian.little); // Byte rate
  header.setUint16(32, blockAlign.toUnsigned(16), Endian.little); // Block align
  header.setUint16(34, bitDepth.toUnsigned(16), Endian.little); // Bits per sample

  // "data" sub-chunk
  header.setUint32(36, 0x64617461, Endian.little); // "data"
  header.setUint32(40, pcmSize.toUnsigned(32), Endian.little); // Ukuran data PCM

  // Gabungkan header dan data PCM
  data.setAll(0, header.buffer.asUint8List());
  data.setAll(44, pcmData);

  return data;
}
*/
// --- AKHIR HAPUS ---