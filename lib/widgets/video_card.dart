import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/video.dart';

// --- PENANDA: ADA 3 LAYOUT UTAMA DI SINI ---
// 1. VideoCardLayout.full (layout default/kolom)
// 2. VideoCardLayout.horizontal (layout baris horizontal)
// 3. VideoCardLayout.shorts (tampilan shorts youtube)

enum VideoCardLayout { full, horizontal, shorts }

class VideoCard extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;
  final VideoCardLayout layout;

  const VideoCard({
    Key? key,
    required this.video,
    required this.onTap,
    this.layout = VideoCardLayout.full,
  }) : super(key: key);

  /// Implementasi agar tidak error jika Video tidak punya getter isShorts.
  /// Gunakan heuristik (judul mengandung "shorts" ATAU durasi <= 5 menit - sama dengan watch_screen.dart)
  bool get _isShorts {
    return video.title.toLowerCase().contains('shorts') || _durationIsShort();
  }

  /// Cek apakah durasi video <= 5 menit
  bool _durationIsShort() {
    List<String> parts = video.duration.split(':');
    if (parts.length == 2) {
      int minutes = int.tryParse(parts[0]) ?? 0;
      int seconds = int.tryParse(parts[1]) ?? 0;
      int totalSeconds = minutes * 60 + seconds;
      return totalSeconds <= 300; // 5 menit = 300 detik
    } else if (parts.length == 3) {
      int hours = int.tryParse(parts[0]) ?? 0;
      int minutes = int.tryParse(parts[1]) ?? 0;
      int seconds = int.tryParse(parts[2]) ?? 0;
      int totalSeconds = hours * 3600 + minutes * 60 + seconds;
      return totalSeconds <= 300;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFFE5FF10);
    final cardColor = isDark ? const Color(0xFF111111) : Colors.white;
    final subtleBorderColor = isDark ? Colors.white10 : Colors.black12;

    switch (layout) {
      case VideoCardLayout.horizontal:
        // --- MULAI: LAYOUT HORIZONTAL ---
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
                      // Thumbnail on the left
                      _buildThumbnail(isDark, horizontal: true),
                      const SizedBox(width: 12),
                      // Title dan metadata di sebelah kanan (tanpa channel)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: _buildTitle(isDark)),
                            const SizedBox(height: 8),
                            _buildHorizontalMetadata(isDark, accentColor: accentColor),
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
        // --- AKHIR: LAYOUT HORIZONTAL ---

      case VideoCardLayout.shorts:
        // --- MULAI: LAYOUT SHORTS (dengan judul di atas dan published time di bawah) ---
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: cardColor,
                  border: Border.all(
                    color: subtleBorderColor,
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.45 : 0.09),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildThumbnail(isDark, shorts: true),
                        const SizedBox(height: 8),
                        // Judul di atas, publishedAt di bawahnya (centered)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _buildTitle(
                            isDark,
                            maxLines: 2,
                            centered: true,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Published time di bawah judul (centered)
                        _buildShortsPublishedAt(isDark, centered: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        // --- AKHIR: LAYOUT SHORTS ---

      case VideoCardLayout.full:
      default:
        // --- MULAI: LAYOUT FULL (DEFAULT/KARTU VERTIKAL) ---
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(5),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: subtleBorderColor, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.5 : 0.08),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildThumbnail(isDark),
                      const SizedBox(height: 12),
                      _buildTitle(isDark),
                      const SizedBox(height: 8),
                      _buildMetadata(isDark, accentColor: accentColor),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        // --- AKHIR: LAYOUT FULL ---
    }
  }

  /// Revisi untuk thumbnail: tambahkan layout shorts
  Widget _buildThumbnail(
    bool isDark, {
    bool horizontal = false,
    bool shorts = false,
  }) {
    // Atur aspek rasio khusus shorts (9:16)
    final double aspect = shorts
        ? 9 / 16
        : horizontal
            ? 16 / 10
            : 16 / 9;

    final double? width = shorts
        ? 108 // Lebih sempit dan tinggi dari default
        : horizontal
            ? 146
            : null;
    final double? height = shorts
        ? 192
        : horizontal
            ? 88
            : null;

    final widget = ClipRRect(
      borderRadius: BorderRadius.circular(5.0),
      child: AspectRatio(
        aspectRatio: aspect,
        child: CachedNetworkImage(
          imageUrl: video.thumbnailUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: isDark ? Colors.grey[800] : Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
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
    );

    final List<Widget> children = [widget];

    // Tambahkan badge "Shorts" di pojok untuk shorts video
    if (shorts || _isShorts) {
      children.add(
        Positioned(
          left: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.92),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.play_arrow, size: 15, color: Colors.white),
                SizedBox(width: 2),
                Text(
                  'SHORTS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 11.5,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Overlay durasi pada thumbnail -- durasi tetap di kanan bawah, size disesuaikan untuk shorts
    if (!(shorts || _isShorts)) {
      children.add(
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              video.duration,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    } else {
      children.add(
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
      );
    }

    final result = Stack(children: children);

    if (shorts) {
      return SizedBox(
        width: width,
        height: height,
        child: result,
      );
    } else if (horizontal) {
      return SizedBox(
        height: 88,
        width: 146,
        child: result,
      );
    } else {
      return result;
    }
  }

  Widget _buildTitle(bool isDark, {int maxLines = 2, bool centered = false}) {
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
      maxLines: maxLines,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildChannelName(bool isDark, {bool centered = false}) {
    return Text(
      video.channelTitle,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.grey[400] : Colors.grey[700],
      ),
      maxLines: 1,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMetadata(bool isDark, {Color accentColor = const Color(0xFFE5FF10)}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor,
          ),
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

  Widget _buildHorizontalMetadata(bool isDark, {Color accentColor = const Color(0xFFE5FF10)}) {
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

  /// Metadata bawah untuk shorts (kosong/dummy, atau bisa untuk views/dll)
  Widget _buildShortsMetadataBelow(bool isDark) {
    return SizedBox.shrink();
  }

  /// Widget untuk waktu publish pada shorts
  Widget _buildShortsPublishedAt(bool isDark, {Color accentColor = const Color(0xFFE5FF10), bool centered = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.start,
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
            textAlign: centered ? TextAlign.center : TextAlign.start,
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