import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/article.dart';
import '../providers/article_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/article_card.dart';
import 'article_detail_screen.dart';
import 'notifications_screen.dart'; // ADD THIS IMPORT
import '../utils/custom_page_transitions.dart';

import '../repositories/article_repository.dart';

class NewsScreen extends StatefulWidget {
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;

  const NewsScreen({
    Key? key,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  final ArticleRepository _articleRepository = ArticleRepository();

  late AnimationController _headerAnimController;
  late Animation<double> _headerHeightAnimation;
  bool _isHeaderVisible = true;

  // Gunakan Set untuk manajemen bookmark yang lebih mudah
  late Set<String> _bookmarkedArticleIds;

  Map<String, List<Article>> _groupedArticles = {};
  List<String> _categoryOrder = [];
  Map<String, bool> _categoryLoadingMore = {};

  Map<String, int> _categoryCurrentPage = {};
  Map<String, bool> _categoryHasMore = {};
  bool _isInitialLoading = true;

  final Map<String, String> _categoryTitles = {
    'ALL_NEWS': 'All News',
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

  final List<String> _allCategoryCodes = [
    'HYPE',
    'OLAHRAGA',
    'EKBIS',
    'MEGAPOLITAN',
    'DAERAH',
    'NASIONAL',
    'INTERNASIONAL',
    'POLITIK',
    'KESEHATAN',
  ];

  final Color _loadMoreColor = const Color(0xFFE5FF10);

  @override
  void initState() {
    super.initState();

    _bookmarkedArticleIds = widget.bookmarkedArticles.map((a) => a.id).toSet();

    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _headerHeightAnimation = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeInOut,
    );

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void didUpdateWidget(covariant NewsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sinkronkan bookmark jika di parent terjadi perubahan (misal sync antar screen)
    if (widget.bookmarkedArticles != oldWidget.bookmarkedArticles) {
      setState(() {
        _bookmarkedArticleIds = widget.bookmarkedArticles.map((a) => a.id).toSet();
      });
    }
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isInitialLoading = true;
    });

    final Map<String, List<Article>> tempGrouped = {};
    final List<String> tempOrder = [];
    final Map<String, bool> tempLoading = {};
    final Map<String, int> tempCurrentPage = {};
    final Map<String, bool> tempHasMore = {};

    const int pageSize = 10;

    const String allNewsKey = 'ALL_NEWS';
    const String allNewsRepoKey = 'Top News';
    try {
      final articles = await _articleRepository.getArticlesByCategory(
        allNewsRepoKey,
        page: 1,
        pageSize: pageSize,
      );

      tempOrder.add(allNewsKey);
      tempGrouped[allNewsKey] = articles;
      tempCurrentPage[allNewsKey] = 1;
      tempHasMore[allNewsKey] = articles.length == pageSize;
      tempLoading[allNewsKey] = false;
    } catch (e) {
      debugPrint("Failed to load ALL_NEWS (as Top News): $e");
      tempOrder.add(allNewsKey);
      tempGrouped[allNewsKey] = [];
      tempCurrentPage[allNewsKey] = 1;
      tempHasMore[allNewsKey] = false;
      tempLoading[allNewsKey] = false;
    }

    for (String categoryCode in _allCategoryCodes) {
      try {
        final articles = await _articleRepository.getArticlesByCategory(
          categoryCode,
          page: 1,
          pageSize: pageSize,
        );

        tempOrder.add(categoryCode);
        tempGrouped[categoryCode] = articles;
        tempCurrentPage[categoryCode] = 1;
        tempHasMore[categoryCode] = articles.length == pageSize;
        tempLoading[categoryCode] = false;
      } catch (e) {
        debugPrint("Failed to load $categoryCode: $e");
        tempOrder.add(categoryCode);
        tempGrouped[categoryCode] = [];
        tempCurrentPage[categoryCode] = 1;
        tempHasMore[categoryCode] = false;
        tempLoading[categoryCode] = false;
      }
    }

    if (mounted) {
      setState(() {
        _groupedArticles = tempGrouped;
        _categoryOrder = tempOrder;
        _categoryLoadingMore = tempLoading;
        _categoryCurrentPage = tempCurrentPage;
        _categoryHasMore = tempHasMore;
        _isInitialLoading = false;
        // Sync bookmark dari widget jika (re)load
        _bookmarkedArticleIds = widget.bookmarkedArticles.map((a) => a.id).toSet();
      });
    }
  }

  void _onScroll() {
    if (!mounted) return;
    final direction = _scrollController.position.userScrollDirection;

    if (direction == ScrollDirection.reverse &&
        _isHeaderVisible &&
        _scrollController.offset > 60.0) {
      _headerAnimController.reverse();
      if (mounted) {
        setState(() => _isHeaderVisible = false);
      }
    } else if ((direction == ScrollDirection.forward && !_isHeaderVisible) ||
        (_scrollController.offset <= 60.0 && !_isHeaderVisible)) {
      _headerAnimController.forward();
      if (mounted) {
        setState(() => _isHeaderVisible = true);
      }
    }
  }

  void _loadMore(String categoryCode) async {
    if (_categoryLoadingMore[categoryCode] == true ||
        _categoryHasMore[categoryCode] == false) {
      return;
    }

    if (mounted) {
      setState(() {
        _categoryLoadingMore[categoryCode] = true;
      });
    }

    const int pageSize = 10;
    final int nextPage = (_categoryCurrentPage[categoryCode] ?? 1) + 1;

    try {
      final String repoCategoryCode =
          (categoryCode == 'ALL_NEWS') ? 'Top News' : categoryCode;

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
          _categoryLoadingMore[categoryCode] = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load more for $categoryCode: $e");
      if (mounted) {
        setState(() {
          _categoryLoadingMore[categoryCode] = false;
          _categoryHasMore[categoryCode] = false;
        });
      }
    }
  }

  /// Bookmark toggle: mengupdate state _bookmarkedArticleIds secara otomatis
  void _toggleBookmark(Article article) {
    setState(() {
      if (_bookmarkedArticleIds.contains(article.id)) {
        _bookmarkedArticleIds.remove(article.id);
      } else {
        _bookmarkedArticleIds.add(article.id);
      }
    });
    // Notify parent for sync (misal ke provider atau save ke db)
    widget.onBookmarkToggle(article);
  }

  /// Navigasi ke detail artikel dan auto refresh jika bookmark di detail berubah
  void _openArticle(Article article) async {
    final heroTag = 'news-screen-article-${article.id}';
    final isBookmarked = _bookmarkedArticleIds.contains(article.id);

    // Menggunakan await supaya bisa detect perubahan bookmark jika detail mengubah
    await Navigator.of(context).push(
      HeroDialogRoute(
        builder: (context) => ArticleDetailScreen(
          article: article,
          isBookmarked: isBookmarked,
          onBookmarkToggle: () => _toggleBookmark(article),
          heroTag: heroTag,
        ),
      ),
    );

    // SetState redundan supaya force refresh (opsional)
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAnimatedHeader(isDark),
            _buildContent(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader(bool isDark) {
    final String svgFillColor = isDark ? "white" : "black";

    return SizeTransition(
      sizeFactor: _headerHeightAnimation,
      axisAlignment: -1.0,
      child: ClipRect(
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
            border: Border(
              bottom: BorderSide(
                color: Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                tooltip: 'Kembali',
              ),

              const Spacer(),

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
                  // debugPrint("Tombol Notifikasi ditekan");
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => NotificationsScreen(),
                    ),
                  );
                },
                tooltip: 'Notifikasi',
              ),
              // IconButton(
              //   icon: SvgPicture.string(
              //     '''
              //     <svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 416 432">
              //       <path fill="${isDark ? '#FFFFFF' : '#000000'}" d="m366 237l45 35q7 6 3 14l-43 74q-4 8-13 4l-53-21q-18 13-36 21l-8 56q-1 9-11 9h-85q-9 0-11-9l-8-56q-19-8-36-21l-53 21q-9 3-13-4L1 286q-4-8 3-14l45-35q-1-12-1-21t1-21L4 160q-7-6-3-14l43-74q5-8 13-4l53 21q18-13 36-21l8-56q2-9 11-9h85q10 0 11 9l8 56q19 8 36 21l53-21q9-3 13 4l43 74q4 8-3 14l-45 35q2 12 2 21t-2 21zm-158.5 54q30.5 0 52.5-22t22-53t-22-53t-52.5-22t-52.5 22t-22 53t22 53t52.5 22z"/>
              //     </svg>
              //     ''',
              //     width: 20,
              //     height: 20,
              //   ),
              //   onPressed: () {
              //     debugPrint("Tombol Pengaturan ditekan");
              //   },
              //   tooltip: 'Pengaturan',
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isInitialLoading) {
      return Expanded(
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_loadMoreColor),
          ),
        ),
      );
    }

    if (_groupedArticles.isEmpty) {
      return Expanded(
        child: Center(
          child: Text(
            'Tidak ada artikel untuk ditampilkan',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: _loadInitialData,
        color: _loadMoreColor,
        backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 80, left: 10, right: 10),
          itemCount: _categoryOrder.length,
          itemBuilder: (context, index) {
            final categoryCode = _categoryOrder[index];
            final title = _categoryTitles[categoryCode] ?? categoryCode;
            final articlesToShow = _groupedArticles[categoryCode] ?? [];
            final isLoadingMore = _categoryLoadingMore[categoryCode] ?? false;
            final hasMore = _categoryHasMore[categoryCode] ?? false;

            return _buildCategorySection(
              title,
              articlesToShow,
              hasMore,
              isLoadingMore,
              isDark,
              categoryCode,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    String title,
    List<Article> articlesToShow,
    bool hasMore,
    bool isLoadingMore,
    bool isDark,
    String categoryCode,
  ) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          child: Text(
            title.toUpperCase(),
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
            padding: const EdgeInsets.symmetric(vertical: 32.0),
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
            final isBookmarked = _bookmarkedArticleIds.contains(article.id);

            return ArticleCard(
              article: article,
              isBookmarked: isBookmarked,
              onBookmarkToggle: () => _toggleBookmark(article),
              index: index,
              layout: ArticleCardLayout.layout2,
            );
          }).toList(),

        const SizedBox(height: 24),
        if (isLoadingMore)
          Center(
            child: SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_loadMoreColor),
                strokeWidth: 3,
              ),
            ),
          )
        else if (hasMore)
          Center(
            child: ElevatedButton(
              onPressed: () => _loadMore(categoryCode),
              style: ElevatedButton.styleFrom(
                backgroundColor: _loadMoreColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text(
                'Lihat Lebih Banyak',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else if (articlesToShow.isNotEmpty)
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
        const SizedBox(height: 16),
      ],
    );
  }
}