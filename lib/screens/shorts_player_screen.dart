import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/video.dart';

class ShortsPlayerScreen extends StatefulWidget {
  final List<Video> videos;
  final int startIndex;

  const ShortsPlayerScreen({
    Key? key,
    required this.videos,
    required this.startIndex,
  }) : super(key: key);

  @override
  State<ShortsPlayerScreen> createState() => _ShortsPlayerScreenState();
}

class _ShortsPlayerScreenState extends State<ShortsPlayerScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.startIndex);
    // Sembunyikan Status Bar untuk Fullscreen Immersive
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Kembalikan Status Bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: widget.videos.length,
        itemBuilder: (context, index) {
          return ShortsPlayerItem(video: widget.videos[index]);
        },
      ),
    );
  }
}

class ShortsPlayerItem extends StatefulWidget {
  final Video video;

  const ShortsPlayerItem({Key? key, required this.video}) : super(key: key);

  @override
  State<ShortsPlayerItem> createState() => _ShortsPlayerItemState();
}

class _ShortsPlayerItemState extends State<ShortsPlayerItem> {
  late YoutubePlayerController _controller;
  bool _isMuted = false;
  bool _isPlaying = true;
  double _currentSliderValue = 0.0;
  double _totalDuration = 1.0;
  bool _showControls = false; // Untuk animasi play/pause icon jika diperlukan

  // NEW: states for showing left/right double-tap info
  bool _showLeftDoubleTap = false;
  bool _showRightDoubleTap = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.video.id,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        loop: true,
        hideControls: true,
        mute: false,
        isLive: false,
        forceHD: false,
        enableCaption: false,
      ),
    )..addListener(_listener);
  }

  void _listener() {
    if (_controller.value.isReady && mounted) {
      setState(() {
        _currentSliderValue = _controller.value.position.inSeconds.toDouble();
        _totalDuration = _controller.metadata.duration.inSeconds.toDouble();
        _isPlaying = _controller.value.isPlaying;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_listener);
    _controller.dispose();
    super.dispose();
  }

  // --- Logic Gestures ---

  void _togglePlayPause() {
    if (_isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
      _showControls = true;
    });
    // Hilangkan icon play/pause setelah 1 detik
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleMute() {
    if (_isMuted) {
      _controller.unMute();
    } else {
      _controller.mute();
    }
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  // Tidak ada skip/rewind, ganti dengan menampilkan info di tengah (dibawah play)
  void _showLeftDoubleTapFeedback() {
    setState(() {
      _showLeftDoubleTap = true;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showLeftDoubleTap = false);
    });
  }

  void _showRightDoubleTapFeedback() {
    setState(() {
      _showRightDoubleTap = true;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showRightDoubleTap = false);
    });
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        duration: const Duration(milliseconds: 500),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black54,
        margin: const EdgeInsets.only(bottom: 100, left: 50, right: 50),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. VIDEO LAYER
        Center(
          child: AspectRatio(
            aspectRatio: 9 / 16, // Paksa rasio Shorts
            child: YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: false,
              aspectRatio: 9 / 16,
            ),
          ),
        ),

        // 2. GESTURE DETECTOR LAYER
        GestureDetector(
          onTap: _togglePlayPause,
          onDoubleTapDown: (details) {
            final screenWidth = size.width;
            final tapPosition = details.globalPosition.dx;
            if (tapPosition < screenWidth * 0.4) {
              _showLeftDoubleTapFeedback(); // only show feedback, no seek
            } else if (tapPosition > screenWidth * 0.6) {
              _showRightDoubleTapFeedback(); // only show feedback, no seek
            }
          },
          child: Container(color: Colors.transparent),
        ),

        // 3. ICON PLAY/PAUSE CENTER ANIMATION & double-tap info
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play/Pause
              if (_showControls || !_isPlaying)
                Icon(
                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 80,
                  color: Colors.white.withOpacity(0.7),
                ),
              // Space
              if (_showControls || !_isPlaying)
                const SizedBox(height: 36)
              else
                const SizedBox(height: 56), // Minimal space if not shown
              // DOUBLE TAP FEEDBACK (-10, +10) di tengah bawah play button
              if (_showLeftDoubleTap || _showRightDoubleTap)
                Column(
                  children: [
                    if (_showLeftDoubleTap) ...[
                      Text(
                        "-10  <<",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                                color: Colors.black.withOpacity(0.6),
                                offset: const Offset(2, 2),
                                blurRadius: 8)
                          ],
                        ),
                      ),
                      const SizedBox(height: 9),
                    ],
                    if (_showRightDoubleTap) ...[
                      Text(
                        "+10  >>",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                                color: Colors.black.withOpacity(0.6),
                                offset: const Offset(2, 2),
                                blurRadius: 8)
                          ],
                        ),
                      ),
                      const SizedBox(height: 9),
                    ],
                  ],
                ),
            ],
          ),
        ),

        // 4. TOP CONTROLS (Back & Volume)
        Positioned(
          top: 40,
          left: 10,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Positioned(
          top: 40,
          right: 10,
          child: IconButton(
            icon: Icon(
              _isMuted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
            ),
            onPressed: _toggleMute,
          ),
        ),

        // 5. BOTTOM INFO & PROGRESS BAR
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.9),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row untuk Title dan Share
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Title
                    Expanded(
                      child: Text(
                        widget.video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Arimo',
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Share Button
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white),
                          onPressed: () {
                            // Implement share logic
                            _showToast("Share clicked");
                          },
                        ),
                        const Text(
                          "Share",
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Bar Durasi Video (Slider)
                SizedBox(
                  height: 20,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFFE5FF10), // Accent Color
                      inactiveTrackColor: Colors.white24,
                      thumbColor: const Color(0xFFE5FF10),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 3,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: _currentSliderValue.clamp(0.0, _totalDuration),
                      min: 0.0,
                      max: _totalDuration > 0 ? _totalDuration : 1.0,
                      onChanged: (value) {
                        setState(() {
                          _currentSliderValue = value;
                        });
                      },
                      onChangeEnd: (value) {
                        _controller.seekTo(Duration(seconds: value.toInt()));
                        if (!_isPlaying) {
                          _controller.play();
                          setState(() => _isPlaying = true);
                        }
                      },
                    ),
                  ),
                ),

                // Indikator Waktu Kecil di bawah slider
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(Duration(seconds: _currentSliderValue.toInt())),
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                      Text(
                        _formatDuration(Duration(seconds: _totalDuration.toInt())),
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}