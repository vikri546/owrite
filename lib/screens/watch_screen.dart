import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../widgets/video_card.dart';
import '../models/video.dart';
import 'youtube_player_screen.dart';

// --- TAMBAHAN: MANAGER UNTUK WISHLIST (SEDERHANA) ---
class WishlistManager {
  static final ValueNotifier<List<Video>> wishlist = ValueNotifier([]);

  static void addToWishlist(BuildContext context, Video video) {
    if (!wishlist.value.any((v) => v.id == video.id)) {
      wishlist.value = [...wishlist.value, video];
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video disimpan ke Wishlist')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video sudah ada di Wishlist')),
      );
    }
  }

  static void removeFromWishlist(String videoId) {
    wishlist.value = wishlist.value.where((v) => v.id != videoId).toList();
  }
}

class WatchScreen extends StatefulWidget {
  const WatchScreen({Key? key}) : super(key: key);

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  bool _loadingMore = false;
  // Flag untuk auto-load ketika halaman pertama hanya berisi shorts
  bool _autoLoadingLongVideos = false;

  @override
  void initState() {
    super.initState();
    // Mengatur UI Mode agar immersive
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Load data awal
        Provider.of<VideoProvider>(context, listen: false)
            .loadVideosFromChannel('UC7LumXPdwm7UlBsyE0DQp6A', refresh: true);
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Helper untuk memparsing durasi string (e.g., "04:20") ke detik
  int _parseDurationToSeconds(String duration) {
    if (duration.isEmpty) return 0;
    try {
      final parts = duration.split(':').map((e) => int.tryParse(e) ?? 0).toList();
      if (parts.length == 2) {
        return parts[0] * 60 + parts[1];
      } else if (parts.length == 3) {
        return parts[0] * 3600 + parts[1] * 60 + parts[2];
      }
    } catch (e) {
      return 0;
    }
    return 0;
  }

  /// Menentukan apakah sebuah video dianggap "Shorts"
  bool _isShorts(Video video) {
    final seconds = _parseDurationToSeconds(video.duration);
    final titleLower = video.title.toLowerCase();

    final byDuration = seconds > 0 && seconds < 180; // < 3 menit
    final byTitle =
        titleLower.contains('#shorts') || titleLower.contains('shorts ');

    return byDuration || byTitle;
  }

  Future<void> _openVideo(Video video) async {
    if (video.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID Video tidak valid')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YouTubePlayerScreen(videoId: video.id),
      ),
    );
  }

