import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Impor SharedPreferences
import '../models/article.dart'; // Pastikan path model benar
import '../repositories/article_repository.dart'; // Pastikan path repository benar
import '../utils/app_exceptions.dart'; // Pastikan path exceptions benar

// Ganti BackgroundNotificationService dengan NotificationService yang disediakan
import '../services/notification_service.dart'; // Pastikan path service benar

// Enum untuk status loading artikel
enum ArticleLoadingStatus {
  initial, // Keadaan awal
  loading, // Sedang memuat halaman pertama atau refresh
  loaded, // Berhasil memuat
  error, // Terjadi error saat memuat
  loadingMore, // Sedang memuat halaman berikutnya
  noMoreData, // Sudah mencapai halaman terakhir
}

// Provider untuk mengelola state artikel
class ArticleProvider with ChangeNotifier {
  final ArticleRepository _repository; // Repository untuk mengambil data
  
  // Ganti ke service yang disediakan
  final NotificationService _notificationService = NotificationService();

  // State utama
  List<Article> _articles = []; // Daftar artikel yang ditampilkan
  String? _currentCategory; // Kategori yang sedang aktif (null untuk 'Semua Berita')
  String _errorMessage = ''; // Pesan error jika terjadi
  ArticleLoadingStatus _status = ArticleLoadingStatus.initial; // Status loading saat ini

  // State untuk paginasi
  int _currentPage = 1; // Halaman saat ini
  bool _hasMorePages = true; // Apakah masih ada halaman berikutnya
  static const int _pageSize = 100; // Jumlah artikel per halaman

  // State untuk pencarian (jika diperlukan di masa depan)
  String _searchQuery = '';
  List<Article> _searchResults = [];
  ArticleLoadingStatus _searchStatus = ArticleLoadingStatus.initial;

  // Menyimpan daftar artikel sebelumnya untuk cek notifikasi
  List<Article> _previousArticles = [];

  // Getters publik untuk mengakses state
  List<Article> get articles => _articles;
  // Menampilkan "Semua Berita" jika _currentCategory null
  String get currentCategory => _currentCategory ?? 'Semua Berita';
  String get errorMessage => _errorMessage;
  ArticleLoadingStatus get status => _status;
  bool get hasMorePages => _hasMorePages;
  String get searchQuery => _searchQuery;
  List<Article> get searchResults => _searchResults;
  ArticleLoadingStatus get searchStatus => _searchStatus;

  // Deteksi kategori dari artikel
  String _detectArticleCategory(Article article) {
     // Asumsikan model Article memiliki properti 'category'
     // yang berisi kode kategori (misal 'POLITIK', 'NASIONAL')
     // Ini berdasarkan penggunaan di home_screen.dart
     return article.category?.toUpperCase() ?? 'NASIONAL'; // Default
   }

  // Constructor, inisialisasi repository
  ArticleProvider({ArticleRepository? repository})
      : _repository = repository ?? ArticleRepository();

