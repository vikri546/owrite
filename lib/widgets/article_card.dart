import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/article.dart';
import '../screens/article_detail_screen.dart';
import '../utils/custom_page_transitions.dart';
import '../utils/auth_service.dart';
import '../screens/login_screen.dart';

enum ArticleCardLayout {
  defaultCard,   // Gambar tengah, judul, deskripsi, kategori, author, bookmark
  layoutfirst,   // Gambar tengah, judul besar center, tanggal, aksi pojok
  layout1,       // Gambar kiri, judul kanan, author/tanggal/bookmark
  layout2,       // Gambar atas, category parallelogram, judul, desc, tanggal
  layout3,       // Gambar square tengah, judul besar, author, tanggal, desc
  layout4,       // Category label atas, judul, desc, tanggal, author, bookmark
  layout5,       // Gambar 16:9, category parallelogram, card hitam bawah
  layoutSlider,  // Untuk carousel slider, gambar kiri, info kanan
  layoutHeadline,// Headline besar (hero), gambar & judul/deskripsi besar
  layoutChoose,  // List icon & judul, untuk menu/subkategori/tag
  layoutFullscreen, // Gambar fullscreen dengan teks overlay di bottom, kategori di top left
}

class ArticleCard extends StatefulWidget {
  final Article article;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final int index;
  final ArticleCardLayout layout;
  final bool showCategoryInLayout2;
  final Function(Article)? onArticleRead;
  final int? titleMaxLines;
  final bool isTodayGrid;
  final bool imageOnLeft;

