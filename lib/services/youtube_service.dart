import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/video.dart';

// TAMBAHAN: Definisikan kelas VideoResult di sini (atau impor jika di file terpisah)
class VideoResult {
  final List<Video> videos;
  final String? nextPageToken;

  VideoResult({required this.videos, this.nextPageToken});
}

// Custom exception untuk error quota YouTube API
class YouTubeQuotaExceededException implements Exception {
  final String message;
  YouTubeQuotaExceededException(this.message);
  
  @override
  String toString() => message;
}

class YouTubeService {
  // Gunakan environment variable dengan fallback ke hardcoded key
  String get _apiKey {
    final envKey = dotenv.env['YOUTUBE_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }
    // Fallback ke hardcoded key (untuk backward compatibility)
    return 'AIzaSyBs7LwI1rq23TMbp1f2dnDd8dBLAQGPGjw';
  }
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';

  final http.Client _client;

  YouTubeService({http.Client? client}) : _client = client ?? http.Client();

  /// Mendapatkan video berdasarkan channel ID atau query pencarian
  /// MODIFIKASI: Mengembalikan VideoResult (videos + nextPageToken)
  Future<VideoResult> getVideos({
    String? channelId,
    String? query,
    int maxResults = 20,
    String? pageToken, // MODIFIKASI: Menerima pageToken
  }) async {
    try {
      // 1. Search untuk mendapatkan video IDs
      final apiKey = _apiKey;
      if (apiKey.isEmpty) {
        throw Exception('YouTube API key is not configured. Please set YOUTUBE_API_KEY in .env file.');
      }
      
      final searchParams = {
        'part': 'snippet',
        'maxResults': maxResults.toString(),
        'key': apiKey,
        'type': 'video',
        'order': 'date', // Urutkan berdasarkan tanggal terbaru
      };

      if (channelId != null) {
        searchParams['channelId'] = channelId;
      }
      if (query != null) {
        searchParams['q'] = query;
      }
      if (pageToken != null) {
        // MODIFIKASI: Tambahkan pageToken ke request jika ada
        searchParams['pageToken'] = pageToken;
      }

      final searchUri = Uri.parse('$_baseUrl/search')
          .replace(queryParameters: searchParams);

      final searchResponse = await _client.get(searchUri).timeout(
        const Duration(seconds: 15),
      );

      if (searchResponse.statusCode != 200) {
        final errorBody = json.decode(searchResponse.body);
        final errorMessage = errorBody['error']?['message'] ?? 'Unknown error';
        if (searchResponse.statusCode == 403) {
          // Cek apakah error karena quota exceeded
          if (errorMessage.toLowerCase().contains('quota') || 
              errorMessage.toLowerCase().contains('exceeded')) {
            throw YouTubeQuotaExceededException(
              'Belum bisa memuat video. Silakan coba lagi nanti.'
            );
          }
          throw Exception('Gagal memuat video: $errorMessage');
        }
        throw Exception('Gagal memuat video: ${searchResponse.statusCode} - $errorMessage');
      }

      final searchData = json.decode(searchResponse.body);
      final items = searchData['items'] as List? ?? [];

      // MODIFIKASI: Ambil nextPageToken dari respons
      final String? nextPageToken = searchData['nextPageToken'] as String?;

      if (items.isEmpty) {
        return VideoResult(videos: [], nextPageToken: null);
      }

      // 2. Extract video IDs
      final videoIds = items
          .map((item) => item['id']?['videoId'] as String?)
          .where((id) => id != null)
          .join(',');

      if (videoIds.isEmpty) {
        return VideoResult(videos: [], nextPageToken: nextPageToken);
      }

      // 3. Get video details (termasuk duration)
      final detailsParams = {
        'part': 'snippet,contentDetails',
        'id': videoIds,
        'key': apiKey,
      };

      final detailsUri = Uri.parse('$_baseUrl/videos')
          .replace(queryParameters: detailsParams);

      final detailsResponse = await _client.get(detailsUri).timeout(
        const Duration(seconds: 15),
      );

      if (detailsResponse.statusCode != 200) {
        final errorBody = json.decode(detailsResponse.body);
        final errorMessage = errorBody['error']?['message'] ?? 'Unknown error';
        if (detailsResponse.statusCode == 403) {
          // Cek apakah error karena quota exceeded
          if (errorMessage.toLowerCase().contains('quota') || 
              errorMessage.toLowerCase().contains('exceeded')) {
            throw YouTubeQuotaExceededException(
              'Belum bisa memuat video. Silakan coba lagi nanti.'
            );
          }
          throw Exception('Gagal memuat detail video: $errorMessage');
        }
        throw Exception('Gagal memuat detail video: ${detailsResponse.statusCode} - $errorMessage');
      }

      final detailsData = json.decode(detailsResponse.body);
      final detailItems = detailsData['items'] as List? ?? [];

      // 4. Parse menjadi Video objects
      final videos = detailItems
          .map((item) => Video.fromYouTubeApi(item))
          .toList();
      
      // MODIFIKASI: Kembalikan VideoResult
      return VideoResult(videos: videos, nextPageToken: nextPageToken);

    } catch (e) {
      print('Error fetching YouTube videos: $e');
      rethrow;
    }
  }

  /// Mendapatkan video trending (popular)
  /// MODIFIKASI: Mengembalikan VideoResult (meskipun trending biasanya tidak dipaginasi seperti ini)
  Future<VideoResult> getTrendingVideos({
    int maxResults = 20,
    String regionCode = 'ID', // Indonesia
    String? pageToken, // MODIFIKASI: Tambahkan pageToken
  }) async {
    try {
      final apiKey = _apiKey;
      if (apiKey.isEmpty) {
        throw Exception('YouTube API key is not configured. Please set YOUTUBE_API_KEY in .env file.');
      }
      
      final params = {
        'part': 'snippet,contentDetails',
        'chart': 'mostPopular',
        'regionCode': regionCode,
        'maxResults': maxResults.toString(),
        'key': apiKey,
      };

      if (pageToken != null) {
        params['pageToken'] = pageToken;
      }

      final uri = Uri.parse('$_baseUrl/videos')
          .replace(queryParameters: params);

      final response = await _client.get(uri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['error']?['message'] ?? 'Unknown error';
        if (response.statusCode == 403) {
          // Cek apakah error karena quota exceeded
          if (errorMessage.toLowerCase().contains('quota') || 
              errorMessage.toLowerCase().contains('exceeded')) {
            throw YouTubeQuotaExceededException(
              'Belum bisa memuat video trending. Silakan coba lagi nanti.'
            );
          }
          throw Exception('Gagal memuat video trending: $errorMessage');
        }
        throw Exception('Gagal memuat video trending: ${response.statusCode} - $errorMessage');
      }

      final data = json.decode(response.body);
      final items = data['items'] as List? ?? [];
      
      // MODIFIKASI: Ambil nextPageToken
      final String? nextPageToken = data['nextPageToken'] as String?;

      final videos = items
          .map((item) => Video.fromYouTubeApi(item))
          .toList();

      return VideoResult(videos: videos, nextPageToken: nextPageToken);

    } catch (e) {
      print('Error fetching trending videos: $e');
      rethrow;
    }
  }

  void dispose() {
    _client.close();
  }
}