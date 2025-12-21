import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../models/video.dart';
import '../repositories/article_repository.dart';
import '../providers/video_provider.dart';
import '../services/history_service.dart';
import '../services/youtube_service.dart';
import 'notification_service.dart';

/// Enum untuk kategori notifikasi
enum NotificationCategory {
  beritaPenting,           // 1. Ada Berita Penting Nihh!
  bacaKembali,             // 2. Mau Baca Kembali Berita Ini?
  beritaTerbaru,           // 3. Berita Terbaru Hari Ini
  headlineRecommendation,  // 4. Berita Yang Mungkin Kamu Suka (HEADLINE)
  beritaPilihanRecommendation, // 5. Berita Yang Mungkin Kamu Suka (BERITA PILIHAN)
  shortsTerbaru,           // 6. Ada Shorts Terbaru, Kamu Harus Tonton!?
  shortsRecommendation,   // 7. Shorts Yang Mungkin Kamu Suka
  videoTerbaru,           // 8. Waduhh Ada Video Terbaru Nihh, GASSS TONTON!!
  videoRecommendation,    // 9. Video Yang Mungkin Kamu Suka
  artikel24Jam,           // 10. Ada X Artikel Terbaru Yang Belum Kamu Baca Hari Ini
}

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final NotificationService _notificationService = NotificationService();
  final ArticleRepository _articleRepository = ArticleRepository();
  final HistoryService _historyService = HistoryService();
  final YouTubeService _youtubeService = YouTubeService();
  final Random _random = Random();

  // Kunci untuk menyimpan notifikasi yang sudah dikirim
  static const String _sentNotificationsKey = 'sent_notifications';
  static const String _last24HourCheckKey = 'last_24hour_check';
  
  // Tag IDs
  static const int headlineTagId = 109;
  static const int beritaPilihanTagId = 113;
  static const int importantNewsTagId = 1810;

  /// Inisialisasi notification manager
  Future<void> initialize() async {
    await _notificationService.init();
    await _cleanOldSentNotifications();
  }

  /// Membersihkan notifikasi yang sudah lama dari tracking
  Future<void> _cleanOldSentNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sentJson = prefs.getString(_sentNotificationsKey) ?? '{}';
      final Map<String, dynamic> sentMap = json.decode(sentJson);
      
      final now = DateTime.now();
      final keysToRemove = <String>[];
      
      sentMap.forEach((key, value) {
        if (value is Map && value['timestamp'] != null) {
          final timestamp = DateTime.fromMillisecondsSinceEpoch(value['timestamp'] as int);
          // Hapus notifikasi yang lebih dari 7 hari
          if (now.difference(timestamp).inDays > 7) {
            keysToRemove.add(key);
          }
        }
      });
      
      for (final key in keysToRemove) {
        sentMap.remove(key);
      }
      
      await prefs.setString(_sentNotificationsKey, json.encode(sentMap));
    } catch (e) {
      debugPrint('Error cleaning old notifications: $e');
    }
  }

  /// Cek apakah notifikasi sudah pernah dikirim
  Future<bool> _hasNotificationBeenSent(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sentJson = prefs.getString(_sentNotificationsKey) ?? '{}';
      final Map<String, dynamic> sentMap = json.decode(sentJson);
      return sentMap.containsKey(notificationId);
    } catch (e) {
      debugPrint('Error checking sent notifications: $e');
      return false;
    }
  }

  /// Tandai notifikasi sebagai sudah dikirim
  Future<void> _markNotificationAsSent(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sentJson = prefs.getString(_sentNotificationsKey) ?? '{}';
      final Map<String, dynamic> sentMap = json.decode(sentJson);
      
      sentMap[notificationId] = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await prefs.setString(_sentNotificationsKey, json.encode(sentMap));
    } catch (e) {
      debugPrint('Error marking notification as sent: $e');
    }
  }

  /// Cek apakah notifikasi enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  /// 1. Ada Berita Penting Nihh! - Artikel dengan tag Important News (1810)
  Future<void> sendBeritaPentingNotification() async {
    if (!await areNotificationsEnabled()) return;
    
    try {
      final articles = await _articleRepository.getArticlesByTag(importantNewsTagId, page: 1, pageSize: 5);
      if (articles.isEmpty) return;
      
      // Ambil artikel terbaru
      articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      final article = articles.first;
      
      final notificationId = 'berita_penting_${article.id}';
      if (await _hasNotificationBeenSent(notificationId)) return;
      
      await _notificationService.showBreakingNewsNotification(
        'Ada Berita Penting Nihh!',
        article.title.length > 100 ? '${article.title.substring(0, 100)}...' : article.title,
        payload: json.encode({
          'type': 'article',
          'id': article.id,
          'url': article.url,
        }),
      );
      
      await _markNotificationAsSent(notificationId);
    } catch (e) {
      debugPrint('Error sending berita penting notification: $e');
    }
  }

  /// 2. Mau Baca Kembali Berita Ini? - Dari history (BACA KEMBALI)
  Future<void> sendBacaKembaliNotification() async {
    if (!await areNotificationsEnabled()) return;
    
    try {
      final history = await _historyService.getHistory();
      if (history.isEmpty) return;
      
      // Ambil artikel random dari history
      final randomArticle = history[_random.nextInt(history.length)];
      
      final notificationId = 'baca_kembali_${randomArticle['id']}';
      if (await _hasNotificationBeenSent(notificationId)) return;
      
      final title = randomArticle['title'] as String? ?? 'Artikel';
      await _notificationService.showRecommendationNotification(
        'Mau Baca Kembali Berita Ini?',
        title.length > 100 ? '${title.substring(0, 100)}...' : title,
        payload: json.encode({
          'type': 'article',
          'id': randomArticle['id'],
          'url': randomArticle['url'],
        }),
      );
      
      await _markNotificationAsSent(notificationId);
    } catch (e) {
      debugPrint('Error sending baca kembali notification: $e');
    }
  }

  /// 3. Berita Terbaru Hari Ini - Artikel yang baru muncul hari ini
  Future<void> sendBeritaTerbaruNotification() async {
    if (!await areNotificationsEnabled()) return;
    
    try {
      // Ambil artikel terbaru dari semua kategori
      final articles = await _articleRepository.getArticlesByCategory(null, page: 1, pageSize: 10);
      if (articles.isEmpty) return;
      
      // Filter artikel yang dipublikasikan hari ini
      final now = DateTime.now();
      final todayArticles = articles.where((article) {
        final publishedDate = article.publishedAt;
        return publishedDate.year == now.year &&
               publishedDate.month == now.month &&
               publishedDate.day == now.day;
      }).toList();
      
      if (todayArticles.isEmpty) return;
      
      // Ambil artikel terbaru
      todayArticles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      final article = todayArticles.first;
      
      final notificationId = 'berita_terbaru_${article.id}_${now.day}_${now.month}_${now.year}';
      if (await _hasNotificationBeenSent(notificationId)) return;
      
      await _notificationService.showTrendingNotification(
        'Berita Terbaru Hari Ini',
        article.title.length > 100 ? '${article.title.substring(0, 100)}...' : article.title,
        payload: json.encode({
          'type': 'article',
          'id': article.id,
          'url': article.url,
        }),
      );
      
      await _markNotificationAsSent(notificationId);
    } catch (e) {
      debugPrint('Error sending berita terbaru notification: $e');
    }
  }

  /// 4. Berita Yang Mungkin Kamu Suka (HEADLINE) - Tag ID 109
  Future<void> sendHeadlineRecommendationNotification() async {
    if (!await areNotificationsEnabled()) return;
    
    try {
      final articles = await _articleRepository.getArticlesByTag(headlineTagId, page: 1, pageSize: 10);
      if (articles.isEmpty) return;
      
      // Ambil artikel random
      final article = articles[_random.nextInt(articles.length)];
      
      final notificationId = 'headline_recommendation_${article.id}';
      if (await _hasNotificationBeenSent(notificationId)) return;
      
      await _notificationService.showRecommendationNotification(
        'Berita Yang Mungkin Kamu Suka (HEADLINE)',
        article.title.length > 100 ? '${article.title.substring(0, 100)}...' : article.title,
        payload: json.encode({
          'type': 'article',
          'id': article.id,
          'url': article.url,
        }),
      );
      
      await _markNotificationAsSent(notificationId);
    } catch (e) {
      debugPrint('Error sending headline recommendation notification: $e');
    }
  }

  /// 5. Berita Yang Mungkin Kamu Suka (BERITA PILIHAN) - Tag ID 113
  Future<void> sendBeritaPilihanRecommendationNotification() async {
    if (!await areNotificationsEnabled()) return;
    
    try {
      final articles = await _articleRepository.getArticlesByTag(beritaPilihanTagId, page: 1, pageSize: 10);
      if (articles.isEmpty) return;
      
      // Ambil artikel random
      final article = articles[_random.nextInt(articles.length)];
      
      final notificationId = 'berita_pilihan_recommendation_${article.id}';
      if (await _hasNotificationBeenSent(notificationId)) return;
      
      await _notificationService.showRecommendationNotification(
        'Berita Yang Mungkin Kamu Suka (BERITA PILIHAN)',
        article.title.length > 100 ? '${article.title.substring(0, 100)}...' : article.title,
        payload: json.encode({
          'type': 'article',
          'id': article.id,
          'url': article.url,
        }),
      );
      
      await _markNotificationAsSent(notificationId);
    } catch (e) {
      debugPrint('Error sending berita pilihan recommendation notification: $e');
    }
  }

  /// 6. Ada Shorts Terbaru, Kamu Harus Tonton!? - Shorts terbaru
  Future<void> sendShortsTerbaruNotification({VideoProvider? videoProvider}) async {
    if (!await areNotificationsEnabled()) return;
    
    try {
      List<Video> videos = [];
      
      // Jika videoProvider tersedia, gunakan itu (foreground)
      if (videoProvider != null) {
        videos = videoProvider.videos;
      } else {
        // Jika tidak ada, fetch dari YouTubeService (background)
        try {
          final videoResult = await _youtubeService.getVideos(
            channelId: 'UC7LumXPdwm7UlBsyE0DQp6A', // OWRITE channel
            maxResults: 20,
          );
          videos = videoResult.videos;
        } catch (e) {
          debugPrint('Error fetching videos for shorts notification: $e');
          return;
        }
      }
      
      if (videos.isEmpty) return;
      
      // Filter shorts (durasi <= 3 menit)
      final shorts = videos.where((v) {
        if (v.title.toLowerCase().contains('shorts')) return true;
        if (v.duration.isEmpty) return false;
        final parts = v.duration.split(':').map((e) => int.tryParse(e) ?? 0).toList();
        int totalSeconds = 0;
        if (parts.length == 2) {
          totalSeconds = parts[0] * 60 + parts[1];
        } else if (parts.length == 3) {
          totalSeconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
        }
        return totalSeconds <= 180;
      }).toList();
      
      if (shorts.isEmpty) return;
      
      // Ambil shorts terbaru
      shorts.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      final video = shorts.first;
      
      final notificationId = 'shorts_terbaru_${video.id}';
      if (await _hasNotificationBeenSent(notificationId)) return;
      
      await _notificationService.showTrendingNotification(
        'Ada Shorts Terbaru, Kamu Harus Tonton!?',
        video.title.length > 100 ? '${video.title.substring(0, 100)}...' : video.title,
        payload: json.encode({
          'type': 'video',
          'id': video.id,
          'isShorts': true,
        }),
      );
      
      await _markNotificationAsSent(notificationId);
    } catch (e) {
      debugPrint('Error sending shorts terbaru notification: $e');
    }
  }

  /// 7. Shorts Yang Mungkin Kamu Suka - Shorts random
  Future<void> sendShortsRecommendationNotification({VideoProvider? videoProvider}) async {
    if (!await areNotificationsEnabled()) return;
    
    try {
      List<Video> videos = [];
      
      // Jika videoProvider tersedia, gunakan itu (foreground)
      if (videoProvider != null) {
        videos = videoProvider.videos;
      } else {
        // Jika tidak ada, fetch dari YouTubeService (background)
        try {
          final videoResult = await _youtubeService.getVideos(
            channelId: 'UC7LumXPdwm7UlBsyE0DQp6A', // OWRITE channel
            maxResults: 20,
          );
          videos = videoResult.videos;
        } catch (e) {
          debugPrint('Error fetching videos for shorts recommendation: $e');
          return;
        }
      }
      
      if (videos.isEmpty) return;
      
      // Filter shorts
      final shorts = videos.where((v) {
        if (v.title.toLowerCase().contains('shorts')) return true;
        if (v.duration.isEmpty) return false;
        final parts = v.duration.split(':').map((e) => int.tryParse(e) ?? 0).toList();
        int totalSeconds = 0;
        if (parts.length == 2) {
          totalSeconds = parts[0] * 60 + parts[1];
        } else if (parts.length == 3) {
          totalSeconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
        }
        return totalSeconds <= 180;
      }).toList();
      
      if (shorts.isEmpty) return;
      
      // Ambil shorts random
      final video = shorts[_random.nextInt(shorts.length)];
      
      final notificationId = 'shorts_recommendation_${video.id}';
      if (await _hasNotificationBeenSent(notificationId)) return;
      
      await _notificationService.showRecommendationNotification(
        'Shorts Yang Mungkin Kamu Suka',
        video.title.length > 100 ? '${video.title.substring(0, 100)}...' : video.title,
        payload: json.encode({
          'type': 'video',
          'id': video.id,
          'isShorts': true,
        }),
      );
      
      await _markNotificationAsSent(notificationId);
    } catch (e) {
      debugPrint('Error sending shorts recommendation notification: $e');
    }
  }

  /// 8. Waduhh Ada Video Terbaru Nihh, GASSS TONTON!! - Video terbaru
  Future<void> sendVideoTerbaruNotification({VideoProvider? videoProvider}) async {
    if (!await areNotificationsEnabled()) return;
    
    try {
      List<Video> videos = [];
      
      // Jika videoProvider tersedia, gunakan itu (foreground)
      if (videoProvider != null) {
        videos = videoProvider.videos;
      } else {
        // Jika tidak ada, fetch dari YouTubeService (background)
        try {
          final videoResult = await _youtubeService.getVideos(
            channelId: 'UC7LumXPdwm7UlBsyE0DQp6A', // OWRITE channel
            maxResults: 20,
          );
          videos = videoResult.videos;
        } catch (e) {
          debugPrint('Error fetching videos for video terbaru notification: $e');
          return;
        }
      }
      
      if (videos.isEmpty) return;
      
      // Filter video (bukan shorts, durasi > 3 menit)
      final regularVideos = videos.where((v) {
        if (v.title.toLowerCase().contains('shorts')) return false;
        if (v.duration.isEmpty) return true;
        final parts = v.duration.split(':').map((e) => int.tryParse(e) ?? 0).toList();
        int totalSeconds = 0;
        if (parts.length == 2) {
          totalSeconds = parts[0] * 60 + parts[1];
        } else if (parts.length == 3) {
          totalSeconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
        }
        return totalSeconds > 180;
      }).toList();
      
      if (regularVideos.isEmpty) return;
      
      // Ambil video terbaru
      regularVideos.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      final video = regularVideos.first;
      
      final notificationId = 'video_terbaru_${video.id}';
      if (await _hasNotificationBeenSent(notificationId)) return;
      
      await _notificationService.showTrendingNotification(
        'Waduhh Ada Video Terbaru Nihh, GASSS TONTON!!',
        video.title.length > 100 ? '${video.title.substring(0, 100)}...' : video.title,
        payload: json.encode({
          'type': 'video',
          'id': video.id,
          'isShorts': false,
        }),
      );
      
      await _markNotificationAsSent(notificationId);
    } catch (e) {
      debugPrint('Error sending video terbaru notification: $e');
    }
  }

  /// 9. Video Yang Mungkin Kamu Suka - Video random
  Future<void> sendVideoRecommendationNotification({VideoProvider? videoProvider}) async {
    if (!await areNotificationsEnabled()) return;
    
    try {
      List<Video> videos = [];
      
      // Jika videoProvider tersedia, gunakan itu (foreground)
      if (videoProvider != null) {
        videos = videoProvider.videos;
      } else {
        // Jika tidak ada, fetch dari YouTubeService (background)
        try {
          final videoResult = await _youtubeService.getVideos(
            channelId: 'UC7LumXPdwm7UlBsyE0DQp6A', // OWRITE channel
            maxResults: 20,
          );
          videos = videoResult.videos;
        } catch (e) {
          debugPrint('Error fetching videos for video recommendation: $e');
          return;
        }
      }
      
      if (videos.isEmpty) return;
      
      // Filter video (bukan shorts)
      final regularVideos = videos.where((v) {
        if (v.title.toLowerCase().contains('shorts')) return false;
        if (v.duration.isEmpty) return true;
        final parts = v.duration.split(':').map((e) => int.tryParse(e) ?? 0).toList();
        int totalSeconds = 0;
        if (parts.length == 2) {
          totalSeconds = parts[0] * 60 + parts[1];
        } else if (parts.length == 3) {
          totalSeconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
        }
        return totalSeconds > 180;
      }).toList();
      
      if (regularVideos.isEmpty) return;
      
      // Ambil video random
      final video = regularVideos[_random.nextInt(regularVideos.length)];
      
      final notificationId = 'video_recommendation_${video.id}';
      if (await _hasNotificationBeenSent(notificationId)) return;
      
      await _notificationService.showRecommendationNotification(
        'Video Yang Mungkin Kamu Suka',
        video.title.length > 100 ? '${video.title.substring(0, 100)}...' : video.title,
        payload: json.encode({
          'type': 'video',
          'id': video.id,
          'isShorts': false,
        }),
      );
      
      await _markNotificationAsSent(notificationId);
    } catch (e) {
      debugPrint('Error sending video recommendation notification: $e');
    }
  }

  /// 10. Ada X Artikel Terbaru Yang Belum Kamu Baca Hari Ini - Artikel 24 jam terakhir
  Future<void> sendArtikel24JamNotification() async {
    if (!await areNotificationsEnabled()) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      // Cek apakah sudah dicek hari ini (hanya muncul sekali di akhir hari)
      final lastCheck = prefs.getInt(_last24HourCheckKey);
      if (lastCheck != null) {
        final lastCheckDate = DateTime.fromMillisecondsSinceEpoch(lastCheck);
        // Jika sudah dicek hari ini, skip
        if (lastCheckDate.year == now.year &&
            lastCheckDate.month == now.month &&
            lastCheckDate.day == now.day) {
          return;
        }
      }
      
      // Hanya kirim di akhir hari (setelah jam 22:00)
      if (now.hour < 22) return;
      
      // Ambil semua artikel
      final articles = await _articleRepository.getArticlesByCategory(null, page: 1, pageSize: 100);
      if (articles.isEmpty) return;
      
      // Filter artikel yang dipublikasikan dalam 24 jam terakhir
      final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));
      final recentArticles = articles.where((article) {
        return article.publishedAt.isAfter(twentyFourHoursAgo);
      }).toList();
      
      // Harus ada minimal 2 artikel (tidak boleh 1)
      if (recentArticles.length < 2) return;
      
      final count = recentArticles.length;
      final notificationId = 'artikel_24jam_${now.day}_${now.month}_${now.year}';
      if (await _hasNotificationBeenSent(notificationId)) return;
      
      await _notificationService.showRecommendationNotification(
        'Ada $count Artikel Terbaru Yang Belum Kamu Baca Hari Ini',
        'Terdapat $count artikel baru yang terbit dalam 24 jam terakhir. Jangan sampai ketinggalan!',
        payload: json.encode({
          'type': 'articles_24h',
          'count': count,
        }),
      );
      
      await _markNotificationAsSent(notificationId);
      await prefs.setInt(_last24HourCheckKey, now.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error sending artikel 24 jam notification: $e');
    }
  }

  /// Kirim notifikasi berdasarkan kategori
  Future<void> sendNotificationByCategory(NotificationCategory category, {VideoProvider? videoProvider}) async {
    switch (category) {
      case NotificationCategory.beritaPenting:
        await sendBeritaPentingNotification();
        break;
      case NotificationCategory.bacaKembali:
        await sendBacaKembaliNotification();
        break;
      case NotificationCategory.beritaTerbaru:
        await sendBeritaTerbaruNotification();
        break;
      case NotificationCategory.headlineRecommendation:
        await sendHeadlineRecommendationNotification();
        break;
      case NotificationCategory.beritaPilihanRecommendation:
        await sendBeritaPilihanRecommendationNotification();
        break;
      case NotificationCategory.shortsTerbaru:
        await sendShortsTerbaruNotification(videoProvider: videoProvider);
        break;
      case NotificationCategory.shortsRecommendation:
        await sendShortsRecommendationNotification(videoProvider: videoProvider);
        break;
      case NotificationCategory.videoTerbaru:
        await sendVideoTerbaruNotification(videoProvider: videoProvider);
        break;
      case NotificationCategory.videoRecommendation:
        await sendVideoRecommendationNotification(videoProvider: videoProvider);
        break;
      case NotificationCategory.artikel24Jam:
        await sendArtikel24JamNotification();
        break;
    }
  }
}

