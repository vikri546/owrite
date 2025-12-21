import 'dart:async';
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Widget untuk icon double arrows (dua panah)
class _DoubleArrowIcon extends StatelessWidget {
  final bool isForward;
  final Color color;
  final double size;

  const _DoubleArrowIcon({
    required this.isForward,
    required this.color,
    this.size = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isForward) ...[
            // Forward: panah pertama di kiri
            Positioned(
              left: 0,
              child: Icon(
                Icons.arrow_forward_ios,
                size: size * 0.7,
                color: color,
              ),
            ),
            // Forward: panah kedua di kanan (overlap)
            Positioned(
              left: size * 0.35,
              child: Icon(
                Icons.arrow_forward_ios,
                size: size * 0.7,
                color: color,
              ),
            ),
          ] else ...[
            // Rewind: panah pertama di kanan
            Positioned(
              right: 0,
              child: Icon(
                Icons.arrow_back_ios,
                size: size * 0.7,
                color: color,
              ),
            ),
            // Rewind: panah kedua di kiri (overlap)
            Positioned(
              right: size * 0.35,
              child: Icon(
                Icons.arrow_back_ios,
                size: size * 0.7,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Komponen kontrol TTS player yang interaktif dan modern
/// Mirip dengan audio player dengan kontrol lengkap untuk pemutaran audio
class TtsPlayerControl extends StatefulWidget {
  /// AudioPlayer instance yang digunakan untuk kontrol audio
  final AudioPlayer audioPlayer;

  /// Callback ketika pemutaran selesai
  final VoidCallback? onCompleted;

  /// Padding horizontal dari container
  final EdgeInsetsGeometry? padding;

  /// Tinggi container player
  final double? height;

  const TtsPlayerControl({
    Key? key,
    required this.audioPlayer,
    this.onCompleted,
    this.padding,
    this.height,
  }) : super(key: key);

  @override
  State<TtsPlayerControl> createState() => _TtsPlayerControlState();
}

class _TtsPlayerControlState extends State<TtsPlayerControl> {
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isSeeking = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayerListeners();
    _loadDuration();
  }

  /// Setup listener untuk perubahan state, duration, dan position audio player
  void _setupAudioPlayerListeners() {
    // Listener untuk perubahan state (playing, paused, stopped)
    _stateSubscription = widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        if (state == PlayerState.playing) {
          _isPlaying = true;
          _isPaused = false;
        } else if (state == PlayerState.paused) {
          _isPlaying = false;
          _isPaused = true;
        } else if (state == PlayerState.stopped || state == PlayerState.completed) {
          _isPlaying = false;
          _isPaused = false;
          _position = Duration.zero;
          if (state == PlayerState.completed && widget.onCompleted != null) {
            widget.onCompleted!();
          }
        }
      });
    });

    // Listener untuk perubahan duration
    _durationSubscription = widget.audioPlayer.onDurationChanged.listen((newDuration) {
      if (!mounted) return;
      setState(() {
        _duration = newDuration;
      });
    });

    // Listener untuk perubahan position (update progress bar)
    _positionSubscription = widget.audioPlayer.onPositionChanged.listen((newPosition) {
      if (!mounted) return;
      if (!_isSeeking) {
        setState(() {
          _position = newPosition;
        });
      }
    });
  }

  /// Load duration audio saat ini
  Future<void> _loadDuration() async {
    final duration = await widget.audioPlayer.getDuration();
    if (duration != null && mounted) {
      setState(() {
        _duration = duration;
      });
    }
  }

  /// Format duration menjadi format 00:00
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  /// Rewind audio 10 detik ke belakang
  Future<void> _rewind() async {
    final currentSeconds = _position.inSeconds;
    final targetSeconds = (currentSeconds - 10).clamp(0, _duration.inSeconds);
    await widget.audioPlayer.seek(Duration(seconds: targetSeconds));
  }

