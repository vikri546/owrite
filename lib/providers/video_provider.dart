import 'package:flutter/foundation.dart';
import '../models/video.dart';
import '../services/youtube_service.dart';

enum VideoLoadingStatus {
  initial,
  loading,
  loaded,
  error,
  loadingMore, // MODIFIKASI: Status baru
  noMoreData,  // MODIFIKASI: Status baru
}

class VideoProvider with ChangeNotifier {
  final YouTubeService _youtubeService;

  List<Video> _videos = [];
  VideoLoadingStatus _status = VideoLoadingStatus.initial;
  String _errorMessage = '';
  String? _channelId;
  String? _searchQuery;
  String? _nextPageToken; // MODIFIKASI: Simpan token halaman berikutnya

  VideoProvider({YouTubeService? youtubeService})
      : _youtubeService = youtubeService ?? YouTubeService();

  // Getters
  List<Video> get videos => _videos;
  VideoLoadingStatus get status => _status;
  String get errorMessage => _errorMessage;

  /// Load videos dari channel tertentu
  Future<void> loadVideosFromChannel(String channelId, {bool refresh = false}) async {
    if (refresh) {
      _videos = [];
      _nextPageToken = null; // MODIFIKASI: Reset token
      _channelId = channelId;
      _searchQuery = null;
      _status = VideoLoadingStatus.loading;
    } else if (_status == VideoLoadingStatus.loading || _status == VideoLoadingStatus.loadingMore) {
      return; // Hindari multiple request
    }

    notifyListeners();

    try {
      final videoResult = await _youtubeService.getVideos(
        channelId: channelId,
        maxResults: 20,
      );

      _videos = videoResult.videos;
      _nextPageToken = videoResult.nextPageToken; // MODIFIKASI: Simpan token
      _status = _nextPageToken == null ? VideoLoadingStatus.noMoreData : VideoLoadingStatus.loaded;
      _errorMessage = '';
    } catch (e) {
      _status = VideoLoadingStatus.error;
      // Tangani YouTubeQuotaExceededException dengan pesan yang lebih ramah
      if (e is YouTubeQuotaExceededException) {
        _errorMessage = e.message;
      } else {
        // Untuk error lain, tampilkan pesan yang lebih user-friendly
        final errorStr = e.toString();
        if (errorStr.contains('403') || errorStr.toLowerCase().contains('quota')) {
          _errorMessage = 'Belum bisa memuat video. Silakan coba lagi nanti.';
        } else {
          _errorMessage = 'Gagal memuat video. Silakan coba lagi nanti.';
        }
      }
      debugPrint('Error loading videos: $e');
    }

    notifyListeners();
  }

  /// Load trending videos
  Future<void> loadTrendingVideos({bool refresh = false}) async {
    if (refresh) {
      _videos = [];
      _nextPageToken = null;
      _channelId = null;
      _searchQuery = null;
      _status = VideoLoadingStatus.loading;
    } else if (_status == VideoLoadingStatus.loading || _status == VideoLoadingStatus.loadingMore) {
      return;
    }

    notifyListeners();

    try {
      final videoResult = await _youtubeService.getTrendingVideos(
        maxResults: 20,
        regionCode: 'ID',
      );

      _videos = videoResult.videos;
      _nextPageToken = videoResult.nextPageToken;
      _status = _nextPageToken == null ? VideoLoadingStatus.noMoreData : VideoLoadingStatus.loaded;
      _errorMessage = '';
    } catch (e) {
      _status = VideoLoadingStatus.error;
      // Tangani YouTubeQuotaExceededException dengan pesan yang lebih ramah
      if (e is YouTubeQuotaExceededException) {
        _errorMessage = e.message;
      } else {
        final errorStr = e.toString();
        if (errorStr.contains('403') || errorStr.toLowerCase().contains('quota')) {
          _errorMessage = 'Belum bisa memuat video trending. Silakan coba lagi nanti.';
        } else {
          _errorMessage = 'Gagal memuat video trending. Silakan coba lagi nanti.';
        }
      }
      debugPrint('Error loading trending videos: $e');
    }

    notifyListeners();
  }

