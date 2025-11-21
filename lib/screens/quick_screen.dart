// quick_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../utils/custom_page_transitions.dart';
import '../services/analytics_service.dart';
import '../services/gemini_service.dart';
import 'article_detail_screen.dart';

// Helper class untuk melacak status refresh
class _RefreshState {
  final int count;
  final DateTime timestamp; // Timestamp dari refresh pertama dalam 24 jam
  _RefreshState(this.count, this.timestamp);
}

class QuickScreen extends StatefulWidget {
  final List<Article> bookmarkedArticles;
  final Function(Article) onBookmarkToggle;
  final Article? initialArticle;
  final bool hideFullPageButton;
  final bool blockScroll;

  const QuickScreen({
    Key? key,
    required this.bookmarkedArticles,
    required this.onBookmarkToggle,
    this.initialArticle,
    this.hideFullPageButton = false,
    this.blockScroll = false,
  }) : super(key: key);

  @override
  State<QuickScreen> createState() => _QuickScreenState();
}

class _QuickScreenState extends State<QuickScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  final Map<String, String> _summaryCache = {};
  final Map<String, bool> _expandedStates = {};
  int _currentPage = 0;
  bool _isLoadingMore = false;

  // Like states lokal
  final Map<String, bool> _likedStates = {};

  // Refresh states lokal
  final Map<String, _RefreshState> _refreshStates = {};

  // State management lokal untuk data
  final ArticleRepository _articleRepository = ArticleRepository();
  List<Article> _articles = [];
  bool _isInitialLoading = true;

  final int _pageSize = 10;
  int _currentPageForCategory = 1;

  // Local scroll lock, overridable per halaman
  bool? _overrideScrollLock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Sembunyikan status bar saat masuk QuickScreen
    Future.microtask(() =>
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialArticles();
    });

    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    // Tampilkan lagi status bar saat keluar dari QuickScreen
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    }
  }

  void _onPageScroll() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }

    final String? currentId =
        (_currentPage < _articles.length) ? _articles[_currentPage].id : null;

    if (_isScrollLockedForCurrent(_currentPage)) {
      return;
    }

    if (widget.blockScroll) return;

    if (!_isLoadingMore &&
        _articles.isNotEmpty &&
        page >= _articles.length - 3) {
      _loadMoreArticles();
    }
  }

  Future<void> _loadInitialArticles() async {
    if (!mounted) return;
    setState(() {
      _isInitialLoading = true;
      _articles = [];
      _currentPageForCategory = 1;
    });

    if (widget.initialArticle != null) {
      if (mounted) {
        setState(() {
          _articles = [widget.initialArticle!];
        });
      }
    }

    if (!widget.blockScroll) {
      await _loadMoreArticles();
    }

    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMoreArticles() async {
    if (_isLoadingMore) return;
    if (mounted) setState(() => _isLoadingMore = true);

    const String repoKey = 'Top News';

    try {
      List<Article> newArticles = [];

      newArticles = await _articleRepository.getArticlesByCategory(
        repoKey,
        page: _currentPageForCategory,
        pageSize: _pageSize,
      );

      if (newArticles.isNotEmpty) {
        if (widget.initialArticle != null) {
          newArticles = newArticles
              .where((article) => article.id != widget.initialArticle!.id)
              .toList();
        }
        newArticles.shuffle();

        if (mounted) {
          setState(() {
            _articles.addAll(newArticles);
            _currentPageForCategory++;
          });
        }
      } else {
        _currentPageForCategory = 1;
      }
    } catch (e) {
      debugPrint("Error fetching $repoKey: $e. Resetting to page 1.");
      _currentPageForCategory = 1;
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<String> _getSummary(Article article) async {
    if (_summaryCache.containsKey(article.id)) {
      return _summaryCache[article.id]!;
    }

    final description = article.description ?? '';
    if (description.isEmpty) {
      return 'Ringkasan tidak tersedia untuk artikel ini.';
    }

    final cleanDescription = _stripHtml(description);
    if (cleanDescription.trim().isEmpty) {
      return 'Ringkasan tidak tersedia untuk artikel ini.';
    }

    try {
      final summary = await GeminiService.summarizeText(cleanDescription);
      _summaryCache[article.id] = summary;
      return summary;
    } catch (e) {
      debugPrint("Error generating summary: $e");
      _summaryCache[article.id] = cleanDescription;
      return cleanDescription;
    }
  }

  void _handleRefreshSummary(Article article) {
    final articleId = article.id;
    final now = DateTime.now();
    final currentState = _refreshStates[articleId];

    bool allowRefresh = false;

    if (currentState == null) {
      _refreshStates[articleId] = _RefreshState(1, now);
      allowRefresh = true;
    } else {
      final bool isExpired = now.difference(currentState.timestamp).inHours >= 24;
      if (isExpired) {
        _refreshStates[articleId] = _RefreshState(1, now);
        allowRefresh = true;
      } else {
        if (currentState.count < 3) {
          _refreshStates[articleId] = _RefreshState(currentState.count + 1, currentState.timestamp);
          allowRefresh = true;
        } else {
          allowRefresh = false;
        }
      }
    }

    if (allowRefresh) {
      if (_summaryCache.containsKey(articleId)) {
        _summaryCache.remove(articleId);
      }
      setState(() {}); 
    }
  }

  bool _canRefreshSummary(Article article) {
    final articleId = article.id;
    final now = DateTime.now();
    final currentState = _refreshStates[articleId];

    if (currentState == null) {
      return true; 
    }

    final bool isExpired = now.difference(currentState.timestamp).inHours >= 24;
    if (isExpired) {
      return true; 
    }

    return currentState.count < 3;
  }

  String _stripHtml(String htmlString) {
    final regex = RegExp(r'<[^>]+>', multiLine: true, caseSensitive: false);
    return htmlString.replaceAll(regex, '').trim();
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('d MMM y', 'id_ID').format(dateTime);
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} menit lalu';
    } else {
      return 'Baru saja';
    }
  }

  void _navigateToDetail(Article article) {
    final heroTag = 'quick_${article.id}';
    final isBookmarked =
        widget.bookmarkedArticles.any((a) => a.id == article.id);

    Navigator.of(context).push(
      HeroDialogRoute(
        builder: (context) => ArticleDetailScreen(
          article: article,
          heroTag: heroTag,
          isBookmarked: isBookmarked,
          onBookmarkToggle: () => widget.onBookmarkToggle(article),
        ),
      ),
    );
  }

  void _handleLike(Article article) async {
    final current = _likedStates[article.id] ?? false;
    setState(() {
      _likedStates[article.id] = !current;
    });
    if (!current) {
      await AnalyticsService.logLikeEvent(article.id, article.title);
    }
  }

  void _handleShare(Article article) async {
    final text = "${article.title}\n\n${article.url}";
    await Share.share(text);
    await AnalyticsService.logShareEvent(article.id, article.title);
  }

  bool _isScrollLockedForCurrent(int pageIndex) {
    if (widget.blockScroll) return true;
    if (_overrideScrollLock != null) return _overrideScrollLock!;
    if (_articles.isEmpty) return false;
    final art = (_articles.length > pageIndex) ? _articles[pageIndex] : null;
    return art != null && (_expandedStates[art.id] ?? false);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final articles = _articles;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDark ? Colors.black : Colors.white;
    final Color cardColor = isDark ? Colors.black : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color subtitleColor = isDark ? Colors.white70 : Colors.black87;
    final Color borderColor = isDark ? Colors.white54 : Colors.black12;
    final Color shadowColor = isDark
        ? Colors.black.withOpacity(0.45)
        : Colors.grey.withOpacity(0.12);
    final highlightColor = isDark ? const Color(0xFFE5FF10) : Colors.black;

    final pageViewPhysics = _isScrollLockedForCurrent(_currentPage)
        ? const NeverScrollableScrollPhysics()
        : (widget.blockScroll ? const NeverScrollableScrollPhysics() : null);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: WillPopScope(
        onWillPop: () async {
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
          );
          return true;
        },
        child: Scaffold(
          backgroundColor: backgroundColor,
          body: Builder(
            builder: (context) {
              if (_isInitialLoading && articles.isEmpty) {
                return Center(
                  child: CircularProgressIndicator(
                    color: highlightColor,
                  ),
                );
              }

              if (articles.isEmpty) {
                return Center(
                  child: Text(
                    "Tidak ada artikel yang ditemukan.",
                    style: TextStyle(color: textColor),
                  ),
                );
              }

              return PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: articles.length,
                physics: pageViewPhysics,
                itemBuilder: (context, index) {
                  final article = articles[index];
                  final isExpanded = _expandedStates[article.id] ?? false;
                  final isLiked = _likedStates[article.id] ?? false;
                  final bool canRefresh = _canRefreshSummary(article); 

                  return _FullScreenArticleCard(
                    article: article,
                    isExpanded: isExpanded,
                    onExpand: () {
                      setState(() {
                        _expandedStates[article.id] = !isExpanded;
                        if (_currentPage == index) {
                          _overrideScrollLock = !_expandedStates[article.id]!;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() {
                              _overrideScrollLock = null;
                            });
                          });
                        }
                      });
                    },
                    onFullStory: () => _navigateToDetail(article),
                    onShare: () => _handleShare(article),
                    onBookmark: () => widget.onBookmarkToggle(article),
                    onRefreshSummary: () => _handleRefreshSummary(article),
                    canRefreshSummary: canRefresh,
                    isBookmarked: widget.bookmarkedArticles
                        .any((a) => a.id == article.id),
                    formatTime: _formatRelativeTime,
                    getSummary: _getSummary,
                    cardColor: cardColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    borderColor: borderColor,
                    shadowColor: shadowColor,
                    highlightColor: highlightColor,
                    isDark: isDark,
                    hideFullPageButton: widget.hideFullPageButton,
                    isLiked: isLiked,
                    onLikeToggle: () => _handleLike(article),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FullScreenArticleCard extends StatelessWidget {
  final Article article;
  final bool isExpanded;
  final VoidCallback onExpand;
  final VoidCallback onFullStory;
  final VoidCallback onShare;
  final VoidCallback onBookmark;
  final VoidCallback onRefreshSummary;
  final bool canRefreshSummary;
  final bool isBookmarked;
  final String Function(DateTime) formatTime;
  final Future<String> Function(Article) getSummary;
  final Color cardColor;
  final Color textColor;
  final Color subtitleColor;
  final Color borderColor;
  final Color shadowColor;
  final Color highlightColor;
  final bool isDark;
  final bool hideFullPageButton;
  final bool isLiked;
  final VoidCallback onLikeToggle;

  const _FullScreenArticleCard({
    Key? key,
    required this.article,
    required this.isExpanded,
    required this.onExpand,
    required this.onFullStory,
    required this.onShare,
    required this.onBookmark,
    required this.onRefreshSummary,
    required this.canRefreshSummary,
    required this.isBookmarked,
    required this.formatTime,
    required this.getSummary,
    required this.cardColor,
    required this.textColor,
    required this.subtitleColor,
    required this.borderColor,
    required this.shadowColor,
    required this.highlightColor,
    required this.isDark,
    this.hideFullPageButton = false,
    required this.isLiked,
    required this.onLikeToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final double imgHeight = media.size.height * 0.44;
    final double barHeight = 56;
    final double stickyMinHeight = 20 + 44 + 16 + 38;

    // ---- MODIFIKASI: Implementasi summaryWidget dengan Bullet List Row ---
    Widget summaryWidget(BuildContext context, {TextStyle? style, bool animated = false}) {
      final double fontSizeSummary = 17.5;
      // ignore: unused_local_variable
      final double summaryLeftPadding = 0; 
      final TextStyle effectiveStyle = (style ?? TextStyle()).copyWith(
        fontSize: fontSizeSummary,
        height: 1.65,
      );

      // Warna bullet sesuai mode
      final Color bulletColor = isDark ? const Color(0xFFE5FF10) : Colors.black;

      // Fungsi helper untuk membuat baris bullet
      Widget buildBulletRow(String line) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "•",
                style: TextStyle(
                  fontSize: 28,
                  height: 1.0, // Sedikit penyesuaian agar pas dengan teks
                  color: bulletColor,
                ),
              ),
              const SizedBox(width: 8), // Jarak antara bullet dan teks
              Expanded(
                child: Text(
                  line.trim(),
                  style: effectiveStyle,
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
        );
      }

      return FutureBuilder<String>(
        future: getSummary(article),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                "Sedang meringkas...", 
                style: effectiveStyle.copyWith(
                  fontStyle: FontStyle.italic, 
                  color: subtitleColor.withOpacity(0.8)
                )
              ),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                "Ringkasan gagal dimuat",
                style: effectiveStyle.copyWith(color: Colors.red),
              ),
            );
          }

          final summaryText = snapshot.data ?? 'Ringkasan tidak tersedia.';
          final rawLines = summaryText.split('\n');
          
          // Filter baris kosong dan bersihkan bullet markdown bawaan jika ada (agar tidak double)
          final List<String> contentLines = rawLines
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .map((l) => l.replaceFirst(RegExp(r'^\s*([•\-\*])\s+'), '')) // Hapus bullet karakter jika sudah ada dari teks
              .toList();

          if (contentLines.isEmpty) {
             return Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                "Ringkasan tidak tersedia.",
                style: effectiveStyle.copyWith(
                  fontStyle: FontStyle.italic, 
                  color: subtitleColor.withOpacity(0.8)
                ),
              ),
            );
          }

          if (animated) {
            // --- COLLAPSE MODE (animated: true) ---
            // Tampilkan hanya 3 baris pertama
            final int maxItems = 3;
            final linesToShow = contentLines.take(maxItems).toList();
            final hasMore = contentLines.length > maxItems;

            Widget content = Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Agar bullet sejajar
              mainAxisSize: MainAxisSize.min,
              children: [
                ...linesToShow.map((line) => buildBulletRow(line)),
                if (hasMore)
                  Padding(
                    padding: const EdgeInsets.only(left: 14.0, top: 4), // Indentasi sejajar teks
                    child: Text(
                      '...',
                      style: effectiveStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        color: effectiveStyle.color?.withOpacity(0.7) ?? Colors.black.withOpacity(0.7),
                      ),
                    ),
                  ),
              ],
            );

            return _FadeOutMask(
              isDark: isDark,
              child: content,
              maskHeight: 40,
            );

          } else {
            // --- EXPAND MODE (animated: false) ---
            // Tampilkan semua baris
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Agar bullet sejajar
              mainAxisSize: MainAxisSize.min,
              children: contentLines.map((line) => buildBulletRow(line)).toList(),
            );
          }
        },
      );
    }
    // ---- AKHIR MODIFIKASI summaryWidget ----

    if (isExpanded) {
      return Container(
        color: cardColor,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: barHeight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .background
                        .withOpacity(0.88),
                    borderRadius: BorderRadius.circular(barHeight / 2),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor),
                    onPressed: () {
                      SystemChrome.setEnabledSystemUIMode(
                        SystemUiMode.manual,
                        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
                      );
                      Navigator.maybePop(context);
                    },
                    padding: EdgeInsets.zero,
                    iconSize: 28,
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: stickyMinHeight + media.padding.bottom,
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight -
                                    (stickyMinHeight + media.padding.bottom),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    article.category.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: highlightColor,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    article.title,
                                    style: TextStyle(
                                      fontFamily: 'Domine',
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                      height: 1.3,
                                      shadows: [
                                        Shadow(
                                          color: isDark
                                              ? Colors.black38
                                              : Colors.grey.withOpacity(0.12),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                        Shadow(
                                          color: isDark
                                              ? Colors.black54
                                              : Colors.grey.withOpacity(0.15),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    maxLines: null,
                                    overflow: TextOverflow.visible,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    formatTime(article.publishedAt),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: subtitleColor,
                                      shadows: isDark
                                          ? [
                                              const Shadow(
                                                color: Colors.black45,
                                                blurRadius: 8,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  summaryWidget( 
                                    context,
                                    style: TextStyle(
                                      fontSize: 17.5,
                                      height: 1.65,
                                      color: textColor,
                                      shadows: [
                                        Shadow(
                                          color: isDark
                                              ? Colors.black38
                                              : Colors.grey.withOpacity(0.08),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    animated: false,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 20,
                              right: 20,
                              bottom: media.viewInsets.bottom == 0
                                  ? media.padding.bottom + 8
                                  : media.viewInsets.bottom + 8,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 20),
                                ExpandCollapseButton(
                                  isExpanded: isExpanded,
                                  onTap: onExpand,
                                  isDark: isDark,
                                  borderColor: borderColor,
                                  textColor: textColor,
                                  buttonBgColor: cardColor,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        _QuickIconButton(
                                          icon: isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                          onTap: onLikeToggle,
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: 16),
                                        _QuickIconButton(
                                          icon: Icons.share_outlined,
                                          onTap: onShare,
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: 16),
                                        _QuickIconButton(
                                          icon: Icons.refresh,
                                          onTap: onRefreshSummary,
                                          isDark: isDark,
                                          isDisabled: !canRefreshSummary,
                                          tooltipMessage: "Batas refresh harian (3x) tercapai",
                                        ),
                                      ],
                                    ),
                                    if (!hideFullPageButton)
                                      _FullStoryButton(
                                        onPressed: onFullStory,
                                        highlightColor: highlightColor,
                                        textColor: textColor,
                                      ),
                                  ],
                                ),
                                if (media.viewInsets.bottom == 0)
                                  const SizedBox(height: 4),
                              ],
                            ),
                          ),
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

    return Stack(
      fit: StackFit.expand,
      children: [
        if (article.urlToImage != null && article.urlToImage!.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: article.urlToImage!,
                  fit: BoxFit.cover,
                  height: imgHeight,
                  width: media.size.width,
                  placeholder: (c, u) => Container(
                    height: imgHeight,
                    color: isDark ? Colors.grey[900] : Colors.grey[300],
                    child: Center(
                      child: CircularProgressIndicator(color: highlightColor),
                    ),
                  ),
                  errorWidget: (c, u, e) => Container(
                    height: imgHeight,
                    color: isDark ? Colors.grey[900] : Colors.grey[300],
                    child: const Center(
                        child: Icon(Icons.broken_image, size: 60)),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDark
                              ? [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.10),
                                  Colors.black.withOpacity(0.25),
                                  Colors.black.withOpacity(0.42),
                                  Colors.black.withOpacity(0.60),
                                  Colors.black,
                                ]
                              : [
                                  Colors.transparent,
                                  Colors.white.withOpacity(0.11),
                                  Colors.white.withOpacity(0.29),
                                  Colors.white.withOpacity(0.53),
                                  Colors.white.withOpacity(0.70),
                                  Colors.white,
                                ],
                          stops: const [0.00, 0.28, 0.44, 0.68, 0.89, 1.00],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: imgHeight + 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black87,
                        Colors.black,
                      ]
                    : [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.white70,
                        Colors.white,
                      ],
                stops: const [0.0, 0.4, 0.76, 1.0],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: barHeight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .background
                        .withOpacity(0.88),
                    borderRadius: BorderRadius.circular(barHeight / 2),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor),
                    onPressed: () {
                      SystemChrome.setEnabledSystemUIMode(
                        SystemUiMode.manual,
                        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
                      );
                      Navigator.maybePop(context);
                    },
                    padding: EdgeInsets.zero,
                    iconSize: 28,
                  ),
                ),
              ),
              SizedBox(height: imgHeight - barHeight),
              Expanded(
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: -25,
                      child: IgnorePointer(
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isDark
                                  ? [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.18),
                                      Colors.black.withOpacity(0.28),
                                      Colors.black.withOpacity(0.41),
                                    ]
                                  : [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.15),
                                      Colors.white.withOpacity(0.30),
                                      Colors.white.withOpacity(0.53),
                                    ],
                              stops: const [0.0, 0.31, 0.56, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(22),
                          topRight: Radius.circular(22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor.withOpacity(0.15),
                            blurRadius: 36,
                            spreadRadius: 0,
                            offset: const Offset(0, -12),
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: stickyMinHeight + media.padding.bottom,
                                ),
                                child: SingleChildScrollView(
                                  // Perubahan di sini: Mematikan scroll internal saat belum di-expand
                                  physics: const NeverScrollableScrollPhysics(), 
                                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight -
                                          (stickyMinHeight + media.padding.bottom),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          article.category.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: highlightColor,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          article.title,
                                          style: TextStyle(
                                            fontFamily: 'Domine',
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                            height: 1.3,
                                            shadows: [
                                              Shadow(
                                                color: isDark
                                                    ? Colors.black38
                                                    : Colors.grey.withOpacity(0.10),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                              Shadow(
                                                color: isDark
                                                    ? Colors.black54
                                                    : Colors.grey.withOpacity(0.15),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          formatTime(article.publishedAt),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: subtitleColor,
                                            shadows: isDark
                                                ? [
                                                    const Shadow(
                                                      color: Colors.black45,
                                                      blurRadius: 8,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        summaryWidget( 
                                          context,
                                          style: TextStyle(
                                            fontSize: 17.5,
                                            height: 1.65,
                                            color: textColor,
                                            shadows: [
                                              Shadow(
                                                color: isDark
                                                    ? Colors.black38
                                                    : Colors.grey.withOpacity(0.07),
                                                blurRadius: 3,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          animated: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: 20,
                                    right: 20,
                                    bottom: media.viewInsets.bottom == 0
                                        ? media.padding.bottom + 8
                                        : media.viewInsets.bottom + 8,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 20),
                                      ExpandCollapseButton(
                                        isExpanded: isExpanded,
                                        onTap: onExpand,
                                        isDark: isDark,
                                        borderColor: borderColor,
                                        textColor: textColor,
                                        buttonBgColor: cardColor,
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              _QuickIconButton(
                                                icon: isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                                onTap: onLikeToggle,
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: 16),
                                        _QuickIconButton(
                                          icon: Icons.share_outlined,
                                          onTap: onShare,
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: 16),
                                        _QuickIconButton(
                                          icon: Icons.refresh,
                                          onTap: onRefreshSummary,
                                          isDark: isDark,
                                          isDisabled: !canRefreshSummary,
                                          tooltipMessage: "Batas refresh harian (3x) tercapai",
                                        ),
                                      ],
                                    ),
                                    if (!hideFullPageButton)
                                            _FullStoryButton(
                                              onPressed: onFullStory,
                                              highlightColor: highlightColor,
                                              textColor: textColor,
                                            ),
                                        ],
                                      ),
                                      if (media.viewInsets.bottom == 0)
                                        const SizedBox(height: 4),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FadeOutMask extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final double maskHeight;

  const _FadeOutMask({
    Key? key,
    required this.child,
    required this.isDark,
    this.maskHeight = 32,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              height: maskHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          Colors.transparent,
                          Colors.black.withOpacity(0.23),
                          Colors.black.withOpacity(0.34),
                          Colors.black.withOpacity(0.77),
                        ]
                      : [
                          Colors.transparent,
                          Colors.white.withOpacity(0.17),
                          Colors.white.withOpacity(0.22),
                          Colors.white.withOpacity(0.84),
                        ],
                  stops: const [0.01, 0.31, 0.65, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FullStoryButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color highlightColor;
  final Color textColor;

  const _FullStoryButton({
    Key? key,
    required this.onPressed,
    required this.highlightColor,
    required this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: highlightColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Read Full Page",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: highlightColor,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.chevron_right,
            size: 22,
            color: highlightColor,
          ),
        ],
      ),
    );
  }
}

class ExpandCollapseButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;
  final bool isDark;
  final Color borderColor;
  final Color textColor;
  final Color buttonBgColor;

  const ExpandCollapseButton({
    Key? key,
    required this.isExpanded,
    required this.onTap,
    required this.isDark,
    required this.borderColor,
    required this.textColor,
    required this.buttonBgColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color lineColor = isDark
        ? Colors.white.withOpacity(0.3)
        : Colors.black.withOpacity(0.1);
    final IconData icon = isExpanded ? Icons.expand_less : Icons.expand_more;

    const double horizontalButtonPadding = 14;
    const double buttonVerticalPadding = 8;
    const double buttonBorderRadius = 100;

    final BoxDecoration buttonDecoration = BoxDecoration(
      color: buttonBgColor,
      border: Border.all(color: borderColor, width: 1.5),
      borderRadius: BorderRadius.circular(buttonBorderRadius),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  height: 1,
                  color: lineColor,
                ),
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: horizontalButtonPadding,
                    vertical: buttonVerticalPadding),
                decoration: buttonDecoration,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isExpanded ? "COLLAPSE" : "EXPAND",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(icon, size: 18, color: textColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final bool isDisabled;
  final String? tooltipMessage;

  const _QuickIconButton({
    Key? key,
    required this.icon,
    required this.onTap,
    required this.isDark,
    this.isDisabled = false,
    this.tooltipMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color baseBgColor = isDark
        ? Colors.white.withOpacity(0.15)
        : Colors.black.withOpacity(0.07);
    final Color baseBrdColor = isDark
        ? Colors.white.withOpacity(0.3)
        : Colors.black.withOpacity(0.17);
    final Color baseIconColor = isDark ? Colors.white : Colors.black87;

    final Color bgColor = isDisabled ? baseBgColor.withOpacity(0.5) : baseBgColor;
    final Color brdColor = isDisabled ? baseBrdColor.withOpacity(0.5) : baseBrdColor;
    final Color iconColor = isDisabled ? baseIconColor.withOpacity(0.5) : baseIconColor;

    Widget button = InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: brdColor,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
      ),
    );

    if (isDisabled && tooltipMessage != null) {
      return Tooltip(
        message: tooltipMessage!,
        child: button,
      );
    }

    return button;
  }
}