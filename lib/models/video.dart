class Video {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String channelTitle;
  final DateTime publishedAt;
  final String duration; // Format: "PT5M30S" atau sudah diparse menjadi "5:30"

  Video({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.channelTitle,
    required this.publishedAt,
    required this.duration,
  });

  // Factory constructor untuk parsing dari YouTube API
  factory Video.fromYouTubeApi(Map<String, dynamic> json) {
    final snippet = json['snippet'] ?? {};
    final contentDetails = json['contentDetails'] ?? {};

    // id bisa String atau Map
    String id = '';
    final rawId = json['id'];
    if (rawId is Map && rawId.containsKey('videoId')) {
        id = rawId['videoId'] ?? '';
    } else if (rawId is String) {
        id = rawId;
    }

    return Video(
        id: id,
        title: snippet['title'] ?? 'No Title',
        thumbnailUrl: snippet['thumbnails']?['medium']?['url'] ??
            snippet['thumbnails']?['default']?['url'] ??
            '',
        channelTitle: snippet['channelTitle'] ?? 'Unknown Channel',
        publishedAt:
            DateTime.tryParse(snippet['publishedAt'] ?? '') ?? DateTime.now(),
        duration: _parseDuration(contentDetails['duration'] ?? 'PT0S'),
    );
    }

  // Parse ISO 8601 duration (PT5M30S) ke format readable (5:30)
  static String _parseDuration(String isoDuration) {
    if (isoDuration.isEmpty || isoDuration == 'PT0S') return '0:00';
    
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(isoDuration);
    
    if (match == null) return '0:00';
    
    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  // Untuk konversi ke JSON (jika perlu caching)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'channelTitle': channelTitle,
      'publishedAt': publishedAt.toIso8601String(),
      'duration': duration,
    };
  }

  // Factory dari JSON (untuk caching)
  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] ?? '',
      title: json['title'] ?? 'No Title',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      channelTitle: json['channelTitle'] ?? 'Unknown Channel',
      publishedAt: DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
      duration: json['duration'] ?? '0:00',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Video && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}