  const ArticleCard({
    Key? key,
    required this.article,
    required this.isBookmarked,
    required this.onBookmarkToggle,
    required this.index,
    this.layout = ArticleCardLayout.defaultCard,
    this.showCategoryInLayout2 = false,
    this.onArticleRead,
    this.titleMaxLines,
    this.isTodayGrid = false,
    this.imageOnLeft = false,
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

  void _navigateToDetail(String heroTag) async {
    if (widget.onArticleRead != null) {
      widget.onArticleRead!(widget.article);
    }

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

  void _shareArticle() {
    Share.share(
      '${widget.article.title}\n\n${widget.article.url}',
      subject: widget.article.title,
    );
  }

  void _handleBookmarkToggle() {
    // Commented out: Original bookmark functionality with login redirect
    // if (_isGuestUser) {
    //   _showLoginRequiredSnackBar('Login is required to save articles');
    // } else {
    //   widget.onBookmarkToggle();
    // }
    
    // New: Show notification instead of redirecting to login
    _showBookmarkDisabledSnackBar('Tidak bisa menyimpan artikel untuk saat ini');
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

  // Commented out: Original login required snackbar
  // void _showLoginRequiredSnackBar(String message) {
  //   if (!mounted) return;
  //   ScaffoldMessenger.of(context).removeCurrentSnackBar();
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Row(
  //         children: [
  //           Icon(Icons.lock_outline, color: Colors.yellow[700]),
  //           const SizedBox(width: 12),
  //           Expanded(
  //               child: Text(message,
  //                   style: const TextStyle(color: Colors.white))),
  //         ],
  //       ),
  //       backgroundColor: const Color(0xFF333333),
  //       behavior: SnackBarBehavior.floating,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //       action: SnackBarAction(
  //         label: 'LOGIN',
  //         textColor: Colors.yellow[700],
  //         onPressed: () {
  //           Navigator.of(context).push(
  //               MaterialPageRoute(builder: (context) => const LoginScreen()));
  //         },
  //       ),
  //     ),
  //   );
  // }

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
          enabled: false, 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              InkWell(
                onTap: () {
                  Navigator.pop(context); 
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('|', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              InkWell(
                onTap: () {
                  Navigator.pop(context); 
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

  @override
  Widget build(BuildContext context) {
    final heroTag = 'article-image-${widget.article.id}-${widget.index}';
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
    
    if (widget.layout == ArticleCardLayout.layout5 || widget.layout == ArticleCardLayout.layoutSlider || widget.layout == ArticleCardLayout.layoutFullscreen) {
      padding = EdgeInsets.zero;
    }
    if (widget.layout == ArticleCardLayout.layoutHeadline || widget.layout == ArticleCardLayout.layoutChoose) {
      padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);
    }
    
    return Padding(
      padding: padding,
      child: switch (widget.layout) {
        ArticleCardLayout.layoutfirst => _buildLayoutFirst(context, heroTag, isDark),
        ArticleCardLayout.layout1 => _buildLayout1(context, heroTag, isDark),
        ArticleCardLayout.layout2 =>
            _buildLayout2(context, heroTag, isDark, showCategory: widget.showCategoryInLayout2),
        ArticleCardLayout.layout3 => _buildLayout3(context, heroTag, isDark),
        ArticleCardLayout.layout4 => _buildLayout4(context, heroTag, isDark),
        ArticleCardLayout.layout5 => _buildLayout5(context, heroTag, isDark),
        ArticleCardLayout.layoutSlider => _buildLayoutSlider(context, heroTag, isDark),
        ArticleCardLayout.layoutHeadline => _buildLayoutHeadline(context, heroTag, isDark),
        ArticleCardLayout.layoutChoose => _buildLayoutChoose(context, heroTag, isDark),
        ArticleCardLayout.layoutFullscreen => _buildLayoutFullscreen(context, heroTag, isDark),
        ArticleCardLayout.defaultCard || _ =>
            _buildDefaultLayout(context, heroTag, isDark)
      },
    );
  }

  // --- Helpers UI ---
  Widget _buildRectangularCategory(bool isDark) {
    final String category = widget.article.category.toUpperCase();
    const double fixedWidth = 100.0;
    const double fixedHeight = 22.0;

    return Container(
      width: fixedWidth,
      height: fixedHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _stabiloGreen,
        borderRadius: BorderRadius.circular(0),
      ),
      child: Text(
        category,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _buildParallelogramCategory() {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, top: 6.0),
      child: Transform(
        transform: Matrix4.skewX(-0.3),
        child: Container(
          color: _stabiloGreen,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: Transform(
            transform: Matrix4.skewX(0.3),
            child: Text(widget.article.category.toUpperCase(), style: const TextStyle(color: Colors.black, fontSize: 8.5, fontWeight: FontWeight.bold, fontFamily: 'Inter', letterSpacing: 0.5)),
          ),
        ),
      ),
    );
  }

  // --- Layout Implementations ---

  Widget _buildLayoutFirst(BuildContext context, String heroTag, bool isDark) {
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
                Positioned(
                  right: -15,
                  top: -8,
                  child: Transform.scale(
                    scale: 0.75, 
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

  Widget _buildLayout1(BuildContext context, String heroTag, bool isDark) {
    final String authorName = (widget.article.author != null && widget.article.author!.isNotEmpty)
        ? widget.article.author!.replaceAll(RegExp(r' ?/ ?'), ' / ')
        : 'Unknown';
    final Color textColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final Color iconColor = isDark ? Colors.white70 : Colors.black54;

    final imageWidget = Expanded(
      flex: 1,
      child: AspectRatio(
        aspectRatio: 1 / 1,
        child: _buildImage(heroTag, isDark, fit: BoxFit.cover),
      ),
    );

    final textWidget = Expanded(
      flex: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRectangularCategory(isDark),
          const SizedBox(height: 10),
          _buildTitle(
            isDark,
            maxLines: widget.titleMaxLines, 
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              Row(
                children: [
                  Flexible(
                    flex: 2,
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: textColor),
                        children: [
                          const TextSpan(
                              text: 'By ',
                              style: TextStyle(fontWeight: FontWeight.normal)),
                          TextSpan(
                              text: authorName,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  // UPDATED DIVIDER TO MATCH LAYOUT 3
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    width: 32, // Changed from 24 to 32
                    height: 1,
                    color: isDark ? Colors.grey[600] : Colors.grey[400], // Updated Color to match Layout 3
                  ),
                  Flexible(
                    flex: 2,
                    child: _buildTimeText(isDark, fontSize: 10),
                  ),
                  const SizedBox(width: 32),
                ],
              ),
              Positioned(
                right: 0,
                top: -2,
                child: InkWell(
                  onTap: _handleBookmarkToggle,
                  child: Icon(
                    widget.isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: widget.isBookmarked
                        ? _stabiloGreen
                        : iconColor,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.imageOnLeft 
              ? [imageWidget, const SizedBox(width: 12), textWidget]
              : [textWidget, const SizedBox(width: 12), imageWidget],
        ),
        const SizedBox(height: 16),
        Divider(
            height: 1, color: isDark ? Colors.grey[700] : Colors.grey[300]),
      ],
    );
  }

  Widget _buildLayout2(BuildContext context, String heroTag, bool isDark, {bool showCategory = false}) {
    return Column(children: [IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: ClipRRect(borderRadius: BorderRadius.circular(5.0), child: AspectRatio(aspectRatio: 16 / 9, child: _buildImage(heroTag, isDark, fit: BoxFit.cover)))), const SizedBox(width: 12), Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [if (showCategory) Padding(padding: const EdgeInsets.only(bottom: 6.0), child: _buildCategoryChip(context, isDark)), _buildTitle(isDark, maxLines: null, fontSize: 16, fontWeight: FontWeight.w700), const SizedBox(height: 6), _buildTimeText(isDark, fontSize: 10)])), Column(mainAxisAlignment: MainAxisAlignment.start, children: [Transform.translate(offset: const Offset(15, -9), child: Transform.scale(scale: 0.75, child: _buildMenuButton(context)))])])), const SizedBox(height: 16), Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[300])]);
  }

  Widget _buildLayout3(BuildContext context, String heroTag, bool isDark) {
    final String authorName = (widget.article.author != null && widget.article.author!.isNotEmpty) ? widget.article.author!.replaceAll(RegExp(r' ?/ ?'), ' / ') : 'Unknown';
    final Color titleColor = isDark ? Colors.white : Colors.black;
    final Color textColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
    
    // REFERENCE LAYOUT FOR DIVIDER STYLE
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 12), Center(child: ClipRRect(borderRadius: BorderRadius.circular(10.0), child: AspectRatio(aspectRatio: 1.0, child: _buildImage(heroTag, isDark, fit: BoxFit.cover)))), const SizedBox(height: 16), Text(widget.article.title?.trim() ?? 'Untitled', textAlign: TextAlign.start, style: TextStyle(fontFamily: 'Anton', fontSize: 44.0, fontWeight: FontWeight.normal, color: titleColor, height: 1.2)), const SizedBox(height: 12), Row(children: [Text.rich(TextSpan(style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: textColor), children: [const TextSpan(text: 'By ', style: TextStyle(fontWeight: FontWeight.normal)), TextSpan(text: authorName, style: const TextStyle(fontWeight: FontWeight.bold))])), 
    // THIS IS THE REFERENCE DIVIDER
    Container(margin: const EdgeInsets.symmetric(horizontal: 8.0), height: 1, width: 32, color: isDark ? Colors.grey[600] : Colors.grey[400]), 
    
    Text(_formatDate(widget.article.publishedAt), style: TextStyle(fontFamily: 'Inter', fontSize: 12.0, color: textColor, fontWeight: FontWeight.w500))]), const SizedBox(height: 12), Text(widget.article.description?.trim() ?? '', style: TextStyle(fontFamily: 'Inter', fontSize: 14.0, color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis), const SizedBox(height: 16), Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[300])]);
  }

  Widget _buildLayout4(BuildContext context, String heroTag, bool isDark) {
    // UPDATED LAYOUT 4 to include Date in the same row with the same divider as Layout 3
    final String authorName = (widget.article.author != null && widget.article.author!.isNotEmpty)
        ? widget.article.author!.replaceAll(RegExp(r' ?/ ?'), ' / ')
        : 'Unknown';
    final Color textColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final Color iconColor = isDark ? Colors.white70 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRectangularCategory(isDark),
        const SizedBox(height: 8),
        _buildTitle(isDark, maxLines: 2, fontSize: 20, fontWeight: FontWeight.w700),
        const SizedBox(height: 8),
        _buildDescription(isDark, maxLines: 3, fontSize: 14),
        const SizedBox(height: 12),
        // Previous Date Text removed, now combined below
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: textColor),
                        children: [
                          const TextSpan(
                              text: 'By ',
                              style: TextStyle(fontWeight: FontWeight.normal)),
                          TextSpan(
                              text: authorName,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  // ADDED DIVIDER MATCHING LAYOUT 3
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    height: 1,
                    width: 32,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  Text(_formatDate(widget.article.publishedAt),
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.0,
                          color: textColor,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            InkWell(
              onTap: _handleBookmarkToggle,
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4, bottom: 4),
                child: Icon(
                  widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: widget.isBookmarked ? _stabiloGreen : iconColor,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[300])
      ],
    );
  }

  Widget _buildLayout5(BuildContext context, String heroTag, bool isDark) {
    final String authorName = (widget.article.author != null && widget.article.author!.isNotEmpty) ? widget.article.author!.replaceAll(RegExp(r' ?/ ?'), ' / ') : 'Unknown';
    const Color shapeColor = Colors.black;
    const Color titleColor = Colors.white;
    final Color textColor = Colors.grey[400]!;
    final Color iconColor = Colors.white70;
    const double sidePadding = 16.0;

    return LayoutBuilder(builder: (context, constraints) {
      final double cardWidth = constraints.maxWidth;
      final double imageHeight = cardWidth * (9 / 16);
      return Stack(clipBehavior: Clip.none, children: [Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Padding(padding: const EdgeInsets.symmetric(horizontal: sidePadding), child: SizedBox(height: imageHeight, child: _buildImage(heroTag, isDark, fit: BoxFit.cover))), Padding(padding: const EdgeInsets.symmetric(horizontal: sidePadding), child: Container(color: shapeColor, width: double.infinity, padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.article.title?.trim() ?? 'Untitled', style: const TextStyle(fontFamily: 'CrimsonPro', fontSize: 20, fontWeight: FontWeight.bold, color: titleColor, height: 1.2), maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.left), const SizedBox(height: 12), Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: RichText(maxLines: 1, overflow: TextOverflow.ellipsis, text: TextSpan(style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: textColor), children: [const TextSpan(text: 'By ', style: TextStyle(fontWeight: FontWeight.normal)), TextSpan(text: authorName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), 
      // UPDATED DIVIDER TO MATCH LAYOUT 3 WIDTH
      WidgetSpan(alignment: PlaceholderAlignment.middle, child: Container(margin: const EdgeInsets.symmetric(horizontal: 8.0), height: 1, width: 32, color: Colors.grey[600])), 
      
      TextSpan(text: _formatDate(widget.article.publishedAt), style: TextStyle(color: textColor, fontWeight: FontWeight.w500))]))), Padding(padding: const EdgeInsets.only(left: 8.0), child: InkWell(onTap: _handleBookmarkToggle, child: Icon(widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: widget.isBookmarked ? _stabiloGreen : iconColor, size: 22)))] )])))]), Positioned(top: imageHeight - 14, left: sidePadding, child: _buildParallelogramCategory())]);
    });
  }

  Widget _buildLayoutSlider(BuildContext context, String heroTag, bool isDark) {
    final String authorName = (widget.article.author != null && widget.article.author!.isNotEmpty)
        ? widget.article.author!.replaceAll(RegExp(r' ?/ ?'), ' / ')
        : 'Unknown Author';
    final Color iconColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      height: 140,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildImage(heroTag, isDark, useHero: false, fit: BoxFit.cover),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    color: _stabiloGreen,
                    alignment: Alignment.center,
                    child: Text(
                      widget.article.category.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.article.title?.trim() ?? 'Untitled',
                    style: TextStyle(
                      fontFamily: 'CrimsonPro',
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.2,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.0,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              children: [
                                const TextSpan(
                                  text: 'By ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                TextSpan(
                                  text: authorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _handleBookmarkToggle,
                          child: Icon(
                            widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: widget.isBookmarked ? _stabiloGreen : iconColor,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorAndBookmarkRowWithoutCategory(bool isDark) {
    // This helper is technically no longer used by Layout4 in its new form, but kept for safety if used elsewhere
    final String authorName = (widget.article.author != null && widget.article.author!.isNotEmpty) ? widget.article.author!.replaceAll(RegExp(r' ?/ ?'), ' / ') : 'Unknown';
    final Color textColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final Color iconColor = isDark ? Colors.white70 : Colors.black54;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: RichText(maxLines: 1, overflow: TextOverflow.ellipsis, text: TextSpan(style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: textColor), children: [const TextSpan(text: 'By ', style: TextStyle(fontWeight: FontWeight.normal)), TextSpan(text: authorName, style: const TextStyle(fontWeight: FontWeight.bold))]))), InkWell(onTap: _handleBookmarkToggle, child: Padding(padding: const EdgeInsets.only(left: 8.0, top: 4, bottom: 4), child: Icon(widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: widget.isBookmarked ? _stabiloGreen : iconColor, size: 20)))]);
  }

  Widget _buildLayoutHeadline(BuildContext context, String heroTag, bool isDark) {
    final String authorName = (widget.article.author != null && widget.article.author!.isNotEmpty)
        ? widget.article.author!.replaceAll(RegExp(r' ?/ ?'), ' / ')
        : 'Unknown Author';
    final Color iconColor = isDark ? Colors.white70 : Colors.black54;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0, top: 4.0),
                child: Icon(
                  Icons.arrow_forward,
                  size: 20,
                  color: isDark ? _stabiloGreen : Colors.black87,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(isDark, maxLines: 3, fontSize: 18, fontWeight: FontWeight.bold),
                    const SizedBox(height: 0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              children: [
                                const TextSpan(
                                    text: 'By ',
                                    style: TextStyle(fontWeight: FontWeight.normal)),
                                TextSpan(
                                    text: authorName,
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: IconButton(
                            onPressed: _handleBookmarkToggle,
                            icon: Icon(
                              widget.isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: widget.isBookmarked ? _stabiloGreen : iconColor,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 0),
        Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[300]),
      ],
    );
  }

  Widget _buildLayoutChoose(BuildContext context, String heroTag, bool isDark) {
    final String authorName = (widget.article.author != null && widget.article.author!.isNotEmpty) ? widget.article.author!.replaceAll(RegExp(r' ?/ ?'), ' / ') : 'Unknown Author';
    final Color iconColor = isDark ? Colors.white70 : Colors.black54;
    return Column(children: [Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(right: 12.0, top: 4.0), child: Icon(Icons.arrow_forward, size: 20, color: isDark ? _stabiloGreen : Colors.black87)), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildTitle(isDark, maxLines: 3, fontSize: 18, fontWeight: FontWeight.bold), const SizedBox(height: 0), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: RichText(maxLines: 1, overflow: TextOverflow.ellipsis, text: TextSpan(style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[600]), children: [const TextSpan(text: 'By ', style: TextStyle(fontWeight: FontWeight.normal)), TextSpan(text: authorName, style: const TextStyle(fontWeight: FontWeight.bold))]))), Padding(padding: const EdgeInsets.only(left: 8.0), child: IconButton(onPressed: _handleBookmarkToggle, icon: Icon(widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: widget.isBookmarked ? Colors.orangeAccent : iconColor, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(), splashRadius: 18))])]))])), const SizedBox(height: 0), Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[300])]);
  }

  Widget _buildLayoutFullscreen(BuildContext context, String heroTag, bool isDark) {
    final String authorName = (widget.article.author != null && widget.article.author!.isNotEmpty)
        ? widget.article.author!.replaceAll(RegExp(r' ?/ ?'), ' / ')
        : 'Unknown';

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double imageHeight = screenWidth * 0.9; // Lebih lebar ke bawah dari 16:9, mendekati 1:0.7

        return Stack(
          children: [
            // Fullscreen image
            SizedBox(
              width: double.infinity,
              height: imageHeight,
              child: _buildImage(heroTag, isDark, useHero: false, fit: BoxFit.cover),
            ),
            // Category label at top left
            Positioned(
              top: 16,
              left: 16,
              child: _buildRectangularCategory(isDark),
            ),
            // Text overlay at bottom with shadow
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with shadow
                    Text(
                      widget.article.title?.trim() ?? 'Untitled',
                      style: TextStyle(
                        fontFamily: 'CrimsonPro',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.3,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 2),
                            blurRadius: 8,
                            color: Colors.black.withOpacity(0.8),
                          ),
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 4,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Description with shadow
                    if (widget.article.description != null && widget.article.description!.isNotEmpty)
                      Text(
                        widget.article.description!.trim(),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1),
                              blurRadius: 4,
                              color: Colors.black.withOpacity(0.7),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 12),
                    // Author and date with shadow
                    Row(
                      children: [
                        Flexible(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.9),
                                shadows: [
                                  Shadow(
                                    offset: const Offset(0, 1),
                                    blurRadius: 3,
                                    color: Colors.black.withOpacity(0.7),
                                  ),
                                ],
                              ),
                              children: [
                                const TextSpan(
                                  text: 'By ',
                                  style: TextStyle(fontWeight: FontWeight.normal),
                                ),
                                TextSpan(
                                  text: authorName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8.0),
                          height: 1,
                          width: 32,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        Text(
                          _formatDate(widget.article.publishedAt),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8), // <- Constant SizedBox di bagian paling bawah
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDefaultLayout(BuildContext context, String heroTag, bool isDark) {
    final String authorName = (widget.article.author != null && widget.article.author!.isNotEmpty)
        ? widget.article.author!.replaceAll(RegExp(r' ?/ ?'), ' / ')
        : 'Unknown';
    final Color iconColor = isDark ? Colors.white70 : Colors.black54;

    // Gaya teks meta lebih kecil jika di TODAY grid
    final double metaFontSize = widget.isTodayGrid ? 10.0 : 12.0;
    final FontWeight metaFontWeight = widget.isTodayGrid ? FontWeight.normal : FontWeight.w500;
    final Color metaColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    // Untuk mengatasi overflow pada grid TODAY, gunakan widget Flexible/Shrink/OverflowBox sesuai kasus
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Penting: agar fit konten
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildImage(heroTag, isDark, useHero: false, fit: BoxFit.cover),
                ),
                Positioned(
                  bottom: -1,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: const BoxDecoration(color: _stabiloGreen),
                    child: Text(
                      widget.article.category.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8), // Dulu 12, dikurangi agar lebih fit saat grid
            _buildTitle(
              isDark,
              maxLines: widget.isTodayGrid ? 2 : null,
              fontSize: widget.isTodayGrid ? 16 : 20,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.start,
            ),
            if (!widget.isTodayGrid) ...[
              const SizedBox(height: 8),
              _buildDescription(isDark, maxLines: 4),
            ],
            if (!widget.isTodayGrid) const SizedBox(height: 12),
            if (widget.isTodayGrid) const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  fit: FlexFit.tight,
                  child: Row(
                    children: [
                      Flexible(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: metaFontSize,
                              color: metaColor,
                            ),
                            children: [
                              const TextSpan(
                                text: 'By ',
                                style: TextStyle(fontWeight: FontWeight.normal),
                              ),
                              TextSpan(
                                text: authorName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8.0),
                        height: 1,
                        width: 28, // sedikit lebih kecil dari 32 agar lebih fit
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      Flexible(
                        child: Text(
                          _formatDate(widget.article.publishedAt),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: metaFontSize,
                            color: metaColor,
                            fontWeight: metaFontWeight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Sembunyikan bookmark jika hanya di grid TODAY
                if (!widget.isTodayGrid)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: InkWell(
                      onTap: _handleBookmarkToggle,
                      child: Icon(
                        widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: widget.isBookmarked ? _stabiloGreen : iconColor,
                        size: 22,
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.isTodayGrid) const SizedBox(height: 10),
            if (!widget.isTodayGrid) const SizedBox(height: 16),
            Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[300]),
          ],
        );
      },
    );
  }

  Widget _buildImage(String heroTag, bool isDark, {bool useHero = true, BoxFit fit = BoxFit.cover}) {
    Widget imageWidget = widget.article.urlToImage != null ? CachedNetworkImage(imageUrl: widget.article.urlToImage!, fit: fit, placeholder: (context, url) => Container(color: isDark ? Colors.grey[800] : Colors.grey[300], child: const Center(child: CircularProgressIndicator())), errorWidget: (context, url, error) => Container(color: isDark ? Colors.grey[800] : Colors.grey[300], child: Icon(Icons.image_not_supported, color: isDark ? Colors.grey[600] : Colors.grey[400], size: 40))) : Container(color: isDark ? Colors.grey[800] : Colors.grey[300], child: Icon(Icons.image_not_supported, color: isDark ? Colors.grey[600] : Colors.grey[400], size: 40));
    if (useHero) return Hero(tag: heroTag, child: imageWidget);
    return imageWidget;
  }

  Widget _buildCategoryChip(BuildContext context, bool isDark) => Text(widget.article.category.toUpperCase(), style: TextStyle(fontFamily: 'Inter', color: _stabiloGreen, fontSize: 10, fontWeight: FontWeight.w700));

  Widget _buildTimeText(bool isDark, {double fontSize = 10.0}) => Text(_formatDate(widget.article.publishedAt), style: TextStyle(fontFamily: 'Inter', fontSize: fontSize, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500));

  Widget _buildTitle(bool isDark, {int? maxLines = 3, double fontSize = 20.0, FontWeight fontWeight = FontWeight.w800, TextAlign? textAlign}) {
    final title = widget.article.title?.trim();
    return Text(title?.isNotEmpty == true ? title! : 'Untitled', style: TextStyle(fontFamily: 'CrimsonPro', fontSize: fontSize, fontWeight: fontWeight, color: isDark ? Colors.white : Colors.black, height: 1.3, letterSpacing: 0.2), maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible, textAlign: textAlign);
  }

  Widget _buildDescription(bool isDark, {int? maxLines = 3, double fontSize = 14.0, Color? color}) {
    final desc = widget.article.description?.trim();
    return Text(desc?.isNotEmpty == true ? desc! : 'No description available.', style: TextStyle(fontFamily: 'Inter', fontSize: fontSize, color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.4), maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes < 1) return 'Baru saja';
        return '${difference.inMinutes} menit lalu';
      }
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      return DateFormat('d MMM yyyy', 'id_ID').format(date);
    }
  }
}