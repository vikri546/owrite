import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../widgets/video_card.dart';
import '../models/video.dart';
import 'youtube_player_screen.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({Key? key}) : super(key: key);

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  bool _loadingMore = false;
  final ScrollController _shortsScrollController = ScrollController();
  bool _shortsIsFetching = false;
  bool _shortsNoMoreData = false;
  int _lastShortsLength = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<VideoProvider>(context, listen: false)
            .loadVideosFromChannel('UC7LumXPdwm7UlBsyE0DQp6A', refresh: true);
      }
    });

    _shortsScrollController.addListener(_handleShortsScroll);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _shortsScrollController.removeListener(_handleShortsScroll);
    _shortsScrollController.dispose();
    super.dispose();
  }

  /// Auto-load shorts when reaching end
  void _handleShortsScroll() async {
    if (_shortsScrollController.position.extentAfter < 220 &&
        !_shortsIsFetching &&
        !_shortsNoMoreData) {
      final provider = Provider.of<VideoProvider>(context, listen: false);

      // Only trigger if there are more videos to load AND no loading in progress
      if (provider.status != VideoLoadingStatus.loadingMore &&
          provider.status != VideoLoadingStatus.noMoreData) {
        setState(() {
          _shortsIsFetching = true;
        });
        int before = provider.videos.length;
        await provider.loadMoreVideos();
        int after = provider.videos.length;
        setState(() {
          _shortsIsFetching = false;
          // Mark no more data for shorts if list didn't grow
          if (after == before) {
            _shortsNoMoreData = true;
          }
        });
      }
    }
  }

  Future<void> _openVideo(Video video) async {
    if (video.id.isEmpty) {
      debugPrint('Error: Video ID is empty.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka video: ID tidak ditemukan.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YouTubePlayerScreen(videoId: video.id),
      ),
    );
  }

  bool _isShorts(Video v) {
    if (v.title.toLowerCase().contains('shorts')) {
      return true;
    }
    if (v.duration.isNotEmpty) {
      final parts = v.duration.split(':').map((e) => int.tryParse(e) ?? 0).toList();
      int totalSeconds = 0;
      if (parts.length == 2) {
        totalSeconds = parts[0] * 60 + parts[1];
      } else if (parts.length == 3) {
        totalSeconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
      }
      if (totalSeconds <= 300) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFFE5FF10);
    final backgroundColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Consumer<VideoProvider>(
          builder: (context, videoProvider, child) {
            final status = videoProvider.status;
            final videos = videoProvider.videos;

            final List<Video> shortsVideos = videos.where(_isShorts).toList();
            final List<Video> regularVideos = videos.where((v) => !_isShorts(v)).toList();

            // Reset shortsNoMoreData if new videos loaded
            if (shortsVideos.length > _lastShortsLength) {
              _shortsNoMoreData = false;
              _lastShortsLength = shortsVideos.length;
            }

            if (status == VideoLoadingStatus.loading) {
              return _buildLoadingState(isDark);
            }
            if (status == VideoLoadingStatus.error) {
              return _buildErrorState(
                isDark,
                videoProvider.errorMessage,
                () => videoProvider.refresh(),
              );
            }
            if (videos.isEmpty && (status == VideoLoadingStatus.loaded || status == VideoLoadingStatus.noMoreData)) {
              return _buildEmptyState(isDark);
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [
                              const Color(0xFF050505),
                              const Color(0xFF050505),
                            ]
                          : [
                              const Color(0xFFFDFDFD),
                              const Color(0xFFF3F3F3),
                            ],
                    ),
                  ),
                  child: RefreshIndicator(
                    onRefresh: () => videoProvider.refresh(),
                    color: accentColor,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(
                        top: 2,
                        bottom: 0,
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(30, 26, 20, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'VIDEO',
                              style: TextStyle(
                                fontFamily: 'Arimo',
                                fontWeight: FontWeight.w900,
                                fontSize: 34,
                                letterSpacing: 5,
                                color: isDark
                                    ? Colors.white.withOpacity(0.92)
                                    : Colors.black.withOpacity(0.93),
                                shadows: [
                                  Shadow(
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                    color: isDark
                                        ? Colors.black.withOpacity(0.06)
                                        : Colors.white.withOpacity(0.05),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ..._buildMainVideoContent(regularVideos, isDark),
                        if (status == VideoLoadingStatus.loadingMore)
                          _buildLoadingMoreIndicator(isDark),
                        if (status == VideoLoadingStatus.noMoreData)
                          _buildNoMoreDataIndicator(isDark),
                        if (status != VideoLoadingStatus.loadingMore &&
                            status != VideoLoadingStatus.noMoreData &&
                            regularVideos.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            child: Center(
                              child: SizedBox(
                                width: 210,
                                height: 46,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      colors: [
                                        accentColor,
                                        accentColor.withOpacity(0.8),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withOpacity(isDark ? 0.18 : 0.25),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                    ),
                                    onPressed: () async {
                                      if (_loadingMore) return;
                                      setState(() {
                                        _loadingMore = true;
                                      });
                                      await Provider.of<VideoProvider>(context, listen: false)
                                          .loadMoreVideos();
                                      setState(() {
                                        _loadingMore = false;
                                      });
                                    },
                                    child: _loadingMore
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.black,
                                              ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(
                                                Icons.refresh_rounded,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Muat lebih banyak',
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (shortsVideos.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 28, 20, 0),
                            child: Row(
                              children: [
                                Text(
                                  'SHORTS',
                                  style: TextStyle(
                                    fontFamily: 'Arimo',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 26,
                                    letterSpacing: 5,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.95)
                                        : Colors.black.withOpacity(0.94),
                                    shadows: [
                                      Shadow(
                                        blurRadius: 2,
                                        offset: const Offset(0, 2),
                                        color: isDark
                                            ? Colors.black.withOpacity(0.06)
                                            : Colors.white.withOpacity(0.05),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Tooltip(
                                  message:
                                      'Bisa digeser secara horizontal untuk menemukan konten lain',
                                  preferBelow: false,
                                  child: Icon(
                                    Icons.swipe,
                                    size: 18,
                                    color: isDark
                                        ? accentColor.withOpacity(0.9)
                                        : accentColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'geser untuk eksplor',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'Inter',
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 290,
                            child: NotificationListener<ScrollNotification>(
                              // Also allow for drag-scroll autoload in web/desktop/etc
                              onNotification: (scroll) {
                                // Fallback: ensure autoload also triggers for pointer scrolling
                                if (_shortsScrollController.hasClients && !_shortsIsFetching && !_shortsNoMoreData) {
                                  if (_shortsScrollController.position.extentAfter < 220) {
                                    _handleShortsScroll();
                                  }
                                }
                                return false;
                              },
                              child: ListView.separated(
                                controller: _shortsScrollController,
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: shortsVideos.length +
                                    (_shortsIsFetching ? 1 : 0) +
                                    (_shortsNoMoreData ? 1 : 0),
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 16),
                                itemBuilder: (context, index) {
                                  if (_shortsIsFetching && index == shortsVideos.length) {
                                    return SizedBox(
                                      width: 180,
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                                          child: SizedBox(
                                            height: 30,
                                            width: 30,
                                            child: CircularProgressIndicator(
                                              color: accentColor,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  if (_shortsNoMoreData &&
                                      index == shortsVideos.length +
                                          (_shortsIsFetching ? 1 : 0)) {
                                    return SizedBox(
                                      width: 180,
                                      child: Center(
                                        child: Text(
                                          'Semua shorts telah dimuat',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[500]
                                                : Colors.grey[600],
                                            fontFamily: 'Inter',
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final video = shortsVideos[index];
                                  return SizedBox(
                                    width: 180,
                                    child: VideoCard(
                                      video: video,
                                      layout: VideoCardLayout.shorts,
                                      onTap: () => _openVideo(video),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildMainVideoContent(List<Video> videos, bool isDark) {
    if (videos.isEmpty) return [
      Center(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Text(
          'Tidak ada video reguler ditemukan',
          style: TextStyle(
            fontFamily: 'Inter',
            color: isDark ? Colors.grey[500] : Colors.grey[700],
            fontSize: 14,
          ),
        ),
      )),
    ];

    final List<Widget> widgets = [];

    if (videos.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 16, left: 16, top: 0),
          child: VideoCard(
            video: videos[0],
            layout: VideoCardLayout.full,
            onTap: () => _openVideo(videos[0]),
          ),
        ),
      );
    }

    if (videos.length > 1) {
      widgets.addAll(
        List.generate(videos.length - 1, (i) {
          final idx = i + 1;
          return Padding(
            padding: EdgeInsets.only(
                right: 16, left: 16, bottom: 4, top: idx == 1 ? 0 : 0),
            child: VideoCard(
              video: videos[idx],
              layout: VideoCardLayout.horizontal,
              onTap: () => _openVideo(videos[idx]),
            ),
          );
        }),
      );
    }
    return widgets;
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: const Color(0xFFE5FF10),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat video...',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark, String errorMessage, VoidCallback onRetry) {
    final isQuotaError = errorMessage.toLowerCase().contains('quota') ||
        errorMessage.toLowerCase().contains('limit') ||
        errorMessage.toLowerCase().contains('habis');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isQuotaError ? Icons.schedule_outlined : Icons.error_outline,
              size: 64,
              color: isQuotaError
                  ? (isDark ? Colors.orange[300] : Colors.orange[600])
                  : (isDark ? Colors.grey[600] : Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: isQuotaError ? 16 : 14,
                fontWeight: isQuotaError ? FontWeight.w500 : FontWeight.normal,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (!isQuotaError)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5FF10),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.orange[900]?.withOpacity(0.2) : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.orange[800]! : Colors.orange[200]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: isDark ? Colors.orange[300] : Colors.orange[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Kuota akan direset setiap hari',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: isDark ? Colors.orange[300] : Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada video ditemukan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Center(
        child: CircularProgressIndicator(
          color: const Color(0xFFE5FF10),
        ),
      ),
    );
  }

  Widget _buildNoMoreDataIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Center(
        child: Text(
          'Semua video telah dimuat',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  // _showSearchDialog tidak dimodifikasi
}