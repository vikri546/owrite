import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // 💡 Tambahan: Untuk ScrollDirection
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../providers/article_provider.dart';
import '../utils/strings.dart';
import '../utils/auth_service.dart';
import 'login_screen.dart';
import '../providers/language_provider.dart';
import '../services/bookmark_service.dart';
import 'package:flutter/foundation.dart';
import 'article_detail_screen.dart';
import '../utils/custom_page_transitions.dart';
import '../widgets/article_card.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/theme_provider.dart';
import '../widgets/snackbar_toggle.dart';
import '../widgets/theme_toggle_button.dart';
// 💡 Tambahan: Impor repository untuk mengambil data secara independen
import '../repositories/article_repository.dart';
// --- AWAL TAMBAHAN: Impor untuk SearchScreen ---
import 'search_screen.dart';
import 'notifications_screen.dart';
// --- AKHIR TAMBAHAN ---

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
  // 💡 Tambahan: Buat instance repository
  final ArticleRepository _articleRepository = ArticleRepository();
  List<Article> _allBookmarkedArticles = [];
  bool _isLoadingBookmarks = true;

  // --- 💡 AWAL PERUBAHAN: State untuk tombol scroll ---
  bool _showScrollLeft = false;
  bool _showScrollRight = false;
  // --- 💡 AKHIR PERUBAHAN ---

  List<Article> _cachedRecommendations = [];
  ArticleLoadingStatus? _previousStatus;

  // 🔑 Map GlobalKey untuk scrolling
  final Map<String, GlobalKey> _categoryKeys = {};

  // --- 🌟 AWAL PERUBAHAN: State untuk Indikator Kategori ---
  // GlobalKey untuk widget Text di dalam item kategori
  final Map<String, GlobalKey> _categoryTextKeys = {}; // ✅ PERTAHANKAN
  // GlobalKey untuk widget ListView kategori itu sendiri
  final GlobalKey _categoryListKey = GlobalKey(); // ✅ PERTAHANKAN
  // --- 🌟 AKHIR PERUBAHAN ---

  // 💡 Tambahan: State untuk menyimpan Future dari kategori 'Terbaru'
  Future<List<Article>>? _latestCategory1Future;
  Future<List<Article>>? _latestCategory2Future;
  String? _latestCategory1Code; // Untuk melacak kategori
  String? _latestCategory2Code; // Untuk melacak kategori

  // --- AWAL PERUBAHAN: State untuk "Berita Terkini" (Load More) ---
  int _beritaTerkiniCount = 7; // Mulai dengan 7 artikel
  bool _isLoadMoreBeritaTerkini = false; // Status loading untuk tombol
  final Color _loadMoreColor = const Color(0xFFE5FF10); // Warna tombol
  // --- AKHIR PERUBAHAN ---

  // --- 🚀 AWAL MODIFIKASI: State untuk Paginasi Kategori (ala news_screen.dart) ---
  // Map untuk menyimpan artikel per kategori
  final Map<String, List<Article>> _groupedArticles = {};
  // Map untuk menyimpan halaman saat ini per kategori
  final Map<String, int> _categoryCurrentPage = {};
  // Map untuk menyimpan status 'masih ada data' per kategori
  final Map<String, bool> _categoryHasMore = {};
  // Map untuk menyimpan status 'loading' per kategori (baik initial/more)
  final Map<String, bool> _categoryLoading = {};
  // Map untuk status loading *awal* (spinner besar di tengah)
  final Map<String, bool> _categoryInitialLoading = {};

  // 🔑 final Map<String, int> _categoryDisplayCounts = {}; // <-- DIHAPUS
  // 🔑 bool _isCategoryLoadingMore = false; // <-- DIHAPUS (diganti Map)
  final Color _loadMoreButtonColor = const Color(0xFFE5FF10);
  // --- 🚀 AKHIR MODIFIKASI ---

  // --- AWAL MODIFIKASI: State untuk Animasi Header ---
  late AnimationController _headerAnimController;
  late Animation<double> _headerHeightAnimation;
  bool _isHeaderVisible = true;
  // --- AKHIR MODIFIKASI ---
  
  // --- PERBAIKAN: Simpan referensi ArticleProvider untuk digunakan di dispose() ---
  ArticleProvider? _articleProvider;
  // --- AKHIR PERBAIKAN ---

  final List<Map<String, dynamic>> _allCategories = [
    {'title': 'Hype', 'category': 'HYPE'},
    {'title': 'Olahraga', 'category': 'OLAHRAGA'},
    {'title': 'Ekonomi Bisnis', 'category': 'EKBIS'},
    {'title': 'Megapolitan', 'category': 'MEGAPOLITAN'},
    {'title': 'Daerah', 'category': 'DAERAH'},
    {'title': 'Nasional', 'category': 'NASIONAL'},
    {'title': 'Internasional', 'category': 'INTERNASIONAL'},
    // --- TAMBAHAN ---
    {'title': 'Politik', 'category': 'POLITIK'},
    {'title': 'Kesehatan', 'category': 'KESEHATAN'},
    // --- AKHIR TAMBAHAN ---
  ];

  // Map untuk mencocokkan kode kategori dengan judul (seperti di news_screen.dart)
  final Map<String, String> _categoryTitles = {
    // 'ALL_NEWS': 'All News', // <-- DIHAPUS
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

  // --- 💡 PERUBAHAN: Variabel untuk kategori harian ---
  Map<String, dynamic>? _dailyCategory1;
  Map<String, dynamic>? _dailyCategory2;

  // Daftar kategori yang akan dirotasi
  final List<String> _rotatingCategoryPoolCodes = [
    'HYPE',
    'OLAHRAGA',
    'EKBIS',
    'MEGAPOLITAN',
    'DAERAH',
  ];

  // Kunci SharedPreferences
  static const String _prefsDailyCategoriesDateKey = 'daily_categories_date';
  static const String _prefsDailyCategoriesListKey = 'daily_categories_list';

  // --- 💡 PERUBAHAN MINGGUAN: Variabel untuk 7 Artikel Pilihan ---
  int _weeklySeed = 0;
  // v2 ditambahkan untuk memastikan pengguna lama mendapat pembaruan jika kunci lama ter-cache
  static const String _prefsWeeklySeedDateKey = 'weekly_seed_date_v2';
  static const String _prefsWeeklySeedValueKey = 'weekly_seed_value_v2';
  // --- 💡 AKHIR PERUBAHAN ---

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // --- AWAL MODIFIKASI: Setup Animasi Header ---
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0, // Mulai dalam keadaan terlihat penuh
    );

    _headerHeightAnimation = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeInOut,
    );
    // --- AKHIR MODIFIKASI ---

    _scrollController.addListener(_onScroll); // <-- Listener untuk header & pagination
    _loadCurrentUser();
    _loadAllBookmarks();
    _loadOrUpdateDailyCategories(); // ⬅️ PANGGIL FUNGSI BARU
    _loadOrUpdateWeeklySeed(); // ⬅️ PANGGIL FUNGSI MINGGUAN

    // --- 🔑 PERUBAHAN: Set 'Top News' sebagai kategori default saat masuk ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _articleProvider != null) {
        // 1. Cek apakah kategori saat ini *bukan* 'Top News'
        if (_previousCategory != 'Top News') {
          // 2. Jika bukan, ubah ke 'Top News'.
          _articleProvider!.changeCategory('Top News');
        } else {
          // 3. Jika defaultnya SUDAH 'Top News', kita tetap harus
          //    load artikel & panggil scroll secara manual.
          _articleProvider!.loadArticles();
          _scrollToSelectedCategory('Top News');
        }
      }
    });
    // --- 🔑 AKHIR PERUBAHAN ---
  }

  // --- PERBAIKAN: didChangeDependencies untuk menyimpan referensi provider ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Simpan referensi ArticleProvider untuk digunakan di dispose()
    if (_articleProvider == null) {
      _articleProvider = Provider.of<ArticleProvider>(context, listen: false);
      _articleProvider!.addListener(_onProviderUpdate);
      // Simpan kategori sebelumnya untuk mendeteksi perubahan
      _previousCategory = _articleProvider!.currentCategory;
    }
  }
  // --- AKHIR PERBAIKAN ---

  // --- 💡 PERUBAHAN: Fungsi baru untuk load/update kategori harian ---
  Future<void> _loadOrUpdateDailyCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    // Format YYYY-MM-DD
    final currentDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final savedDate = prefs.getString(_prefsDailyCategoriesDateKey);
    List<String> chosenCategoryCodes = [];

    if (savedDate == currentDate) {
      // Masih hari yang sama, load dari cache
      chosenCategoryCodes =
          prefs.getStringList(_prefsDailyCategoriesListKey) ?? [];
    } else {
      // Hari baru atau cache kosong, generate kategori baru
      List<String> pool = List.from(_rotatingCategoryPoolCodes);
      pool.shuffle(Random());

      // Ambil 2 kategori teratas
      chosenCategoryCodes = pool.take(2).toList();

      // Simpan ke SharedPreferences
      await prefs.setString(_prefsDailyCategoriesDateKey, currentDate);
      await prefs.setStringList(_prefsDailyCategoriesListKey, chosenCategoryCodes);
    }

    // Setelah dapat 'chosenCategoryCodes', ubah menjadi Map<String, dynamic>
    // dan update state
    Map<String, dynamic>? cat1;
    Map<String, dynamic>? cat2;

    if (chosenCategoryCodes.isNotEmpty) {
      cat1 = _allCategories.firstWhere(
        (cat) => cat['category'] == chosenCategoryCodes[0],
        orElse: () => <String, dynamic>{}, // empty map
      );
      if (cat1.isEmpty) cat1 = null; // jika tidak ketemu, set null
    }

    if (chosenCategoryCodes.length > 1) {
      cat2 = _allCategories.firstWhere(
        (cat) => cat['category'] == chosenCategoryCodes[1],
        orElse: () => <String, dynamic>{}, // empty map
      );
      if (cat2.isEmpty) cat2 = null; // jika tidak ketemu, set null
    }

    if (mounted) {
      setState(() {
        _dailyCategory1 = cat1;
        _dailyCategory2 = cat2;
      });
    }
  }
  // --- 💡 AKHIR PERUBAHAN ---

  // ==========================================
  // BAGIAN 2: FUNGSI _onProviderUpdate (DIUBAH BESAR)
  // ==========================================
  void _onProviderUpdate() {
    if (!mounted) return;
    final provider = Provider.of<ArticleProvider>(context, listen: false);
    final currentStatus = provider.status;

    // --- 🚀 AWAL MODIFIKASI: Hentikan loading paginasi kategori ---
    // Logika ini tidak lagi relevan karena provider tidak mengontrol
    // loading kategori. DIHAPUS.
    /*
    if (_isCategoryLoadingMore && currentStatus != ArticleLoadingStatus.loading) {
      setState(() {
        _isCategoryLoadingMore = false;
      });
    }
    */
    // --- 🚀 AKHIR MODIFIKASI ---

    bool wasLoading =
        (_previousStatus == ArticleLoadingStatus.loading || _previousStatus == null);

    bool isNotLoadingAnymore = currentStatus != ArticleLoadingStatus.loading;

    // Update cache HANYA untuk Top News
    if (provider.currentCategory == 'Top News') {
      if (wasLoading && isNotLoadingAnymore) {
        if (currentStatus != ArticleLoadingStatus.error) {
          _updateCachedRecommendations(provider.articles);
        }
      }
    }

    // Cek jika kategori berubah
    if (_previousCategory != provider.currentCategory) {
      final String currentCategoryKey = provider.currentCategory;
      _previousCategory = provider.currentCategory;

      // --- 🚀 AWAL MODIFIKASI: "Top News" sekarang di-load seperti kategori lain ---
      // 1. Cek apakah data sudah pernah di-load
      if (!_groupedArticles.containsKey(currentCategoryKey)) {
        // 2. Jika belum, panggil _loadCategoryData untuk fetch page 1
        _loadCategoryData(currentCategoryKey);
      }
      // 3. Jika sudah ada, build() method akan otomatis menampilkannya
      //    dari _groupedArticles.
      // --- 🚀 AKHIR MODIFIKASI ---

      // Panggil scroll setelah frame di-render
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Scroll ke kategori yang dipilih
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

  // --- 💡 PERBAIKAN: Menambahkan metode yang hilang ---
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
  // --- 💡 AKHIR PERBAIKAN ---

  // --- 💡 PERUBAHAN MINGGUAN: Fungsi baru untuk load/update seed mingguan ---
  Future<void> _loadOrUpdateWeeklySeed() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final savedDateString = prefs.getString(_prefsWeeklySeedDateKey);
    int seedToUse;
    // Format YYYY-MM-DD
    final currentDateString =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    bool isNewWeek = false;

    if (savedDateString == null) {
      isNewWeek = true;
      debugPrint("Weekly Seed: First time run.");
    } else {
      try {
        final savedDate = DateTime.parse(savedDateString);
        // Cek apakah sudah 7 hari atau lebih
        if (now.difference(savedDate).inDays >= 7) {
          isNewWeek = true;
          debugPrint("Weekly Seed: New week detected.");
        } else {
          debugPrint("Weekly Seed: Same week.");
        }
      } catch (e) {
        // Jika parse gagal (format tanggal lama, dll), anggap minggu baru
        isNewWeek = true;
        debugPrint("Weekly Seed: Parse error, generating new seed.");
      }
    }

    if (isNewWeek) {
      seedToUse = now.millisecondsSinceEpoch; // Seed baru
      await prefs.setString(_prefsWeeklySeedDateKey, currentDateString);
      await prefs.setInt(_prefsWeeklySeedValueKey, seedToUse);
      debugPrint("Weekly Seed: New seed generated and saved: $seedToUse");
    } else {
      // Gunakan seed yang ada. Jika null (error aneh), buat seed baru
      seedToUse =
          prefs.getInt(_prefsWeeklySeedValueKey) ?? now.millisecondsSinceEpoch;
      debugPrint("Weekly Seed: Loaded existing seed: $seedToUse");
    }

    if (mounted) {
      setState(() {
        _weeklySeed = seedToUse;
      });
    }
  }

  /// Mengacak daftar artikel berdasarkan seed mingguan.
  List<Article> _getWeeklyShuffledArticles(List<Article> articles) {
    // Jangan acak jika list kosong atau seed belum siap
    if (articles.isEmpty || _weeklySeed == 0) return articles;
    // Buat salinan list agar tidak mengubah list aslinya (penting!)
    final shuffledList = List<Article>.from(articles);
    // Acak list menggunakan seed mingguan
    shuffledList.shuffle(Random(_weeklySeed));
    return shuffledList;
  }
  // --- 💡 AKHIR PERUBAHAN ---

  // --- AWAL MODIFIKASI: Logika _onScroll diubah ---
  void _onScroll() {
    if (!mounted) return;

    // --- Logika Animasi Header ---
    final direction = _scrollController.position.userScrollDirection;

    // Sembunyikan header saat scroll ke bawah, hanya jika sudah melewati tinggi header (60)
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
    // Tampilkan header saat scroll ke atas atau saat di paling atas
    else if ((direction == ScrollDirection.forward && !_isHeaderVisible) ||
        (_scrollController.offset <= 60.0 && !_isHeaderVisible)) {
      _headerAnimController.forward();
      if (mounted) {
        setState(() {
          _isHeaderVisible = true;
        });
      }
    }
    // --- Akhir Logika Animasi Header ---

    // --- 🚀 AWAL MODIFIKASI: Logika Pagination disatukan ---
    //    Sekarang "Top News" juga menggunakan _loadMoreCategoryArticles
    final provider = Provider.of<ArticleProvider>(context, listen: false);
    final currentCategory = provider.currentCategory;

    // Cek jika sedang loading atau sudah tidak ada data
    if (_categoryLoading[currentCategory] == true ||
        _categoryHasMore[currentCategory] == false) {
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;

    if (offset >= maxScroll - 300 &&
        _scrollController.position.outOfRange == false) {
      // Panggil fungsi load more dari repository
      _loadMoreCategoryArticles(currentCategory);
    }
    // --- 🚀 AKHIR MODIFIKASI ---
  }
  // --- AKHIR MODIFIKASI ---

  // --- 💡 AWAL PERUBAHAN: Tambah fungsi scroll kategori ---

  // ==========================================
  // BAGIAN 3: FUNGSI _onCategoryScrollNotification (DIGANTI)
  // ==========================================
  bool _onCategoryScrollNotification(ScrollNotification notification) {
    // Hanya update tombol panah, TIDAK update indikator
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
    final maxScroll = _categoryScrollController.position.maxScrollExtent;
    // Definisikan "satu langkah". Misal 150 pixels.
    const double scrollAmount = 150.0;

    final targetScroll = (currentScroll + scrollAmount).clamp(0.0, maxScroll);

    _categoryScrollController.animateTo(
      targetScroll,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollCategoryLeft() {
    if (!_categoryScrollController.hasClients) return;
    final currentScroll = _categoryScrollController.offset;
    // Definisikan "satu langkah".
    const double scrollAmount = 150.0;

    final targetScroll = (currentScroll - scrollAmount)
        .clamp(0.0, _categoryScrollController.position.maxScrollExtent);

    _categoryScrollController.animateTo(
      targetScroll,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
  // --- 💡 AKHIR PERUBAHAN ---

  Future<void> _handleBookmarkTap(BuildContext context, Article article) async {
    final bool isCurrentlyBookmarked =
        _allBookmarkedArticles.any((a) => a.id == article.id);

    final authService = AuthService();
    final user = await authService.getCurrentUser();
    final bool isGuest = user == null || user['username'] == 'Guest';
    if (isGuest) {
      _showLoginRequiredSnackBar("Masuk untuk menyimpan artikel ini");
      return;
    }

    // 💡 TAMBAHAN: Dapatkan userId dari map 'user'
    // Asumsikan key-nya adalah 'id'. Ganti 'id' menjadi 'uid' jika
    // Anda menggunakan Firebase Authentication.
    // Kita bisa pakai `!` karena sudah lolos cek `isGuest`.
    
    // 💡 PERBAIKAN: Mengganti key 'uid' menjadi 'username'
    // Karena 'username' adalah satu-satunya key yang kita tahu pasti ada
    // untuk pengguna yang login (dari pengecekan 'isGuest').
    final String userId = user!['username'] as String;
    

    if (isCurrentlyBookmarked) {
      // Hapus bookmark
      // Note: Jika removeBookmark juga error, tambahkan `userId` di sini
      bool removed = await _bookmarkService.removeBookmark(article);
      if (removed && mounted) {
        setState(() {
          _allBookmarkedArticles.removeWhere((a) => a.id == article.id);
        });
        widget.onBookmarkToggle(article);
        showBookmarkSnackbar(context, false); // gunakan snackbar custom
      }
    } else {
      // Simpan bookmark
      // 💡 PERBAIKAN: Ganti cara menangani 'added' karena method mengembalikan 'void'
      bool added = false; // 1. Inisialisasi 'added' sebagai false
      try {
        // 2. Panggil method 'void' tanpa menetapkan hasilnya
        await _bookmarkService.addBookmark(article, userId);
        
        // 3. Jika baris di atas berhasil (tidak melempar error), set 'added' ke true
        added = true;
      } catch (e) {
        // 4. Jika terjadi error, 'added' akan tetap false
        debugPrint("Gagal menambahkan bookmark: $e");
        if (mounted) {
          // Tampilkan pesan error ke pengguna
          _showErrorSnackBar("Gagal menyimpan artikel. Silakan coba lagi.");
        }
      }

      // 5. Cek 'added' seperti sebelumnya
      if (added && mounted) {
        setState(() {
          _allBookmarkedArticles.insert(0, article);
        });
        widget.onBookmarkToggle(article);
        showBookmarkSnackbar(context, true); // gunakan snackbar custom
      }
    }
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes < 1) return 'Baru saja';
        return '${difference.inMinutes} menit yang lalu';
      }
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari yang lalu';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  List<Article> _getPopularArticles(List<Article> articles) {
    if (articles.isEmpty) return [];
    final sorted = List<Article>.from(articles);
    return sorted.take(1).toList();
  }

  // --- AWAL PERUBAHAN: Ganti nama dan logika _getMustReadArticles ---
  List<Article> _getBeritaTerkiniArticles(List<Article> articles) {
    if (articles.isEmpty) return [];
    // Ambil artikel berdasarkan jumlah state, bukan hardcode 7
    return articles.skip(1).take(_beritaTerkiniCount).toList();
  }
  // --- AKHIR PERUBAHAN ---

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

  // --- TAMBAHKAN FUNGSI INI ---
  // Fungsi ini disalin dari search_screen.dart untuk menangani navigasi
  // dari card kustom yang akan kita buat.
  void _openArticle(Article article) {
    final heroTag = 'home-article-${article.id}'; // Ubah hero tag agar unik
    // 🚀 PERUBAHAN: Gunakan _allBookmarkedArticles
    final isBookmarked = _allBookmarkedArticles.any((a) => a.id == article.id);

    Navigator.of(context).push(
      HeroDialogRoute(
        builder: (context) => ArticleDetailScreen(
          article: article,
          isBookmarked: isBookmarked,
          // 🚀 PERUBAHAN: Gunakan _handleBookmarkTap
          onBookmarkToggle: () => _handleBookmarkTap(context, article),
          heroTag: heroTag,
        ),
      ),
    );
  }
  // --- AKHIR PENAMBAHAN ---

  // --- AWAL PERUBAHAN: Fungsi handler untuk load more ---
  void _loadMoreBeritaTerkini() {
    // Jangan lakukan apapun jika sedang loading
    if (_isLoadMoreBeritaTerkini) return;

    setState(() {
      _isLoadMoreBeritaTerkini = true;
    });

    // Simulasi penundaan jaringan (AJAX call)
    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted) { // Pastikan widget masih ada di tree
        setState(() {
          _beritaTerkiniCount += 7; // Tambah 7 artikel lagi
          _isLoadMoreBeritaTerkini = false; // Selesai loading
        });
      }
    });
  }
  // --- AKHIR PERUBAHAN ---

  // --- 🚀 AWAL MODIFIKASI: Handler untuk Paginasi Kategori (BARU) ---
  // Fungsi ini menggantikan _loadMoreCategoryArticles(ArticleProvider provider)
  // dan mirip dengan _loadMore di news_screen.dart
  Future<void> _loadMoreCategoryArticles(String categoryCode) async {
    // 1. Cek status
    if (_categoryLoading[categoryCode] == true ||
        _categoryHasMore[categoryCode] == false) {
      return;
    }

    // 2. Set state loading
    if (mounted) {
      setState(() {
        _categoryLoading[categoryCode] = true;
      });
    }

    // 3. Persiapan fetch
    const int pageSize = 10;
    final int nextPage = (_categoryCurrentPage[categoryCode] ?? 1) + 1;
    // Tentukan kode kategori yang benar untuk repository
    final String repoCategoryCode =
        (categoryCode == 'ALL_NEWS') ? 'Top News' : categoryCode;

    // 4. Fetch data
    try {
      final newArticles = await _articleRepository.getArticlesByCategory(
        repoCategoryCode,
        page: nextPage,
        pageSize: pageSize,
      );

      // 5. Update state jika berhasil
      if (mounted) {
        setState(() {
          _groupedArticles[categoryCode]?.addAll(newArticles); // Tambahkan ke list
          _categoryCurrentPage[categoryCode] = nextPage; // Update halaman
          _categoryHasMore[categoryCode] = newArticles.length == pageSize; // Update hasMore
          _categoryLoading[categoryCode] = false; // Selesai loading
        });
      }
    } catch (e) {
      debugPrint("Failed to load more for $categoryCode: $e");
      // 6. Update state jika gagal
      if (mounted) {
        setState(() {
          _categoryLoading[categoryCode] = false;
          _categoryHasMore[categoryCode] = false; // Asumsikan gagal = tidak ada lagi
        });
      }
    }
  }
  // --- 🚀 AKHIR MODIFIKASI ---

  // --- 🚀 AWAL MODIFIKASI: Fungsi untuk Load Data Awal Kategori (BARU) ---
  Future<void> _loadCategoryData(String categoryCode, {bool isRefresh = false}) async {
    // 1. Cek status
    if (_categoryLoading[categoryCode] == true && !isRefresh) return;

    // 2. Set state loading
    if (mounted) {
      setState(() {
        _categoryInitialLoading[categoryCode] = true;
        _categoryLoading[categoryCode] = true;
      });
    }

    // 3. Persiapan fetch
    const int pageSize = 10;
    const int pageToLoad = 1; // Selalu load halaman 1
    final String repoCategoryCode =
        (categoryCode == 'ALL_NEWS') ? 'Top News' : categoryCode;

    // 4. Fetch data
    try {
      final articles = await _articleRepository.getArticlesByCategory(
        repoCategoryCode,
        page: pageToLoad,
        pageSize: pageSize,
      );

      // 5. Update state jika berhasil
      if (mounted) {
        setState(() {
          _groupedArticles[categoryCode] = articles; // Ganti list (bukan addAll)
          _categoryCurrentPage[categoryCode] = pageToLoad;
          _categoryHasMore[categoryCode] = articles.length == pageSize;
        });
      }
    } catch (e) {
      debugPrint("Failed to load initial data for $categoryCode: $e");
      // 6. Update state jika gagal
      if (mounted) {
        setState(() {
          _groupedArticles[categoryCode] = []; // Set list kosong
          _categoryHasMore[categoryCode] = false;
        });
      }
    } finally {
      // 7. Selalu matikan spinner
      if (mounted) {
        setState(() {
          _categoryInitialLoading[categoryCode] = false;
          _categoryLoading[categoryCode] = false;
        });
      }
    }
  }
  // --- 🚀 AKHIR MODIFIKASI ---


  // --- 💡 PERBAIKAN: Menambahkan kembali 'dispose' yang hilang ---
  @override
  void dispose() {
    // --- AWAL MODIFIKASI: Dispose Animasi Header ---
    _headerAnimController.dispose();
    // --- AKHIR MODIFIKASI ---
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _categoryScrollController.dispose();
    // --- PERBAIKAN: Gunakan referensi yang sudah disimpan, bukan context ---
    if (_articleProvider != null) {
      _articleProvider!.removeListener(_onProviderUpdate);
    }
    super.dispose();
  }
  // --- 💡 AKHIR PERBAIKAN ---

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // --- AWAL PERUBAHAN: Dapatkan ThemeProvider di sini ---
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    // --- AKHIR PERUBAHAN ---
    final articleProvider = Provider.of<ArticleProvider>(context);
    final status = articleProvider.status;
    final articles = articleProvider.articles;
    final currentCategory = articleProvider.currentCategory;

    // 💡 PERUBAHAN: Logika untuk menentukan tampilan konten
    final isTopNews = currentCategory == 'Top News';
    final isAllNews = currentCategory == 'ALL_NEWS';
    // 💡 AKHIR PERUBAHAN

    return Scaffold(
      // backgroundColor: isDark ? Colors.black : Colors.white,
      // --- AWAL PERUBAHAN: Tambahkan drawer ---
      drawer: _buildAppDrawer(isDark),
      // --- AKHIR PERUBAHAN ---
      body: SafeArea(
        child: Column(
          children: [
            // --- AWAL PERUBAHAN: Animasi Wrapper untuk Header ---
            SizeTransition(
              sizeFactor: _headerHeightAnimation,
              axisAlignment: -1.0,
              child: ClipRect(
                // --- 🌟 PERBAIKAN: Kirim articleProvider ke header ---
                child: _buildStickyHeader(isDark, themeProvider, articleProvider),
              ),
            ),
            // --- AKHIR PERUBAHAN ---
            _buildCategoriesBar(articleProvider, isDark),
            Divider(
              height: 1,
              thickness: 1.5,
              color: isDark ? Colors.grey[700] : Colors.grey[400],
            ),
            Expanded(
              // 💡 PERUBAHAN: Mengirim state kategori baru
              child: _buildContent(status, articles, isDark, articleProvider,
                  isTopNews),
              // 💡 AKHIR PERUBAHAN
            ),
          ],
        ),
      ),
    );
  }

  // --- AWAL PERUBAHAN: _buildHeader diganti dengan _buildStickyHeader ---
  // --- 🌟 PERBAIKAN: Tambahkan ArticleProvider sebagai parameter ---
  Widget _buildStickyHeader(bool isDark, ThemeProvider themeProvider, ArticleProvider articleProvider) {
    // --- AWAL MODIFIKASI: SVG Icon diganti menjadi ikon search ---
    final String svgFillColor = isDark ? "white" : "black";
    final String svgIcon = '''
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
      <path fill="$svgFillColor" d="M15.5 5a3.5 3.5 0 1 0 0 7a3.5 3.5 0 0 0 0-7ZM10 8.5a5.5 5.5 0 1 1 10.032 3.117l2.675 2.676l-1.414 1.414l-2.675-2.675A5.5 5.5 0 0 1 10 8.5ZM3 4h5v2H3V4Zm0 7h5v2H3v-2Zm18 7v2H3v-2h18Z"/>
      </svg>
    ''';
    // --- AKHIR MODIFIKASI ---

    return Container(
      height: 60,
      color: isDark ? Colors.black : Colors.white, // Latar belakang header
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        children: [
          // --- AWAL MODIFIKASI: Tombol diganti menjadi Search ---
          IconButton(
            icon: SvgPicture.string(
              svgIcon,
              width: 24,
              height: 24,
            ),
            onPressed: () {
              // --- 🌟 AWAL PERBAIKAN: Dapatkan kategori aktif ---
              final String activeCategory = articleProvider.currentCategory;
              // --- 🌟 AKHIR PERBAIKAN ---

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SearchScreen(
                    // Kirim data yang diperlukan oleh SearchScreen
                    bookmarkedArticles: widget.bookmarkedArticles,
                    onBookmarkToggle: widget.onBookmarkToggle,
                    
                    // --- 🌟 AWAL PERBAIKAN: Kirim kategori aktif ---
                    // (Asumsi SearchScreen memiliki parameter 'initialCategory')
                    initialCategory: activeCategory,
                    // --- 🌟 AKHIR PERBAIKAN ---
                  ),
                ),
              );
            },
            tooltip: 'Cari', // Tooltip diperbarui
          ),
          // --- AKHIR MODIFIKASI ---

          // 2. Logo (Tengah)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 10.0), // beri jarak ke kanan (logo agak geser ke kanan)
                child: Image.asset(
                  isDark
                      ? 'assets/images/banner-owrite-black.jpg'
                      : 'assets/images/banner-owrite-white.jpg',
                  height: 44,
                  // fit: BoxFit.contain, // Gunakan ini jika logo terlalu lebar
                ),
              ),
            ),
          ),

          // 3. Ikon Notifikasi (Kanan)
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
              // Navigasi ke NotificationsScreen
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
            tooltip: 'Notifikasi',
          ),

          // 4. Tombol Ganti Tema (Kanan)
          const ThemeToggleButton(),

        ],
      ),
    );
  }
  // --- AKHIR PERUBAHAN ---

  // --- AWAL TAMBAHAN: Drawer Kategori ---
  Widget _buildAppDrawer(bool isDark) {
    // _allCategories tersedia langsung di dalam state
    return Drawer(
      backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
      // Memastikan tidak ada radius (non radius) sesuai permintaan
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Drawer
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0), // Tambah padding atas
              child: Text(
                'Semua Kategori',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900, // Dibuat lebih tebal
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
            // Daftar Kategori
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _allCategories.length, // Menggunakan _allCategories dari state
                itemBuilder: (context, index) {
                  final category = _allCategories[index];
                  final categoryCode = category['category'];
                  final categoryTitle = category['title'];

                  // --- AWAL PERUBAHAN: Tambahkan Column dan DottedDivider ---
                  return Column(
                    children: [
                      ListTile(
                        title: Text(
                          categoryTitle,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w500, // Sedikit lebih tebal
                          ),
                        ),
                        onTap: () {
                          // 1. Ganti kategori
                          Provider.of<ArticleProvider>(context, listen: false)
                              .changeCategory(categoryCode);
                          // 2. Tutup drawer
                          Navigator.of(context).pop();
                        },
                      ),
                      // Tambahkan divider titik-titik dengan jarak (indent)
                      DottedDivider(
                        color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        height: 1,
                        indent: 16.0, // Jarak dari kiri
                        endIndent: 16.0, // Jarak dari kanan
                      ),
                    ],
                  );
                  // --- AKHIR PERUBAHAN ---
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  // --- AKHIR TAMBAHAN ---

  // --- Widget _buildThemeToggle DIHAPUS (karena tombolnya dihapus) ---

  // 💡 PERUBAHAN: Memperbarui logika keyString
  void _scrollToSelectedCategory(String? categoryCode) {
    final String keyString;
    if (categoryCode == 'Top News' || categoryCode == null) {
      keyString = 'top-news'; // ⬅️ Key untuk Top News
    // --- 🚀 AWAL MODIFIKASI: Hapus 'ALL_NEWS' ---
    // } else if (categoryCode == 'ALL_NEWS') {
    //   keyString = 'all-news'; // ⬅️ Key untuk All News
    // --- 🚀 AKHIR MODIFIKASI ---
    } else {
      keyString = categoryCode; // ⬅️ Key untuk kategori lain
    }
    // 💡 AKHIR PERUBAHAN

    final GlobalKey? key = _categoryKeys[keyString];

    if (key == null ||
        key.currentContext == null ||
        !_categoryScrollController.hasClients) return;

    final RenderBox? renderBox =
        key.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // Hitung posisi target
    final position = renderBox.localToGlobal(Offset.zero);
    final viewportWidth = _categoryScrollController.position.viewportDimension;
    final itemWidth = renderBox.size.width;

    // Kita perlu offset item relatif terhadap area scroll
    // Global position - Global position of scroll area
    // Cara lebih mudah: Gunakan Scrollable.ensureVisible
    Scrollable.ensureVisible(
      key.currentContext!,
      alignment: 0.5, // 0.5 = tengah
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ==========================================
  // BAGIAN 4: FUNGSI _buildCategoryItem (BARU/DIGANTI)
  // ==========================================
  Widget _buildCategoryItem(
  Map<String, dynamic> category,
  ArticleProvider provider,
  bool isDark,
  GlobalKey textKey,
  ) {
    // 💡 PERBAIKAN: Logika 'isSelected' disederhanakan
    final String categoryCode = category['category']; // 'Top News', 'ALL_NEWS', 'HYPE'
    final String activeCategory = provider.currentCategory; // 'Top News', 'ALL_NEWS', 'HYPE'
    
    final bool isSelected = (categoryCode == activeCategory);
    // 💡 AKHIR PERBAIKAN

    final Color activeColor = isDark ? Color(0xFFE5FF10) : Colors.black;

    return GestureDetector(
      onTap: () {
        // 💡 PERBAIKAN: Kirim 'null' jika itu 'Top News'
        provider.changeCategory(category['category']);
        // 💡 AKHIR PERBAIKAN
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
                // The Text itself
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
                // Space between text and indicator
                const SizedBox(height: 4),
                if (isSelected)
                  Builder(builder: (context) {
                    // Calculate indicatorWidth safely (avoid "was not laid out" error)
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

  // ==========================================
  // BAGIAN 5: FUNGSI _buildCategoriesBar (UPDATE/DIGANTI)
  // ==========================================
  Widget _buildCategoriesBar(ArticleProvider provider, bool isDark) {
    // 1. Definisikan kategori statis
    final Map<String, dynamic> topNewsCategory = {
      'title': 'Top News',
      'category': 'Top News', // 💡 PERBAIKAN: Gunakan 'Top News' sebagai string
    };

    // --- 🚀 AWAL MODIFIKASI: Hapus 'ALL_NEWS' ---
    // final Map<String, dynamic> allBeritaCategory = {
    //   'title': 'All News',
    //   'category': 'ALL_NEWS',
    // };
    // --- 🚀 AKHIR MODIFIKASI ---

    // 2. Buat daftar lengkap
    final List<Map<String, dynamic>> fullCategoriesList = [
      topNewsCategory,
      // allBeritaCategory, // <-- DIHAPUS
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
            // 1. ListView kategori
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

                // Tentukan keyString
                if (index == 0) {
                  keyString = 'top-news';
                // --- 🚀 AWAL MODIFIKASI: Hapus 'ALL_NEWS' ---
                // } else if (categoryCode == 'ALL_NEWS') {
                //   keyString = 'all-news';
                // --- 🚀 AKHIR MODIFIKASI ---
                } else {
                  keyString = categoryCode ?? 'category_$index';
                }

                // Buat GlobalKey jika belum ada
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

            // 2. Tombol Kiri & Gradien
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

            // 3. Tombol Kanan & Gradien
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

  // 💡 PERUBAHAN: Memperbarui tanda tangan metode
  Widget _buildContent(ArticleLoadingStatus status, List<Article> providerArticles, // 💡 Ganti nama
      bool isDark, ArticleProvider provider, bool isTopNews, 
      // bool isAllNews // <-- DIHAPUS
      ) {
    // 💡 AKHIR PERUBAHAN

    // --- 🚀 AWAL MODIFIKASI: Hapus 'isAllNews' ---
    final isAllNews = false; // <-- Set ke false (tidak terpakai lagi)
    // --- 🚀 AKHIR MODIFIKASI ---


    // --- 🚀 MODIFIKASI: Logika loading awal ---
    if (isTopNews) {
      // --- 🚀 AWAL MODIFIKASI: Logika loading untuk "Top News" (dari repositori) ---
      if (_categoryInitialLoading['Top News'] == true) {
        return Center(
            child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_loadMoreButtonColor),
        ));
      }
      // Error dan empty state ditangani di dalam _buildRepositoryCategoryList
      // (tapi Top News punya layout sendiri, jadi kita cek manual)
      final articlesToShow = _groupedArticles['Top News'] ?? [];
      if (articlesToShow.isEmpty && _categoryInitialLoading['Top News'] == false) {
         return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.article_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Tidak ada artikel Top News',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadCategoryData('Top News', isRefresh: true),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        );
      }
      // --- 🚀 AKHIR MODIFIKASI ---
    } else {
      // Logika loading untuk Kategori (menggunakan state repository)
      final currentCategory = provider.currentCategory;
      if (_categoryInitialLoading[currentCategory] == true) {
        return Center(
            child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_loadMoreButtonColor),
        ));
      }
      // Error dan empty state ditangani di dalam _buildRepositoryCategoryList
    }
    // --- 🚀 AKHIR MODIFIKASI ---


    // --- 🚀 AWAL MODIFIKASI: Tentukan sumber data ---
    final List<Article> articlesForView;
    if (isTopNews) {
      // "Top News" sekarang mengambil data dari state repositori
      articlesForView = _groupedArticles['Top News'] ?? [];
    } else {
      // Kategori lain (saat di-klik, meski layout-nya beda)
      articlesForView = _groupedArticles[provider.currentCategory] ?? [];
    }

    // --- 💡 PERUBAHAN MINGGUAN: Acak artikel di sini ---
    // Menggunakan 'articlesForView' (dari repositori)
    
    // --- 🚀 AWAL MODIFIKASI: Menghapus acak mingguan (sesuai permintaan) ---
    // final List<Article> displayArticles =
    //     isTopNews ? _getWeeklyShuffledArticles(articlesForView) : articlesForView;
    
    // Selalu gunakan daftar berurutan
    final List<Article> displayArticles = articlesForView;
    // --- 🚀 AKHIR MODIFIKASI ---

    // --- 🚀 AWAL MODIFIKASI: Logika RefreshIndicator ---
    return RefreshIndicator(
      onRefresh: () async {
        // Cek kategori mana yang aktif
        final currentCategory =
            Provider.of<ArticleProvider>(context, listen: false)
                .currentCategory;
        if (currentCategory == 'Top News') {
          // Jika Top News, refresh provider
          await provider.refreshArticles();
        } else {
          // Jika Kategori, refresh repository
          await _loadCategoryData(currentCategory, isRefresh: true);
        }
      },
      color: const Color(0xFF00FF00),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          // 💡 PERUBAHAN: Logika tampilan berdasarkan isTopNews, isAllNews
          if (isTopNews) ...[
            // --- 🚀 AWAL MODIFIKASI: Layout Top News (Sesuai Permintaan) ---

            // 1. Tampilkan Artikel Populer (Artikel ke-1, tidak diacak)
            //    Menggunakan 'articlesForView' (dari repositori, tidak diacak)
            _buildPopularSection(articlesForView, isDark),

            // 2. Tampilkan sisa artikel dengan layout berulang (4, 5, 1)
            //    Menggunakan 'displayArticles' (dari repositori, diacak)
            _buildRepeatingTopNewsLayout(displayArticles.skip(1).toList(), isDark),

            // 3. Tampilkan indikator loading di akhir
            //    jika repositori sedang memuat lebih banyak
            // --- 🚀 AWAL MODIFIKASI: Ubah indikator loading ---
            if (_categoryLoading['Top News'] == true && articlesForView.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_loadMoreButtonColor),
                  ),
                ),
              ),
            // --- 🚀 AKHIR MODIFIKASI ---

            // --- 🚀 AKHIR MODIFIKASI ---
          ] else ...[
            // Tampilan "All News" atau Kategori Spesifik (dari repository)
            _buildRepositoryCategoryList(
                isDark, provider.currentCategory, 
                // isAllNews // <-- DIHAPUS
                ),
          ],
          // --- 🚀 AKHIR MODIFIKASI ---
        ],
      ),
    );
    // --- 🚀 AKHIR MODIFIKASI ---
  }

  // --- 🚀 AWAL MODIFIKASI: Widget baru untuk layout Top News ---
  /// Membangun layout 4, 5, 1 berulang untuk Top News
  Widget _buildRepeatingTopNewsLayout(List<Article> articles, bool isDark) {
    if (articles.isEmpty) {
      return const SizedBox.shrink();
    }

    // Pola layout membutuhkan 9 artikel (2 + 2 + 5)
    const int patternSize = 9;
    
    // Hitung berapa kali pola akan berulang penuh
    final int fullPatternCount = articles.length ~/ patternSize;
    // Hitung sisa artikel
    final int remainder = articles.length % patternSize;

    List<Widget> layoutWidgets = [];

    // 1. Bangun pola penuh
    for (int i = 0; i < fullPatternCount; i++) {
      // Dapatkan 9 artikel untuk pola ini
      final int startIndex = i * patternSize;
      final List<Article> patternArticles = articles.sublist(startIndex, startIndex + patternSize);

      // Terapkan layout 4, 5, 1
      // Layout 4 (2 artikel)
      layoutWidgets.add(_buildLayout4Section(patternArticles.take(2).toList(), isDark));
      // Layout 5 (2 artikel)
      layoutWidgets.add(_buildLayout5Section(patternArticles.skip(2).take(2).toList(), isDark));
      // Layout 1 (5 artikel)
      layoutWidgets.add(_buildLayout1Section(patternArticles.skip(4).take(5).toList(), isDark));
    }

    // 2. Bangun sisa artikel
    if (remainder > 0) {
      final List<Article> remainderArticles = articles.sublist(fullPatternCount * patternSize);
      
      // Terapkan layout secara berurutan
      if (remainderArticles.isNotEmpty) {
          // Ambil 2 artikel pertama untuk Layout 4
          final layout4Articles = remainderArticles.take(2).toList();
          layoutWidgets.add(_buildLayout4Section(layout4Articles, isDark));
      }

      if (remainderArticles.length > 2) {
          // Ambil 2 artikel berikutnya untuk Layout 5
          final layout5Articles = remainderArticles.skip(2).take(2).toList();
          layoutWidgets.add(_buildLayout5Section(layout5Articles, isDark));
      }

      if (remainderArticles.length > 4) {
          // Ambil sisa artikel (maks 5) untuk Layout 1
          final layout1Articles = remainderArticles.skip(4).take(5).toList();
          layoutWidgets.add(_buildLayout1Section(layout1Articles, isDark));
      }
    }

    // Kita butuh Column untuk menampung semua widget
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: layoutWidgets,
    );
  }
  // --- 🚀 AKHIR MODIFIKASI ---

  // --- 🚀 AWAL MODIFIKASI: Fungsi _buildPaginatedCategoryList DIGANTI ---
  /// Mengganti _buildPaginatedCategoryList dengan
  /// _buildRepositoryCategoryList (ala news_screen.dart)
  Widget _buildRepositoryCategoryList(
      bool isDark, String categoryCode, 
      // bool isAllNews // <-- DIHAPUS
      ) {
    // 1. Ambil data dari state repository
    final articlesToShow = _groupedArticles[categoryCode] ?? [];
    final isLoadingMore = _categoryLoading[categoryCode] ?? false;
    final hasMore = _categoryHasMore[categoryCode] ?? false;

    // 2. Dapatkan Judul
    String displayTitle = _categoryTitles[categoryCode] ?? categoryCode;

    // 3. Tampilkan UI
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          // --- Judul Kategori dan Divider ---
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            child: Text(
              displayTitle.toUpperCase(), // CAPSLOCK
              textAlign: TextAlign.center, // Tengah
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

          // --- Daftar Artikel ---
          const SizedBox(height: 16),
          if (articlesToShow.isEmpty && !isLoadingMore)
            // Tampilkan pesan jika kosong DAN tidak sedang loading
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48.0),
              child: Text(
                'Tidak ada artikel pada kategori ini',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
            )
          else
            // Tampilkan list artikel
            ...articlesToShow.asMap().entries.map((entry) {
              final index = entry.key;
              final article = entry.value;
              // 🚀 PERUBAHAN: Cek bookmark dari _allBookmarkedArticles
              final isBookmarked =
                  _allBookmarkedArticles.any((b) => b.id == article.id);

              // Gunakan layout2 untuk semua (seperti news_screen.dart)
              // const ArticleCardLayout cardLayout = ArticleCardLayout.layout2; // <-- DIHAPUS

              // --- AWAL PERUBAHAN (Sesuai Permintaan) ---
              final ArticleCardLayout cardLayout;
              // --- 🚀 AWAL MODIFIKASI: Hapus cek 'isAllNews' ---
              // if (isAllNews) {
              //   // Untuk "All News", semua pakai layout2
              //   cardLayout = ArticleCardLayout.layout2;
              // } else {
                // Untuk Kategori Lain ('Hype', 'Olahraga', dll.):
                // Artikel pertama (index 0) menggunakan defaultCard
                // Artikel selanjutnya (index > 0) menggunakan layout2
                cardLayout = (index == 0)
                    ? ArticleCardLayout.defaultCard
                    : ArticleCardLayout.layout2;
              // }
              // --- 🚀 AKHIR MODIFIKASI ---
              // --- AKHIR PERUBAHAN ---

              return ArticleCard(
                article: article,
                isBookmarked: isBookmarked,
                // 🚀 PERUBAHAN: Gunakan _handleBookmarkTap
                onBookmarkToggle: () => _handleBookmarkTap(context, article),
                index: index,
                layout: cardLayout,
              );
            }).toList(),

          // --- Tombol "Lihat Lebih Banyak" atau Loading ---
          const SizedBox(height: 24),
          if (isLoadingMore)
            // 1. Tampilkan Animasi Loading jika sedang memuat
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_loadMoreButtonColor),
                strokeWidth: 3,
              ),
            )
          // --- 🚀 AWAL MODIFIKASI: Hapus Tombol "Lihat Lebih Banyak" ---
          /*
          else if (hasMore)
            // 2. Tampilkan Tombol jika BISA memuat lebih banyak
            ElevatedButton(
              onPressed: () => _loadMoreCategoryArticles(categoryCode),
              style: ElevatedButton.styleFrom(
                backgroundColor: _loadMoreButtonColor, // Warna background
                foregroundColor: Colors.black, // Warna teks
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20), // Shape radius
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text(
                'Lihat Lebih Banyak', // Teks tombol
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            )
          */
          // --- 🚀 AKHIR MODIFIKASI ---
          else if (articlesToShow.isNotEmpty && !hasMore) // Kondisi diperbarui
            // 3. Tampilkan Pesan Akhir jika semua sudah dilihat
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
  // --- 🚀 AKHIR MODIFIKASI ---

  // --- 🚀 AWAL MODIFIKASI: Helper untuk Layout 4 (dibuat generik) ---
  Widget _buildLayout4Section(List<Article> articlesToRender, bool isDark) {
    // 💡 HAPUS: Logika skip/take
    if (articlesToRender.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          ...articlesToRender.asMap().entries.map((entry) { // 💡 Ganti ke articlesToRender
            final index = entry.key;
            final article = entry.value;
            // 🚀 PERUBAHAN: Cek bookmark dari _allBookmarkedArticles
            final isBookmarked =
                _allBookmarkedArticles.any((b) => b.id == article.id);

            // ArticleCard untuk layout 4 sudah termasuk padding dan divider-nya sendiri
            return ArticleCard(
              article: article,
              isBookmarked: isBookmarked,
              // 🚀 PERUBAHAN: Gunakan _handleBookmarkTap
              onBookmarkToggle: () => _handleBookmarkTap(context, article),
              index: index,
              layout: ArticleCardLayout.layout4, // Gunakan Layout 4
            );
          }).toList(),
        ],
      ),
    );
  }
  // --- 🚀 AKHIR MODIFIKASI ---

  // --- 🚀 AWAL MODIFIKASI: Helper untuk Layout 5 (Grid) (dibuat generik) ---
  Widget _buildLayout5Section(List<Article> articlesToRender, bool isDark) {
    // 💡 HAPUS: Logika skip/take
    if (articlesToRender.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 27),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16), // Jarak lebih sedikit setelah divider
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 kolom
              crossAxisSpacing: 16, // Jarak horizontal
              mainAxisSpacing: 16, // Jarak vertikal
              childAspectRatio: 0.7, // Sesuaikan rasio agar pas
            ),
            itemCount: articlesToRender.length, // 💡 Ganti
            shrinkWrap: true, // Wajib di dalam ListView
            physics: const NeverScrollableScrollPhysics(), // Wajib di dalam ListView
            itemBuilder: (context, index) {
              final article = articlesToRender[index]; // 💡 Ganti
              // 🚀 PERUBAHAN: Cek bookmark dari _allBookmarkedArticles
              final isBookmarked =
                  _allBookmarkedArticles.any((b) => b.id == article.id);

              return ArticleCard(
                article: article,
                isBookmarked: isBookmarked,
                // 🚀 PERUBAHAN: Gunakan _handleBookmarkTap
                onBookmarkToggle: () => _handleBookmarkTap(context, article),
                index: index,
                layout: ArticleCardLayout.layout5, // Gunakan Layout 5
              );
            },
          ),
          Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[300]),
        ],
      ),
    );
  }
  // --- 🚀 AKHIR MODIFIKASI ---

  // --- 🚀 AWAL MODIFIKASI: Helper untuk Layout 1 (dibuat generik) ---
  Widget _buildLayout1Section(List<Article> articlesToRender, bool isDark) {
    // 💡 HAPUS: Logika skip/take
    if (articlesToRender.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          ...articlesToRender.asMap().entries.map((entry) { // 💡 Ganti
            final index = entry.key;
            final article = entry.value;
            // 🚀 PERUBAHAN: Cek bookmark dari _allBookmarkedArticles
            final isBookmarked =
                _allBookmarkedArticles.any((b) => b.id == article.id);

            // ArticleCard untuk layout 1 sudah termasuk divider-nya sendiri
            return ArticleCard(
              article: article,
              isBookmarked: isBookmarked,
              // 🚀 PERUBAHAN: Gunakan _handleBookmarkTap
              onBookmarkToggle: () => _handleBookmarkTap(context, article),
              index: index,
              layout: ArticleCardLayout.layout1, // Gunakan Layout 1
            );
          }).toList(),
          // Tidak ada tombol "Lihat Lebih Banyak"
        ],
      ),
    );
  }
  // --- 🚀 AKHIR MODIFIKASI ---

  Widget _buildCategoryLatestSection(
  Future<List<Article>>? future, // 💡 Terima Future
  String categoryCode, // 💡 Tetap terima code & title untuk tombol
  String categoryTitle,
  bool isDark
  ) {

    // 💡 Gunakan FutureBuilder untuk mengambil data terpisah
    return FutureBuilder<List<Article>>(
      // 💡 Gunakan Future yang sudah stabil
      future: future,
      builder: (context, snapshot) {

        // --- Tampilan Judul (selalu tampil) ---
        final titleWidget = Text(
          categoryTitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: 'BG_Condensed',
            color: isDark ? Colors.white : Colors.black,
          ),
        );

        // 1. Saat Sedang Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              const SizedBox(height: 16),
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          );
        }

        // 2. Jika Gagal (Error) atau Tidak Ada Data
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          String message = 'Belum ada artikel terbaru di $categoryTitle';
          if (snapshot.hasError) {
            message = 'Gagal memuat $categoryTitle';
            // Log error untuk debugging
            debugPrint("Error fetching latest for $categoryCode: ${snapshot.error}");
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              const SizedBox(height: 16),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(
                    message, // Pesan error/kosong
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? Colors.grey[800] : Colors.grey[300],
              ),
              const SizedBox(height: 16),
              // 💡 Tombol 'Lihat Semua' tetap ada
              _buildLihatSemuaButton(context, categoryTitle, categoryCode, isDark),
            ],
          );
        }

        // 3. Jika Berhasil dan Ada Data
        final displayArticles = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleWidget, // Judul
            const SizedBox(height: 16),

            // --- Logika tampilan list (disalin dari kode asli) ---
            if (displayArticles.isNotEmpty)
              ArticleCard(
                article: displayArticles[0],
                // 🚀 PERUBAHAN: Cek bookmark dari _allBookmarkedArticles
                isBookmarked: _allBookmarkedArticles
                    .any((b) => b.id == displayArticles[0].id),
                // 🚀 PERUBAHAN: Gunakan _handleBookmarkTap
                onBookmarkToggle: () => _handleBookmarkTap(context, displayArticles[0]),
                index: 0,
                // MODIFIKASI: Menggunakan layout3
                layout: ArticleCardLayout.layout3,
              ),
            if (displayArticles.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: DottedDivider(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  indent: 0,
                  endIndent: 0,
                ),
              ),
            if (displayArticles.length > 1)
              ArticleCard(
                article: displayArticles[1],
                // 🚀 PERUBAHAN: Cek bookmark dari _allBookmarkedArticles
                isBookmarked: _allBookmarkedArticles
                    .any((b) => b.id == displayArticles[1].id),
                // 🚀 PERUBAHAN: Gunakan _handleBookmarkTap
                onBookmarkToggle: () => _handleBookmarkTap(context, displayArticles[1]),
                index: 1,
                // MODIFIKASI: Menggunakan layout3
                layout: ArticleCardLayout.layout3,
              ),
            if (displayArticles.length > 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: DottedDivider(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  indent: 0,
                  endIndent: 0,
                ),
              ),
            if (displayArticles.length > 2)
              ArticleCard(
                article: displayArticles[2],
                // 🚀 PERUBAHAN: Cek bookmark dari _allBookmarkedArticles
                isBookmarked: _allBookmarkedArticles
                    .any((b) => b.id == displayArticles[2].id),
                // 🚀 PERUBAHAN: Gunakan _handleBookmarkTap
                onBookmarkToggle: () => _handleBookmarkTap(context, displayArticles[2]),
                index: 2,
                // MODIFIKASI: Menggunakan layout3
                layout: ArticleCardLayout.layout3,
              ),

            const SizedBox(height: 16),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            // 💡 Tombol 'Lihat Semua'
            _buildLihatSemuaButton(context, categoryTitle, categoryCode, isDark),
          ],
        );
      },
    );
  }

  // 💡 BUAT FUNGSI HELPER BARU untuk tombol 'Lihat Semua'
  // Ini membersihkan kode dan mengubah logika navigasi
  Widget _buildLihatSemuaButton(BuildContext context, String categoryTitle, String categoryCode, bool isDark) {
    return GestureDetector(
      onTap: () {
        // 💡 KEMBALIKAN LOGIKA: Buka halaman baru 'CategoryLatestScreen'
        // Halaman ini akan mengambil datanya sendiri.
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                CategoryLatestScreen(
              categoryTitle: categoryTitle,
              categoryCode: categoryCode,
              // 💡 'articles' dihapus, CategoryLatestScreen akan fetch sendiri
              bookmarkedArticles: widget.bookmarkedArticles,
              // 🚀 PERUBAHAN: Kirim _handleBookmarkTap
              onBookmarkToggle: (article) => _handleBookmarkTap(context, article),
            ),
            // Animasi slide-in dari atas (sesuai permintaan user sebelumnya)
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, -1.0); // dari atas ke bawah
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween = Tween(begin: begin, end: end)
                  .chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);
              return SlideTransition(
                  position: offsetAnimation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Lihat Semua',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFe5ff10), // circle color: green
                ),
                child: Center(
                  child: Builder(
                    builder: (context) {
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      return IconTheme(
                        data: IconThemeData(
                          size: 20,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                        child: SvgPicture.string(
                          '''
                              <svg clip-rule="evenodd" fill-rule="evenodd" stroke-linejoin="round" stroke-miterlimit="2" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                                <path d="m12.012 1.995c-5.518 0-9.998 4.48-9.998 9.998s4.48 9.998 9.998 9.998 9.997-4.48 9.997-9.998-4.479-9.998-9.997-9.998zm0 1.5c4.69 0 8.497 3.808 8.497 8.498s-3.807 8.498-8.497 8.498-8.498-3.808-8.498-8.498 3.808-8.498 8.498-8.498zm1.528 4.715s1.502 1.505 3.255 3.259c.146.147.219.339.219.531s-.073.383-.219.53c-1.753 1.754-3.254 3.258-3.254 3.258-.145.145-.336.217-.527.217-.191-.001-.383-.074-.53-.221-.293-.293-.295-.766-.004-1.057l1.978-1.977h-6.694c-.414 0-.75-.336-.75-.75s.336-.75.75-.75h6.694l-1.979-1.979c-.289-.289-.286-.762.006-1.054.147-.147.339-.221.531-.222.19 0 .38.071.524.215z" fill="${isDark ? '#000000' : '#ffffff'}" fill-rule="nonzero"/>
                              </svg>
                            ''',
                          height: 20,
                          width: 20,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 💡 AWAL MODIFIKASI: _buildCategoryArticlesList ---
  // Fungsi ini dipanggil untuk kategori selain Top News dan All News
  Widget _buildCategoryArticlesList(List<Article> articles, bool isDark, {bool isAllNewsList = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ...articles.asMap().entries.map((entry) {
            final index = entry.key;
            final article = entry.value;
            // 🚀 PERUBAHAN: Cek bookmark dari _allBookmarkedArticles
            final isBookmarked =
                _allBookmarkedArticles.any((b) => b.id == article.id);

            // --- 💡 AWAL LOGIKA BARU ---
            final ArticleCardLayout cardLayout;
            if (isAllNewsList) {
              // Untuk "All News", semua pakai layout2
              cardLayout = ArticleCardLayout.layout2;
            } else {
              // Untuk Kategori Lain:
              // Artikel pertama (index 0) menggunakan defaultCard
              // Artikel selanjutnya (index > 0) menggunakan layout2
              cardLayout = (index == 0)
                  ? ArticleCardLayout.defaultCard
                  : ArticleCardLayout.layout2;
            }
            // --- 💡 AKHIR LOGIKA BARU ---

            return ArticleCard(
              article: article,
              isBookmarked: isBookmarked,
              // 🚀 PERUBAHAN: Gunakan _handleBookmarkTap
              onBookmarkToggle: () => _handleBookmarkTap(context, article),
              index: index,
              // MODIFIKASI: Menggunakan layout dinamis yang baru ditentukan
              layout: cardLayout,
            );
          }).toList(),
        ],
      ),
    );
  }
  // --- 💡 AKHIR MODIFIKASI ---

  Widget _buildPopularSection(List<Article> articles, bool isDark) {
    final popularArticles = _getPopularArticles(articles);
    if (popularArticles.isEmpty) return const SizedBox.shrink();

    final article = popularArticles.first;
    // 🚀 PERUBAHAN: Cek bookmark dari _allBookmarkedArticles
    final isBookmarked =
        _allBookmarkedArticles.any((b) => b.id == article.id);

    return ArticleCard(
      article: article,
      isBookmarked: isBookmarked,
      // 🚀 PERUBAHAN: Gunakan _handleBookmarkTap
      onBookmarkToggle: () => _handleBookmarkTap(context, article),
      index: 0,
      layout: ArticleCardLayout.layout3, // Biarkan seperti ini
    );
  }

  // --- AWAL PERUBAHAN: Modifikasi besar pada _buildMustReadSection ---
  Widget _buildBeritaTerkiniSection(List<Article> articles, bool isDark) {
    // 'articles' di sini adalah 'displayArticles' (shuffled list) dari _buildContent

    // Ambil *semua* artikel yang tersedia untuk pengecekan 'hasMore'
    final allBeritaTerkini = articles.skip(1).toList();

    // Ambil hanya sejumlah '_beritaTerkiniCount' untuk ditampilkan
    final displayArticles = allBeritaTerkini.take(_beritaTerkiniCount).toList();

    // Cek apakah masih ada artikel tersisa di 'allBeritaTerkini'
    final bool hasMore = allBeritaTerkini.length > _beritaTerkiniCount;

    if (displayArticles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            'Belum ada artikel pilihan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Berita Terkini', // <-- Judul diubah
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFamily: 'Arimo',
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          // Tampilkan list artikel (sejumlah _beritaTerkiniCount)
          ...displayArticles.asMap().entries.map((entry) {
            final index = entry.key;
            final article = entry.value;
            // 🚀 PERUBAHAN: Cek bookmark dari _allBookmarkedArticles
            final isBookmarked =
                _allBookmarkedArticles.any((b) => b.id == article.id);

            return Column(
              children: [
                ArticleCard(
                  article: article,
                  isBookmarked: isBookmarked,
                  // 🚀 PERUBAHAN: Gunakan _handleBookmarkTap
                  onBookmarkToggle: () => _handleBookmarkTap(context, article),
                  index: index,
                  // MODIFIKASI: Menggunakan layout3
                  layout: ArticleCardLayout.layout3,
                ),
                if (index < displayArticles.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: DottedDivider(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      indent: 0,
                      endIndent: 0,
                    ),
                  ),
              ],
            );
          }).toList(),

          // --- Tambahan Tombol Load More ---
          const SizedBox(height: 24), // Spasi sebelum tombol
          if (_isLoadMoreBeritaTerkini) ...[
            // 1. Tampilkan Indikator Loading
            Center(
              child: SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_loadMoreColor),
                  strokeWidth: 3,
                ),
              ),
            ),
          ] else if (hasMore) ...[
            // 2. Tampilkan Tombol "Muat Lebih Banyak"
            Center(
              child: ElevatedButton(
                onPressed: _loadMoreBeritaTerkini, // Panggil fungsi handler
                style: ElevatedButton.styleFrom(
                  backgroundColor: _loadMoreColor, // Warna background
                  foregroundColor: Colors.black, // Warna teks
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // Shape radius
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  'Muat Lebih Banyak', // Teks tombol
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
          // --- Akhir Tambahan Tombol Load More ---
        ],
      ),
    );
  }
  // --- AKHIR PERUBAHAN ---

  Widget _buildDiscoverMoreSection(List<Article> articles, bool isDark) {
    // 💡 PERUBAHAN: Ambil list asli, skip, lalu shuffle (random per session)
    final discoverMoreArticles = _getDiscoverMoreArticles(articles);
    discoverMoreArticles.shuffle(Random());
    // 💡 AKHIR PERUBAHAN

    if (discoverMoreArticles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            'Belum ada artikel lainnya',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final displayArticles = discoverMoreArticles.take(10).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Temukan lebih banyak',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFamily: 'Arimo',
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          ...displayArticles.asMap().entries.map((entry) {
            final index = entry.key;
            final article = entry.value;
            // 🚀 PERUBAHAN: Cek bookmark dari _allBookmarkedArticles
            final isBookmarked =
                _allBookmarkedArticles.any((b) => b.id == article.id);

            return ArticleCard(
              article: article,
              isBookmarked: isBookmarked,
              // 🚀 PERUBAHAN: Gunakan _handleBookmarkTap
              onBookmarkToggle: () => _handleBookmarkTap(context, article),
              index: index,
              // MODIFIKASI: Menggunakan layout3
              layout: ArticleCardLayout.layout3,
            );
          }).toList(),
        ],
      ),
    );
  }

  // --- TAMBAHKAN FUNGSI INI ---
  // Widget ini disalin dari search_screen.dart untuk membuat card kustom
  // yang sesuai dengan tampilan di halaman pencarian.
  Widget _buildCategoryArticleCard(BuildContext context, Article article, bool isDark) {
    return GestureDetector(
      onTap: () => _openArticle(article), // Memanggil _openArticle yang baru ditambahkan
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar
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

            // Judul di luar gambar dengan background sesuai tema
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
  // --- AKHIR PENAMBAHAN ---

  // --- AWAL PERUBAHAN: FUNGSI _buildCustomCategorySection DIPERBARUI ---
  // Widget ini diubah agar sesuai dengan tampilan slide di search_screen.dart
  Widget _buildCustomCategorySection(BuildContext context, String categoryCode, String categoryTitle, List<Article> articles, bool isDark) {

    return Padding( // <-- Padding luar 24.0 dipertahankan
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // <-- DITAMBAHKAN
            children: [
              Text(
                categoryTitle, // <-- Gunakan parameter categoryTitle
                style: TextStyle(
                  fontFamily: 'Arimo', // <-- Font dari file asli
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),

              // --- Tombol More di-aktifkan ---
              GestureDetector(
                onTap: () => _navigateToSeeAll(categoryTitle, articles), // <-- Navigasi disesuaikan ke _navigateToSeeAll
                child: Row(
                  children: [
                    Text(
                      'More',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFF00),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: isDark ? Colors.black : Colors.white, // <-- Sesuai search_screen.dart
                      ),
                    ),
                  ],
                ),
              ),
              // --- Akhir Tombol More ---
            ],
          ),
          const SizedBox(height: 12), // <-- Spasi dikurangi (sesuai search_screen)

          // --- BAGIAN YANG DIUBAH (Meniru search_screen) ---
          SizedBox(
            height: 240, // <-- Tinggi slider dari search_screen
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              // List dimulai dari tepi (padding 24.0 sudah ada di luar)
              padding: EdgeInsets.zero,
              itemCount: articles.length, // <-- Ambil semua artikel
              itemBuilder: (context, index) {
                final article = articles[index];
                // Panggil card kustom dari search_screen
                // yang sudah ada di home_screen
                return _buildCategoryArticleCard(context, article, isDark);
              },
            ),
          ),
          // --- AKHIR BAGIAN YANG DIUBAH ---
        ],
      ),
    );
  }
  // --- AKHIR PERUBAHAN ---

  // --- 💡 PERUBAHAN: Logika untuk menentukan kategori dinamis ---
  Widget _buildLatestSection(List<Article> articles, bool isDark) {
    Map<String, dynamic> category1;
    Map<String, dynamic>? category2;

    // Prioritas 1: Gunakan _dailyCategory1 jika ada
    if (_dailyCategory1 != null) {
      category1 = _dailyCategory1!;
      // Prioritas 2: Gunakan _dailyCategory2 jika ada DAN BEDA
      if (_dailyCategory2 != null &&
          _dailyCategory2!['category'] != category1['category']) {
        category2 = _dailyCategory2!;
      } else {
        // _dailyCategory2 null atau sama, cari fallback
        // Fallback 1: 'NASIONAL' jika beda
        if (category1['category'] != 'NASIONAL') {
          category2 = {'title': 'Nasional', 'category': 'NASIONAL'};
        } else {
          // Fallback 2: 'INTERNASIONAL' (pasti beda)
          category2 = {'title': 'Internasional', 'category': 'INTERNASIONAL'};
        }
      }
    } else {
      // _dailyCategory1 null, gunakan default
      category1 = {'title': 'Nasional', 'category': 'NASIONAL'};
      // Cek _dailyCategory2. Jika ada dan BEDA, pakai.
      if (_dailyCategory2 != null &&
          _dailyCategory2!['category'] != 'NASIONAL') {
        category2 = _dailyCategory2!;
      } else {
        // _dailyCategory2 null atau sama, pakai default kedua
        category2 = {'title': 'Internasional', 'category': 'INTERNASIONAL'};
      }
    }

    // 💡 PERUBAHAN: Inisialisasi atau perbarui Future HANYA jika kategori berubah
    // Logika ini memastikan future hanya dibuat sekali per kategori,
    // atau ketika kategori harian berganti.
    if (category1['category'] != _latestCategory1Code || _latestCategory1Future == null) {
      _latestCategory1Code = category1['category']!;
      _latestCategory1Future = _articleRepository.getArticlesByCategory(
        _latestCategory1Code!,
        page: 1,
        pageSize: 3,
      );
    }

    if (category2 != null && (category2['category'] != _latestCategory2Code || _latestCategory2Future == null)) {
      _latestCategory2Code = category2['category']!;
      _latestCategory2Future = _articleRepository.getArticlesByCategory(
        _latestCategory2Code!,
        page: 1,
        pageSize: 3,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terbaru',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFamily: 'BG_Condensed',
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 24),

          // Kategori 1 (Pasti ada, dinamis atau default)
          _buildCategoryLatestSection(
              _latestCategory1Future, // 💡 Kirim Future
              category1['category']!,
              category1['title']!,
              isDark),

          const SizedBox(height: 32),

          // Kategori 2 (Pasti ada, dinamis atau default)
          _buildCategoryLatestSection(
              _latestCategory2Future, // 💡 Kirim Future
              category2!['category']!, // category2 dijamin non-null di sini
              category2['title']!,
              isDark),
        ],
      ),
    );
  }
  // --- 💡 AKHIR PERUBAHAN ---
}