  /// Forward audio 10 detik ke depan
  Future<void> _forward() async {
    final currentSeconds = _position.inSeconds;
    final targetSeconds = (currentSeconds + 10).clamp(0, _duration.inSeconds);
    await widget.audioPlayer.seek(Duration(seconds: targetSeconds));
  }

  /// Toggle play/pause
  Future<void> _togglePlayPause() async {
    if (_isPaused) {
      await widget.audioPlayer.resume();
    } else {
      await widget.audioPlayer.pause();
    }
  }

  /// Seek audio ke posisi tertentu (dipanggil saat slider digeser)
  Future<void> _seekAudio(double seconds) async {
    final newPosition = Duration(seconds: seconds.toInt());
    await widget.audioPlayer.seek(newPosition);
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF252525)
        : Colors.white;
    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.1);
    final Color iconColor = isDark ? Colors.white : Colors.black87;
    final Color inactiveTrackColor = isDark
        ? Colors.grey.shade700
        : Colors.grey.shade300;

    final double containerHeight = widget.height ?? 64.0;
    final EdgeInsetsGeometry containerPadding = widget.padding ??
        const EdgeInsets.fromLTRB(18.0, 16.0, 18.0, 0.0);

    return Padding(
      padding: containerPadding,
      child: Container(
        height: containerHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- CONTROLS SECTION (Rewind, Play/Pause, Forward) ---
            
            // Rewind Button (-10 detik) - Double arrows ke kiri
            IconButton(
              onPressed: _rewind,
              icon: _DoubleArrowIcon(isForward: false, color: iconColor, size: 20.0),
              iconSize: 24,
              color: iconColor,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: "-10s",
            ),
            
            const SizedBox(width: 8),
            
            // Play/Pause Button
            InkWell(
              onTap: _togglePlayPause,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: iconColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _isPaused || !_isPlaying
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  color: iconColor,
                  size: 26,
                ),
              ),
            ),

            const SizedBox(width: 8),
            
            // Forward Button (+10 detik) - Double arrows ke kanan
            IconButton(
              onPressed: _forward,
              icon: _DoubleArrowIcon(isForward: true, color: iconColor, size: 20.0),
              iconSize: 24,
              color: iconColor,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: "+10s",
            ),

            const SizedBox(width: 12),

            // --- TIMELINE SECTION ---
            
            // Current Time
            Text(
              _formatDuration(_position),
              style: TextStyle(
                fontSize: 11,
                color: iconColor,
                fontWeight: FontWeight.w500,
                fontFeatures: [ui.FontFeature.tabularFigures()],
              ),
            ),

            const SizedBox(width: 6),

            // Progress Slider
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                  activeTrackColor: iconColor,
                  inactiveTrackColor: inactiveTrackColor,
                  thumbColor: iconColor,
                  trackShape: const RoundedRectSliderTrackShape(),
                ),
                child: Slider(
                  min: 0.0,
                  max: _duration.inSeconds.toDouble() > 0
                      ? _duration.inSeconds.toDouble()
                      : 1.0,
                  value: _position.inSeconds.toDouble().clamp(
                    0.0,
                    (_duration.inSeconds.toDouble() > 0
                        ? _duration.inSeconds.toDouble()
                        : 1.0),
                  ),
                  onChangeStart: (value) {
                    setState(() => _isSeeking = true);
                  },
                  onChanged: (value) {
                    setState(() {
                      _position = Duration(seconds: value.toInt());
                    });
                  },
                  onChangeEnd: (value) {
                    _seekAudio(value);
                    setState(() => _isSeeking = false);
                  },
                ),
              ),
            ),

            const SizedBox(width: 6),

            // Total Duration
            Text(
              _formatDuration(_duration),
              style: TextStyle(
                fontSize: 11,
                color: iconColor.withOpacity(0.6),
                fontWeight: FontWeight.w500,
                fontFeatures: [ui.FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