  // Fungsi utama untuk memuat artikel
  Future<void> loadArticles({bool refresh = false}) async {
    // 1. Atur status loading berdasarkan kondisi (refresh, load more, atau initial load)
    if (refresh) {
      _currentPage = 1; // Reset halaman ke 1 jika refresh
      _hasMorePages = true; // Anggap ada halaman lagi saat refresh
      _status = ArticleLoadingStatus.loading;
    } else if (_status == ArticleLoadingStatus.loading || _status == ArticleLoadingStatus.loadingMore) {
      return; // Hindari request ganda jika sedang loading
    } else if (_currentPage > 1) {
      _status = ArticleLoadingStatus.loadingMore; // Status untuk memuat halaman berikutnya
    } else {
      _status = ArticleLoadingStatus.loading; // Status untuk memuat halaman pertama
    }
    // Beri tahu listener (UI) bahwa state berubah (loading dimulai)
    notifyListeners();

    try {
      // 2. Panggil repository untuk mengambil data artikel
      // Kirimkan _currentCategory (bisa null) agar repository tahu kategori mana yang diminta
      final newArticles = await _repository.getArticlesByCategory(
        _currentCategory, // Null jika "Semua Berita"
        forceRefresh: refresh, // Parameter opsional untuk cache repository
        page: _currentPage,
        pageSize: _pageSize,
      );

      // 3. Proses hasil dari repository
      if (_currentPage == 1) {
        // Jika ini halaman pertama (atau refresh)
        _previousArticles = List.from(_articles); // Simpan daftar lama untuk cek notifikasi
        _articles = newArticles; // Ganti daftar artikel dengan yang baru

        // Cek notifikasi hanya saat refresh dan ada artikel baru
        if (refresh && _articles.isNotEmpty) {
          await _checkForNewArticles();
        }
      } else {
        // Jika ini halaman berikutnya (load more)
        // Hindari duplikasi artikel (berdasarkan ID) sebelum ditambahkan
        final uniqueNewArticles = newArticles.where((article) => !_articles.any((a) => a.id == article.id)).toList();
        _articles.addAll(uniqueNewArticles); // Tambahkan artikel unik ke daftar yang ada
      }

      // 4. Update status paginasi dan loading
      // Jika jumlah artikel baru kurang dari ukuran halaman, berarti sudah halaman terakhir
      if (newArticles.isEmpty || newArticles.length < _pageSize) {
        _hasMorePages = false;
        _status = ArticleLoadingStatus.noMoreData; // Tandai sudah tidak ada data lagi
      } else {
        _currentPage++; // Naikkan nomor halaman untuk request berikutnya
        _status = ArticleLoadingStatus.loaded; // Tandai loading selesai
      }
    } catch (e) {
      // 5. Tangani error jika terjadi
      _status = ArticleLoadingStatus.error; // Set status error
      _errorMessage = e is AppException ? e.message : 'Gagal memuat artikel'; // Ambil pesan error
      debugPrint("Error loading articles in provider: $e"); // Log error untuk debug
    } finally {
       // 6. Selalu beri tahu listener (UI) setelah selesai, baik sukses maupun error
       // Cek mounted jika berada di dalam context widget, tapi di provider tidak perlu
       notifyListeners();
    }
  }

  // Cek apakah ada artikel baru dibandingkan sebelumnya dan kirim notifikasi
  Future<void> _checkForNewArticles() async {
     if (_previousArticles.isEmpty) return; // Tidak bisa dibandingkan jika list sebelumnya kosong

     // Filter artikel baru (yang ada di _articles tapi tidak ada di _previousArticles)
     final newArticles = _articles.where((a) => !_previousArticles.any((p) => p.id == a.id)).toList();

     // Jika ada artikel baru
     if(newArticles.isNotEmpty) {
        // ---- LOGIKA NOTIFIKASI BARU (SYARAT 8) ----
        // 1. Muat preferensi filter pengguna
        final prefs = await SharedPreferences.getInstance();
        final Set<String> subscribedCategories = prefs.getStringList('subscribed_categories')?.toSet() ?? {};

        // 2. Filter artikel baru berdasarkan preferensi
        final articlesToSend = newArticles.where((article) {
          final category = _detectArticleCategory(article);
          // Jika tidak ada preferensi (kosong), kirim semua.
          // Jika ada, cek apakah kategori artikel ada di daftar langganan.
          return subscribedCategories.isEmpty || subscribedCategories.contains(category);
        }).toList();

        if (articlesToSend.isEmpty) return; // Tidak ada artikel baru yang sesuai filter

        // 3. Kirim notifikasi untuk artikel pertama yang lolos filter
        final firstArticle = articlesToSend.first;
        await _notificationService.showBreakingNewsNotification(
          firstArticle.title,
          firstArticle.description ?? '', // Asumsi ada deskripsi
          payload: firstArticle.id, // Kirim ID untuk navigasi
        );
        
        // Kirim 'Trending' jika lebih dari 1 (sesuai logika lama)
        if(articlesToSend.length > 1) {
          // Asumsi `showTrendingNotification` adalah notifikasi ringkasan
          // Jika bukan, mungkin perlu kirim notifikasi kedua
           await _notificationService.showTrendingNotification(
             'Berita Populer Baru', 
             'Ada ${articlesToSend.length} artikel baru yang mungkin Anda sukai.',
           );
        }
        // ---- AKHIR LOGIKA NOTIFIKASI BARU ----
     }
  }

