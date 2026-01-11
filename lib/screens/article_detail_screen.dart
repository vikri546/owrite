import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
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
import 'package:flutter/services.dart';

// --- Impor flutter_html ---
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_video/flutter_html_video.dart';
// --- Akhir Impor ---

import '../services/api_service.dart';
import '../models/article.dart';
import '../services/history_service.dart';
import '../main.dart';
import '../utils/auth_service.dart';
import '../services/audio_player_service.dart';
import '../widgets/snackbar_toggle.dart';
import 'login_screen.dart';
import 'quick_screen.dart';
import 'in_app_browser_screen.dart';
import '../services/reading_tracker_service.dart';

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

class _ArticleDetailScreenState extends State<ArticleDetailScreen>
    with TickerProviderStateMixin {
  final String _geminiApiKey = dotenv.env['GOOGLE_TTS_API_KEY'] ?? '';
  final ApiService _apiService = ApiService();
  late ScrollController _scrollController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;

  late AnimationController _headerAnimController;
  late AnimationController _bottomBarAnimController;
  double _lastScrollOffset = 0.0;
  bool _isHeaderVisible = true;
  bool _isBottomBarVisible = true;

  final HistoryService _historyService = HistoryService();
  final AuthService _authService = AuthService();
  final ReadingTrackerService _readingTracker = ReadingTrackerService();
  bool _isLoggedIn = false;

  AudioPlayerService get _audioService => AudioPlayerService.instance;
  AudioPlayer get _audioPlayer => _audioService.player;

  List<Article> _relatedArticles = [];
  bool _isLoadingRelated = true;
  String? _relatedError;

  bool _isSwiping = false;

  void _navigateToQuickScreen() async {
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
          blockScroll: true,
        ),
      ),
    );
  }

  void _navigateToQuickScreenOriginal() async {
    if (_isSpeaking || _isLoading) {
      await _stopSpeaking();
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuickScreen(
          bookmarkedArticles: [],
          onBookmarkToggle: (article) {
            // Handle toggle
          },
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

    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _headerAnimController.value = 0.0;
    
    _bottomBarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _bottomBarAnimController.value = 0.0;

    _setupAudioPlayerListener();
    _scrollController.addListener(_scrollListener);
    _fetchRelatedArticles();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeController.forward();
      _slideController.forward();
    });
    
    // Start reading tracker
    _readingTracker.startReadingArticle(widget.article);
  }

  // --- PERBAIKAN UTAMA ADA DI SINI ---
  void _setupAudioPlayerListener() {
    debugPrint("🎧 Setting up audio player listener");
    
    // 1. Listen State Changed (Play/Pause/Stop)
    _audioPlayer.onPlayerStateChanged.listen((state) {
      debugPrint("AudioPlayer state: $state");
      // Hanya handle stop manual atau error di sini
      if (state == PlayerState.stopped) {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _isLoading = false;
          });
        }
      }
    });

    // 2. Listen Player Complete (Otomatis berhenti saat audio habis)
    // Event ini lebih akurat untuk mendeteksi akhir pembacaan
    _audioPlayer.onPlayerComplete.listen((event) {
      debugPrint("✅ Audio finished playing automatically");
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    debugPrint("🔥 Hot restart detected - resetting audio");
    AudioPlayerService.forceReset();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isLoading = false;
      });
    }
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _setupAudioPlayerListener();
      }
    });
  }

  void _scrollListener() {
    final currentOffset = _scrollController.offset;
    final direction = currentOffset - _lastScrollOffset;

    if (direction.abs() < 10 || currentOffset < 0) return;

    if (direction > 0 && currentOffset > kToolbarHeight) {
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

  @override
  void dispose() {
    debugPrint("🗑️ Disposing ArticleDetailScreen");
    
    // Calculate scroll percentage for reading tracker
    double scrollPercentage = 0.0;
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
      scrollPercentage = _scrollController.offset / _scrollController.position.maxScrollExtent;
      scrollPercentage = scrollPercentage.clamp(0.0, 1.0);
    }
    
    // End reading tracking with scroll percentage
    _readingTracker.endReadingArticle(widget.article, scrollPercentage);
    
    _scrollController.removeListener(_scrollListener);
    _headerAnimController.dispose();
    _bottomBarAnimController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _audioService.reset();
    super.dispose();
  }

  bool _isSpeaking = false;
  bool _isLoading = false;
  String _fullTextForSpeech = "";
  late bool _isBookmarkedLocal;

  final List<double> _fontSizes = [14.0, 16.0, 18.0, 20.0, 22.0];
  int _currentFontSizeIndex = 2;

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
    } catch (e) {
      debugPrint('Error adding to history: $e');
    }
  }

  String _getTtsLocale(String? articleLanguage) {
    if (articleLanguage == null || articleLanguage.isEmpty) {
      return 'id-ID';
    }
    final Map<String, String> commonLocales = {
      'id': 'id-ID', 'en': 'en-US', 'es': 'es-ES', 'fr': 'fr-FR',
      'de': 'de-DE', 'ja': 'ja-JP', 'ko': 'ko-KR', 'zh': 'zh-CN',
      'ru': 'ru-RU', 'ar': 'ar-SA', 'pt': 'pt-BR', 'it': 'it-IT',
      'nl': 'nl-NL', 'tr': 'tr-TR', 'vi': 'vi-VN', 'th': 'th-TH',
    };
    if (commonLocales.containsKey(articleLanguage)) return commonLocales[articleLanguage]!;
    if (articleLanguage.contains('-') || articleLanguage.contains('_')) return articleLanguage;
    if (articleLanguage.length == 2) return articleLanguage;
    return 'id-ID';
  }

  Future<void> _fetchRelatedArticles() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRelated = true;
      _relatedError = null;
    });

    try {
      final articles = await _apiService.getArticlesByCategory(
        widget.article.category,
        page: 1,
        pageSize: 5,
      );

      final related = articles
          .where((a) => a.id != widget.article.id)
          .take(4)
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
      });
    }
  }

  Future<void> _fetchAndNavigateToRandomArticle() async {
    if (_isSwiping) return;
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    if (mounted) {
      setState(() {
        _isSwiping = true;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Mencari artikel lain..."),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      final randomPage = Random().nextInt(3) + 1;
      final articles = await _apiService.getArticlesByCategory(
        null,
        page: randomPage,
        pageSize: 50,
      );

      final otherArticles = articles.where((a) => a.id != widget.article.id).toList();

      if (otherArticles.isEmpty) {
        throw Exception("Tidak menemukan artikel lain.");
      }

      final randomArticle = otherArticles[Random().nextInt(otherArticles.length)];
      final String heroTag = 'swipe_${randomArticle.id}_${UniqueKey().toString()}';

      if (_isSpeaking || _isLoading) {
        await _stopSpeaking();
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ArticleDetailScreen(
            article: randomArticle,
            heroTag: heroTag,
            isBookmarked: false, 
            onBookmarkToggle: widget.onBookmarkToggle, 
          ),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (mounted) _showErrorSnackBar("Gagal memuat artikel lain.");
      if (mounted) setState(() => _isSwiping = false);
    }
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() > 300) {
      _fetchAndNavigateToRandomArticle();
    }
  }

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

  String _processHtmlForTts(String htmlString) {
    final document = parse(htmlString);
    final StringBuffer buffer = StringBuffer();

    void _visit(var node) {
      if (node.nodeType == 3) { // Text Node
        String text = node.text?.trim() ?? '';
        if (text.isNotEmpty) buffer.write("$text ");
      } else if (node.nodeType == 1) { // Element Node
        final String tagName = node.localName ?? '';
        
        if (tagName == 'blockquote') {
          var citeNode = node.querySelector('cite');
          for (var child in node.nodes) {
            if (child != citeNode) {
              _visit(child);
            }
          }
          if (citeNode != null) {
            String author = citeNode.text.trim();
            if (author.isNotEmpty) {
              buffer.write(". Kata $author. ");
            }
          }
        } else if (tagName == 'br') {
          buffer.write("\n");
        } else {
          for (var child in node.nodes) {
            _visit(child);
          }
          if (['p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'ul', 'ol'].contains(tagName)) {
            buffer.write("\n");
          }
        }
      }
    }

    if (document.body != null) {
      for (var node in document.body!.nodes) {
        _visit(node);
      }
    }

    return buffer.toString().trim();
  }

  String _formatDateRelative(DateTime dateTime) {
    try {
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 60) {
         if (difference.inMinutes <= 0) return 'Baru saja';
         return '${difference.inMinutes} menit lalu';
      }
      if (difference.inHours < 24) {
        return '${difference.inHours} jam lalu';
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (dateTime.year == yesterday.year && 
          dateTime.month == yesterday.month && 
          dateTime.day == yesterday.day) {
        return 'Kemarin';
      }
      if (difference.inDays < 7) {
        return '${difference.inDays} hari lalu';
      }
      return DateFormat('d MMM y', 'id_ID').format(dateTime);
    } catch (e) {
      return DateFormat('d MMM y', 'id_ID').format(dateTime);
    }
  }

  Future<void> _launchURL(String urlString) async {
    try {
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
        _showErrorSnackBar('Fitur ini hanya bisa dibuka di handphone (Android atau iOS).');
      }
    } catch (e) {
      _showErrorSnackBar('Gagal membuka browser:\n$urlString');
    }
  }

  Future<void> _toggleSpeech() async {
    if (_isLoading) return; 

    if (_isSpeaking) {
      await _stopSpeaking();
    } else {
      _fullTextForSpeech = _prepareTextForSpeech();
      await _startGeminiTts();
    }
  }

  Future<void> _startGeminiTts() async {
    if (_geminiApiKey == "AIzaSyDa3Fo_obfSV_DTUo8OmaSUiR7U7KllYEs" || _geminiApiKey.isEmpty) {
      _showDetailedErrorDialog("API Key Belum Dikonfigurasi",
          "Gunakan 'Suara Normal' untuk saat ini.");
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;  
    });

    await _fetchAndPlayGeminiTts();
  }

  Future<void> _fetchAndPlayGeminiTts() async {
    if (_fullTextForSpeech.isEmpty) {
      _showErrorSnackBar("Tidak ada teks untuk dibacakan");
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final String? apiKey = dotenv.env['GOOGLE_TTS_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      _showDetailedErrorDialog("API Key Belum Dikonfigurasi",
          "Gunakan 'Suara Normal' untuk saat ini.");
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final String apiUrl = "https://texttospeech.googleapis.com/v1/text:synthesize";

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
        "speakingRate": 1.04, 
        "volumeGainDb": 0.5 
      }
    });

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint("Mengirim request ke Cloud TTS API (Gemini)...");
      
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
          await _audioPlayer.play(BytesSource(audioBytes));

          if (mounted) {
            setState(() {
              _isLoading = false;
              _isSpeaking = true;
            });
          }
        } else {
          throw Exception("Tidak ada data audio dalam respons");
        }
      } else {
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
        });
      }
    } catch (e) {
      debugPrint("Error fetching Cloud TTS: $e");
      _showErrorSnackBar("Gagal memuat audio: ${e.toString()}");
      if (mounted) {
        setState(() {  
          _isLoading = false;  
          _isSpeaking = false;  
        });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error stopping TTS: $e");
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isLoading = false;
        });
      }
    }
  }

  // --- BARU: Fungsi Normalisasi Teks Asing (Mata Uang & Istilah) ---
  /// Mengubah simbol atau format asing menjadi teks bahasa Indonesia
  /// agar TTS Gemini bisa membacanya dengan natural.
  /// Termasuk mengubah tanda strip pada nominal menjadi 'sampai' (misal: Rp 63 - 64 Miliar -> 63 sampai 64 Miliar rupiah)
  /// Angka dengan koma akan diubah jadi "koma", misal: 3,9 -> "3 koma 9"
  /// Juga mengubah 21,9 persen => 21 koma 9 persen dan 3,4 jam => 3 koma 4 jam, dll.
  String _normalizeForeignTerms(String input) {
    String text = input;

    String normalizeNumber(String? num) {
      if (num == null) return '';
      // Tangani angka dengan koma (desimal)
      // Hilangkan titik pemisah ribuan
      String cleaned = num.replaceAll('.', '');
      if (cleaned.contains(',')) {
        var parts = cleaned.split(',');
        // Misal: 3,9 -> 3 koma 9; 12,53 -> 12 koma 53
        return '${parts[0]} koma ${parts[1]}';
      }
      return cleaned;
    }

    // 0. Range/mata uang besar (Miliar dst) --- GUNAKAN FUNGSI normalizeNumber
    text = text.replaceAllMapped(
      RegExp(r'(?:US)?\$\s*([\d\.,]+)\s*-\s*([\d\.,]+)\s+(Miliar|Juta|Triliun|Biliun)', caseSensitive: false),
      (match) {
        final num1 = normalizeNumber(match.group(1));
        final num2 = normalizeNumber(match.group(2));
        return "$num1 sampai $num2 ${match.group(3)} dolar Amerika";
      },
    );
    text = text.replaceAllMapped(
      RegExp(r'Rp\.?\s*([\d\.,]+)\s*-\s*([\d\.,]+)\s+(Miliar|Juta|Triliun|Biliun)', caseSensitive: false),
      (match) {
        final num1 = normalizeNumber(match.group(1));
        final num2 = normalizeNumber(match.group(2));
        return "$num1 sampai $num2 ${match.group(3)} rupiah";
      },
    );

    // 0.1 Versi tanpa satuan besar, misal: Rp 1.000 - 2.000
    text = text.replaceAllMapped(
      RegExp(r'Rp\.?\s*([\d\.,]+)\s*-\s*([\d\.,]+)', caseSensitive: false),
      (match) {
        final num1 = normalizeNumber(match.group(1));
        final num2 = normalizeNumber(match.group(2));
        return "$num1 sampai $num2 rupiah";
      },
    );
    text = text.replaceAllMapped(
      RegExp(r'(?:US)?\$\s*([\d\.,]+)\s*-\s*([\d\.,]+)', caseSensitive: false),
      (match) {
        final num1 = normalizeNumber(match.group(1));
        final num2 = normalizeNumber(match.group(2));
        return "$num1 sampai $num2 dolar Amerika";
      },
    );
    // Euro range
    text = text.replaceAllMapped(
      RegExp(r'€\s*([\d\.,]+)\s*-\s*([\d\.,]+)', caseSensitive: false),
      (match) {
        final num1 = normalizeNumber(match.group(1));
        final num2 = normalizeNumber(match.group(2));
        return "$num1 sampai $num2 Euro";
      },
    );
    // Poundsterling range
    text = text.replaceAllMapped(
      RegExp(r'£\s*([\d\.,]+)\s*-\s*([\d\.,]+)', caseSensitive: false),
      (match) {
        final num1 = normalizeNumber(match.group(1));
        final num2 = normalizeNumber(match.group(2));
        return "$num1 sampai $num2 Poundsterling";
      },
    );
    // Yen/Yuan range
    text = text.replaceAllMapped(
      RegExp(r'¥\s*([\d\.,]+)\s*-\s*([\d\.,]+)', caseSensitive: false),
      (match) {
        final num1 = normalizeNumber(match.group(1));
        final num2 = normalizeNumber(match.group(2));
        return "$num1 sampai $num2 Yen";
      },
    );
    // USD kode rentang
    text = text.replaceAllMapped(
      RegExp(r'USD\s*([\d\.,]+)\s*-\s*([\d\.,]+)\s+(Miliar|Juta|Triliun|Biliun)', caseSensitive: false),
      (match) {
        final num1 = normalizeNumber(match.group(1));
        final num2 = normalizeNumber(match.group(2));
        return "$num1 sampai $num2 ${match.group(3)} dolar Amerika";
      },
    );
    text = text.replaceAllMapped(
      RegExp(r'USD\s*([\d\.,]+)\s*-\s*([\d\.,]+)', caseSensitive: false),
      (match) {
        final num1 = normalizeNumber(match.group(1));
        final num2 = normalizeNumber(match.group(2));
        return "$num1 sampai $num2 dolar Amerika";
      },
    );

    // 1. [PRIORITAS TINGGI] Mata Uang dengan Satuan Besar (Miliar, Juta, Triliun)
    // Dollar + Satuan Besar
    text = text.replaceAllMapped(
      RegExp(r'(?:US)?\$\s*([\d\.,]+)\s+(Miliar|Juta|Triliun|Biliun)', caseSensitive: false),
      (match) {
        final num = normalizeNumber(match.group(1));
        return "$num ${match.group(2)} dolar Amerika";
      }
    );
    // Rupiah + Satuan Besar
    text = text.replaceAllMapped(
      RegExp(r'Rp\.?\s*([\d\.,]+)\s+(Miliar|Juta|Triliun|Biliun)', caseSensitive: false),
      (match) {
        final num = normalizeNumber(match.group(1));
        return "$num ${match.group(2)} rupiah";
      }
    );

    // 2. Mata Uang Dollar Biasa ($) - angka dengan koma akan dibaca "koma"
    text = text.replaceAllMapped(
      RegExp(r'(?:US)?\$\s*([\d\.,]+)', caseSensitive: false),
      (match) {
        String number = match.group(1)!;
        // Jika angka diakhiri titik/koma (misal akhir kalimat), bersihkan
        if (number.endsWith('.') || number.endsWith(',')) {
          number = number.substring(0, number.length - 1);
        }
        number = normalizeNumber(number);
        return "$number dolar Amerika";
      },
    );

    // 3. Kode Mata Uang USD
    text = text.replaceAllMapped(
      RegExp(r'\bUSD\s*([\d\.,]+)', caseSensitive: false),
      (match) {
        final num = normalizeNumber(match.group(1));
        return "$num dolar Amerika";
      },
    );

    // 4. Simbol Mata Uang Lain
    text = text.replaceAllMapped(
      RegExp(r'€\s*([\d\.,]+)'),
      (match) {
        final num = normalizeNumber(match.group(1));
        return "$num Euro";
      },
    );
    text = text.replaceAllMapped(
      RegExp(r'£\s*([\d\.,]+)'),
      (match) {
        final num = normalizeNumber(match.group(1));
        return "$num Poundsterling";
      },
    );
    text = text.replaceAllMapped(
      RegExp(r'¥\s*([\d\.,]+)'),
      (match) {
        final num = normalizeNumber(match.group(1));
        return "$num Yen";
      },
    );

    // 5. Mata Uang Rupiah Biasa (Opsional, merapikan format)
    text = text.replaceAllMapped(
      RegExp(r'Rp\.?\s*([\d\.,]+)', caseSensitive: false),
      (match) {
        final num = normalizeNumber(match.group(1));
        return "$num rupiah";
      },
    );

    // 6. Persen/kata satuan lain: angka dengan koma sebelum 'persen', 'jam', 'hari', 'tahun', 'bulan', dll
    // Contoh: 21,9 persen -> 21 koma 9 persen; 3,4 jam -> 3 koma 4 jam
    // Note: lakukan setelah currency agar tidak bentrok string di atas!
    text = text.replaceAllMapped(
      RegExp(r'(\d{1,3}(?:\.\d{3})*),(\d+)\s*(persen|jam|hari|tahun|bulan|menit|detik|minggu)', caseSensitive: false),
      (match) {
        String whole = match.group(1)!;
        String frac = match.group(2)!;
        String satuan = match.group(3)!;
        // Hilangkan titik di whole
        whole = whole.replaceAll('.', '');
        return '$whole koma $frac $satuan';
      }
    );

    // 6.1 Standalone angka dengan koma, misal: "3,4" tanpa satuan
    // Hati-hati jangan replace angka dalam konteks lain, pastikan bukan di tengah kata, gunakan \b
    text = text.replaceAllMapped(
      RegExp(r'\b(\d{1,3}(?:\.\d{3})*),(\d+)\b', caseSensitive: false),
      (match) {
        String whole = match.group(1)!;
        String frac = match.group(2)!;
        whole = whole.replaceAll('.', '');
        return '$whole koma $frac';
      }
    );

    // 7. Istilah Asing Umum dalam Berita (Contoh)
    text = text.replaceAll(RegExp(r'\bvs\b', caseSensitive: false), "melawan");
    text = text.replaceAll(RegExp(r'\bapprox\.\b', caseSensitive: false), "kira-kira");

    return text;
  }
  // --- AKHIR FUNGSI BARU ---

  String _prepareTextForSpeech() {
    StringBuffer buffer = StringBuffer();
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

    final dt = widget.article.modifiedAt;
    
    final day = dt.day;
    final month = DateFormat('MMMM', 'id_ID').format(dt); 
    final year = dt.year;

    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');

    String period = '';
    if (hour >= 0 && hour < 11) {
      period = 'pagi';
    } else if (hour >= 11 && hour < 15) {
      period = 'siang';
    } else if (hour >= 15 && hour < 18) {
      period = 'sore';
    } else {
      period = 'malam';
    }

    final String updateString = 
        "Update tanggal $day bulan $month tahun $year, jam $hour:$minute $period Waktu Indonesia Barat";

    buffer.writeln(updateString);
    buffer.writeln();

    String? content = widget.article.content ?? widget.article.description;
    if (content != null && content.isNotEmpty) {
      String cleanContent = _processHtmlForTts(content);
      
      cleanContent = cleanContent
          .replaceAll("dll.", "dan lain-lain")
          .replaceAll("dsb.", "dan sebagainya")
          .replaceAll("Yth.", "Yang terhormat");

      // --- MODIFIKASI: Panggil fungsi normalisasi teks asing ---
      cleanContent = _normalizeForeignTerms(cleanContent);
      // --- AKHIR MODIFIKASI ---
      
      buffer.write(cleanContent);
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
                'Belum bisa untuk menyimpan artikel ini',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              // ElevatedButton(
              //   onPressed: () {
              //     Navigator.pop(context);
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //           builder: (context) => const LoginScreen()),
              //     ).then((_) => _checkLoginStatus());
              //   },
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: customGreen,
              //     foregroundColor: Colors.black,
              //     minimumSize: const Size(double.infinity, 50),
              //     shape: RoundedRectangleBorder(
              //       borderRadius: BorderRadius.circular(8),
              //     ),
              //   ),
              //   child: const Text(
              //     'Lanjutkan',
              //     style: TextStyle(
              //       fontSize: 16,
              //       fontWeight: FontWeight.bold,
              //     ),
              //   ),
              // ),
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
        if (_isSpeaking || _isLoading) await _stopSpeaking();
        _popWithResult(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: isDark ? Color(0xFF1A1A1A) : Color(0xFFF5F5F5),
        appBar: AppBar(
          toolbarHeight: 0,
          elevation: 0,
          backgroundColor: isDark ? Color(0xFF1A1A1A) : Color(0xFFF5F5F5),
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: isDark ? Colors.black : Colors.white,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        body: GestureDetector( 
          onHorizontalDragEnd: _handleHorizontalSwipe, 
          child: Column(
            children: [
              SizeTransition( 
                axis: Axis.vertical,
                axisAlignment: -1.0, 
                sizeFactor: CurvedAnimation(
                  parent: _headerAnimController,
                  curve: Curves.fastOutSlowIn,
                ).drive(Tween<double>(begin: 1.0, end: 0.0)), 
                child: _buildHeaderBar(context),
              ),
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
                            Padding(
                              padding: const EdgeInsets.fromLTRB(23.0, 16.0, 23.0, 20.0), 
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ClipPath(
                                        clipper: ParallelogramClipper(skew: 10.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 4), 
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE5FF10),
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
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    widget.article.title,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Domine',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                      letterSpacing: 0.3,
                                      height: 1.3,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.article.urlToImage != null)
                              Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: GestureDetector(
                                      onTap: () => _showFocusedImage(
                                          context,
                                          widget.article.urlToImage,
                                          widget.heroTag,
                                          widget.article.title,
                                          widget.article.category),
                                      child: Hero(
                                        tag: widget.heroTag,
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
                                              color: Theme.of(context).brightness == Brightness.dark ? Color(0xFFE5FF10) : Colors.black,
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
                                  
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _buildTtsPlayBar(context),
                                  ),

                                  Padding(
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
                            
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildStandardView(context),

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
                                            : Colors.black, 
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  const SizedBox(height: 20), 
                                  _buildSwipePrompt(context), 
                                  
                                  const SizedBox(height: 30), 
                                ],
                              ),
                            ),

                            _buildRelatedTopicsSection(),
                            const SizedBox(height: 24), 
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
        bottomNavigationBar: SizeTransition(
          axis: Axis.vertical,
          axisAlignment: 1.0, 
          sizeFactor: CurvedAnimation(
            parent: _bottomBarAnimController,
            curve: Curves.fastOutSlowIn,
          ).drive(Tween<double>(begin: 1.0, end: 0.0)),
          child: _buildBottomNavBar(context),
        ),
      ),
    );
  }

  Widget _buildSwipePrompt(BuildContext context) {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return const SizedBox.shrink(); 
    }

    final Color hintColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[600]!
        : Colors.grey[500]!;

    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 24.0), 
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

  Widget _buildHeaderBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1A1A1A) : Color(0xFFF5F5F5),
        border: Border(
          bottom: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[400]!, width: 1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 4.0,
          right: 4.0,
          bottom: 4.0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
              ],
            ),

            Row(
              children: [
                _buildNewFontMenuButton(),
                BookmarkIconButton(
                  isBookmarked: _isBookmarkedLocal,
                  onToggle: () {
                    if (_isLoggedIn) {
                      widget.onBookmarkToggle();
                      final newBookmarkState = !_isBookmarkedLocal;
                      setState(() {
                        _isBookmarkedLocal = newBookmarkState;
                      });
                      showBookmarkSnackbar(context, newBookmarkState);
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
                          ? Color(0xFFE5FF10)
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
                          child: isSelected && !isDark
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(
                                      "A",
                                      style: TextStyle(
                                        fontFamily: 'Domine',
                                        fontSize: size,
                                        fontWeight: FontWeight.bold,
                                        foreground: Paint()
                                          ..style = PaintingStyle.stroke
                                          ..strokeWidth = 2
                                          ..color = Colors.black,
                                      ),
                                    ),
                                    Text(
                                      "A",
                                      style: TextStyle(
                                        fontFamily: 'Domine',
                                        fontSize: size,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFE5FF10),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
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

  Widget _buildStandardView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildMetaInfoSection(context),
        const SizedBox(height: 16),
        
        _buildQuickButton(context),
        const SizedBox(height: 24),
        _buildContentWithBlockquotes(widget.article.content),
      ],
    );
  }

  Widget _buildMetaInfoSection(BuildContext context) {
    String displayName = "";
    bool showName = false;

    if (widget.article.penulis != null && widget.article.penulis!.isNotEmpty) {
      displayName = widget.article.penulis!;
      showName = true;
    } 
    else if (widget.article.author != null && 
             widget.article.author!.isNotEmpty && 
             widget.article.author != "Unknown Author") {
      String cleanAuthor = widget.article.author!.replaceAll(RegExp(r'^https?:\/\/.*'), '').trim();
      if (cleanAuthor.isNotEmpty) {
        displayName = cleanAuthor;
        showName = true;
      }
    }

    final String publishString = _formatDateRelative(widget.article.publishedAt);
    
    final String updateString = 
        "Update ${DateFormat('d MMM y, HH:mm', 'id_ID').format(widget.article.modifiedAt)} WIB";
    
    final String combinedDateString = "$publishString | $updateString";

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showName)
            Padding(
              padding: const EdgeInsets.only(bottom: 2.0),
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w400, 
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.9),
                      ),
                  children: [
                    const TextSpan(
                      text: "By ",
                    ),
                    TextSpan(
                      text: displayName, 
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, 
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Text(
            combinedDateString,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withOpacity(0.7),
                  fontWeight: FontWeight.w400,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tags = widget.article.tags;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
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
          child: Wrap(
            alignment: WrapAlignment.start,
            spacing: 4,
            runSpacing: 4,
            children: [
              for (int i = 0; i < tags.length; i++)
                Text(
                  '#${tags[i]}${i != tags.length - 1 ? ',' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTtsPlayBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.black.withOpacity(0.13);
    final Color bgColor = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.05);

    late Color iconColor;
    if (_isLoading) {
      iconColor = isDark ? Colors.white54 : Colors.black54;
    } else if (_isSpeaking) {
      iconColor = Colors.redAccent;
    } else {
      iconColor = isDark ? Colors.white : Colors.black87;
    }

    late Color textColor;
    if (isDark) {
      if (_isSpeaking) {
        textColor = Colors.redAccent;
      } else {
        textColor = Colors.white;
      }
    } else {
      if (_isSpeaking) {
        textColor = Colors.red;
      } else {
        textColor = Colors.black87;
      }
    }

    void _onTtsPlayBarTap() {
      if (_isLoading) return;
      _toggleSpeech(); 
    }

    IconData getIcon() {
      if (_isLoading) {
        return Icons.hourglass_empty;
      } else if (_isSpeaking) {
        return Icons.stop_rounded; 
      } else {
        return Icons.play_arrow_rounded; 
      }
    }

    String getButtonText() {
      if (_isLoading) {
        return "Process...";
      } else if (_isSpeaking) {
        return "Berhenti";
      } else {
        return "Dengarkan";
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18.0, 16.0, 18.0, 0.0), 
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
              mainAxisSize: MainAxisSize.min, 
              mainAxisAlignment: MainAxisAlignment.center, 
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

  Widget _buildQuickButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0), 
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToQuickScreen(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity, 
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
                const SizedBox(width: 16), 
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentWithBlockquotes(String? content) {
    final currentFontSize = _fontSizes[_currentFontSizeIndex];
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

    final baseTextStyle = TextStyle(
      fontFamily: 'SourceSerif4',
      fontWeight: FontWeight.w400,
      fontSize: currentFontSize, 
      height: 1.6,
      color: isDark ? Colors.white70 : Colors.black87,
    );

    final Color blockquoteAccentColor = isDark ? const Color(0xFFE5FF10) : Colors.black;

    return Html(
      data: htmlData,
      extensions: [
        VideoHtmlExtension(), 
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
            final currentFontSize = _fontSizes[_currentFontSizeIndex];

            final Color blockquoteAccentColor = isDark ? const Color(0xFFE5FF10) : Colors.black;

            if (mainQuote.isEmpty) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 16, top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850]?.withOpacity(0.5) : Colors.grey[100],
                borderRadius: BorderRadius.vertical(top: Radius.circular(16), bottom: Radius.circular(10)),
                border: Border(
                  left: BorderSide(
                    color: blockquoteAccentColor,
                    width: 4,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.format_quote,
                    color: blockquoteAccentColor,
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
                                  color: blockquoteAccentColor,
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

  Widget _buildRelatedTopicsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingRelated) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

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

    if (_relatedArticles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22.0),
          child: Divider(
            color: Color(0xFF888888),
            thickness: 1.0,
            height: 0, 
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 23.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Article Related",
                style: TextStyle(
                  fontFamily: 'Domine',
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),

              GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, 
                  crossAxisSpacing: 16.0, 
                  mainAxisSpacing: 16.0, 
                  childAspectRatio: 0.9, 
                ),
                itemCount: _relatedArticles.length, 
                shrinkWrap: true, 
                physics: const NeverScrollableScrollPhysics(), 
                itemBuilder: (context, index) {
                  final article = _relatedArticles[index];
                  return _buildRelatedArticleCard(article);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedArticleCard(Article article) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String heroTag = 'related_${article.id}_${UniqueKey().toString()}';

    return GestureDetector(
      onTap: () {
        if (_isSpeaking || _isLoading) {
          _stopSpeaking();
        }

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

  Widget _buildBottomNavBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color background = isDark ? const Color(0xFF1A1A1A) : Color(0xFFF5F5F5);
    final Color inactiveColor = isDark ? Colors.grey[700]! : Colors.grey[500]!;
    final Color borderTopColor = isDark ? Colors.grey[800]! : Colors.grey[400]!;

    String colorToHex(Color color) {
      return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    }

    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: BorderSide(
            color: borderTopColor, 
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
              Expanded(
                child: InkWell(
                  onTap: () {
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
              
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const MainScreen(initialTab: 2),
                      ),
                      (route) => false, 
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
              
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const MainScreen(initialTab: 3),
                      ),
                      (route) => false, 
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
                                <path fill="${colorToHex(inactiveColor)}" d="M3.9 12c0-1.71 1.39-3.1 3.1-3.1h4V7H7c-2.76 0-5 2.24-5 5s2.24 5 5 5h4v-1.9H7c-1.71 0-3.1-1.39-3.1-3.1M8 13h8v-2H8v2m9-6h-4v1.9h4c1.71 0 3.1 1.39 3.1 3.1s-1.39 3.1-3.1 3.1h-4V17h4c2.76 0 5-2.24 5-5s-2.24-5-5-5Z"/>
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
      padding: const EdgeInsets.all(12), 
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.pop(context), 
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
                child: Hero(
                    tag: widget.heroTag,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: CachedNetworkImage(
                              imageUrl: widget.imageUrl,
                              fit: BoxFit.contain,
                              placeholder: (c, u) => const Center(
                                  child: CircularProgressIndicator()),
                              errorWidget: (c, u, e) => const Center(
                                  child: Icon(Icons.broken_image,
                                    color: Colors.white)))),
                    ))),
          ],
        ),
      ),
    );
  }
}

class ParallelogramClipper extends CustomClipper<Path> {
  final double skew;

  ParallelogramClipper({this.skew = 20.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(skew, 0.0);
    path.lineTo(size.width, 0.0);
    path.lineTo(size.width - skew, size.height);
    path.lineTo(0.0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant ParallelogramClipper oldClipper) {
    return oldClipper.skew != skew;
  }
}