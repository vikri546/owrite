import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Widget layar baru untuk memutar video YouTube.
/// [isShorts] menentukan apakah video tersebut bertipe shorts (potrait).
class YouTubePlayerScreen extends StatefulWidget {
  final String videoId;
  final bool isShorts;

  const YouTubePlayerScreen({Key? key, required this.videoId, this.isShorts = false})
      : super(key: key);

  @override
  _YouTubePlayerScreenState createState() => _YouTubePlayerScreenState();
}

class _YouTubePlayerScreenState extends State<YouTubePlayerScreen> {
  late YoutubePlayerController _controller;
  bool _isFullscreen = false;
  bool _showMenu = false;
  DateTime? _lastLeftTap;
  DateTime? _lastRightTap;
  static const double _tapZoneFraction = 0.32; // zone lebar untuk 2 side tap
  static const Duration _doubleTapDelay = Duration(milliseconds: 350);
  OverlayEntry? _overlayEntry;
  String? _showOverlayIcon;
  int? _showOverlaySeconds;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: false,
        isLive: false,
      ),
    )..addListener(_handlePlayerState);
  }

  void _handlePlayerState() async {
    final isFull = _controller.value.isFullScreen;
    if (isFull != _isFullscreen) {
      setState(() => _isFullscreen = isFull);

      if (isFull) {
        if (widget.isShorts) {
          // SHORTS: mode portrait fullscreen
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        } else {
          // VIDEO: mode landscape fullscreen
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }
      } else {
        // Kembali ke mode normal (portrait + show systemUI)
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handlePlayerState);
    _controller.dispose();
    _removeOverlay();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _showOverlayIcon = null;
    _showOverlaySeconds = null;
  }

  // Fungsi untuk share/copy link YouTube ke clipboard dan tampilkan snackbar
  void _shareCurrentVideo() {
    final url = 'https://www.youtube.com/watch?v=${widget.videoId}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link YouTube disalin!')),
    );
  }

  // Memposisikan overlay animasi/prompt pada "tengah KIRI" dan "tengah KANAN" video, bukan titik jari
  void _showOverlay(BuildContext context, String icon, int seconds, Offset tapPos, {double? videoWidth, double? videoHeight}) {
    _removeOverlay();
    _showOverlayIcon = icon;
    _showOverlaySeconds = seconds;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context, rootOverlay: true);
    final Size screenSize = MediaQuery.of(context).size;

    double overlayWidth = videoWidth ?? screenSize.width;
    double overlayHeight = videoHeight ?? screenSize.height;

    // Atur posisi overlay tepat di tengah bagian KIRI atau KANAN player.
    double centerY = (screenSize.height / 2) - 50;
    double left;
    if (icon == 'rewind') {
      // Tengah KIRI
      left = (screenSize.width / 4) - 50;
    } else {
      // Tengah KANAN
      left = (screenSize.width * 3 / 4) - 50;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: centerY,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 60),
              child: Container(
                width: 100,
                height: 100,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon == 'rewind'
                          ? Icons.fast_rewind_rounded
                          : Icons.fast_forward_rounded,
                      color: Colors.white,
                      size: 56,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 8),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${seconds.abs()}s",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 8),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay?.insert(_overlayEntry!);

    Future.delayed(const Duration(milliseconds: 500)).then((_) {
      _removeOverlay();
      if (mounted) setState(() {}); // To update any state change if needed
    });
  }

  void _onGeneralTapDown(TapDownDetails details, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final tapPos = details.localPosition;
    if (_showMenu) {
      // Tap anywhere (kecuali tombol action) untuk hide menu
      setState(() => _showMenu = false);
      return;
    }
    // Left/right double-tap need to be handled in actual doubleTapDown.
    // Single tap: toggle menu.
    setState(() => _showMenu = true);
  }

  void _onDoubleTapDown(TapDownDetails details, BoxConstraints constraints) {
    final tapZoneWidth = constraints.maxWidth * _tapZoneFraction;
    final tapPos = details.localPosition;
    final videoWidth = constraints.maxWidth;
    final videoHeight = constraints.maxHeight;
    // Left side
    if (tapPos.dx < tapZoneWidth) {
      // Double tap kiri: previous 10 sec
      final prev = _controller.value.position - const Duration(seconds: 10);
      _controller.seekTo(prev > Duration.zero ? prev : Duration.zero);
      _showOverlay(context, 'rewind', -10, tapPos, videoWidth: videoWidth, videoHeight: videoHeight);
    }
    // Right side
    else if (tapPos.dx > constraints.maxWidth - tapZoneWidth) {
      // Double tap kanan: next 10 sec
      final dur = _controller.metadata.duration;
      final next = _controller.value.position + const Duration(seconds: 10);
      if (dur != Duration.zero) {
        _controller.seekTo(next < dur ? next : dur);
      } else {
        _controller.seekTo(next);
      }
      _showOverlay(context, 'forward', 10, tapPos, videoWidth: videoWidth, videoHeight: videoHeight);
    }
    // Ignore double tap on middle area
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget player = YoutubePlayer(
      controller: _controller,
      showVideoProgressIndicator: true,
      progressIndicatorColor: const Color(0xFFE5FF10),
      progressColors: const ProgressBarColors(
        playedColor: Color(0xFFE5FF10),
        handleColor: Color(0xFFE5FF10),
      ),
      controlsTimeOut: _showMenu ? const Duration(seconds: 600) : const Duration(milliseconds: 1),
      bottomActions: null, // pakai default for better menu toggle handling
      onReady: () => debugPrint('Player is ready.'),
    );

    Widget buildPlayerWithGesture(BoxConstraints constraints) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _onGeneralTapDown(details, constraints),
        onDoubleTapDown: (details) => _onDoubleTapDown(details, constraints),
        // just to make it feel responsive on all area except control buttons
        child: Stack(
          alignment: Alignment.center,
          children: [
            player,
            // Overlay is managed via OverlayEntry for icon animation, nothing required here.
          ],
        ),
      );
    }

    // Sembunyikan appBar saat fullscreen
    return Scaffold(
      appBar: (!_isFullscreen)
          ? AppBar(
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              elevation: 0,
              backgroundColor: isDark ? Colors.black : Colors.white,
              surfaceTintColor: Colors.transparent,
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.share_outlined,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: _shareCurrentVideo,
                  tooltip: 'Bagikan',
                ),
              ],
            )
          : null,
      body: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        child: LayoutBuilder(
          builder: (context, constraints) {
            double aspect = widget.isShorts ? 9 / 16 : 16 / 9;

            Widget arWidget = AspectRatio(
              aspectRatio: aspect,
              child: buildPlayerWithGesture(constraints),
            );

            if (_isFullscreen) {
              return Center(child: arWidget);
            } else {
              return Center(child: arWidget);
            }
          },
        ),
      ),
    );
  }
}