  // Fungsi untuk mengganti kategori berita
  Future<void> changeCategory(String? category) async {
    // Jika kategori yang dipilih sama dengan yang aktif, tidak perlu load ulang
    if (_currentCategory == category) return;

    _currentCategory = category; // Update kategori aktif (bisa null)
    // Reset state paginasi dan daftar artikel
    _currentPage = 1;
    _hasMorePages = true;
    _articles = []; // Kosongkan list saat ganti kategori
    _status = ArticleLoadingStatus.loading; // Set status loading

    notifyListeners(); // Beri tahu UI untuk menampilkan loading
    // Panggil loadArticles untuk mengambil data kategori baru
    await loadArticles(refresh: true);
  }

  // Fungsi untuk memuat halaman artikel berikutnya
  Future<void> loadMoreArticles() async {
    // Jangan load more jika sudah tidak ada halaman lagi atau sedang loading
    if (!_hasMorePages || _status == ArticleLoadingStatus.loading || _status == ArticleLoadingStatus.loadingMore) {
      return;
    }
    // Panggil loadArticles (tanpa refresh)
    await loadArticles();
  }

  // Fungsi untuk me-refresh data artikel (mengambil ulang halaman pertama)
  Future<void> refreshArticles() async {
    // Panggil loadArticles dengan refresh true
    await loadArticles(refresh: true);
  }

  // Fungsi untuk mencari artikel (implementasi detail ada di repository)
  Future<void> searchArticles(String query, {required Map<String, dynamic> dateFilter, required String sortBy, String? language}) async {
     if (query.isEmpty) { clearSearch(); return; } // Hapus pencarian jika query kosong
     // Hindari pencarian ganda jika query sama dan sudah selesai loading
     if (_searchQuery == query && _searchStatus == ArticleLoadingStatus.loaded) return;

     _searchQuery = query; // Simpan query pencarian
     _searchStatus = ArticleLoadingStatus.loading; // Set status loading
     notifyListeners(); // Update UI

     try {
       // Panggil repository untuk melakukan pencarian
       _searchResults = await _repository.searchArticles(query: query, language: language, sortBy: sortBy);
       _searchStatus = ArticleLoadingStatus.loaded; // Set status selesai

       // Kirim notifikasi rekomendasi jika hasil ditemukan
        if (_searchResults.isNotEmpty) {
          final firstArticle = _searchResults.first;
          final category = _detectArticleCategory(firstArticle);

          // ---- LOGIKA NOTIFIKASI BARU (SYARAT 8) ----
          // 1. Muat preferensi filter pengguna
          final prefs = await SharedPreferences.getInstance();
          final Set<String> subscribedCategories = prefs.getStringList('subscribed_categories')?.toSet() ?? {};
          
          // 2. Cek filter
          if (subscribedCategories.isEmpty || subscribedCategories.contains(category)) {
            // 3. Kirim notifikasi
            await _notificationService.showRecommendationNotification(
              firstArticle.title, 
              firstArticle.description ?? '',
              payload: firstArticle.id
            );
          }
          // ---- AKHIR LOGIKA NOTIFIKASI BARU ----
        }
     } catch (e) {
       _searchStatus = ArticleLoadingStatus.error; // Set status error
       _errorMessage = e is AppException ? e.message : 'Gagal mencari artikel';
       debugPrint("Error searching articles in provider: $e"); // Log error
     }
     notifyListeners(); // Update UI
  }

  // Fungsi untuk membersihkan hasil pencarian
  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _searchStatus = ArticleLoadingStatus.initial;
    notifyListeners();
  }

  // Fungsi untuk membersihkan cache (jika repository mendukung)
  Future<void> clearCache() async {
     try {
       // Panggil method clearCache di repository (jika ada)
       await _repository.clearCache();
       _articles = []; // Kosongkan juga artikel di provider
       _previousArticles = [];
       _currentPage = 1;
       _hasMorePages = true;
       _status = ArticleLoadingStatus.initial; // Reset status
       debugPrint("Cache cleared");
     } catch (e) {
       _errorMessage = 'Gagal membersihkan cache';
       debugPrint("Error clearing cache in provider: $e"); // Log error
     }
     notifyListeners(); // Update UI
  }

  // Override dispose untuk membersihkan resource jika perlu
  @override
  void dispose() {
    // Panggil dispose pada repository jika ada methodnya
    // _repository.dispose();
    super.dispose();
  }
}