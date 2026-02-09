import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/error_view.dart';
import '../providers/article_provider.dart';
import '../screens/article_detail_screen.dart';
import '../utils/custom_page_transitions.dart';
import '../providers/language_provider.dart';
import '../utils/strings.dart';
import '../utils/auth_service.dart';
import '../screens/login_screen.dart';
import '../providers/theme_provider.dart';

// 💡 --- AWAL TAMBAHAN ---
import 'search_focus_screen.dart';
import 'news_screen.dart';
import 'today_screen.dart';
import 'settings_screen.dart';
import 'feedback_screen.dart';
import 'contact_screen.dart';
// 💡 --- AKHIR TAMBAHAN ---

class SearchScreen extends StatefulWidget {
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;
  final String? initialCategory;

  const SearchScreen({
    Key? key,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
    this.initialCategory,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  // Variabel baru untuk mengontrol visibilitas kursor
  bool _showCursor = false;

  final List<String> _searchRecommendations = [
    'Politik',
    'Ekonomi',
    'Olahraga',
    'Teknologi',
    'Hukum',
    'Kesehatan',
  ];
  
  List<String> _searchHistory = [];
  bool _isTyping = false;
  List<Article> _mostPopularArticles = [];
  Map<String, List<Article>> _categorizedArticles = {};
  List<Article> _topStoriesArticles = [];
  bool _isLoggedIn = false;
  
  Timer? _debounce;
  List<Article> _liveResults = [];
  bool _isSearching = false;
  
  // Slider variables
  late PageController _sliderPageController;
  int _currentSliderPage = 0;
  Timer? _sliderTimer;
  AnimationController? _progressAnimationController;
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadSearchHistory();
    _checkLoginStatus();

    String startCategory = widget.initialCategory ?? 'Top News';

    // Tambahkan listener untuk FocusNode
    _searchFocusNode.addListener(_onFocusChange);
    
    // Initialize slider components
    _sliderPageController = PageController();
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    
    _progressAnimationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextSliderPage();
      }
    });
    
    // Load articles first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArticlesByCategory();
    });
  }

  void _onFocusChange() {
    if (_searchFocusNode.hasFocus) {
      // Ketika search bar mendapatkan fokus, pindah ke SearchFocusScreen
      _searchFocusNode.unfocus(); // Hindari membuka keyboard 2x
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => SearchFocusScreen(
          bookmarkedArticles: widget.bookmarkedArticles,
          onBookmarkToggle: widget.onBookmarkToggle,
        ),
      ));
    }
    if (mounted) {
      setState(() {
        _showCursor = _searchFocusNode.hasFocus;
      });
    }
  }
  
  Future<void> _checkLoginStatus() async {
    final authService = AuthService();
    final user = await authService.getCurrentUser();
    setState(() {
      _isLoggedIn = user != null && user['username'] != 'Guest';
    });
  }
  
  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }
  
  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', _searchHistory);
  }
  
  void _loadArticlesByCategory() {
    final articleProvider = Provider.of<ArticleProvider>(context, listen: false);
    if (articleProvider.articles.isNotEmpty) {
      if (mounted) {
        setState(() {
          var randomArticles = List<Article>.from(articleProvider.articles);
          randomArticles.shuffle();
          _topStoriesArticles = randomArticles.take(5).toList();
          
          var allArticles = List<Article>.from(articleProvider.articles);
          allArticles.shuffle();
          _mostPopularArticles = allArticles.take(5).toList();
          
          _categorizedArticles.clear();
          for (var category in _searchRecommendations) {
            var categoryArticles = articleProvider.articles
                .where((article) => article.category.toLowerCase() == category.toLowerCase())
                .take(5)
                .toList();
            if (categoryArticles.isNotEmpty) {
              _categorizedArticles[category] = categoryArticles;
            }
          }
        });
        
        if (_topStoriesArticles.isNotEmpty) {
          _progressAnimationController?.forward();
          _startAutoSlider();
        }
      }
    }
  }
  
  void _startAutoSlider() {
    _sliderTimer?.cancel();
  }
  
  void _nextSliderPage() {
    if (!mounted || _progressAnimationController == null || _topStoriesArticles.isEmpty) return;
    int nextPage = (_currentSliderPage + 1) % _topStoriesArticles.length;
    
    _sliderPageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    ).then((_) {
      if (mounted) {
        setState(() {
          _currentSliderPage = nextPage;
        });
        _progressAnimationController!.reset();
        _progressAnimationController!.forward();
      }
    });
  }
  
  void _onSliderPageChanged(int index) {
    if (!mounted || _progressAnimationController == null) return;
    
    setState(() {
      _currentSliderPage = index;
    });
    
    _progressAnimationController!.reset();
    _progressAnimationController!.forward();
  }
  
  void _addToSearchHistory(String query) {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _searchHistory.removeWhere((item) => item.toLowerCase() == query.toLowerCase());
      _searchHistory.insert(0, query);
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.sublist(0, 10);
      }
    });
    
    _saveSearchHistory();
  }
  
  void _clearSearchHistory() async {
    setState(() => _searchHistory.clear());
    _saveSearchHistory();
  }
  
  void _onSearchChanged() {
    final query = _searchController.text;
    
    if (mounted) setState(() => _isTyping = query.isNotEmpty);
    
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.isEmpty) {
      if (mounted) setState(() { _liveResults = []; _isSearching = false; });
      return;
    }
    
    if (mounted) setState(() => _isSearching = true);
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performLiveSearch(query);
    });
  }
  
  void _performLiveSearch(String query) {
    if (query.trim().isEmpty) return;
    
    final articleProvider = Provider.of<ArticleProvider>(context, listen: false);
    final allArticles = articleProvider.articles;
    
    final results = allArticles.where((article) {
      final titleLower = article.title.toLowerCase();
      final descLower = (article.description ?? '').toLowerCase();
      final authorLower = (article.author ?? '').toLowerCase();
      final categoryLower = article.category.toLowerCase();
      final queryLower = query.toLowerCase();
      
      return titleLower.contains(queryLower) ||
             descLower.contains(queryLower) ||
             authorLower.contains(queryLower) ||
             categoryLower.contains(queryLower);
    }).toList();
    
    if (mounted) {
      setState(() {
        _liveResults = results;
        _isSearching = false;
      });
    }
  }
  
  void _performSearch(String query) {
    if (query.trim().isNotEmpty) {
      _addToSearchHistory(query);
      _performLiveSearch(query);
      FocusScope.of(context).unfocus();
    }
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    
    _debounce?.cancel();
    _sliderTimer?.cancel();
    _sliderPageController.dispose();
    _progressAnimationController?.dispose();
    super.dispose();
  }
  
  void _selectRecommendation(String recommendation) {
    _searchController.text = recommendation;
    _searchController.selection = TextSelection.fromPosition(TextPosition(offset: _searchController.text.length));
    _performSearch(recommendation);
  }
  
  void _openArticle(Article article) {
    final heroTag = 'search-article-${article.id}';
    final isBookmarked = widget.bookmarkedArticles.any((a) => a.id == article.id);
    
    Navigator.of(context).push(
      HeroDialogRoute(
        builder: (context) => ArticleDetailScreen(
          article: article,
          isBookmarked: isBookmarked,
          onBookmarkToggle: () => widget.onBookmarkToggle(article),
          heroTag: heroTag,
        ),
      ),
    );
  }
  
  void _navigateToCategory(String category, List<Article> articles) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CategoryArticlesScreen(
          category: category,
          articles: articles,
          bookmarkedArticles: widget.bookmarkedArticles,
          onBookmarkToggle: widget.onBookmarkToggle,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings(context.watch<LanguageProvider>().locale.languageCode);
    
    final Color mainBackgroundColor = isDark 
    ? const Color(0xFF222222) // Lebih gelap sedikit
    : const Color(0xFFF0F0F0); // Putih pudar
    final Color itemBackgroundColor = isDark 
    ? const Color(0xFF222222) // Lebih gelap sedikit
    : const Color(0xFFF0F0F0); // Putih pudar
    final Color searchBarColor = isDark ? Colors.grey[800]! : Colors.grey[300]!; // Sesuai gambar

    return Scaffold(
      backgroundColor: mainBackgroundColor,
      appBar: null,
      body: SafeArea(
        child: Column(
          children: [
            // BARIS KUSTOM 1: Negara & Tombol Close
            Padding(
              padding: const EdgeInsets.fromLTRB(22.0, 10.0, 10.0, 10.0),
              child: Row(
                children: [
                  Text(
                    'Negara: ',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  Text(
                    'Indonesia',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            
            // BARIS KUSTOM 2: Search Bar - Ubah agar saat tap pindah ke SearchFocusScreen
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 10.0),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  // Pindah ke SearchFocusScreen
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => SearchFocusScreen(
                      bookmarkedArticles: widget.bookmarkedArticles,
                      onBookmarkToggle: widget.onBookmarkToggle,
                    ),
                  ));
                },
                child: AbsorbPointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: searchBarColor,
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: false,
                      showCursor: _showCursor,
                      decoration: InputDecoration(
                        hintText: 'Search keywords, topics and more',
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark ? Colors.white : Colors.black,
                          size: 22,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 10.0),
                        hintStyle: TextStyle(
                          fontFamily: 'Inter',
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 16,
                        ),
                        suffixIcon: _isTyping
                            ? IconButton(
                                icon: Icon(
                                  Icons.close,
                                  size: 20,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                      ),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 16,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: _performSearch,
                    ),
                  ),
                ),
              ),
            ),
            
            // Hapus tombol-tombol (CNA, Lifestyle, dll) - Selesai (karena tidak ada di kode)
            
            // KONTEN UTAMA: Hasil Pencarian atau Menu Navigasi
            Expanded(
              child: Consumer<ArticleProvider>(
                builder: (context, articleProvider, child) {
                  if (_categorizedArticles.isEmpty && articleProvider.articles.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _loadArticlesByCategory();
                    });
                  }
                  
                  // Mode Searching: Tampilkan Hasil
                  if (_isTyping && _liveResults.isNotEmpty) {
                    return Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.grey[50],
                            border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.filter_list, size: 16, color: isDark ? Colors.white70 : Colors.black54),
                              const SizedBox(width: 8),
                              Text(
                                '${_liveResults.length} artikel ditemukan',
                                style: TextStyle(fontFamily: 'SourceSerif4', fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: _liveResults.length,
                            itemBuilder: (context, index) {
                              final article = _liveResults[index];
                              final isBookmarked = widget.bookmarkedArticles.any((a) => a.id == article.id);
                              
                              return ArticleCard(
                                article: article,
                                isBookmarked: isBookmarked,
                                onBookmarkToggle: () => widget.onBookmarkToggle(article),
                                index: index,
                                layout: ArticleCardLayout.layout1, 
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }
                  
                  // Mode Searching: Loading
                  if (_isTyping && _isSearching) {
                    return Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.grey[50],
                            border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!, width: 1)),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white70 : Colors.black54),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Mencari...',
                                style: TextStyle(fontFamily: 'SourceSerif4', fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: ShimmerLoading(isDark: isDark)),
                      ],
                    );
                  }
                  
                  // Mode Searching: Tidak Ada Hasil
                  if (_isTyping && _liveResults.isEmpty && !_isSearching) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak Ada Hasil',
                              style: TextStyle(fontFamily: 'SourceSerif4', fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Coba gunakan kata kunci lain',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'SourceSerif4', fontSize: 14, color: isDark ? Colors.white70 : Colors.black54, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  // Default View - GANTI DENGAN MENU NAVIGASI
                  return Container(
                    width: double.infinity,
                    color: itemBackgroundColor,
                    child: Column(
                      children: [
                        _buildNavigationItem("NEWS", isDark),
                        Divider(color: Colors.grey[700], height: 0.5, indent: 24, endIndent: 24),
                        _buildNavigationItem("SETTINGS", isDark),
                        Divider(color: Colors.grey[700], height: 0.5, indent: 24, endIndent: 24),
                        _buildNavigationItem("FEEDBACK", isDark),
                        Divider(color: Colors.grey[700], height: 0.5, indent: 24, endIndent: 24),
                        _buildNavigationItem("OWRITE MEDIA", isDark),
                        Divider(color: Colors.grey[700], height: 0.5, indent: 24, endIndent: 24),
                        // TODAY temporarily hidden
                        // _buildNavigationItem("TODAY", isDark),
                        // Divider(color: Colors.grey[700], height: 0.5, indent: 24, endIndent: 24),
                        // _buildNavigationItem("LISTEN", isDark),
                        // Divider(color: Colors.grey[700], height: 0.5, indent: 24, endIndent: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget helper baru untuk item navigasi
  Widget _buildNavigationItem(String title, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // 💡 --- AWAL PERUBAHAN: Navigasi ke NewsScreen & TodayScreen ---
          if (title == "NEWS") {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => NewsScreen(
                  bookmarkedArticles: widget.bookmarkedArticles,
                  onBookmarkToggle: widget.onBookmarkToggle,
                ),
              ),
            );
          } 
          else if (title == "TODAY") {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TodayScreen(
                  bookmarkedArticles: widget.bookmarkedArticles,
                  onBookmarkToggle: widget.onBookmarkToggle,
                ),
              ),
            );
          }
          else if (title == "SETTINGS") {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          }
          else if (title == "FEEDBACK") {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const FeedbackScreen(),
              ),
            );
          }
          else if (title == "OWRITE MEDIA") {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ContactScreen(),
              ),
            );
          }
          else {
            print("$title tapped");
          }
          // 💡 --- AKHIR PERUBAHAN ---
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 22.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter', 
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.white : Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Fungsi-fungsi di bawah ini tidak lagi digunakan untuk membangun UI default,
  // tapi saya biarkan jika logic-nya masih terpakai di tempat lain (spt _openArticle)
  
  Widget _buildLoginForm(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[300],
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'owrite',
            style: TextStyle(
              fontFamily: 'Domine',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Penasaran dengan apa yang ada disini? Jelajahi konten berita terbaru kami setiap hari dan dapatkan informasi terkini yang Anda butuhkan.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCCFF00),
                foregroundColor: isDark ? Colors.white : Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                elevation: 0,
              ),
              child: Text(
                'Sign Up',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTopStoriesSlider(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      child: Container(
        height: 280,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: Stack(
          children: [
            // PageView Slider
            PageView.builder(
              controller: _sliderPageController,
              onPageChanged: _onSliderPageChanged,
              itemCount: _topStoriesArticles.length,
              itemBuilder: (context, index) {
                final article = _topStoriesArticles[index];
                return GestureDetector(
                  onTap: () => _openArticle(article),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image
                      article.urlToImage != null
                          ? CachedNetworkImage(
                              imageUrl: article.urlToImage!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: isDark ? Colors.grey[800] : Colors.grey[300],
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: isDark ? Colors.grey[800] : Colors.grey[300],
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                                  size: 60,
                                ),
                              ),
                            )
                          : Container(
                              color: isDark ? Colors.grey[800] : Colors.grey[300],
                              child: Icon(
                                Icons.image_not_supported,
                                color: isDark ? Colors.grey[600] : Colors.grey[400],
                                size: 60,
                              ),
                            ),
                      
                      // Gradient shadow for title area only
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 200,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(1.0),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Title
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 24,
                        child: Text(
                          article.title,
                          style: const TextStyle(
                            fontFamily: 'BG_Condensed',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            // Progress indicators (inside image, on top)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: List.generate(
                  _topStoriesArticles.length,
                  (i) => Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(right: i == _topStoriesArticles.length - 1 ? 0 : 4),
                      child: _progressAnimationController != null
                          ? AnimatedBuilder(
                              animation: _progressAnimationController!,
                              builder: (context, child) {
                                double progress = 0.0;
                                if (i < _currentSliderPage) {
                                  progress = 1.0;
                                } else if (i == _currentSliderPage) {
                                  progress = _progressAnimationController!.value;
                                }
                                
                                return LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white.withOpacity(0.3),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                );
                              },
                            )
                          : LinearProgressIndicator(
                              value: 0.0,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
  
  Widget _buildCategorySection(BuildContext context, String category, List<Article> articles, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: TextStyle(
                  fontFamily: 'BG_Condensed',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToCategory(category, articles),
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
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];
              return _buildCategoryArticleCard(context, article, isDark);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildCategoryArticleCard(BuildContext context, Article article, bool isDark) {
    return GestureDetector(
      onTap: () => _openArticle(article),
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
                  fontFamily: 'Domine',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMostPopularItem(BuildContext context, Article article, int rank, bool isDark) {
    return GestureDetector(
      onTap: () => _openArticle(article),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar dengan angka di pojok kiri bawah
            SizedBox(
              width: 120,
              height: 90,
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: article.urlToImage ?? '',
                    fit: BoxFit.cover,
                    width: 120,
                    height: 90,
                    placeholder: (context, url) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      child: Icon(Icons.image_not_supported,
                          color: isDark ? Colors.grey[600] : Colors.grey[400]),
                    ),
                  ),
                  Positioned(
                    left: -2,
                    bottom: -15,
                    child: Text(
                      rank.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                article.title,
                style: TextStyle(
                  fontFamily: 'Domine',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                  height: 1.3,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSolidDivider(bool isDark) {
    return Container(
      height: 2,
      color: isDark ? Colors.grey[800] : Colors.grey[300],
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
    this.indent = 0,
    this.endIndent = 0,
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
          padding: EdgeInsets.only(
            left: indent,
            right: endIndent,
            top: 8,
            bottom: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class CategoryArticlesScreen extends StatelessWidget {
  final String category;
  final List<Article> articles;
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;

  const CategoryArticlesScreen({
    Key? key,
    required this.category,
    required this.articles,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFCCCCCC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFCCCCCC),
        foregroundColor: isDark ? Colors.white : Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          category,
          style: const TextStyle(
            fontFamily: 'BG_Condensed',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final article = articles[index];
          final isBookmarked = bookmarkedArticles.any((a) => a.id == article.id);
          
          return ArticleCard(
            article: article,
            isBookmarked: isBookmarked,
            onBookmarkToggle: () => onBookmarkToggle(article),
            index: index,
          );
        },
      ),
    );
  }
}