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

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: false, // Gunakan ini sebagai pengganti forceHideAnnotation
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
    // Kembalikan orientasi dan UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              title: Text(
                'Memutar Video',
                style: TextStyle(
                  fontFamily: 'Arimo',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              elevation: 0,
              backgroundColor: isDark ? Colors.black : Colors.white,
              surfaceTintColor: Colors.transparent,
            )
          : null,
      body: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        child: LayoutBuilder(
          builder: (context, constraints) {
            Widget player = YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: const Color(0xFFE5FF10),
              progressColors: const ProgressBarColors(
                playedColor: Color(0xFFE5FF10),
                handleColor: Color(0xFFE5FF10),
              ),
              onReady: () => debugPrint('Player is ready.'),
            );

            if (_isFullscreen) {
              if (widget.isShorts) {
                // Shorts: Portrait fullscreen (player fit height, black side on width if needed)
                return Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: player,
                  ),
                );
              } else {
                // Video: Landscape fullscreen
                return Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: player,
                  ),
                );
              }
            } else {
              // Mode normal, tetap dengan aspect sesuai tipe
              return Center(
                child: AspectRatio(
                  aspectRatio: widget.isShorts ? 9 / 16 : 16 / 9,
                  child: player,
                ),
              );
            }
          },
        ),
      ),
    );
  }
}