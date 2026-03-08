import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import '../widgets/shimmer_loading.dart';
import '../providers/article_provider.dart';
import '../screens/article_detail_screen.dart';
import '../utils/custom_page_transitions.dart';
import '../providers/language_provider.dart';
import '../utils/strings.dart';
// Tambah import bookmark snackbar:
import '../widgets/snackbar_toggle.dart';

// --- TAMBAHKAN IMPORT REPOSITORY ---
import '../repositories/article_repository.dart';

class SortFilterScreen extends StatefulWidget {
  final String initialSortOption;
  final Set<String> initialCategories;
  final bool isDark;

  static const Map<String, int?> categoryMap = {
    'HYPE': 16,
    'OLAHRAGA': 15,
    'EKBIS': 17,
    'MEGAPOLITAN': 14,
    'DAERAH': 1,
    'NASIONAL': 12,
    'INTERNASIONAL': 13,
    'POLITIK': 530,
    'KESEHATAN': 725,
    'HUKUM': 1532,
    'WARGA SPILL': null,
    'CARI TAHU': 1420,
  };

  static const List<Map<String, String>> sortOptions = [
    {'value': 'most_recent', 'label': 'Most Recent'},
    {'value': 'oldest_to_newest', 'label': 'Oldest to Newest'},
  ];

  const SortFilterScreen({
    Key? key,
    required this.initialSortOption,
    required this.initialCategories,
    required this.isDark,
  }) : super(key: key);

  @override
  State<SortFilterScreen> createState() => _SortFilterScreenState();
}