  /// Search videos
  Future<void> searchVideos(String query, {bool refresh = false}) async {
    if (refresh) {
      _videos = [];
      _nextPageToken = null;
      _searchQuery = query;
      _channelId = null;
      _status = VideoLoadingStatus.loading;
    } else if (_status == VideoLoadingStatus.loading || _status == VideoLoadingStatus.loadingMore) {
      return;
    }

    notifyListeners();

    try {
      final videoResult = await _youtubeService.getVideos(
        query: query,
        maxResults: 20,
      );

      _videos = videoResult.videos;
      _nextPageToken = videoResult.nextPageToken;
      _status = _nextPageToken == null ? VideoLoadingStatus.noMoreData : VideoLoadingStatus.loaded;
      _errorMessage = '';
    } catch (e) {
      _status = VideoLoadingStatus.error;
      // Tangani YouTubeQuotaExceededException dengan pesan yang lebih ramah
      if (e is YouTubeQuotaExceededException) {
        _errorMessage = e.message;
      } else {
        final errorStr = e.toString();
        if (errorStr.contains('403') || errorStr.toLowerCase().contains('quota')) {
          _errorMessage = 'Belum bisa mencari video. Silakan coba lagi nanti.';
        } else {
          _errorMessage = 'Gagal mencari video. Silakan coba lagi nanti.';
        }
      }
      debugPrint('Error searching videos: $e');
    }

    notifyListeners();
  }

  /// MODIFIKASI: Fungsi baru untuk memuat lebih banyak video
  Future<void> loadMoreVideos() async {
    // Jangan muat lebih jika sedang loading, atau sudah tidak ada data
    if (_status == VideoLoadingStatus.loadingMore || 
        _status == VideoLoadingStatus.noMoreData ||
        _status == VideoLoadingStatus.loading) {
      return;
    }

    // Jika tidak ada token, berarti tidak ada halaman selanjutnya
    if (_nextPageToken == null) {
      _status = VideoLoadingStatus.noMoreData;
      notifyListeners();
      return;
    }

    _status = VideoLoadingStatus.loadingMore;
    notifyListeners();

    try {
      // Tentukan apakah kita memuat lebih banyak dari channel, search, atau trending
      if (_channelId != null) {
        final videoResult = await _youtubeService.getVideos(
          channelId: _channelId,
          maxResults: 20,
          pageToken: _nextPageToken,
        );
        _videos.addAll(videoResult.videos); // Tambahkan ke list
        _nextPageToken = videoResult.nextPageToken; // Update token
      } else if (_searchQuery != null) {
        final videoResult = await _youtubeService.getVideos(
          query: _searchQuery,
          maxResults: 20,
          pageToken: _nextPageToken,
        );
        _videos.addAll(videoResult.videos);
        _nextPageToken = videoResult.nextPageToken;
      } else {
        // Asumsi default adalah trending jika tidak ada channelId atau searchQuery
        final videoResult = await _youtubeService.getTrendingVideos(
          maxResults: 20,
          regionCode: 'ID',
          pageToken: _nextPageToken,
        );
        _videos.addAll(videoResult.videos);
        _nextPageToken = videoResult.nextPageToken;
      }

      // Perbarui status berdasarkan apakah ada token berikutnya
      _status = _nextPageToken == null ? VideoLoadingStatus.noMoreData : VideoLoadingStatus.loaded;

    } catch (e) {
      // Jika terjadi error saat load more, kembali ke status loaded
      // agar pengguna bisa mencoba lagi nanti
      _status = VideoLoadingStatus.loaded; 
      _errorMessage = 'Gagal memuat video tambahan: ${e.toString()}';
      debugPrint('Error loading more videos: $e');
      // Kita tidak ingin menampilkan error fullscreen, jadi biarkan status 'loaded'
    }

    notifyListeners();
  }

  /// Refresh current content
  Future<void> refresh() async {
    // Reset nextPageToken saat refresh
    _nextPageToken = null; 
    if (_channelId != null) {
      await loadVideosFromChannel(_channelId!, refresh: true);
    } else if (_searchQuery != null) {
      await searchVideos(_searchQuery!, refresh: true);
    } else {
      await loadTrendingVideos(refresh: true);
    }
  }

  /// Clear all data
  void clear() {
    _videos = [];
    _status = VideoLoadingStatus.initial;
    _errorMessage = '';
    _channelId = null;
    _searchQuery = null;
    _nextPageToken = null; // MODIFIKASI: Clear token
    notifyListeners();
  }

  @override
  void dispose() {
    _youtubeService.dispose();
    super.dispose();
  }
}