  void _openWishlistScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WishlistScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFFE5FF10); // Warna aksen kuning neon

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true, // Agar gradient full screen
        body: Consumer<VideoProvider>(
          builder: (context, videoProvider, child) {
            final status = videoProvider.status;
            final allVideos = videoProvider.videos;

            // --- LOGIKA FILTER UTAMA ---
            // Hanya tampilkan VIDEO (>= 3 menit), sembunyikan semua Shorts.
            final List<Video> filteredVideos =
                allVideos.where((v) => !_isShorts(v)).toList();

            if (status == VideoLoadingStatus.loading && allVideos.isEmpty) {
              return _buildLoadingState(isDark);
            }

            if (status == VideoLoadingStatus.error && allVideos.isEmpty) {
              return _buildErrorState(
                isDark,
                videoProvider.errorMessage,
                () => videoProvider.refresh(),
              );
            }

            // Jika saat ini tidak ada VIDEO (>= 3 menit) yang lolos filter,
            // tetapi sudah ada data mentah dari API, coba auto-load halaman
            // berikutnya sekali lagi sebelum menampilkan empty state.
            if (filteredVideos.isEmpty &&
                allVideos.isNotEmpty &&
                status != VideoLoadingStatus.loading &&
                status != VideoLoadingStatus.loadingMore &&
                status != VideoLoadingStatus.noMoreData &&
                !_autoLoadingLongVideos) {
              _autoLoadingLongVideos = true;
              // Jalankan setelah frame ini supaya tidak memicu setState di tengah build.
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;
                await Provider.of<VideoProvider>(context, listen: false)
                    .loadMoreVideos();
                if (!mounted) return;
                setState(() {
                  _autoLoadingLongVideos = false;
                });
              });
              return _buildLoadingState(isDark);
            }

            // Setelah mencoba auto-load (atau memang benar-benar tidak ada data),
            // tampilkan empty state bila tetap tidak ada video yang lolos filter.
            if (filteredVideos.isEmpty &&
                status != VideoLoadingStatus.loading &&
                status != VideoLoadingStatus.loadingMore &&
                !_autoLoadingLongVideos) {
              return _buildEmptyState(isDark, accentColor);
            }

            return Container(
              decoration: BoxDecoration(
                // Gradient Background yang lebih menarik (Deep Dark)
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF0F0F0F), // Sangat gelap
                          const Color(0xFF1C1C1C), // Agak terang dikit
                          const Color(0xFF050505), // Kembali gelap
                        ]
                      : [
                          const Color(0xFFF0F0F0),
                          const Color(0xFFFFFFFF),
                        ],
                ),
              ),
              child: RefreshIndicator(
                onRefresh: () => videoProvider.refresh(),
                color: accentColor,
                backgroundColor: isDark ? const Color(0xFF222222) : Colors.white,
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                  // Jumlah item = Header + List Video + Loading Indicator/Tombol Load More
                  itemCount: 1 + filteredVideos.length + 1,
                  itemBuilder: (context, index) {
                    // 1. Header Section
                    if (index == 0) {
                      return Padding(
                        // Di sini diubah vertikal padding atas semula 60 menjadi 24 agar space kosong hilang
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'OWRITE VIDEO',
                                  style: TextStyle(
                                    fontFamily: 'Arimo',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 32,
                                    letterSpacing: 2,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.95)
                                        : Colors.black.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                            // --- TOMBOL WISHLIST SAJA (FILTER DIHAPUS) ---
                            IconButton(
                              onPressed: _openWishlistScreen,
                              icon: Icon(
                                  Icons.bookmarks_outlined,
                                  color: isDark ? accentColor : Colors.black,
                                ),
                              ),
                          ],
                        ),
                      );
                    }

                    // 2. Footer Section (Loading More / Button)
                    if (index == filteredVideos.length + 1) {
                      return _buildFooterSection(
                          status, isDark, accentColor, filteredVideos.isNotEmpty);
                    }

                    // 3. Video List Item
                    final videoIndex = index - 1; // Adjust index karena ada header
                    final video = filteredVideos[videoIndex];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24, left: 20, right: 20),
                      child: VideoCard(
                        video: video,
                        layout: VideoCardLayout.full, // Selalu pakai layout Full
                        onTap: () => _openVideo(video),
                        // Callback untuk tombol aksi di card
                        onAddToWishlist: () => WishlistManager.addToWishlist(context, video),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- Widget Bagian Bawah (Tombol Load More / Loading) ---
  Widget _buildFooterSection(VideoLoadingStatus status, bool isDark,
      Color accentColor, bool hasData) {
    if (status == VideoLoadingStatus.loadingMore) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
            child: CircularProgressIndicator(color: accentColor, strokeWidth: 2)),
      );
    }

    if (status == VideoLoadingStatus.noMoreData) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            'Semua video telah ditampilkan',
            style: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              fontFamily: 'Inter',
            ),
          ),
        ),
      );
    }

    // Tombol Load More Manual
    if (hasData) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFFE5FF10) : Colors.black,
              foregroundColor: accentColor,
              elevation: 0,
              side: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
            ),
            onPressed: () async {
              if (_loadingMore) return;
              setState(() => _loadingMore = true);
              await Provider.of<VideoProvider>(context, listen: false)
                  .loadMoreVideos();
              setState(() => _loadingMore = false);
            },
            child: _loadingMore
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: accentColor, strokeWidth: 2))
                : Text(
                    'SHOW MORE',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
          )
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildLoadingState(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F5F5),
      child: Center(
        child: CircularProgressIndicator(color: const Color(0xFFE5FF10)),
      ),
    );
  }

  Widget _buildErrorState(
      bool isDark, String errorMessage, VoidCallback onRetry) {
    return Container(
      color: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F5F5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: isDark ? Colors.grey[700] : Colors.grey[400]),
            const SizedBox(height: 16),
            Text(errorMessage,
                style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600])),
            TextButton(
              onPressed: onRetry,
              child: const Text('Coba Lagi',
                  style: TextStyle(color: Color(0xFFE5FF10))),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0F0F0F),
                  const Color(0xFF1C1C1C),
                  const Color(0xFF050505),
                ]
              : [
                  const Color(0xFFF0F0F0),
                  const Color(0xFFFFFFFF),
                ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 80,
              color: isDark ? Colors.grey[700] : Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Belum ada video',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
                fontFamily: 'Arimo',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Video akan muncul di sini setelah data dimuat',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- SCREEN TAMBAHAN: TAMPILAN WISHLIST ---
class WishlistScreen extends StatelessWidget {
  const WishlistScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFFE5FF10);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'WISHLIST',
          style: TextStyle(
            fontFamily: 'Arimo',
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder<List<Video>>(
        valueListenable: WishlistManager.wishlist,
        builder: (context, savedVideos, _) {
          if (savedVideos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmarks_outlined,
                      size: 60, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada video disimpan',
                    style: TextStyle(
                        color: Colors.grey.withOpacity(0.8), fontFamily: 'Inter'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: savedVideos.length,
            itemBuilder: (context, index) {
              final video = savedVideos[index];
              return Dismissible(
                key: Key(video.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) {
                  WishlistManager.removeFromWishlist(video.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dihapus dari wishlist')),
                  );
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red.withOpacity(0.8),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: VideoCard(
                    video: video,
                    layout: VideoCardLayout.full,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => YouTubePlayerScreen(videoId: video.id),
                        ),
                      );
                    },
                    // Di wishlist, menu opsinya mungkin berbeda atau dihilangkan
                    // Tapi kita biarkan agar tetap bisa share
                    onAddToWishlist: null, 
                    isWishlistMode: true, // Mode khusus untuk hapus
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}