// --- AWAL PERUBAHAN: Widget AllCategoriesScreen DIHAPUS karena digantikan oleh Drawer ---
// (Kode AllCategoriesScreen dihapus)
// --- AKHIR PERUBAHAN ---

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

// 💡 UBAH: Menjadi StatefulWidget agar bisa mengambil data sendiri
class CategoryLatestScreen extends StatefulWidget {
  final String categoryTitle;
  final String categoryCode;
  // final List<Article> articles; // 💡 Dihapus
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle; // 🚀 PERUBAHAN: Tipe diubah

  const CategoryLatestScreen({
    Key? key,
    required this.categoryTitle,
    required this.categoryCode,
    // required this.articles, // 💡 Dihapus
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  State<CategoryLatestScreen> createState() => _CategoryLatestScreenState();
}

class _CategoryLatestScreenState extends State<CategoryLatestScreen> {
  // 💡 State untuk menampung data yang di-fetch
  late Future<List<Article>> _articlesFuture;
  final ArticleRepository _repository = ArticleRepository(); // Repository
  
  // 🚀 PERUBAHAN: State lokal untuk bookmark
  late List<Article> _currentBookmarkedArticles;


  @override
  void initState() {
    super.initState();
    // 🚀 PERUBAHAN: Inisialisasi bookmark lokal
    _currentBookmarkedArticles = widget.bookmarkedArticles;
    // 💡 Panggil fetch saat widget pertama kali dibuat
    _articlesFuture = _repository.getArticlesByCategory(
      widget.categoryCode,
      page: 1,
      pageSize: 50, // Ambil 50 artikel untuk "Lihat Semua"
    );
  }

  // 🚀 PERUBAHAN: Fungsi bookmark lokal
  void _toggleBookmark(Article article) {
    // Panggil callback dari parent (HomeScreen)
    widget.onBookmarkToggle(article);

    // Update state lokal untuk refresh UI di layar ini
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
          widget.categoryTitle, // 💡 Ambil dari widget
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'CrimsonPro',
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        // 💡 Tombol kembali akan muncul otomatis
      ),
      body: SafeArea(
        // 💡 Gunakan FutureBuilder untuk menampilkan data
        child: FutureBuilder<List<Article>>(
          future: _articlesFuture,
          builder: (context, snapshot) {
            // 1. Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // 2. Error
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

            // 3. Data Kosong
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

            // 4. Sukses, tampilkan list
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final article = articles[index];
                // 🚀 PERUBAHAN: Cek dari state lokal
                final isBookmarked =
                    _currentBookmarkedArticles.any((b) => b.id == article.id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ArticleCard(
                    article: article,
                    isBookmarked: isBookmarked,
                    // 🚀 PERUBAHAN: Panggil _toggleBookmark lokal
                    onBookmarkToggle: () => _toggleBookmark(article), 
                    index: index,
                    // MODIFIKASI: Menggunakan layout3
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
                    // MODIFIKASI: Menggunakan layout3
                    layout: ArticleCardLayout.layout3,
                  );
                },
              ),
      ),
    );
  }
}

// --- 💡 DIHAPUS: CategoryCustomizerScreen tidak lagi diperlukan ---
// (Kode CategoryCustomizerScreen dihapus)
// --- 💡 AKHIR PERUBAHAN ---