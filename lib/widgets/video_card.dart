import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk Clipboard
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/video.dart';
// Import watch_screen untuk akses WishlistManager jika perlu hapus direct
import '../screens/watch_screen.dart'; 

enum VideoCardLayout { full, horizontal, shorts }

class VideoCard extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;
  final VideoCardLayout layout;
  // Callback opsional untuk tombol simpan
  final VoidCallback? onAddToWishlist;
  final bool isWishlistMode;

  const VideoCard({
    Key? key,
    required this.video,
    required this.onTap,
    this.layout = VideoCardLayout.full,
    this.onAddToWishlist,
    this.isWishlistMode = false,
  }) : super(key: key);

  void _shareVideo(BuildContext context) {
    // Copy link ke clipboard
    final url = 'https://www.youtube.com/watch?v=${video.id}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link YouTube disalin!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFFE5FF10);
    final subtleBorderColor = isDark ? Colors.white10 : Colors.black12;
    final cardColor = isDark ? const Color(0xFF111111) : Colors.white;

    switch (layout) {
      case VideoCardLayout.shorts:
        // --- LAYOUT SHORTS (TIDAK BERUBAH) ---
        return GestureDetector(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: isDark ? Colors.grey[850] : Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDark ? Colors.grey[850] : Colors.grey[300],
                      child: Icon(
                        Icons.broken_image,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 10,
                  right: 10,
                  child: Text(
                    video.title.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Arimo',
                      color: Colors.white,
                      fontSize: 13, 
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3.0,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      case VideoCardLayout.horizontal:
        // --- LAYOUT HORIZONTAL (TIDAK BERUBAH) ---
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(5),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: subtleBorderColor, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.45 : 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildThumbnail(isDark, video, horizontal: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: _buildTitle(isDark, video)),
                            const SizedBox(height: 8),
                            _buildHorizontalMetadata(isDark, video, accentColor: accentColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

      case VideoCardLayout.full:
      default:
        // --- LAYOUT FULL (DITAMBAHKAN ACTION BUTTON) ---
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Thumbnail Image
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: CachedNetworkImage(
                            imageUrl: video.thumbnailUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5FF10)),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
                              child: Icon(Icons.broken_image, 
                                 color: isDark ? Colors.grey[700] : Colors.grey[400]),
                            ),
                          ),
                        ),
                      ),
                      // Durasi Badge
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.play_arrow, size: 10, color: accentColor),
                              const SizedBox(width: 4),
                              Text(
                                video.duration,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 2. Konten Teks & Action Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16), // Right padding dikurangi sedikit
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // KONTEN TEKS (JUDUL + INFO)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video.title.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Arimo',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                  color: isDark ? Colors.white.withOpacity(0.95) : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'VIDEO',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatRelativeTime(video.publishedAt),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ACTION BUTTON (TITIK 3)
                        PopupMenuButton<String>(
                          icon: Padding(
                            padding: const EdgeInsets.only(bottom: 12, left: 12),
                            child: SvgPicture.string(
                              '''
                              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
                                <path fill="${(isDark ? '#ffffff' : '#000000')}" d="M10 10h4v4h-4zm0-6h4v4h-4zm0 12h4v4h-4z"/>
                              </svg>
                              ''',
                              width: 24,
                              height: 24,
                            ),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                          onSelected: (value) {
                            if (value == 'wishlist') {
                              if (isWishlistMode) {
                                // Jika di halaman wishlist, logic hapus
                                WishlistManager.removeFromWishlist(video.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Dihapus dari wishlist')),
                                );
                              } else {
                                // Jika di home, simpan
                                if (onAddToWishlist != null) onAddToWishlist!();
                              }
                            } else if (value == 'share') {
                              _shareVideo(context);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'wishlist',
                              child: Row(
                                children: [
                                  if (isWishlistMode) ...[
                                    Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                  ] else ...[
                                    // Tampilkan ikon sesuai status: sudah/memang simpan
                                    ValueListenableBuilder<List<Video>>(
                                      valueListenable: WishlistManager.wishlist,
                                      builder: (context, wishlist, _) {
                                        final isBookmarked = wishlist.any((v) => v.id == video.id);
                                        return Icon(
                                          isBookmarked ? Icons.bookmark : Icons.bookmark_add_outlined,
                                          // Filled jika sudah di bookmark, outlined jika belum
                                          size: 20,
                                          color: isBookmarked
                                              ? Color(0xFFE5FF10)
                                              : (isDark ? Colors.white : Colors.black),
                                        );
                                      },
                                    ),
                                  ],
                                  const SizedBox(width: 12),
                                  ValueListenableBuilder<List<Video>>(
                                    valueListenable: WishlistManager.wishlist,
                                    builder: (context, wishlist, _) {
                                      final isBookmarked = wishlist.any((v) => v.id == video.id);
                                      return Text(
                                        isWishlistMode
                                            ? 'Hapus'
                                            : (isBookmarked ? 'Disimpan' : 'Simpan'),
                                        style: TextStyle(
                                          color: isWishlistMode
                                              ? Colors.red
                                              : (isBookmarked
                                                  ? Color(0xFFE5FF10)
                                                  : (isDark ? Colors.white : Colors.black)),
                                          // fontWeight: isBookmarked ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share_outlined, size: 20, color: isDark ? Colors.white : Colors.black),
                                  const SizedBox(width: 12),
                                  Text('Bagikan', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                                ],
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
          ),
        );
    }
  }

  // --- Helper Widgets ---

  Widget _buildThumbnail(bool isDark, Video video, {bool horizontal = false}) {
    final double aspect = horizontal ? 16 / 10 : 16 / 9;
    final double? height = horizontal ? 88 : null;
    final double? width = horizontal ? 146 : null;

    return SizedBox(
      height: height,
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5.0),
        child: AspectRatio(
          aspectRatio: aspect,
          child: Stack(
            children: [
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5FF10)),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                    child: Icon(
                      Icons.play_circle_outline,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                      size: 48,
                    ),
                  ),
                ),
              ),
              if (!horizontal)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.73),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(bool isDark, Video video) {
    return Text(
      video.title.trim(),
      style: TextStyle(
        fontFamily: 'Arimo',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : Colors.black,
        height: 1.3,
        letterSpacing: 0.2,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildHorizontalMetadata(bool isDark, Video video, {Color accentColor = const Color(0xFFE5FF10)}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time,
          size: 12,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            _formatRelativeTime(video.publishedAt),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks minggu lalu';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months bulan lalu';
    } else {
      return DateFormat('d MMM yyyy').format(date);
    }
  }
}