import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart'; // Import intl untuk format waktu H:M:S
import '../models/article.dart';
import '../screens/article_detail_screen.dart';
import '../utils/custom_page_transitions.dart';
import '../utils/auth_service.dart';
import '../screens/login_screen.dart';
// Hapus import theme_provider jika tidak digunakan di file ini
// import '../providers/theme_provider.dart';

enum ArticleCardLayout {
  defaultCard,
  layout1,
  layout2,
  layout3,
  layout4, // 1. Layout baru (Judul, Deskripsi, Waktu)
  layout5, // 2. Layout baru (Grid 2 kolom)
}

class FeaturedArticleCard extends StatefulWidget {
  final Article article;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final int index;

  const FeaturedArticleCard({
    Key? key,
    required this.article,
    required this.isBookmarked,
    required this.onBookmarkToggle,
    required this.index,
  }) : super(key: key);

  @override
  State<FeaturedArticleCard> createState() => _FeaturedArticleCardState();
}

class _FeaturedArticleCardState extends State<FeaturedArticleCard> {
  @override
  Widget build(BuildContext context) {
    final heroTag = 'featured-article-image-${widget.article.id}';
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          HeroDialogRoute(
            builder: (context) => ArticleDetailScreen(
              article: widget.article,
              isBookmarked: widget.isBookmarked,
              onBookmarkToggle: widget.onBookmarkToggle,
              heroTag: heroTag,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: heroTag,
              child: CachedNetworkImage(
                imageUrl: widget.article.urlToImage ?? '',
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: Colors.grey.shade300),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade300,
                  child:
                      const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.8)
                  ],
                  stops: const [0.5, 0.7, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.yellow,
                    ),
                    child: Text(
                      widget.article.category,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                              color: Colors.white.withOpacity(0.7),
                              blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.article.title,
                    style: const TextStyle(
                      fontFamily: 'CrimsonPro',
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 18,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 5,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArticleCard extends StatefulWidget {
  final Article article;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final int index;
  final ArticleCardLayout layout;

  /// NEW: showCategoryInLayout2 memungkinkan show/hide kategori khusus di layout2
  final bool showCategoryInLayout2;

  const ArticleCard({
    Key? key,
    required this.article,
    required this.isBookmarked,
    required this.onBookmarkToggle,
    required this.index,
    this.layout = ArticleCardLayout.defaultCard,
    this.showCategoryInLayout2 = false, // Default: tidak tampilkan kategori
  }) : super(key: key);

  @override
  State<ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<ArticleCard> {
  final AuthService _authService = AuthService();
  bool _isGuestUser = false;

  static const Color _stabiloGreen = Color(0xFFE5FF10);

  @override
  void initState() {
    super.initState();
    _checkGuestStatus();
  }

  Future<void> _checkGuestStatus() async {
    final user = await _authService.getCurrentUser();
    if (user == null || user['username'] == 'Guest') {
      if (mounted) {
        setState(() {
          _isGuestUser = true;
        });
      }
    }
  }

  void _showLoginRequiredSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.yellow[700]),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'LOGIN',
          textColor: Colors.yellow[700],
          onPressed: () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LoginScreen()));
          },
        ),
      ),
    );
  }

  void _navigateToDetail(String heroTag) async {
    await Navigator.of(context).push(
      HeroDialogRoute(
        builder: (context) => ArticleDetailScreen(
          article: widget.article,
          isBookmarked: widget.isBookmarked,
          onBookmarkToggle: widget.onBookmarkToggle,
          heroTag: heroTag,
        ),
      ),
    );
  }

  // --- Fungsi untuk Tombol Menu 3-Titik ---
  void _shareArticle() {
    Share.share(
      '${widget.article.title}\n\n${widget.article.url}',
      subject: widget.article.title,
    );
  }

  void _handleBookmarkToggle() {
    if (_isGuestUser) {
      _showLoginRequiredSnackBar('Login is required to save articles');
    } else {
      widget.onBookmarkToggle();
    }
  }

  Widget _buildMenuButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color iconColor = isDark ? Colors.white70 : Colors.black54;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: iconColor),
      onSelected: (value) {
        if (value == 'bookmark') {
          _handleBookmarkToggle();
        } else if (value == 'share') {
          _shareArticle();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false, // supaya tidak trigger default onSelected
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Bookmark
              InkWell(
                onTap: () {
                  Navigator.pop(context); // tutup popup
                  _handleBookmarkToggle();
                },
                child: Row(
                  children: [
                    Icon(
                      widget.isBookmarked
                          ? Icons.bookmark_added
                          : Icons.bookmark_add_outlined,
                      color: widget.isBookmarked ? _stabiloGreen : iconColor,
                    ),
                    const SizedBox(width: 4),
                    Text(widget.isBookmarked ? 'Remove' : 'Bookmark'),
                  ],
                ),
              ),

              // Pembatas |
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('|', style: TextStyle(fontWeight: FontWeight.bold)),
              ),

              // Share
              InkWell(
                onTap: () {
                  Navigator.pop(context); // tutup popup
                  _shareArticle();
                },
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, color: iconColor),
                    const SizedBox(width: 4),
                    const Text('Share'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  // --- Akhir Fungsi Tombol Menu ---

  @override
  Widget build(BuildContext context) {
    final heroTag = 'article-image-${widget.article.id}-${widget.index}';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Hapus animasi tekan lama dengan AnimatedBuilder dan GestureDetector
    return GestureDetector(
      onTap: () => _navigateToDetail(heroTag),
      child: Container(
        child: _buildCardLayout(context, heroTag, isDark),
      ),
    );
  }

  Widget _buildCardLayout(BuildContext context, String heroTag, bool isDark) {
    EdgeInsetsGeometry padding =
        const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0);
    if (widget.layout == ArticleCardLayout.layout3) {
      padding = const EdgeInsets.only(bottom: 16.0);
    }
    if (widget.layout == ArticleCardLayout.layout5) {
      padding = EdgeInsets.zero;
    }

    return Padding(
      padding: padding,
      child: switch (widget.layout) {
        ArticleCardLayout.layout1 => _buildLayout1(context, heroTag, isDark),
        ArticleCardLayout.layout2 =>
            _buildLayout2(context, heroTag, isDark, showCategory: widget.showCategoryInLayout2),
        ArticleCardLayout.layout3 => _buildLayout3(context, heroTag, isDark),
        ArticleCardLayout.layout4 => _buildLayout4(context, heroTag, isDark),
        ArticleCardLayout.layout5 => _buildLayout5(context, heroTag, isDark),
        ArticleCardLayout.defaultCard || _ =>
            _buildDefaultLayout(context, heroTag, isDark)
      },
    );
  }

  // 3. Perbaikan Layout1
  Widget _buildLayout1(BuildContext context, String heroTag, bool isDark) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: _buildImage(heroTag, isDark, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitle(
                    isDark,
                    maxLines: null,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 6),
                  _buildTimeText(isDark, fontSize: 10),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[300]),
      ],
    );
  }

  // 4. Perbaikan Layout2 DENGAN OPSI showCategory
  Widget _buildLayout2(BuildContext context, String heroTag, bool isDark, {bool showCategory = false}) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5.0),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _buildImage(heroTag, isDark, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showCategory)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: _buildCategoryChip(context, isDark),
                      ),
                    _buildTitle(
                      isDark,
                      maxLines: null,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 6),
                    _buildTimeText(isDark, fontSize: 10),
                  ],
                ),
              ),
              // Menu button digeser ke atas, ke kanan, dan diperkecil
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(15, -9),
                    child: Transform.scale(
                      scale: 0.75,
                      child: _buildMenuButton(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[300]),
      ],
    );
  }

  // Layout 3: Responsive, aspect ratio 3/4, gradient & text responsive
  Widget _buildLayout3(BuildContext context, String heroTag, bool isDark) {
    final Color textBgColor = isDark ? const Color(0xFF222222) : const Color(0xFF000000);
    final Color titleColor = Colors.white;
    final Color descriptionColor = Colors.grey[300]!;
    final Color timeColor = Colors.grey[400]!;

    // Get screen height for responsive sizing; fallback for test
    final screenHeight = MediaQuery.of(context).size.height;
    // Use 45% of screen height, but limit between min and max heights for better usability
    final double cardHeight = (screenHeight * 0.45).clamp(220.0, 420.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: cardHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              _buildImage(heroTag, isDark, fit: BoxFit.cover),
              // Gradient overlay from bottom up, covers whole card
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      textBgColor.withOpacity(0.92),
                      textBgColor.withOpacity(0.85),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
              ),
              // Text (keeps inside overlay area at the bottom)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        widget.article.title?.trim() ?? 'Untitled',
                        style: TextStyle(
                          fontFamily: 'Arimo',
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                          height: 1.3,
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: const Offset(0, 1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Text(
                        widget.article.description?.trim() ?? 'No description available.',
                        style: TextStyle(
                          fontFamily: 'SourceSerif4',
                          fontSize: 14.0,
                          color: descriptionColor,
                          height: 1.4,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.25),
                              offset: const Offset(0, 1),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Publication time
                    Text(
                      _formatDate(widget.article.publishedAt),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.0,
                        color: timeColor,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.4),
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  // 1. Layout Baru (Layout 4)
  Widget _buildLayout4(BuildContext context, String heroTag, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(
          isDark,
          maxLines: 2,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 8),
        _buildDescription(
          isDark,
          maxLines: 3,
          fontSize: 14,
        ),
        const SizedBox(height: 12),
        Text(
          _formatDate(widget.article.publishedAt),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[300]),
      ],
    );
  }

  // 2. Layout Baru (Layout 5)
  Widget _buildLayout5(BuildContext context, String heroTag, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: _buildImage(heroTag, isDark, fit: BoxFit.cover),
        ),
        const SizedBox(height: 8),
        _buildTitle(
          isDark,
          maxLines: 3,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 10),
        _buildTimeText(isDark, fontSize: 10),
      ],
    );
  }

  // 5. Perbaikan DefaultLayout
  Widget _buildDefaultLayout(BuildContext context, String heroTag, bool isDark) {
    return Column(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Hero(
              tag: heroTag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5.0),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildImage(heroTag, isDark,
                      useHero: false, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: _buildTitle(
                      isDark,
                      maxLines: null,
                      fontSize: 20,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // Geser lebih ke atas dan ke kanan, tanpa padding/spacing eksternal
                Positioned(
                  right: -15,
                  top: -8,
                  child: Transform.scale(
                    scale: 0.75, // Lebih kecil lagi
                    child: _buildMenuButton(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _buildTimeText(isDark, fontSize: 10),
          ],
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[300]),
      ],
    );
  }

  Widget _buildImage(String heroTag, bool isDark,
      {bool useHero = true, BoxFit fit = BoxFit.cover}) {
    Widget imageWidget = widget.article.urlToImage != null
        ? CachedNetworkImage(
            imageUrl: widget.article.urlToImage!,
            fit: fit,
            placeholder: (context, url) => Container(
              color: isDark ? Colors.grey[800] : Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: isDark ? Colors.grey[800] : Colors.grey[300],
              child: Icon(
                Icons.image_not_supported,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                size: 40,
              ),
            ),
          )
        : Container(
            color: isDark ? Colors.grey[800] : Colors.grey[300],
            child: Icon(
              Icons.image_not_supported,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              size: 40,
            ),
          );

    if (useHero) {
      return Hero(
        tag: heroTag,
        child: imageWidget,
      );
    }
    return imageWidget;
  }

  Widget _buildCategoryChip(BuildContext context, bool isDark) {
    return Text(
      widget.article.category.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Inter',
        color: _stabiloGreen,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildTimeText(bool isDark, {double fontSize = 10.0}) {
    return Text(
      _formatDate(widget.article.publishedAt),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: fontSize,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTitle(
    bool isDark, {
    int? maxLines = 3,
    double fontSize = 20.0,
    FontWeight fontWeight = FontWeight.w800,
    TextAlign? textAlign,
  }) {
    final title = widget.article.title?.trim();
    return Text(
      title?.isNotEmpty == true ? title! : 'Untitled',
      style: TextStyle(
        fontFamily: 'Arimo',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: isDark ? Colors.white : Colors.black,
        height: 1.3,
        letterSpacing: 0.2,
      ),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
      textAlign: textAlign,
    );
  }

  Widget _buildDescription(
    bool isDark, {
    int? maxLines = 3,
    double fontSize = 14.0,
    Color? color,
  }) {
    final desc = widget.article.description?.trim();
    return Text(
      desc?.isNotEmpty == true ? desc! : 'No description available.',
      style: TextStyle(
        fontFamily: 'SourceSerif4',
        fontSize: fontSize,
        color: isDark ? Colors.grey[400] : Colors.grey[700],
        height: 1.4,
      ),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes < 1) return 'NEW';
        return '${difference.inMinutes} MIN';
      }
      return '${difference.inHours} HOUR';
    } else if (difference.inDays == 1) {
      return 'YESTERDAY';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} DAY';
    } else {
      // Gunakan intl untuk format yang lebih baik
      return DateFormat('d MMM yyyy').format(date);
    }
  }

  // 1. Fungsi baru untuk format H:M:S
  String _formatTime(DateTime date) {
    // Menggunakan package intl untuk format jam:menit:detik
    return DateFormat('HH:mm:ss').format(date.toLocal());
  }
}