class _SortFilterScreenState extends State<SortFilterScreen>
    with TickerProviderStateMixin {
  late String _currentSortOption;
  late Set<String> _selectedCategories;
  bool _isSortExpanded = true;
  bool _isCategoryExpanded = true;

  final Color _activeColor = const Color(0xFFE5FF10);
  final Color _buttonTextColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _currentSortOption = widget.initialSortOption;
    _selectedCategories = Set.from(widget.initialCategories);
  }

  Widget _buildExpandableHeader({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final Color textColor = widget.isDark ? Colors.white : Colors.black;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                if (trailing != null) trailing,
                if (trailing != null) const SizedBox(width: 8),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: textColor,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSortSection() {
    final Color textColor = widget.isDark ? Colors.white : Colors.black;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExpandableHeader(
          title: 'Sort',
          isExpanded: _isSortExpanded,
          onTap: () {
            setState(() {
              _isSortExpanded = !_isSortExpanded;
            });
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: ConstrainedBox(
            constraints: _isSortExpanded
                ? const BoxConstraints()
                : const BoxConstraints(maxHeight: 0.0),
            child: Column(
              children: SortFilterScreen.sortOptions.map((option) {
                return RadioListTile<String>(
                  value: option['value']!,
                  groupValue: _currentSortOption,
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() {
                        _currentSortOption = newValue;
                      });
                    }
                  },
                  title: Text(
                    option['label']!,
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black,
                      fontFamily: 'Inter',
                    ),
                  ),
                  activeColor: _activeColor,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  selected: _currentSortOption == option['value'],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    final Color textColor = widget.isDark ? Colors.white : Colors.black;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCategories.clear();
                  });
                },
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: _activeColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        _buildExpandableHeader(
          title: 'Category',
          isExpanded: _isCategoryExpanded,
          onTap: () {
            setState(() {
              _isCategoryExpanded = !_isCategoryExpanded;
            });
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: ConstrainedBox(
            constraints: _isCategoryExpanded
                ? const BoxConstraints()
                : const BoxConstraints(maxHeight: 0.0),
            child: GridView.builder(
              padding: const EdgeInsets.only(top: 8.0),
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 4.0,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: SortFilterScreen.categoryMap.length,
              itemBuilder: (context, index) {
                String categoryName =
                    SortFilterScreen.categoryMap.keys.elementAt(index);
                bool isSelected = _selectedCategories.contains(categoryName);

                return _buildCheckboxItem(categoryName, isSelected);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxItem(String title, bool isSelected) {
    final Color subtleTextColor =
        widget.isDark ? Colors.white70 : Colors.black54;
    return CheckboxListTile(
      value: isSelected,
      onChanged: (bool? newValue) {
        if (newValue != null) {
          setState(() {
            if (newValue) {
              _selectedCategories.add(title);
            } else {
              _selectedCategories.remove(title);
            }
          });
        }
      },
      title: Text(
        title,
        style: TextStyle(
          color: widget.isDark ? Colors.white : Colors.black,
          fontFamily: 'Inter',
          fontSize: 14,
        ),
      ),
      activeColor: _activeColor,
      checkColor: _buttonTextColor,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      side: BorderSide(
        color: isSelected ? _activeColor : subtleTextColor,
        width: 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = widget.isDark ? Colors.white : Colors.black;
    final Color pageBgColor =
        widget.isDark ? const Color(0xFF222222) : Colors.white;
    return Scaffold(
      backgroundColor: pageBgColor,
      appBar: AppBar(
        backgroundColor: pageBgColor,
        elevation: 0.5,
        automaticallyImplyLeading: true,
        title: Text(
          'Sort & Filter',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              children: [
                _buildSortSection(),
                const Divider(height: 32),
                _buildFilterSection(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0)
                .copyWith(bottom: 16.0 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: pageBgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop({
                    'sort': _currentSortOption,
                    'categories': Set<String>.from(_selectedCategories),
                  });

                  // --- GANTI Snackbar sort&filter dengan snackbarnya dari bookmark_toggle.dart ---
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    showSortFilterSnackbar(
                      context,
                      sortLabel: _currentSortOption == 'most_recent'
                          ? 'Terbaru'
                          : 'Terlama',
                      categoryCount: _selectedCategories.length,
                    );
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _activeColor,
                  foregroundColor: _buttonTextColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('Apply'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------- END Sort & Filter Screen ------------

// --- BOOKMARK LOGIC REFACTOR: Mirip article_card.dart + article_detail_screen.dart ---

class SearchFocusScreen extends StatefulWidget {
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;
  // [PERUBAHAN PENTING]: Tambahkan opsi untuk menentukan mode unlock kategori search
  final String? lockCategoryTab; // Jika null, search global! (unlock kategori)

  const SearchFocusScreen({
    Key? key,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
    this.lockCategoryTab, // opsional, abaikan untuk unlock
  }) : super(key: key);

  @override
  State<SearchFocusScreen> createState() => _SearchFocusScreenState();
}

class _SearchFocusScreenState extends State<SearchFocusScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // --- TAMBAHKAN REPOSITORY & KONTROL PAGINASI ---
  final ArticleRepository _articleRepository = ArticleRepository();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  // ---

  bool _showCursor = false;
  bool _isTyping = false;
  List<Article> _searchResults = [];
  bool _isLoading = false;
  String _submittedQuery = '';
  List<String> _trendingTopics = [];

  String _sortOption = 'most_recent';
  Set<String> _selectedCategories = <String>{};

  /// ----------------- BOOKMARK LOGIC STATE UPDATER -----------------
  /// This keeps track of real-time local bookmark state (for UI only, not persistent storage)
  late Set<String> _bookmarkedArticleIds;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChange);
    // --- TAMBAHKAN LISTENER UNTUK SCROLL PAGINATION ---
    _scrollController.addListener(_onScroll);
    // ---
    _bookmarkedArticleIds = widget.bookmarkedArticles.map((a) => a.id).toSet();

    // [PERUBAHAN]: Jika search di-lock pada kategori, otomatis pasang filter di kategori itu
    if (widget.lockCategoryTab != null &&
        widget.lockCategoryTab!.trim().isNotEmpty) {
      _selectedCategories = {widget.lockCategoryTab!};
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrendingTopics();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    // --- HAPUS LISTENER SCROLL ---
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // ---
    super.dispose();
  }

  bool get _isGuestUser {
    // Dummy logic; gantikan jika ada authProvider
    // return <logika guest>;
    return false;
  }

  void _showLoginRequiredSnackBar([String? message]) {
    final text = message ?? 'Login is required to save articles';
    final context_ = context;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context_).removeCurrentSnackBar();
      ScaffoldMessenger.of(context_).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.login_rounded, color: Color(0xFFE5FF10)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF333333),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'LOGIN',
            textColor: Colors.yellow[700],
            onPressed: () {
              // TODO: Navigate ke halaman login
            },
          ),
        ),
      );
    });
  }

  void _handleBookmarkToggle(Article article) {
    if (_isGuestUser) {
      _showLoginRequiredSnackBar('Login is required to save articles');
      return;
    }

    final String articleId = article.id;
    final bool currentlyBookmarked = _bookmarkedArticleIds.contains(articleId);

    setState(() {
      if (currentlyBookmarked) {
        _bookmarkedArticleIds.remove(articleId);
      } else {
        _bookmarkedArticleIds.add(articleId);
      }
    });

    widget.onBookmarkToggle(article);

    // --- GANTI Snackbar bookmark ke global snackbar dari bookmark_toggle.dart ---
    final bool isNowBookmarked = !currentlyBookmarked;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showBookmarkSnackbar(context, isNowBookmarked);
    });
  }

  /// ============= END BOOKMARK LOGIC ===============

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _showCursor = _searchFocusNode.hasFocus;
      });
    }
  }

  // --- FUNGSI BARU UNTUK LOAD MORE (PAGINATION) ---
  void _onScroll() {
    // Cek jika kita 400px sebelum akhir list, dan tidak sedang loading,
    // dan masih ada data, dan ada query yang aktif
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400 &&
        !_isLoadingMore &&
        _hasMore &&
        _submittedQuery.isNotEmpty) {
      _loadMoreResults();
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoadingMore || !_hasMore) return;

    if (mounted) {
      setState(() {
        _isLoadingMore = true;
      });
    }

    final int nextPage = _currentPage + 1;

    try {
      // Siapkan parameter yang sama seperti pencarian awal
      final String apiSort = (_sortOption == 'most_recent') ? 'newest' : 'oldest';
      final List<int> apiCategoryIds = _selectedCategories
          .map((name) => SortFilterScreen.categoryMap[name])
          .whereType<int>()
          .toList();

      // Panggil API untuk halaman berikutnya
      final List<Article> newResults = await _articleRepository.searchArticles(
        query: _submittedQuery,
        sortBy: apiSort,
        // PERBAIKAN: Mengganti 'categories' menjadi 'categoryIds' (asumsi)
        categoryIds: apiCategoryIds,
        page: nextPage,
        pageSize: 20, // Asumsi 20 per halaman
      );

      if (mounted) {
        setState(() {
          _searchResults.addAll(newResults);
          _currentPage = nextPage;
          _hasMore = newResults.length == 20; // Cek jika kita dapat halaman penuh
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading more search results: $e");
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasMore = false; // Hentikan jika ada error
        });
      }
    }
  }
  // --- AKHIR FUNGSI BARU ---

  void _loadTrendingTopics() {
    final articleProvider = Provider.of<ArticleProvider>(context, listen: false);

    // [PERUBAHAN]: Trending diambil global, bukan dari kategori ("unlock")
    if (articleProvider.articles.isEmpty) return;

    final Set<String> allTags = {};
    for (var article in articleProvider.articles) {
      for (var tag in article.tags) {
        final cleanTag = tag.replaceAll('#', '').trim();
        if (cleanTag.isNotEmpty) {
          allTags.add(cleanTag);
        }
      }
    }

    final uniqueTags = allTags.toList();
    uniqueTags.shuffle(Random());

    if (mounted) {
      setState(() {
        _trendingTopics = uniqueTags.take(8).toList();
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (mounted) {
      setState(() {
        _isTyping = query.isNotEmpty;
        if (query.isEmpty) {
          _searchResults = [];
          _submittedQuery = '';
          _isLoading = false;
        }
      });
    }
  }

  // --- PERUBAHAN BESAR PADA _performSearch ---
  // Mengganti filter lokal dengan panggilan API server-side
  Future<void> _performSearch(String query) async {
    // Jadikan async
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    FocusScope.of(context).unfocus();

    if (mounted) {
      setState(() {
        _isLoading = true;
        _submittedQuery = trimmedQuery;
        _searchResults = [];
        // Reset state paginasi setiap kali pencarian baru
        _currentPage = 1;
        _hasMore = true;
        _isLoadingMore = false;
      });
    }

    // Hapus Future.delayed, ganti dengan try-catch untuk network call
    try {
      // 1. Siapkan parameter untuk API
      final String apiSort = (_sortOption == 'most_recent') ? 'newest' : 'oldest';

      final List<int> apiCategoryIds = _selectedCategories
          .map((name) => SortFilterScreen.categoryMap[name])
          .whereType<int>() // Filter null
          .toList();

      // 2. Panggil Repository (Asumsi ada method searchArticles)
      // Ini akan mencari di *seluruh database*, bukan hanya data lokal
      final List<Article> results = await _articleRepository.searchArticles(
        query: trimmedQuery,
        sortBy: apiSort,
        // PERBAIKAN: Mengganti 'categories' menjadi 'categoryIds' (asumsi)
        categoryIds: apiCategoryIds,
        page: 1, // Selalu mulai dari halaman 1 untuk pencarian baru
        pageSize: 20, // Asumsi 20 per halaman
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
          _hasMore = results.length == 20; // Cek jika ada lebih banyak data
        });
      }
    } catch (e) {
      debugPrint("Error performing search: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _searchResults = []; // Tampilkan list kosong jika error
        });
      }
    }
  }

  void _onTagPressed(String topic) {
    _searchController.text = topic;
    _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length));
    _performSearch(topic);
  }

  void _openArticle(Article article) async {
    final heroTag = 'search-focus-article-${article.id}';
    final bool isBookmarkedInit = _bookmarkedArticleIds.contains(article.id);

    final result = await Navigator.of(context).push(
      HeroDialogRoute(
        builder: (context) => ArticleDetailScreen(
          article: article,
          isBookmarked: isBookmarkedInit,
          onBookmarkToggle: () => _handleBookmarkToggle(article),
          heroTag: heroTag,
        ),
      ),
    );

    // --- Mirip article_detail_screen.dart: Update bookmark local via popWithResult ---
    if (result is Map && result.containsKey('isBookmarked')) {
      final bool isBookmarkedLocal = result['isBookmarked'] as bool;
      final exists = _bookmarkedArticleIds.contains(article.id);
      if (isBookmarkedLocal && !exists) {
        setState(() {
          _bookmarkedArticleIds.add(article.id);
        });
        widget.onBookmarkToggle(article);
      } else if (!isBookmarkedLocal && exists) {
        setState(() {
          _bookmarkedArticleIds.remove(article.id);
        });
        widget.onBookmarkToggle(article);
      }
      // (snackbar handled in ArticleDetailScreen)
    }
  }

  Future<void> _showSortFilterPage() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => SortFilterScreen(
          initialSortOption: _sortOption,
          initialCategories: _selectedCategories,
          isDark: isDark,
        ),
      ),
    );

    if (result != null) {
      if (mounted) {
        setState(() {
          _sortOption = result['sort'] as String;
          _selectedCategories =
              Set<String>.from(result['categories'] as Set<String>);
        });
        if (_submittedQuery.isNotEmpty) {
          _performSearch(_submittedQuery);
        }
      }
      // --- GANTI Snackbar sort&filter dengan snackbar dari bookmark_toggle.dart ---
      showSortFilterSnackbar(
        context,
        sortLabel: _sortOption == 'most_recent' ? 'Terbaru' : 'Terlama',
        categoryCount: _selectedCategories.length,
      );
    }
  }

  Widget _buildSortFilterButton({Color? textColor, Color? subtleTextColor}) {
    // [PERUBAHAN]: Tombol tetap selalu aktif, unlock filtering
    return InkWell(
      onTap: _showSortFilterPage,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_vert, size: 18, color: subtleTextColor ?? Colors.grey),
          const SizedBox(width: 4),
          Text(
            'Sort & Filter',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: subtleTextColor ?? Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings =
        AppStrings(context.watch<LanguageProvider>().locale.languageCode);

    final Color mainBackgroundColor =
        isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0);
    final Color itemBackgroundColor =
        isDark ? const Color(0xFF333333) : const Color(0xFFFFFFFF);
    final Color searchBarColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color subtleTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: mainBackgroundColor,
      appBar: null,
      body: SafeArea(
        child: Column(
          children: [
            Stack(
              children: [
                Positioned(
                  top: 4,
                  right: 8,
                  child: (_isTyping || _submittedQuery.isNotEmpty)
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: Icon(
                            Icons.close,
                            color: textColor,
                          ),
                          onPressed: () {
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          },
                          tooltip: "Tutup",
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                      top: 52, left: 10, right: 20, bottom: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: textColor,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      if (_submittedQuery.isEmpty) ...[
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: searchBarColor,
                              borderRadius: BorderRadius.circular(2.0),
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              autofocus: true,
                              showCursor: _showCursor,
                              cursorColor: textColor,
                              decoration: InputDecoration(
                                hintText: 'Search keywords, topics and more',
                                border: InputBorder.none,
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: textColor,
                                  size: 22,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14.0, horizontal: 10.0),
                                hintStyle: TextStyle(
                                  fontFamily: 'Inter',
                                  color: textColor,
                                  fontSize: 16,
                                ),
                                suffixIcon: _isTyping
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.close,
                                          size: 20,
                                          color: textColor,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                      )
                                    : null,
                              ),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: textColor,
                                fontSize: 16,
                              ),
                              textInputAction: TextInputAction.search,
                              onSubmitted: _performSearch,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: Consumer<ArticleProvider>(
                builder: (context, articleProvider, child) {
                  if (_submittedQuery.isNotEmpty && _isLoading) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 12.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      subtleTextColor),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Searching for "$_submittedQuery"...',
                                style: TextStyle(
                                    fontFamily: 'SourceSerif4',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: subtleTextColor),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: ShimmerLoading(isDark: isDark)),
                      ],
                    );
                  } else if (_submittedQuery.isNotEmpty &&
                      !_isLoading &&
                      _searchResults.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              24.0, 12.0, 24.0, 12.0),
                          child: Text(
                            'You searched for',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 10.0),
                            decoration: BoxDecoration(
                              color: searchBarColor,
                              borderRadius: BorderRadius.circular(2.0),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _submittedQuery,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    _searchController.clear();
                                  },
                                  child: Icon(
                                    Icons.close,
                                    size: 20,
                                    color: subtleTextColor,
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing ${_searchResults.length} results',
                                style: TextStyle(
                                    fontFamily: 'DMSans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: subtleTextColor),
                              ),
                              _buildSortFilterButton(
                                  textColor: textColor,
                                  subtleTextColor: subtleTextColor),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            // --- TAMBAHKAN CONTROLLER & UPDATE ITEM COUNT ---
                            controller: _scrollController,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            itemCount: _searchResults.length + 1, // +1 untuk loader
                            // ---
                            itemBuilder: (context, index) {
                              // --- TAMBAHKAN LOGIKA LOADER DI AKHIR LIST ---
                              if (index == _searchResults.length) {
                                if (_isLoadingMore) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                if (!_hasMore && _searchResults.isNotEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        'Anda telah mencapai akhir hasil pencarian',
                                        style: TextStyle(color: subtleTextColor),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox
                                    .shrink(); // Sembunyikan jika tidak ada apa-apa
                              }
                              // ---

                              final article = _searchResults[index];
                              final isBookmarked =
                                  _bookmarkedArticleIds.contains(article.id);

                              // Set showCategory: true di layout2 ArticleCard
                              return ArticleCard(
                                article: article,
                                isBookmarked: isBookmarked,
                                onBookmarkToggle: () =>
                                    _handleBookmarkToggle(article),
                                index: index,
                                layout: ArticleCardLayout.layout2,
                                showCategoryInLayout2:
                                    true, // <-- Show category in layout2
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  } else if (_submittedQuery.isNotEmpty &&
                      !_isLoading &&
                      _searchResults.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              24.0, 12.0, 24.0, 12.0),
                          child: Text('You searched for',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: textColor)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 10.0),
                            decoration: BoxDecoration(
                                color: searchBarColor,
                                borderRadius: BorderRadius.circular(2.0)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_submittedQuery,
                                    style: TextStyle(
                                        fontFamily: 'Inter',
                                        color: textColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500)),
                                InkWell(
                                  onTap: () {
                                    _searchController.clear();
                                  },
                                  child: Icon(Icons.close,
                                      size: 20, color: subtleTextColor),
                                )
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Showing 0 results',
                                  style: TextStyle(
                                      fontFamily: 'DMSans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: subtleTextColor)),
                              _buildSortFilterButton(
                                  textColor: textColor,
                                  subtleTextColor: subtleTextColor),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off,
                                      size: 80, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Results Found',
                                    style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: textColor),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try using different or more general keywords',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontFamily: 'DMSans',
                                        fontSize: 14,
                                        color: subtleTextColor,
                                        height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Trending Topics',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            _buildSortFilterButton(
                                textColor: textColor,
                                subtleTextColor: subtleTextColor),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (_trendingTopics.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                'Tidak ada topik trending saat ini.',
                                style: TextStyle(
                                    color: subtleTextColor, fontSize: 14),
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 14.0,
                            runSpacing: 12.0,
                            children: _trendingTopics.map((topic) {
                              return ActionChip(
                                label: Text(
                                  topic,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                backgroundColor: itemBackgroundColor,
                                onPressed: () {
                                  _onTagPressed(topic);
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32.0),
                                  side: BorderSide(
                                    color: textColor.withOpacity(0.5),
                                    width: 0.5,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: 12.0),
                              );
                            }).toList(),
                          ),
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
}