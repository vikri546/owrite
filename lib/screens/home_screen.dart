import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../models/video.dart'; 
import '../providers/article_provider.dart';
import '../providers/video_provider.dart'; // Import VideoProvider
import '../utils/strings.dart';
import '../utils/auth_service.dart';
import 'login_screen.dart';
import '../providers/language_provider.dart';
import '../services/bookmark_service.dart';
import '../services/history_service.dart';
import 'package:flutter/foundation.dart';
import 'article_detail_screen.dart';
import '../utils/custom_page_transitions.dart';
import '../widgets/article_card.dart';
import '../widgets/video_card.dart'; 
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/theme_provider.dart';
import '../widgets/snackbar_toggle.dart';
import '../widgets/theme_toggle_button.dart';
import '../repositories/article_repository.dart';
import 'search_screen.dart';
import 'notifications_screen.dart';
import 'shorts_player_screen.dart'; 

class HomeScreen extends StatefulWidget {
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;

  const HomeScreen({
    Key? key,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  String? _previousCategory;
  String _currentUsername = 'Guest';
  final BookmarkService _bookmarkService = BookmarkService();
  
  final HistoryService _historyService = HistoryService();
  
  final ArticleRepository _articleRepository = ArticleRepository();
  List<Article> _allBookmarkedArticles = [];
  bool _isLoadingBookmarks = true;

  bool _showScrollLeft = false;
  bool _showScrollRight = true;

  List<Article> _cachedRecommendations = [];
  ArticleLoadingStatus? _previousStatus;

  final Map<String, GlobalKey> _categoryKeys = {};
  final Map<String, GlobalKey> _categoryTextKeys = {};
  final GlobalKey _categoryListKey = GlobalKey();

  Future<List<Article>>? _latestCategory1Future;
  Future<List<Article>>? _latestCategory2Future;
  String? _latestCategory1Code;
  String? _latestCategory2Code;

  int _beritaTerkiniCount = 7;
  bool _isLoadMoreBeritaTerkini = false;
  final Color _loadMoreColor = const Color(0xFFE5FF10);

  final Map<String, List<Article>> _groupedArticles = {};
  final Map<String, int> _categoryCurrentPage = {};
  final Map<String, bool> _categoryHasMore = {};
  final Map<String, bool> _categoryLoading = {};
  final Map<String, bool> _categoryInitialLoading = {};

  final Color _loadMoreButtonColor = const Color(0xFFE5FF10);
  
  bool _isLoadingMoreButton = false;
  
  // State untuk tracking retry otomatis Top News
  int _topNewsRetryCount = 0;
  static const int _maxRetryAttempts = 3;
  
  // State untuk tracking loading semua artikel Top News
  bool _isLoadingAllTopNews = false;

  late AnimationController _headerAnimController;
  late Animation<double> _headerHeightAnimation;
  bool _isHeaderVisible = true;

  List<Article> _debugImportantArticles = [];

  final PageController _headlinePageController = PageController();
  int _currentHeadlineIndex = 0; 

  List<Article> _readingHistory = [];
        
  ArticleProvider? _articleProvider;

  // --- DATA SHORTS DIHAPUS (Diganti VideoProvider) ---
  // List<Video> _shortsVideos = []; 
  // bool _isLoadingShorts = true;
  // -------------------

  // --- 🆕 STATE UNTUK SLIDER (FETCH TERPISAH) ---
  List<Article> _headlineArticles = [];
  List<Article> _editorialArticles = [];
  bool _isLoadingSlider = true;
  // ----------------------------------------------

  // --- 🆕 STATE UNTUK PAGINATION TODAY ---
  int _todayPageIndex = 0;
  final PageController _todayPageController = PageController();
  // ---------------------------------------

  final List<Map<String, dynamic>> _allCategories = [
    {'title': 'Hype', 'category': 'HYPE'},
    {'title': 'Olahraga', 'category': 'OLAHRAGA'},
    {'title': 'Ekonomi Bisnis', 'category': 'EKBIS'},
    {'title': 'Megapolitan', 'category': 'MEGAPOLITAN'},
    {'title': 'Daerah', 'category': 'DAERAH'},
    {'title': 'Nasional', 'category': 'NASIONAL'},
    {'title': 'Internasional', 'category': 'INTERNASIONAL'},
    {'title': 'Politik', 'category': 'POLITIK'},
    {'title': 'Kesehatan', 'category': 'KESEHATAN'},
  ];

  final Map<String, String> _categoryTitles = {
    'HYPE': 'Hype',
    'OLAHRAGA': 'Olahraga',
    'EKBIS': 'Ekonomi Bisnis',
    'MEGAPOLITAN': 'Megapolitan',
    'DAERAH': 'Daerah',
    'NASIONAL': 'Nasional',
    'INTERNASIONAL': 'Internasional',
    'POLITIK': 'Politik',
    'KESEHATAN': 'Kesehatan',
  };

  Map<String, dynamic>? _dailyCategory1;
  Map<String, dynamic>? _dailyCategory2;

  final List<String> _rotatingCategoryPoolCodes = [
    'HYPE',
    'OLAHRAGA',
    'EKBIS',
    'MEGAPOLITAN',
    'DAERAH',
  ];

  static const String _prefsDailyCategoriesDateKey = 'daily_categories_date';
  static const String _prefsDailyCategoriesListKey = 'daily_categories_list';

  int _weeklySeed = 0;
  static const String _prefsWeeklySeedDateKey = 'weekly_seed_date_v2';
  static const String _prefsWeeklySeedValueKey = 'weekly_seed_value_v2';

  @override
  bool get wantKeepAlive => true;

  Future<List<Article>>? _popularArticlesFuture;

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0, 
    );

    _popularArticlesFuture = _articleRepository.getArticlesByTag(1810, page: 1, pageSize: 5);

    _headerHeightAnimation = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeInOut,
    );

    _scrollController.addListener(_onScroll); 
    _loadCurrentUser();
    _loadAllBookmarks();
    _loadOrUpdateDailyCategories(); 
    _loadOrUpdateWeeklySeed(); 
    
    _loadReadingHistory(); 
    _loadSliderData();
    
