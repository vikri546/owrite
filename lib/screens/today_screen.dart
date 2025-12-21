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
import '../utils/custom_page_transitions.dart';
import 'notifications_screen.dart';
// 💡 Tambahkan Import Repository
import '../repositories/article_repository.dart';

class TodayScreen extends StatefulWidget {
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;

  const TodayScreen({
    Key? key,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
  }) : super(key: key);

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  
  // 💡 Inisialisasi Repository untuk mengambil data fresh
  final ArticleRepository _articleRepository = ArticleRepository();

  late AnimationController _headerAnimController;
  late Animation<double> _headerHeightAnimation;
  bool _isHeaderVisible = true;

  late Set<String> _bookmarkedArticleIds;

  List<Article> _todayArticles = [];
  bool _isInitialLoading = true;

  final Color _loadMoreColor = const Color(0xFFE5FF10);

  // Tambahkan flag untuk memastikan refresh tidak berulang-ulang saat discroll ke atas
  bool _isDoingRefreshOnScrollTop = false;

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
      _loadData24Hours(); // 💡 Panggil fungsi baru
    });
  }

  @override
  void didUpdateWidget(covariant TodayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  // 💡 LOGIKA BARU: Mengambil semua data 'Top News' (Agregat semua kategori)
  // dengan limit besar (100) lalu difilter manual 24 jam.
  Future<void> _loadData24Hours() async {
    if (!mounted) return;
    setState(() {
      _isInitialLoading = true;
    });

    try {
      // 1. Ambil data dari Repository langsung (bukan provider yang mungkin terbatas/kategori lain)
      // Gunakan pageSize besar (misal 100) untuk memastikan kita mendapat semua berita hari ini
      final allFetchArticles = await _articleRepository.getArticlesByCategory(
        'Top News', 
        page: 1, 
        pageSize: 100 
      );

      // 2. Tentukan batas waktu 24 jam yang lalu
      final now = DateTime.now();
      final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));

      // 3. Filter artikel yang benar-benar dalam 24 jam terakhir
      final filteredArticles = allFetchArticles.where((article) {
        return article.publishedAt.isAfter(twentyFourHoursAgo);
      }).toList();

      // 4. Urutkan dari yang paling baru
      filteredArticles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      if (mounted) {
        setState(() {
          _todayArticles = filteredArticles;
          _isInitialLoading = false;
          _bookmarkedArticleIds = widget.bookmarkedArticles.map((a) => a.id).toSet();
        });
      }
    } catch (e) {
      debugPrint("Error loading today articles: $e");
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _todayArticles = []; // Kosongkan jika error
        });
      }
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

    // Deteksi scroll sampai ke atas (offset <= 0.0)
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 0.0 && // Sudah benar-benar di atas
        !_isDoingRefreshOnScrollTop) {
      _isDoingRefreshOnScrollTop = true;
      // Jalankan refresh seperti pull-to-refresh
      _loadData24Hours().whenComplete(() {
        // Berikan delay sedikit agar tidak trigger terus-menerus jika user diam di atas
        Future.delayed(const Duration(milliseconds: 500), () {
          _isDoingRefreshOnScrollTop = false;
        });
      });
    }
  }

  void _toggleBookmark(Article article) {
    setState(() {
      if (_bookmarkedArticleIds.contains(article.id)) {
        _bookmarkedArticleIds.remove(article.id);
      } else {
        _bookmarkedArticleIds.add(article.id);
      }
    });
    widget.onBookmarkToggle(article);
  }

  void _openArticle(Article article) async {
    final heroTag = 'today-screen-article-${article.id}';
    final isBookmarked = _bookmarkedArticleIds.contains(article.id);

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
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => NotificationsScreen(),
                    ),
                  );
                },
                tooltip: 'Notifikasi',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sectioned block builder (Dynamic Length)
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

    if (_todayArticles.isEmpty) {
      return Expanded(
        child: Center(
          child: Text(
            'Tidak ada artikel dalam 24 jam terakhir',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      );
    }

    final l = _todayArticles.length;
    final blocks = <Widget>[];

    int idx = 0;

    // 1. layout5 (1x, fullwidth)
    if (idx < l) {
      final a = _todayArticles[idx];
      blocks.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 20.0), 
          child: ArticleCard(
            article: a,
            isBookmarked: _bookmarkedArticleIds.contains(a.id),
            onBookmarkToggle: () => _toggleBookmark(a),
            index: idx,
            layout: ArticleCardLayout.layout5,
          ),
        ),
      );
      idx++;
    }

    // 2. layout1 (2x, vertical)
    if (idx < l) {
      final colChildren = <Widget>[];
      // Item 1
      if (idx < l) {
        colChildren.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ArticleCard(
            article: _todayArticles[idx],
            isBookmarked: _bookmarkedArticleIds.contains(_todayArticles[idx].id),
            onBookmarkToggle: () => _toggleBookmark(_todayArticles[idx]),
            index: idx,
            layout: ArticleCardLayout.layout1,
          ),
        ));
        idx++;
      }
      // Item 2
      if (idx < l) {
        colChildren.add(ArticleCard(
          article: _todayArticles[idx],
          isBookmarked: _bookmarkedArticleIds.contains(_todayArticles[idx].id),
          onBookmarkToggle: () => _toggleBookmark(_todayArticles[idx]),
          index: idx,
          layout: ArticleCardLayout.layout1,
        ));
        idx++;
      }
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(children: colChildren),
      ));
    }

    // 3. layout5 (4x: two rows, two column each)
    // 💡 Loop ini akan berjalan selama masih ada data untuk mengisi pola Grid Layout 5
    // tapi kita batasi 2 baris (4 item) sesuai request awal, atau bisa diloop terus jika mau.
    // Sesuai kode sebelumnya: 2 baris (idx 3,4,5,6)
    for (int row = 0; row < 2; row++) {
      if (idx < l) {
        final leftIdx = idx;
        final rightIdx = idx + 1;
        blocks.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 2.0, 16.0, 20.0),
            child: Row(
              children: [
                if (leftIdx < l && rightIdx < l)
                  ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ArticleCard(
                          article: _todayArticles[leftIdx],
                          isBookmarked: _bookmarkedArticleIds.contains(_todayArticles[leftIdx].id),
                          onBookmarkToggle: () => _toggleBookmark(_todayArticles[leftIdx]),
                          index: leftIdx,
                          layout: ArticleCardLayout.layout5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: ArticleCard(
                          article: _todayArticles[rightIdx],
                          isBookmarked: _bookmarkedArticleIds.contains(_todayArticles[rightIdx].id),
                          onBookmarkToggle: () => _toggleBookmark(_todayArticles[rightIdx]),
                          index: rightIdx,
                          layout: ArticleCardLayout.layout5,
                        ),
                      ),
                    ),
                  ]
                else if (leftIdx < l)
                  Expanded(
                    child: ArticleCard(
                      article: _todayArticles[leftIdx],
                      isBookmarked: _bookmarkedArticleIds.contains(_todayArticles[leftIdx].id),
                      onBookmarkToggle: () => _toggleBookmark(_todayArticles[leftIdx]),
                      index: leftIdx,
                      layout: ArticleCardLayout.layout5,
                    ),
                  ),
              ],
            ),
          ),
        );
        idx += 2;
      }
    }

    // 4. Sisanya layout1 (vertical) sampai habis
    // 💡 Bagian ini menjamin "Tampilkan semua berita" (tidak ada limit 10)
    while (idx < l) {
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: Column(
            children: [
              const SizedBox(height: 4),
              ArticleCard(
                article: _todayArticles[idx],
                isBookmarked: _bookmarkedArticleIds.contains(_todayArticles[idx].id),
                onBookmarkToggle: () => _toggleBookmark(_todayArticles[idx]),
                index: idx,
                layout: ArticleCardLayout.layout1,
              ),
            ],
          ),
        ),
      );
      idx++;
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: _loadData24Hours, // Gunakan fungsi load baru
        color: _loadMoreColor,
        backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 80, left: 10, right: 10),
          children: [
            _buildTodayHeader(isDark),
            ...blocks,
          ],
        ),
      ),
    );
  }

  Widget _buildTodayHeader(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          child: Text(
            "TODAY",
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
      ],
    );
  }
}