    // 🆕 TAMBAHKAN INI: Set initial loading state untuk Top News
    _categoryInitialLoading['Top News'] = true;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<VideoProvider>(context, listen: false)
            .loadVideosFromChannel('UC7LumXPdwm7UlBsyE0DQp6A');
      }

      if (mounted && _articleProvider != null) {
        if (_previousCategory != 'Top News') {
          _articleProvider!.changeCategory('Top News');
        } else {
          _articleProvider!.loadArticles();
          _scrollToSelectedCategory('Top News');
        }
      }
    });
  }

  // --- 🆕 FETCH SLIDER DATA SECARA PAKSA (BY TAG ID) ---
  Future<void> _loadSliderData() async {
    if (!mounted) return;
    setState(() => _isLoadingSlider = true);

    try {
      // Fetch HEADLINE (Tag ID: 109)
      // Ambil 10 item untuk jaga-jaga sorting
      final List<Article> headlines = await _articleRepository.getArticlesByTag(109, page: 1, pageSize: 10);
      
      // Fetch BERITA PILIHAN / EDITORIAL (Tag ID: 113)
      final List<Article> editorials = await _articleRepository.getArticlesByTag(113, page: 1, pageSize: 10);

      if (mounted) {
        setState(() {
          // 1. Sort Terbaru ke Terlama (descending date)
          headlines.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
          editorials.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

          // 2. Simpan di state (Full list, nanti dipotong di UI jika perlu exclude)
          _headlineArticles = headlines;
          _editorialArticles = editorials;
          _isLoadingSlider = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading slider data: $e");
      if (mounted) setState(() => _isLoadingSlider = false);
    }
  }

  // Helper untuk filter shorts (Maks 3 menit / 180 detik)
  bool _isShorts(Video v) {
    if (v.title.toLowerCase().contains('shorts')) {
      return true;
    }
    // Parsing durasi (misal "04:20" atau "1:05:20")
    if (v.duration.isNotEmpty) {
      final parts = v.duration.split(':').map((e) => int.tryParse(e) ?? 0).toList();
      int totalSeconds = 0;
      if (parts.length == 2) {
        totalSeconds = parts[0] * 60 + parts[1];
      } else if (parts.length == 3) {
        totalSeconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
      }
      // Syarat: Maksimal 3 menit (180 detik)
      if (totalSeconds <= 180) {
        return true;
      }
    }
    return false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_articleProvider == null) {
      _articleProvider = Provider.of<ArticleProvider>(context, listen: false);
      _articleProvider!.addListener(_onProviderUpdate);
      _previousCategory = _articleProvider!.currentCategory;
      
      // 🆕 TRIGGER LOAD: Pastikan kategori Top News dan langsung load
      Future.microtask(() async {
        if (mounted) {
          final currentCategory = _articleProvider!.currentCategory;
          
          // Jika kategori saat ini adalah Top News, load semua datanya
          if (currentCategory == 'Top News') {
            // Load semua artikel Top News secara otomatis
            await _loadAllTopNewsArticles();
          }
        }
      });
    }
  }

  // --- PERBAIKAN LOGIC LOADING HISTORY ---
  Future<void> _loadReadingHistory() async {
    try {
      final List<Map<String, dynamic>> historyData = await _historyService.getHistory();
      
      final List<Article> validHistory = [];
      
      for (var data in historyData) {
        try {
          // 💡 FIXED: Parsing manual karena format data di HistoryService (SharedPrefs)
          // berbeda dengan format dari API WordPress (Article.fromJson).
          // HistoryService menyimpan data yang sudah di-flatten (disederhanakan).
          
          validHistory.add(Article(
            id: data['id'].toString(),
            source: Source(
              id: data['source'] != null ? data['source']['id'] : null, 
              name: data['source'] != null ? data['source']['name'] : 'Owrite ID'
            ),
            title: data['title'] ?? 'No Title',
            description: data['description'],
            url: data['url'] ?? '',
            urlToImage: data['urlToImage'],
            publishedAt: DateTime.tryParse(data['publishedAt'] ?? '') ?? DateTime.now(),
            modifiedAt: DateTime.now(), // Fallback
            content: data['content'],
            category: data['category'] ?? 'General',
            author: data['author'],
            // Data tagIds mungkin tidak disimpan oleh history service sederhana, 
            // set empty agar tidak error.
            tagIds: [], 
            tags: [],
          ));
        } catch (e) {
          debugPrint("Error parsing history item: $e");
        }
      }

      if (mounted) {
        setState(() {
          _readingHistory = validHistory.take(5).toList(); 
        });
      }
    } catch (e) {
      debugPrint("Error loading reading history: $e");
    }
  }

  Future<void> _loadOrUpdateDailyCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final savedDate = prefs.getString(_prefsDailyCategoriesDateKey);
    List<String> chosenCategoryCodes = [];

    if (savedDate == currentDate) {
      chosenCategoryCodes =
          prefs.getStringList(_prefsDailyCategoriesListKey) ?? [];
    } else {
      List<String> pool = List.from(_rotatingCategoryPoolCodes);
      pool.shuffle(Random());
      chosenCategoryCodes = pool.take(2).toList();
      await prefs.setString(_prefsDailyCategoriesDateKey, currentDate);
      await prefs.setStringList(_prefsDailyCategoriesListKey, chosenCategoryCodes);
    }

    Map<String, dynamic>? cat1;
    Map<String, dynamic>? cat2;

    if (chosenCategoryCodes.isNotEmpty) {
      cat1 = _allCategories.firstWhere(
        (cat) => cat['category'] == chosenCategoryCodes[0],
        orElse: () => <String, dynamic>{}, 
      );
      if (cat1.isEmpty) cat1 = null; 
    }

    if (chosenCategoryCodes.length > 1) {
      cat2 = _allCategories.firstWhere(
        (cat) => cat['category'] == chosenCategoryCodes[1],
        orElse: () => <String, dynamic>{}, 
      );
      if (cat2.isEmpty) cat2 = null; 
    }

    if (mounted) {
      setState(() {
        _dailyCategory1 = cat1;
        _dailyCategory2 = cat2;
      });
    }
  }

  void _onProviderUpdate() {
    if (!mounted) return;
    final provider = Provider.of<ArticleProvider>(context, listen: false);
    final currentStatus = provider.status;

    // --- LOGIC TAMBAHAN: Handle loading state untuk Top News ---
    // Pastikan loading spinner Top News dimatikan ketika status selesai
    // Catatan: Top News sekarang menggunakan repository langsung dengan pageSize 10
    // bukan melalui provider, jadi logic ini mungkin tidak diperlukan lagi
    // Tapi tetap dipertahankan untuk kompatibilitas
    if (provider.currentCategory == 'Top News') {
      if (currentStatus != ArticleLoadingStatus.loading && 
          _categoryInitialLoading['Top News'] == true &&
          !_isLoadingAllTopNews) {
          setState(() {
            _categoryInitialLoading['Top News'] = false;
          });
      }
    }
    // -----------------------------------------------------------

    if (_previousCategory != provider.currentCategory) {
      final String currentCategoryKey = provider.currentCategory;
      _previousCategory = provider.currentCategory;

      // --- MODIFIKASI: Force Loading State ---
      // Paksa UI menampilkan spinner segera setelah kategori berubah
      setState(() {
        _categoryInitialLoading[currentCategoryKey] = true;
      });
      // --------------------------------------

      if (currentCategoryKey == 'Top News') {
        // Reset retry count saat kategori berubah ke Top News
        _topNewsRetryCount = 0;
        // Load semua artikel Top News secara otomatis
        _loadAllTopNewsArticles();
      } else {
        _loadCategoryData(currentCategoryKey, isRefresh: true);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToSelectedCategory(provider.currentCategory);
        }
      });
    }

    _previousStatus = currentStatus;
  }

  void _updateCachedRecommendations(List<Article> articles) {
    if (articles.isEmpty) {
      if (mounted) {
        setState(() {
          _cachedRecommendations = [];
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _cachedRecommendations = _getRecommendations(articles);
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    final authService = AuthService();
    final user = await authService.getCurrentUser();
    if (mounted) {
      setState(() => _currentUsername = user?['username'] ?? 'Guest');
    }
  }

  Future<void> _loadAllBookmarks() async {
    if (_isLoadingBookmarks) {
      if (mounted) setState(() => _isLoadingBookmarks = true);
    }
    try {
      final bookmarks = await _bookmarkService.getAllBookmarkedArticles();
      if (mounted) {
        setState(() {
          _allBookmarkedArticles = bookmarks;
          _isLoadingBookmarks = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading all bookmarks: $e");
      if (mounted) setState(() => _isLoadingBookmarks = false);
    }
  }

  Future<void> _loadOrUpdateWeeklySeed() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final savedDateString = prefs.getString(_prefsWeeklySeedDateKey);
    int seedToUse;
    final currentDateString =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    bool isNewWeek = false;

    if (savedDateString == null) {
      isNewWeek = true;
    } else {
      try {
        final savedDate = DateTime.parse(savedDateString);
        if (now.difference(savedDate).inDays >= 7) {
          isNewWeek = true;
        }
      } catch (e) {
        isNewWeek = true;
      }
    }

    if (isNewWeek) {
      seedToUse = now.millisecondsSinceEpoch; 
      await prefs.setString(_prefsWeeklySeedDateKey, currentDateString);
      await prefs.setInt(_prefsWeeklySeedValueKey, seedToUse);
    } else {
      seedToUse =
          prefs.getInt(_prefsWeeklySeedValueKey) ?? now.millisecondsSinceEpoch;
    }

    if (mounted) {
      setState(() {
        _weeklySeed = seedToUse;
      });
    }
  }

  List<Article> _getWeeklyShuffledArticles(List<Article> articles) {
    if (articles.isEmpty || _weeklySeed == 0) return articles;
    final shuffledList = List<Article>.from(articles);
    shuffledList.shuffle(Random(_weeklySeed));
    return shuffledList;
  }

  void _onScroll() {
    if (!mounted) return;

    final direction = _scrollController.position.userScrollDirection;

    if (direction == ScrollDirection.reverse &&
        _isHeaderVisible &&
        _scrollController.offset > 60.0) {
      _headerAnimController.reverse();
      if (mounted) {
        setState(() {
          _isHeaderVisible = false;
        });
      }
    }
    else if ((direction == ScrollDirection.forward && !_isHeaderVisible) ||
        (_scrollController.offset <= 60.0 && !_isHeaderVisible)) {
      _headerAnimController.forward();
      if (mounted) {
        setState(() {
          _isHeaderVisible = true;
        });
      }
    }

    final provider = Provider.of<ArticleProvider>(context, listen: false);
    final currentCategory = provider.currentCategory;

    if (currentCategory == 'Top News') {
      return; 
    }

    if (_categoryLoading[currentCategory] == true ||
        _categoryHasMore[currentCategory] == false) {
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;

    if (offset >= maxScroll - 300 &&
        _scrollController.position.outOfRange == false) {
      _loadMoreCategoryArticles(currentCategory);
    }
  }

  bool _onCategoryScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification ||
        notification is ScrollMetricsNotification) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _categoryScrollController.hasClients) {
          final metrics = _categoryScrollController.position;
          final maxScroll = metrics.maxScrollExtent;
          final currentScroll = metrics.pixels;
          const double tolerance = 1.0;

          bool showLeft = currentScroll > tolerance;
          bool showRight = currentScroll < maxScroll - tolerance;

          if (maxScroll <= tolerance) {
            showLeft = false;
            showRight = false;
          }

          if (showLeft != _showScrollLeft || showRight != _showScrollRight) {
            setState(() {
              _showScrollLeft = showLeft;
              _showScrollRight = showRight;
            });
          }
        }
      });
    }
    return true;
  }

  void _scrollCategoryRight() {
    if (!_categoryScrollController.hasClients) return;
    final currentScroll = _categoryScrollController.offset;
    const double scrollAmount = 150.0;

    final targetScroll = (currentScroll + scrollAmount).clamp(0.0, _categoryScrollController.position.maxScrollExtent);

    _categoryScrollController.animateTo(
      targetScroll,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollCategoryLeft() {
    if (!_categoryScrollController.hasClients) return;
    final currentScroll = _categoryScrollController.offset;
    const double scrollAmount = 150.0;

    final targetScroll = (currentScroll - scrollAmount)
        .clamp(0.0, _categoryScrollController.position.maxScrollExtent);

    _categoryScrollController.animateTo(
      targetScroll,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleBookmarkTap(BuildContext context, Article article) async {
    // Commented out: Original bookmark functionality with login redirect
    // final bool isCurrentlyBookmarked =
    //     _allBookmarkedArticles.any((a) => a.id == article.id);
    // final authService = AuthService();
    // final user = await authService.getCurrentUser();
    // final bool isGuest = user == null || user['username'] == 'Guest';
    // if (isGuest) {
    //   _showLoginRequiredSnackBar("Masuk untuk menyimpan artikel ini");
    //   return;
    // }
    // final String userId = user!['username'] as String;
    // if (isCurrentlyBookmarked) {
    //   bool removed = await _bookmarkService.removeBookmark(article);
    //   if (removed && mounted) {
    //     setState(() {
    //       _allBookmarkedArticles.removeWhere((a) => a.id == article.id);
    //     });
    //     widget.onBookmarkToggle(article);
    //     showBookmarkSnackbar(context, false); 
    //   }
    // } else {
    //   bool added = false; 
    //   try {
    //     await _bookmarkService.addBookmark(article, userId);
    //     added = true;
    //   } catch (e) {
    //     debugPrint("Gagal menambahkan bookmark: $e");
    //     if (mounted) {
    //       _showErrorSnackBar("Gagal menyimpan artikel. Silakan coba lagi.");
    //     }
    //   }
    //   if (added && mounted) {
    //     setState(() {
    //       _allBookmarkedArticles.insert(0, article);
    //     });
    //     widget.onBookmarkToggle(article);
    //     showBookmarkSnackbar(context, true); 
    //   }
    // }
    
    // New: Show notification instead of redirecting to login
    _showBookmarkDisabledSnackBar("Tidak bisa menyimpan artikel untuk saat ini");
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

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
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
                ScaffoldMessenger.of(context).hideCurrentSnackBar()),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.green[300]),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: Colors.white)))
        ]),
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
        content: Row(children: [
          Icon(Icons.lock_outline, color: Colors.yellow[700]),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)))
        ]),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
            label: 'LOGIN',
            textColor: Colors.yellow[700],
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LoginScreen()))),
      ),
    );
  }

  // --- 💡 MODIFIED: Use ID-based isImportantNews check ---
  List<Article> _getPopularArticles(List<Article> articles) {
    if (articles.isEmpty) {
      print("🔴 POPULAR DEBUG: No articles in source list");
      return [];
    }

    print("🟡 POPULAR DEBUG: Total articles in source: ${articles.length}");

    // Filter artikel dengan TAG ID 1810
    final filtered = articles.where((article) {
      final hasTag = article.isImportantNews;
      print("📋 Article ID ${article.id}: hasTag=$hasTag, tagIds=${article.tagIds}");
      return hasTag;
    }).toList();

    print("🟢 POPULAR DEBUG: Filtered articles count: ${filtered.length}");

    if (filtered.isEmpty) {
      print("🔴 POPULAR DEBUG: No articles with tag 1810 found");
      return [];
    }

    // Sort berdasarkan modifiedAt (terbaru di atas)
    filtered.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

    print("✅ POPULAR DEBUG: Showing article: ${filtered.first.title}");
    
    // Simpan untuk debugging
    if (mounted) {
      setState(() {
        _debugImportantArticles = filtered;
      });
    }

    return [filtered.first];
  }

  List<Article> _getBeritaTerkiniArticles(List<Article> articles) {
    if (articles.isEmpty) return [];
    return articles.skip(1).take(_beritaTerkiniCount).toList();
  }

  List<Article> _getDiscoverMoreArticles(List<Article> articles) {
    if (articles.isEmpty) return [];
    return articles.skip(8).toList();
  }

  List<Article> _getArticlesByCategory(List<Article> articles, String category) {
    if (articles.isEmpty) return [];
    return articles
        .where((article) => article.category.toUpperCase() == category.toUpperCase())
        .toList();
  }

  List<Article> _getRecommendations(List<Article> articles) {
    if (articles.isEmpty) return [];
    final shuffled = List<Article>.from(articles)..shuffle(Random());
    return shuffled.take(5).toList();
  }

  void _navigateToSeeAll(String title, List<Article> articles) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SeeAllArticlesScreen(
          title: title,
          articles: articles,
          bookmarkedArticles: widget.bookmarkedArticles,
          onBookmarkToggle: widget.onBookmarkToggle,
        ),
      ),
    );
  }

  // --- 💡 REAL-TIME LOGIC FIX ---
  void _onArticleRead(Article article) {
    if (mounted) {
      setState(() {
        _readingHistory.removeWhere((a) => a.id == article.id);
        _readingHistory.insert(0, article);
        
        if (_readingHistory.length > 5) {
          _readingHistory = _readingHistory.take(5).toList();
        }
      });
      
      _historyService.addToHistory(article).then((_) {
          // _loadReadingHistory(); 
      });
    }
  }

  void _openArticle(Article article) {
    _onArticleRead(article);
  }

  void _loadMoreBeritaTerkini() {
    if (_isLoadMoreBeritaTerkini) return;

    setState(() {
      _isLoadMoreBeritaTerkini = true;
    });

    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted) { 
        setState(() {
          _beritaTerkiniCount += 7; 
          _isLoadMoreBeritaTerkini = false; 
        });
      }
    });
  }

  Future<void> _loadMoreCategoryArticles(String categoryCode) async {
    if (_categoryLoading[categoryCode] == true ||
        _categoryHasMore[categoryCode] == false) {
      return;
    }

    if (mounted) {
      setState(() {
        _categoryLoading[categoryCode] = true;
      });
    }

    const int pageSize = 10;
    final int nextPage = (_categoryCurrentPage[categoryCode] ?? 1) + 1;
    final String repoCategoryCode =
        (categoryCode == 'ALL_NEWS') ? 'Top News' : categoryCode;

    try {
      final newArticles = await _articleRepository.getArticlesByCategory(
        repoCategoryCode,
        page: nextPage,
        pageSize: pageSize,
      );

      if (mounted) {
        setState(() {
          _groupedArticles[categoryCode]?.addAll(newArticles); 
          _categoryCurrentPage[categoryCode] = nextPage; 
          _categoryHasMore[categoryCode] = newArticles.length == pageSize; 
          _categoryLoading[categoryCode] = false; 
        });
      }
    } catch (e) {
      debugPrint("Failed to load more for $categoryCode: $e");
      if (mounted) {
        setState(() {
          _categoryLoading[categoryCode] = false;
          _categoryHasMore[categoryCode] = false; 
        });
      }
    }
  }
  
  Future<void> _handleTopNewsLoadMoreButton() async {
    if (_isLoadingMoreButton) return;
    
    // Cek apakah masih ada artikel yang bisa dimuat
    if (_categoryHasMore['Top News'] != true) return;
    
    setState(() {
      _isLoadingMoreButton = true;
    });
    
    try {
      const int pageSize = 10;
      final int currentPage = _categoryCurrentPage['Top News'] ?? 1;
      final int nextPage = currentPage + 1;
      
      // Load 10 artikel berikutnya menggunakan repository
      final newArticles = await _articleRepository.getArticlesByCategory(
        'Top News',
        page: nextPage,
        pageSize: pageSize,
      );
      
      if (mounted) {
        setState(() {
          // Tambahkan artikel baru ke list yang sudah ada
          final existingArticles = _groupedArticles['Top News'] ?? [];
          final allArticles = [...existingArticles, ...newArticles];
          
          // Urutkan semua artikel berdasarkan tanggal terbaru ke terlama
          allArticles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
          
          _groupedArticles['Top News'] = allArticles;
          _categoryCurrentPage['Top News'] = nextPage;
          _categoryHasMore['Top News'] = newArticles.length == pageSize;
          _isLoadingMoreButton = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading more Top News articles: $e");
      if (mounted) {
        setState(() {
          _isLoadingMoreButton = false;
          _categoryHasMore['Top News'] = false; // Set false jika error
        });
      }
    }
  }

  // 🆕 FUNGSI UNTUK MEMUAT HALAMAN PERTAMA TOP NEWS (10 ARTIKEL)
  Future<void> _loadAllTopNewsArticles() async {
    if (_isLoadingAllTopNews) return; // Hindari multiple calls
    
    if (mounted) {
      setState(() {
        _isLoadingAllTopNews = true;
        _categoryInitialLoading['Top News'] = true;
      });
    }

    try {
      const int pageSize = 10;
      const int pageToLoad = 1;
      
      // Load 10 artikel pertama menggunakan repository
      final articles = await _articleRepository.getArticlesByCategory(
        'Top News',
        page: pageToLoad,
        pageSize: pageSize,
      );
      
      // Urutkan artikel berdasarkan tanggal terbaru ke terlama
      final sortedArticles = List<Article>.from(articles);
      sortedArticles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      
      if (mounted) {
        setState(() {
          _groupedArticles['Top News'] = sortedArticles;
          _categoryCurrentPage['Top News'] = pageToLoad;
          _categoryHasMore['Top News'] = articles.length == pageSize;
          _categoryInitialLoading['Top News'] = false;
          _isLoadingAllTopNews = false;
          // Reset retry count jika berhasil load
          if (sortedArticles.isNotEmpty) {
            _topNewsRetryCount = 0;
          }
        });
        
        // Update cached recommendations
        if (sortedArticles.isNotEmpty) {
          _updateCachedRecommendations(sortedArticles);
        }
      }
    } catch (e) {
      debugPrint("Error loading Top News articles: $e");
      if (mounted) {
        setState(() {
          _categoryInitialLoading['Top News'] = false;
          _isLoadingAllTopNews = false;
          // Jika error, tetap tampilkan artikel yang sudah dimuat sebelumnya (jika ada)
          if (_groupedArticles['Top News'] == null) {
            _groupedArticles['Top News'] = [];
          }
        });
      }
    }
  }

  Future<void> _loadCategoryData(String categoryCode, {bool isRefresh = false}) async {
    if (_categoryLoading[categoryCode] == true && !isRefresh) return;

    if (mounted) {
      setState(() {
        _categoryInitialLoading[categoryCode] = true;
        _categoryLoading[categoryCode] = true;
      });
    }

    const int pageSize = 10;
    const int pageToLoad = 1; 
    final String repoCategoryCode =
        (categoryCode == 'ALL_NEWS') ? 'Top News' : categoryCode;

    try {
      final articles = await _articleRepository.getArticlesByCategory(
        repoCategoryCode,
        page: pageToLoad,
        pageSize: pageSize,
      );

      if (mounted) {
        setState(() {
          _groupedArticles[categoryCode] = articles; 
          _categoryCurrentPage[categoryCode] = pageToLoad;
          _categoryHasMore[categoryCode] = articles.length == pageSize;
          // Reset retry count jika berhasil load Top News
          if (categoryCode == 'Top News' && articles.isNotEmpty) {
            _topNewsRetryCount = 0;
          }
        });
      }
    } catch (e) {
      debugPrint("Failed to load initial data for $categoryCode: $e");
      if (mounted) {
        setState(() {
          _groupedArticles[categoryCode] = []; 
          _categoryHasMore[categoryCode] = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _categoryInitialLoading[categoryCode] = false;
          _categoryLoading[categoryCode] = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _categoryScrollController.dispose();
    _headlinePageController.dispose();
    _todayPageController.dispose(); 
    if (_articleProvider != null) {
      _articleProvider!.removeListener(_onProviderUpdate);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final articleProvider = Provider.of<ArticleProvider>(context);
    final status = articleProvider.status;
    final articles = articleProvider.articles;
    final currentCategory = articleProvider.currentCategory;

    final isTopNews = currentCategory == 'Top News';
    final isAllNews = currentCategory == 'ALL_NEWS';

    return Scaffold(
      drawer: _buildAppDrawer(isDark),
      body: SafeArea(
        child: Column(
          children: [
            SizeTransition(
              sizeFactor: _headerHeightAnimation,
              axisAlignment: -1.0,
              child: ClipRect(
                child: _buildStickyHeader(isDark, themeProvider, articleProvider),
              ),
            ),
            _buildCategoriesBar(articleProvider, isDark),
            Divider(
              height: 1,
              thickness: 1.5,
              color: isDark ? Colors.grey[700] : Colors.grey[400],
            ),
            Expanded(
              child: _buildContent(status, articles, isDark, articleProvider,
                  isTopNews),
            ),
          ],
        ),
      ),
    );
  }

  // ... (Header and Drawer methods unchanged) ...
  Widget _buildStickyHeader(bool isDark, ThemeProvider themeProvider, ArticleProvider articleProvider) {
    final String svgFillColor = isDark ? "white" : "black";
    final String svgIcon = '''
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
      <path fill="$svgFillColor" d="M15.5 5a3.5 3.5 0 1 0 0 7a3.5 3.5 0 0 0 0-7ZM10 8.5a5.5 5.5 0 1 1 10.032 3.117l2.675 2.676l-1.414 1.414l-2.675-2.675A5.5 5.5 0 0 1 10 8.5ZM3 4h5v2H3V4Zm0 7h5v2H3v-2Zm18 7v2H3v-2h18Z"/>
      </svg>
    ''';

    return Container(
      height: 60,
      color: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: SvgPicture.string(
              svgIcon,
              width: 24,
              height: 24,
            ),
            onPressed: () {
              final String activeCategory = articleProvider.currentCategory;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SearchScreen(
                    bookmarkedArticles: widget.bookmarkedArticles,
                    onBookmarkToggle: widget.onBookmarkToggle,
                    initialCategory: activeCategory,
                  ),
                ),
              );
            },
            tooltip: 'Cari', 
          ),

          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 10.0), 
                child: Image.asset(
                  isDark
                      ? 'assets/images/banner-owrite-black.jpg'
                      : 'assets/images/banner-owrite-white.jpg',
                  height: 44,
                ),
              ),
            ),
          ),

          IconButton(
            icon: SvgPicture.string(
              '''
                  <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 20 20">
                    <path fill="${isDark ? '#FFFFFF' : '#000000'}" d="M4 8a6 6 0 0 1 4.03-5.67a2 2 0 1 1 3.95 0A6 6 0 0 1 16 8v6l3 2v1H1v-1l3-2V8zm8 10a2 2 0 1 1-4 0h4z"/>
                  </svg>
                  ''',
              width: 20,
              height: 20,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
            tooltip: 'Notifikasi',
          ),

          const ThemeToggleButton(),

        ],
      ),
    );
  }

  Widget _buildAppDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0), 
              child: Text(
                'Semua Kategori',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900, 
                  fontFamily: 'Arimo',
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[300],
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _allCategories.length, 
                itemBuilder: (context, index) {
                  final category = _allCategories[index];
                  final categoryCode = category['category'];
                  final categoryTitle = category['title'];

                  return Column(
                    children: [
                      ListTile(
                        title: Text(
                          categoryTitle,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w500, 
                          ),
                        ),
                        onTap: () {
                          Provider.of<ArticleProvider>(context, listen: false)
                              .changeCategory(categoryCode);
                          Navigator.of(context).pop();
                        },
                      ),
                      DottedDivider(
                        color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        height: 1,
                        indent: 16.0, 
                        endIndent: 16.0, 
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToSelectedCategory(String? categoryCode) {
    final String keyString;
    if (categoryCode == 'Top News' || categoryCode == null) {
      keyString = 'top-news'; 
    } else {
      keyString = categoryCode; 
    }

    final GlobalKey? key = _categoryKeys[keyString];

    if (key == null ||
        key.currentContext == null ||
        !_categoryScrollController.hasClients) return;

    final RenderBox? renderBox =
        key.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final viewportWidth = _categoryScrollController.position.viewportDimension;
    final itemWidth = renderBox.size.width;

    Scrollable.ensureVisible(
      key.currentContext!,
      alignment: 0.5, 
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildCategoryItem(
  Map<String, dynamic> category,
  ArticleProvider provider,
  bool isDark,
  GlobalKey textKey,
  ) {
    final String categoryCode = category['category']; 
    final String activeCategory = provider.currentCategory; 
      
    final bool isSelected = (categoryCode == activeCategory);

    final Color activeColor = isDark ? Color(0xFFE5FF10) : Colors.black;

    return GestureDetector(
      onTap: () {
        provider.changeCategory(category['category']);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        constraints: const BoxConstraints(
          minHeight: 34,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category['title'] ?? 'Top News',
                  key: textKey,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? activeColor
                        : (isDark ? Colors.grey[500] : Colors.grey[600]),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                if (isSelected)
                  Builder(builder: (context) {
                    double indicatorWidth;
                    final contextObj = textKey.currentContext;
                    if (contextObj != null) {
                      final RenderObject? renderObj = contextObj.findRenderObject();
                      if (renderObj is RenderBox && renderObj.hasSize) {
                        indicatorWidth = renderObj.size.width.clamp(36.0, 110.0);
                      } else {
                        final String text = category['title'] ?? 'Top News';
                        indicatorWidth = (text.length * 7.6).clamp(36.0, 110.0);
                      }
                    } else {
                      final String text = category['title'] ?? 'Top News';
                      indicatorWidth = (text.length * 7.6).clamp(36.0, 110.0);
                    }
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.ease,
                      height: 2,
                      width: indicatorWidth,
                      color: activeColor,
                      margin: const EdgeInsets.only(top: 0, bottom: 0),
                    );
                  })
                else
                  const SizedBox(height: 2),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoriesBar(ArticleProvider provider, bool isDark) {
    final Map<String, dynamic> topNewsCategory = {
      'title': 'Top News',
      'category': 'Top News', 
    };

    final List<Map<String, dynamic>> fullCategoriesList = [
      topNewsCategory,
      ..._allCategories,
    ];

    final Color fogColor = isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor;
    final Color buttonIconColor = isDark ? Colors.white : Colors.black;

    return Container(
      height: 50,
      color: fogColor,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onCategoryScrollNotification,
        child: Stack(
          children: [
            ListView.builder(
              key: _categoryListKey,
              scrollDirection: Axis.horizontal,
              controller: _categoryScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: fullCategoriesList.length,
              itemBuilder: (context, index) {
                final Map<String, dynamic> category = fullCategoriesList[index];
                final String keyString;

                final categoryCode = category['category'];

                if (index == 0) {
                  keyString = 'top-news';
                } else {
                  keyString = categoryCode ?? 'category_$index';
                }

                if (!_categoryKeys.containsKey(keyString)) {
                  _categoryKeys[keyString] = GlobalKey();
                }
                if (!_categoryTextKeys.containsKey(keyString)) {
                  _categoryTextKeys[keyString] = GlobalKey();
                }

                return Container(
                  key: _categoryKeys[keyString]!,
                  child: _buildCategoryItem(
                    category,
                    provider,
                    isDark,
                    _categoryTextKeys[keyString]!,
                  ),
                );
              },
            ),

            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 55,
              child: IgnorePointer(
                ignoring: !_showScrollLeft,
                child: AnimatedOpacity(
                  opacity: _showScrollLeft ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.centerRight,
                        colors: [
                          fogColor,
                          fogColor.withOpacity(0.0),
                        ],
                      ),
                    ),
                    child: Center(
                      child: IconButton(
                        icon: Icon(Icons.chevron_left, color: buttonIconColor),
                        onPressed: _scrollCategoryLeft,
                        tooltip: 'Scroll Kiri',
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 55,
              child: IgnorePointer(
                ignoring: !_showScrollRight,
                child: AnimatedOpacity(
                  opacity: _showScrollRight ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.centerLeft,
                        colors: [
                          fogColor,
                          fogColor.withOpacity(0.0),
                        ],
                      ),
                    ),
                    child: Center(
                      child: IconButton(
                        icon: Icon(Icons.chevron_right, color: buttonIconColor),
                        onPressed: _scrollCategoryRight,
                        tooltip: 'Scroll Kanan',
                      ),
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

  Widget _buildContent(ArticleLoadingStatus status, List<Article> providerArticles, 
      bool isDark, ArticleProvider provider, bool isTopNews) {
    final isAllNews = false; 

    if (isTopNews) {
      if (_categoryInitialLoading['Top News'] == true) {
        return Center(
            child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_loadMoreButtonColor),
        ));
      }
      final articlesToShow = _groupedArticles['Top News'] ?? [];
      if (articlesToShow.isEmpty && _categoryInitialLoading['Top News'] == false) {
        // 🆕 RETRY OTOMATIS: Trigger retry otomatis jika belum mencapai max attempts
        if (_topNewsRetryCount < _maxRetryAttempts) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _topNewsRetryCount++;
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  // Load halaman pertama Top News (10 artikel) secara otomatis
                  _loadAllTopNewsArticles();
                }
              });
            }
          });
        }
        
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.string(
                '''
                <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 24 24">
                  <path fill="${isDark ? "#FFFFFF" : "#000000"}" d="M9.5 6.5a.75.75 0 0 1 .75-.75h6.5a.75.75 0 0 1 0 1.5h-6.5a.75.75 0 0 1-.75-.75m4.638 2.25h2.224c.06 0 .13 0 .193.005a.8.8 0 0 1 .285.077a.75.75 0 0 1 .328.328a.7.7 0 0 1 .077.285c.005.063.005.134.005.193v1.724c0 .06 0 .13-.005.193a.8.8 0 0 1-.077.286a.75.75 0 0 1-.328.327a.8.8 0 0 1-.285.077c-.063.005-.134.005-.193.005h-2.224c-.06 0-.13 0-.193-.005a.8.8 0 0 1-.286-.077a.75.75 0 0 1-.327-.327a.8.8 0 0 1-.077-.286c-.005-.063-.005-.134-.005-.193V9.638c0-.06 0-.13.005-.193a.8.8 0 0 1 .077-.285a.75.75 0 0 1 .327-.328a.8.8 0 0 1 .286-.077c.063-.005.134-.005.193-.005m.112 1v1.5h2v-1.5zm-4.5-.25a.5.5 0 0 1 .5-.5h1.25a.5.5 0 0 1 0 1h-1.25a.5.5 0 0 1-.5-.5m.5 1.75a.5.5 0 0 0 0 1h1.25a.5.5 0 0 0 0-1zm-.5 3.25a.5.5 0 0 1 .5-.5h6.5a.5.5 0 0 1 0 1h-6.5a.5.5 0 0 1-.5-.5"/>
                  <path fill="${isDark ? "#FFFFFF" : "#000000"}" d="M16.321 3H10.68c-.542 0-.98 0-1.333.029c-.365.03-.685.093-.981.243a2.5 2.5 0 0 0-1.093 1.093c-.15.296-.213.616-.243.98C7 5.7 7 6.138 7 6.68V17H4.5a.5.5 0 0 0-.5.5c0 1.622.548 2.536 1.2 3.025c.314.236.629.354.866.413c.14.035.283.06.427.062c1.657.012 7.187 0 10.123 0c.689 0 1.385.05 2.019-.273c.813-.414 1.264-1.185 1.336-2.073c.029-.354.029-.79.029-1.332V6.679c0-.542 0-.98-.029-1.333c-.03-.365-.093-.685-.244-.981a2.5 2.5 0 0 0-1.092-1.093c-.296-.15-.616-.213-.98-.243C17.3 3 16.862 3 16.32 3m.479 16.725c-.348-.261-.8-.847-.8-2.225a.5.5 0 0 0-.5-.5H8V6.7c0-.568 0-.964.026-1.273c.024-.302.07-.476.137-.608a1.5 1.5 0 0 1 .656-.656c.132-.067.306-.113.608-.137C9.736 4 10.132 4 10.7 4h5.6c.568 0 .965 0 1.273.026c.302.024.476.07.608.137a1.5 1.5 0 0 1 .656.656c.067.132.113.306.137.608C19 5.736 19 6.132 19 6.7v10.6c0 .568 0 .965-.026 1.273c-.044.546-.286 1.005-.793 1.264c-.45.229-.98.189-1.381-.112M15.68 20H6.506a1.3 1.3 0 0 1-.705-.275c-.303-.227-.684-.7-.778-1.725h9.996c.07.896.323 1.542.663 2"/>
                </svg>
                ''',
                width: 64,
                height: 64,
              ),
              const SizedBox(height: 16),
              Text('Tidak ada artikel Top News',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              if (_topNewsRetryCount < _maxRetryAttempts) ...[
                const SizedBox(height: 8),
                Text(
                  'Memuat ulang otomatis...',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        );
      }
    } else {
      final currentCategory = provider.currentCategory;
      if (_categoryInitialLoading[currentCategory] == true) {
        return Center(
            child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_loadMoreButtonColor),
        ));
      }
    }

    final List<Article> articlesForView;
    if (isTopNews) {
      // 🆕 Pastikan artikel Top News diurutkan dari terbaru ke terlama
      final allTopNews = _groupedArticles['Top News'] ?? [];
      articlesForView = List<Article>.from(allTopNews)
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    } else {
      articlesForView = _groupedArticles[provider.currentCategory] ?? [];
    }

    final List<Article> displayArticles = articlesForView;

    return RefreshIndicator(
      onRefresh: () async {
        final currentCategory =
            Provider.of<ArticleProvider>(context, listen: false)
                .currentCategory;
        if (currentCategory == 'Top News') {
          // 🆕 Refresh Slider juga saat pull-to-refresh
          _loadSliderData();
          // Load halaman pertama Top News (10 artikel) saat refresh
          await _loadAllTopNewsArticles();
        } else {
          await _loadCategoryData(currentCategory, isRefresh: true);
        }
      },
      color: const Color(0xFF00FF00),
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        children: [
          if (isTopNews) ...[
            // 💡 NEW LOGIC: Menampilkan 1 berita terbaru menggunakan layoutFullscreen PALING ATAS
            if (articlesForView.isNotEmpty)
               ArticleCard(
                 article: articlesForView.first,
                 isBookmarked: _allBookmarkedArticles.any((b) => b.id == articlesForView.first.id),
                 onBookmarkToggle: () => _handleBookmarkTap(context, articlesForView.first),
                 index: 0,
                 layout: ArticleCardLayout.layoutFullscreen, // Menggunakan Fullscreen Layout
                 onArticleRead: _onArticleRead,
               ),

            // 💡 REORDERED: Slider now appears second (after the first news)
            // 🆕 Gunakan Slider Section yang sudah dimodifikasi dengan state khusus
            _buildSliderSection(isDark, articlesForView.isNotEmpty ? articlesForView.first : null),
                        
            // 💡 MODIFIED: Pass 'articlesForView' (full list) but skip(1) to avoid duplication of the top article
            // Karena index 0 sudah ditampilkan di atas sebagai defaultCard, list di bawah mulai dari index 1
            // PENTING: Pass 'articlesForView' sebagai fullArticles untuk keperluan filtering "TODAY" nanti
            _buildRepeatingTopNewsLayout(displayArticles.skip(1).toList(), isDark, articlesForView),

          ] else ...[
            _buildRepositoryCategoryList(
                isDark, provider.currentCategory, 
                ),
          ],
        ],
      ),
    );
  }

  // ... (Helper methods for headlines and daily seed unchanged) ...
  // 💡 PERBAIKAN LOGIC: Filter berdasarkan TAG Headline (ID 109)
  // ⚠️ NOTE: Method ini sekarang digantikan oleh _loadSliderData,
  // tapi kita biarkan untuk fallback jika diperlukan atau dihapus.
  // Untuk kebersihan kode, logika utama sekarang ada di _loadSliderData.

  // 💡 MODIFIKASI: Method ini sekarang menggunakan data yang SUDAH di-fetch (State: _headlineArticles & _editorialArticles)
  Widget _buildSliderSection(bool isDark, Article? topNewsArticle) {
    // Gunakan state local yang sudah difetch secara khusus
    var headlineArticles = List<Article>.from(_headlineArticles);
    var choiceArticles = List<Article>.from(_editorialArticles);

    // Filter duplikasi: Hapus artikel Top News #1 jika ada di dalam headline/choice
    if (topNewsArticle != null) {
      headlineArticles.removeWhere((a) => a.id == topNewsArticle.id);
      choiceArticles.removeWhere((a) => a.id == topNewsArticle.id);
    }

    // Filter duplikasi: Pastikan artikel Choice tidak sama dengan artikel Headline
    choiceArticles.removeWhere((choice) => headlineArticles.any((head) => head.id == choice.id));

    // Ambil maksimal 3 setelah filter
    headlineArticles = headlineArticles.take(3).toList();
    choiceArticles = choiceArticles.take(3).toList();

    // Jika tidak ada data headline, sembunyikan section
    if (headlineArticles.isEmpty && !_isLoadingSlider) return const SizedBox.shrink();

    // Tampilkan loading jika sedang fetch
    if (_isLoadingSlider && headlineArticles.isEmpty) {
       return const Padding(
         padding: EdgeInsets.all(20.0),
         child: Center(child: CircularProgressIndicator()),
       );
    }

    final String currentTitle = _currentHeadlineIndex == 0 ? "HEADLINE" : "BERITA PILIHAN";

    return Column(
      children: [
        const SizedBox(height: 36),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 10), 
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5FF10),
                      shape: BoxShape.circle,
                    ),
                    margin: const EdgeInsets.only(right: 10),
                  ),
                  Text(
                    currentTitle,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                      letterSpacing: 1.2, 
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),

              Row(
                children: [
                  _buildNavButton(
                    context, 
                    icon: Icons.chevron_left, 
                    isActive: _currentHeadlineIndex == 0,
                    onTap: () {
                      _headlinePageController.animateToPage(
                        0, 
                        duration: const Duration(milliseconds: 300), 
                        curve: Curves.easeInOut
                      );
                    },
                    isDark: isDark
                  ),
                  const SizedBox(width: 8),
                  _buildNavButton(
                    context, 
                    icon: Icons.chevron_right, 
                    isActive: _currentHeadlineIndex == 1,
                    onTap: () {
                      _headlinePageController.animateToPage(
                        1, 
                        duration: const Duration(milliseconds: 300), 
                        curve: Curves.easeInOut
                      );
                    },
                    isDark: isDark
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 460, 
          child: PageView(
            controller: _headlinePageController,
            onPageChanged: (index) {
              setState(() {
                _currentHeadlineIndex = index;
              });
            },
            children: [
              _buildVerticalList(headlineArticles, ArticleCardLayout.layoutHeadline, isDark),
              // Jika BERITA PILIHAN kosong, tampilkan widget kosong atau pesan, 
              // tapi biasanya PageView tetap merender, jadi kita cek di builder
              choiceArticles.isEmpty 
                  ? Center(child: Text("Belum ada Berita Pilihan", style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600])))
                  : _buildVerticalList(choiceArticles, ArticleCardLayout.layoutChoose, isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNavButton(BuildContext context, {required IconData icon, required bool isActive, required VoidCallback onTap, required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? const Color(0xFFE5FF10) : Colors.transparent, 
          border: isActive ? null : Border.all(color: Colors.grey, width: 1), 
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.black : (isDark ? Colors.white : Colors.black),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildVerticalList(List<Article> articles, ArticleCardLayout layout, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: articles.map((article) {
           final isBookmarked = _allBookmarkedArticles.any((b) => b.id == article.id);
           return ArticleCard(
             article: article,
             isBookmarked: isBookmarked,
             onBookmarkToggle: () => _handleBookmarkTap(context, article),
             index: 0, 
             layout: layout,
             // 💡 PASS CALLBACK DISINI
             onArticleRead: _onArticleRead, 
           );
        }).toList(),
      ),
    );
  }

  // --- 💡 WIDGET READING HISTORY (BACA ULANG) ---
  Widget _buildReadingHistorySection(bool isDark) {
    // 💡 Gunakan _readingHistory yang diupdate real-time
    final bool hasHistory = _readingHistory.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        
        Padding(
          padding: const EdgeInsets.only(left: 18.0, right: 18.0, bottom: 0, top: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BACA KEMBALI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Arimo',
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 1.5,
                color: isDark ? Colors.grey[700] : Colors.grey[400],
              ),
            ],
          ),
        ),

        if (!hasHistory)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reading History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'CrimsonPro',
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Stories you've read in the last 24 hours will show up here.",
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Inter',
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

        if (hasHistory)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0, top: 24.0),
            child: ArticleSlider( 
              articles: _readingHistory,
              onBookmarkToggle: (index, article) => _handleBookmarkTap(context, article),
              isBookmarked: (article) => _allBookmarkedArticles.any((b) => b.id == article.id),
              // 💡 PASS CALLBACK DISINI JUGA (Agar history reorder kalau klik dari slider sendiri)
              onArticleRead: _onArticleRead,
            ),
          ),
          
        if (!hasHistory)
          const SizedBox(height: 16),
      ],
    );
  }

  // --- 🆕 WIDGET SHORTS SECTION (REAL DATA) ---
  Widget _buildShortsSection(bool isDark) {
    // Gunakan Consumer untuk mendengarkan perubahan pada VideoProvider
    return Consumer<VideoProvider>(
      builder: (context, videoProvider, child) {
        
        // Cek loading awal
        if (videoProvider.status == VideoLoadingStatus.loading && videoProvider.videos.isEmpty) {
           return const Padding(
             padding: EdgeInsets.symmetric(vertical: 20),
             child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
           );
        }

        // Filter video untuk mendapatkan shorts (durasi <= 3 menit / 180 detik)
        final shortsVideos = videoProvider.videos.where(_isShorts).toList();
        
        // Jika tidak ada data shorts
        if (shortsVideos.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Padding(
              padding: const EdgeInsets.only(left: 18.0, right: 18.0, bottom: 0, top: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                       Text(
                        'SHORTS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Arimo',
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    thickness: 1.5,
                    color: isDark ? Colors.grey[700] : Colors.grey[400],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // UPDATE: Menyesuaikan height container untuk rasio 9:16
            SizedBox(
              height: 290, 
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: shortsVideos.length,
                itemBuilder: (context, index) {
                  final video = shortsVideos[index];
                  // UPDATE: Lebar item disesuaikan (160px)
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: SizedBox(
                      width: 160, 
                      child: VideoCard(
                        video: video,
                        onTap: () {
                           // Navigasi ke Shorts Player Full Screen
                           // Mengirim list lengkap dan index yang diklik
                           Navigator.of(context).push(
                             MaterialPageRoute(
                               builder: (context) => ShortsPlayerScreen(
                                 videos: shortsVideos,
                                 startIndex: index,
                               ),
                             ),
                           );
                        },
                        layout: VideoCardLayout.shorts, 
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // --- 🆕 WIDGET TODAY SECTION (BAGIAN PALING BAWAH) ---
  Widget _buildTodaySection(bool isDark, List<Article> allArticles) {
    // 1. Filter artikel 24 jam terakhir
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));

    final todayArticles = allArticles.where((a) {
      return a.publishedAt.isAfter(yesterday);
    }).toList();

    // Sort terbaru ke terlama
    todayArticles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    // --- LOGIKA PAGINATION (NEXT/PREV) ---
    const int batchSize = 5;
    final int totalItems = todayArticles.length;
    final int totalPages = (totalItems / batchSize).ceil(); // Calculate total pages

    // Safety Check: Reset index if out of bounds
    if (_todayPageIndex >= totalPages && totalPages > 0) {
      _todayPageIndex = 0;
    }

    final bool hasPrevious = _todayPageIndex > 0;
    final bool hasNext = _todayPageIndex < totalPages - 1;

    if (todayArticles.isEmpty) return const SizedBox.shrink();

    // Calculate Dynamic Height for PageView container
    final double screenWidth = MediaQuery.of(context).size.width;
    final double gridItemWidth = (screenWidth - 20) / 2; // approx padding 10*2
    final double gridItemHeight = gridItemWidth / 0.95; 
    final double sectionHeight = 180 + 16 + (gridItemHeight * 2) + 20;

    // Warna Icon
    final Color activeColor = isDark ? Colors.white : Colors.black;
    final Color inactiveColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Title TODAY & Navigation Icons
        Padding(
          padding: const EdgeInsets.only(left: 18.0, right: 18.0, bottom: 0, top: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TODAY',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Arimo',
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  // Navigation Icons Row
                  Row(
                    children: [
                      // Previous Icon
                      IconButton(
                        onPressed: hasPrevious
                            ? () {
                                _todayPageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        icon: Icon(
                          Icons.arrow_left, // Icon Panah Kiri
                          size: 28,
                          color: hasPrevious ? activeColor : inactiveColor,
                        ),
                        tooltip: 'Previous',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      ),
                      const SizedBox(width: 0), // Jarak antar icon
                      // Next Icon
                      IconButton(
                        onPressed: hasNext
                            ? () {
                                _todayPageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                        icon: Icon(
                          Icons.arrow_right, // Icon Panah Kanan
                          size: 28,
                          color: hasNext ? activeColor : inactiveColor,
                        ),
                        tooltip: 'Next',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 0),
              Divider(
                height: 1,
                thickness: 1.5,
                color: isDark ? Colors.grey[700] : Colors.grey[400],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // PAGEVIEW CONTENT
        SizedBox(
          height: sectionHeight,
          child: PageView.builder(
            controller: _todayPageController,
            physics: const NeverScrollableScrollPhysics(), // Disable swipe, use buttons
            onPageChanged: (index) {
              setState(() {
                _todayPageIndex = index;
              });
            },
            itemCount: totalPages,
            itemBuilder: (context, pageIndex) {
              final int startIndex = pageIndex * batchSize;
              final int endIndex = (startIndex + batchSize) > totalItems ? totalItems : (startIndex + batchSize);
              final List<Article> displayArticles = todayArticles.sublist(startIndex, endIndex);
              
              if (displayArticles.isEmpty) return const SizedBox.shrink();

              return Column(
                children: [
                   // Artikel Utama (Layout 1) - Index 0 dari batch saat ini
                  if (displayArticles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: ArticleCard(
                        article: displayArticles[0],
                        isBookmarked: _allBookmarkedArticles.any((b) => b.id == displayArticles[0].id),
                        onBookmarkToggle: () => _handleBookmarkTap(context, displayArticles[0]),
                        index: 0,
                        layout: ArticleCardLayout.layout1,
                        onArticleRead: _onArticleRead,
                        titleMaxLines: 3,
                        imageOnLeft: true,
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Grid 2 Columns x 2 Rows (Layout Default)
                  if (displayArticles.length > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 0,
                          mainAxisSpacing: 0,
                          childAspectRatio: 0.95, 
                        ),
                        itemCount: displayArticles.length - 1,
                        itemBuilder: (context, index) {
                          final article = displayArticles[index + 1];
                          return ArticleCard(
                            article: article,
                            isBookmarked: _allBookmarkedArticles.any((b) => b.id == article.id),
                            onBookmarkToggle: () => _handleBookmarkTap(context, article),
                            index: index + 1,
                            layout: ArticleCardLayout.defaultCard, 
                            onArticleRead: _onArticleRead,
                            isTodayGrid: true,
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        
        // --- BUTTONS BAWAH DIHAPUS ---
      ],
    );
  }
  
  // --- MODIFIED SECTION: REORDERED LIST ---
  // Layout: Header -> Slider -> Daftar Artikel (5 items) -> Popular -> Baca Ulang -> Daftar Artikel (sisa)
  Widget _buildRepeatingTopNewsLayout(List<Article> articles, bool isDark, List<Article> fullArticles) {
    // 1. Jika list kosong, tampilkan fallback Popular -> History -> Shorts -> Today
    if (articles.isEmpty) {
      return Column(
        children: [
          _buildPopularSection(fullArticles, isDark),
          const SizedBox(height: 36),
          _buildReadingHistorySection(isDark),
           const SizedBox(height: 24),
          _buildShortsSection(isDark), 
           const SizedBox(height: 36),
          _buildTodaySection(isDark, fullArticles), // Fallback Today
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...articles.asMap().entries.map((entry) {
            final index = entry.key;
            final article = entry.value;
            final isBookmarked = _allBookmarkedArticles.any((b) => b.id == article.id);

            ArticleCardLayout layout;

            // Logika layout asli untuk 5 item pertama
            if (index == 0) {
              layout = ArticleCardLayout.layout5;
            } else if (index >= 1 && index <= 4) {
              layout = ArticleCardLayout.layout4;
            } else {
              // --- NEW LOGIC: Setelah Baca Ulang (index >= 5) ---
              // Pattern: 1x Default, 5x Layout1, Repeat.
              // Relative index starts from 0 for items after the 5th item.
              int relativeIndex = index - 5;
              // Cycle length = 1 (Default) + 5 (Layout1) = 6
              int cyclePosition = relativeIndex % 6;

              if (cyclePosition == 0) {
                // Posisi ke-1 dalam cycle: Default Card
                layout = ArticleCardLayout.defaultCard;
              } else {
                // Posisi ke-2 sampai ke-6 dalam cycle: Layout 1
                layout = ArticleCardLayout.layout1;
              }
            }

            final cardWidget = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (index == 0) const SizedBox(height: 18),
                ArticleCard(
                  article: article,
                  isBookmarked: isBookmarked,
                  onBookmarkToggle: () => _handleBookmarkTap(context, article),
                  index: index,
                  layout: layout,
                  onArticleRead: _onArticleRead,
                ),
                
                // 💡 INSERT POPULAR & READING HISTORY HERE (after index 4, i.e., 5th item)
                // Layout: Slider -> List (0..4) -> Popular -> History -> List (5...)
                if (index == 4) ...[
                   const SizedBox(height: 16),
                   _buildPopularSection(fullArticles, isDark),
                   const SizedBox(height: 36),
                   _buildReadingHistorySection(isDark),
                   const SizedBox(height: 16),
                ],
                
                if (index == 0)
                  const SizedBox(height: 36),
              ],
            );

            return cardWidget;
          }).toList(),

          // 💡 FALLBACK: Jika list kurang dari 5 artikel (index 4 tidak pernah tercapai),
          // Maka Popular dan History belum muncul. Kita harus menambahkannya di akhir.
          if (articles.length <= 4) ...[
             const SizedBox(height: 16),
             _buildPopularSection(fullArticles, isDark),
             const SizedBox(height: 36),
             _buildReadingHistorySection(isDark),
          ],
          
          // 🆕 TOMBOL "LOAD MORE" UNTUK MEMUAT 10 ARTIKEL BERIKUTNYA
          if (_categoryHasMore['Top News'] == true) 
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 32.0, left: 20, right: 20),
              child: InkWell(
                onTap: _handleTopNewsLoadMoreButton,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? _loadMoreButtonColor
                        : Colors.black,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Center(
                    child: _isLoadingMoreButton
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.black
                                    : const Color(0xFFE5FF10),
                              ),
                            ),
                          )
                        : Text(
                            "SHOW MORE",
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              fontFamily: 'Arimo',
                            ),
                          ),
                  ),
                ),
              ),
            ),
           
           // --- 🆕 SECTION SHORTS SETELAH BUTTON LOAD MORE ---
           const SizedBox(height: 24),
           _buildShortsSection(isDark), // TAMPILKAN SHORTS DI SINI (REAL DATA)
           
           // --- 🆕 SECTION TODAY SETELAH SHORTS ---
           const SizedBox(height: 36),
           _buildTodaySection(isDark, fullArticles), // Bagian TODAY Ditambahkan Disini
           // --------------------------------------------------
           const SizedBox(height: 48),
        ],
      ),
    );
  }

  // ... (Other helper methods remain the same, just ensure _onArticleRead is passed where needed) ...
  Widget _buildRepositoryCategoryList(
      bool isDark, String categoryCode, 
      ) {
    final articlesToShow = _groupedArticles[categoryCode] ?? [];
    final isLoadingMore = _categoryLoading[categoryCode] ?? false;
    final hasMore = _categoryHasMore[categoryCode] ?? false;

    String displayTitle = _categoryTitles[categoryCode] ?? categoryCode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            child: Text(
              displayTitle.toUpperCase(), 
              textAlign: TextAlign.center, 
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Arimo',
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FractionallySizedBox(
            widthFactor: 0.93,
            child: Divider(
              height: 1.5,
              thickness: 1.5,
              color: isDark ? Colors.grey[700] : Colors.grey[400],
            ),
          ),

          const SizedBox(height: 16),
          if (articlesToShow.isEmpty && !isLoadingMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48.0),
              child: Text(
                'Tidak ada artikel pada kategori ini',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
            )
          else
            ...articlesToShow.asMap().entries.map((entry) {
              final index = entry.key;
              final article = entry.value;
              final isBookmarked =
                  _allBookmarkedArticles.any((b) => b.id == article.id);

              final ArticleCardLayout cardLayout;
                
              // 💡 UPDATE: Gunakan layoutfirst untuk item pertama
              cardLayout = (index == 0)
                  ? ArticleCardLayout.layoutfirst // <-- Layout baru
                  : ArticleCardLayout.layout2;
                
              return ArticleCard(
                article: article,
                isBookmarked: isBookmarked,
                onBookmarkToggle: () => _handleBookmarkTap(context, article),
                index: index,
                layout: cardLayout,
                onArticleRead: _onArticleRead, // Pass here too
              );
            }).toList(),

          const SizedBox(height: 24),
          if (isLoadingMore)
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_loadMoreButtonColor),
                strokeWidth: 3,
              ),
            )
            
          else if (articlesToShow.isNotEmpty && !hasMore) 
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Anda telah melihat semua berita yang tampil pada kategori ini',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- _buildCategoryArticleCard Logic ---
  Widget _buildCategoryArticleCard(BuildContext context, Article article, bool isDark) {
    return GestureDetector(
      onTap: () => _onArticleRead(article), 
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 160,
              width: double.infinity,
              child: article.urlToImage != null
                  ? CachedNetworkImage(
                      imageUrl: article.urlToImage!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        child: Icon(Icons.image_not_supported,
                            color: isDark ? Colors.grey[600] : Colors.grey[400], size: 40),
                      ),
                    )
                  : Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      child: Icon(Icons.image_not_supported,
                          color: isDark ? Colors.grey[600] : Colors.grey[400], size: 40),
                    ),
            ),

            Container(
              width: double.infinity,
              color: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
              padding: const EdgeInsets.all(8),
              child: Text(
                article.title,
                style: TextStyle(
                  fontFamily: 'Arimo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 💡 UPDATED: Create CLEAN Article to hide Tags & Broaden Filter ---
  Widget _buildPopularSection(List<Article> articles, bool isDark) {
    return FutureBuilder<List<Article>>(
      future: _popularArticlesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          print("⚠️ No popular articles from API");
          return const SizedBox.shrink();
        }

        final popularArticles = snapshot.data!;
        final article = popularArticles.first; // Ambil terbaru
        final isBookmarked = _allBookmarkedArticles.any((b) => b.id == article.id);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFE5FF10),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7.0),
              child: ArticleCard(
                article: article,
                isBookmarked: isBookmarked,
                onBookmarkToggle: () => _handleBookmarkTap(context, article),
                index: 0,
                layout: ArticleCardLayout.layout3,
                onArticleRead: _onArticleRead,
              ),
            ),
          ),
        );
      },
    );
  }
}

class ArticleSlider extends StatefulWidget {
  final List<Article> articles;
  final Function(int, Article) onBookmarkToggle;
  final bool Function(Article) isBookmarked;
  final Function(Article)? onArticleRead; // Baru

  const ArticleSlider({
    Key? key,
    required this.articles,
    required this.onBookmarkToggle,
    required this.isBookmarked,
    this.onArticleRead,
  }) : super(key: key);

  @override
  State<ArticleSlider> createState() => _ArticleSliderState();
}

class _ArticleSliderState extends State<ArticleSlider> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.articles.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.articles.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final article = widget.articles[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ArticleCard(
                  article: article,
                  isBookmarked: widget.isBookmarked(article),
                  onBookmarkToggle: () => widget.onBookmarkToggle(index, article),
                  index: index,
                  layout: ArticleCardLayout.layoutSlider,
                  // 💡 Teruskan callback ke ArticleCard di dalam Slider
                  onArticleRead: widget.onArticleRead,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.articles.length, (index) {
            final isActive = index == _currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: isActive ? 10 : 6,
              width: isActive ? 10 : 6,
              decoration: BoxDecoration(
                color: isActive 
                    ? const Color(0xFFE5FF10) 
                    : Colors.grey.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class DottedDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double indent;
  final double endIndent;

  const DottedDivider({
    Key? key,
    this.height = 1,
    this.color = Colors.grey,
    this.indent = 16,
    this.endIndent = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth() - indent - endIndent;
        const dashWidth = 1.0;
        const dashSpace = 3.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();

        return Padding(
          padding:
              EdgeInsets.only(left: indent, right: endIndent, top: 8, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: height,
                child: DecoratedBox(decoration: BoxDecoration(color: color)),
              );
            }),
          ),
        );
      },
    );
  }
}

class CategoryLatestScreen extends StatefulWidget {
  final String categoryTitle;
  final String categoryCode;
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle; 

  const CategoryLatestScreen({
    Key? key,
    required this.categoryTitle,
    required this.categoryCode,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  State<CategoryLatestScreen> createState() => _CategoryLatestScreenState();
}

class _CategoryLatestScreenState extends State<CategoryLatestScreen> {
  late Future<List<Article>> _articlesFuture;
  final ArticleRepository _repository = ArticleRepository(); 
    
  late List<Article> _currentBookmarkedArticles;


  @override
  void initState() {
    super.initState();
    _currentBookmarkedArticles = widget.bookmarkedArticles;
    _articlesFuture = _repository.getArticlesByCategory(
      widget.categoryCode,
      page: 1,
      pageSize: 50, 
    );
  }

  void _toggleBookmark(Article article) {
    widget.onBookmarkToggle(article);

    setState(() {
      final isBookmarked = _currentBookmarkedArticles.any((a) => a.id == article.id);
      if (isBookmarked) {
        _currentBookmarkedArticles.removeWhere((a) => a.id == article.id);
      } else {
        _currentBookmarkedArticles.insert(0, article);
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
      appBar: AppBar(
        backgroundColor:
            isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.categoryTitle, 
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'CrimsonPro',
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Article>>(
          future: _articlesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Gagal memuat artikel',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              );
            }

            final articles = snapshot.data;
            if (articles == null || articles.isEmpty) {
              return Center(
                child: Text(
                  'Tidak ada artikel',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final article = articles[index];
                final isBookmarked =
                    _currentBookmarkedArticles.any((b) => b.id == article.id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ArticleCard(
                    article: article,
                    isBookmarked: isBookmarked,
                    onBookmarkToggle: () => _toggleBookmark(article), 
                    index: index,
                    layout: ArticleCardLayout.layout3,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class SeeAllArticlesScreen extends StatelessWidget {
  final String title;
  final List<Article> articles;
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;

  const SeeAllArticlesScreen({
    Key? key,
    required this.title,
    required this.articles,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
      appBar: AppBar(
        backgroundColor:
            isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'CrimsonPro',
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: articles.isEmpty
            ? const Center(child: Text('Tidak ada artikel'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  final article = articles[index];
                  final isBookmarked =
                      bookmarkedArticles.any((b) => b.id == article.id);

                  return ArticleCard(
                    article: article,
                    isBookmarked: isBookmarked,
                    onBookmarkToggle: () => onBookmarkToggle(article),
                    index: index,
                    layout: ArticleCardLayout.layout3,
                  );
                },
              ),
      ),
    );
  }
}