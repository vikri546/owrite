import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import 'notification_service.dart';

/// Reading Behavior Tracker
class ReadingTrackerService {
  static final ReadingTrackerService _instance = ReadingTrackerService._internal();
  factory ReadingTrackerService() => _instance;
  ReadingTrackerService._internal();

  final NotificationService _notificationService = NotificationService();
  final ArticleRepository _articleRepository = ArticleRepository();

  // Timers
  Timer? _bacaKembaliTimer;
  Timer? _recommendationTimer;

  // State Tracking
  Article? _lastPartialReadArticle;
  Article? _lastCompleteReadArticle;
  DateTime? _articleOpenTime;
  
  // Delay Config
  static const int _bacaKembaliDelaySeconds = 180; // 3 minutes
  static const int _recommendationDelaySeconds = 120; // 2 minutes

  // Notification Category Keys
  static const Map<String, String> _categoryKeys = {
    'berita_penting': 'notif_cat_berita_penting',
    'berita_terbaru': 'notif_cat_berita_terbaru',
    'headline': 'notif_cat_headline',
    'berita_pilihan': 'notif_cat_berita_pilihan',
    'baca_kembali': 'notif_cat_baca_kembali',
    'shorts': 'notif_cat_shorts',
    'video': 'notif_cat_video',
    'artikel_24jam': 'notif_cat_artikel_24jam',
  };

  /// Check Global Notification Status
  Future<bool> _areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  /// Check Category Status
  Future<bool> _isCategoryEnabled(String categoryKey) async {
    if (!await _areNotificationsEnabled()) return false;
    final prefs = await SharedPreferences.getInstance();
    final prefKey = _categoryKeys[categoryKey];
    if (prefKey == null) return false;
    return prefs.getBool(prefKey) ?? true;
  }

  /// Start Reading Tracking
  void startReadingArticle(Article article) {
    _articleOpenTime = DateTime.now();
    _cancelAllTimers();
    debugPrint('[ReadingTracker] Started reading: ${article.title}');
  }

  /// End Reading Tracking
  Future<void> endReadingArticle(Article article, double scrollPercentage) async {
    final readingDuration = _articleOpenTime != null 
        ? DateTime.now().difference(_articleOpenTime!).inSeconds 
        : 0;
    
    debugPrint('[ReadingTracker] Ended reading: ${article.title}');
    debugPrint('[ReadingTracker] Scroll: ${(scrollPercentage * 100).toStringAsFixed(1)}%, Duration: ${readingDuration}s');

    // Partial read: < 70% scroll AND < 60 seconds reading
    if (scrollPercentage < 0.7 && readingDuration < 60) {
      await _scheduleBackaKembaliNotification(article);
    }
    // Complete read: > 80% scroll OR > 90 seconds reading
    else if (scrollPercentage > 0.8 || readingDuration > 90) {
      await _scheduleRecommendationNotification(article);
    }
    
    _articleOpenTime = null;
  }

  /// Shorts Partial View Tracking
  Future<void> trackPartialShortsView(int shortsId, String title) async {
    if (!await _isCategoryEnabled('shorts')) return;
    
    debugPrint('[ReadingTracker] Partial shorts view: $title');
    
    // Schedule shorts recommendation after delay
    _bacaKembaliTimer?.cancel();
    _bacaKembaliTimer = Timer(
      Duration(seconds: _bacaKembaliDelaySeconds),
      () => _sendShortsNotification(shortsId, title),
    );
  }

  /// Video Completion Tracking
  Future<void> trackVideoCompletion(String videoId, String title, bool completed) async {
    if (!await _isCategoryEnabled('video')) return;
    
    debugPrint('[ReadingTracker] Video ${completed ? "completed" : "partial"}: $title');
    
    if (!completed) {
      // Partial video - remind to continue
      _bacaKembaliTimer?.cancel();
      _bacaKembaliTimer = Timer(
        Duration(seconds: _bacaKembaliDelaySeconds),
        () => _sendVideoReminderNotification(videoId, title),
      );
    } else {
      // Completed video - recommend more
      _recommendationTimer?.cancel();
      _recommendationTimer = Timer(
        Duration(seconds: _recommendationDelaySeconds),
        () => _sendVideoRecommendationNotification(),
      );
    }
  }

  /// Schedule Read-Again Notification
  Future<void> _scheduleBackaKembaliNotification(Article article) async {
    if (!await _isCategoryEnabled('baca_kembali')) return;
    
    _lastPartialReadArticle = article;
    _bacaKembaliTimer?.cancel();
    
    debugPrint('[ReadingTracker] Scheduling Baca Kembali notification in $_bacaKembaliDelaySeconds seconds');
    
    _bacaKembaliTimer = Timer(
      Duration(seconds: _bacaKembaliDelaySeconds),
      () => _sendBacaKembaliNotification(),
    );
  }

  /// Schedule Post-Read Recommendation
  Future<void> _scheduleRecommendationNotification(Article article) async {
    _lastCompleteReadArticle = article;
    _recommendationTimer?.cancel();
    
    debugPrint('[ReadingTracker] Scheduling recommendation notification in $_recommendationDelaySeconds seconds');
    
    _recommendationTimer = Timer(
      Duration(seconds: _recommendationDelaySeconds),
      () => _sendRecommendationNotification(),
    );
  }

  /// Send Read-Again Notification
  Future<void> _sendBacaKembaliNotification() async {
    if (_lastPartialReadArticle == null) return;
    if (!await _isCategoryEnabled('baca_kembali')) return;
    
    final article = _lastPartialReadArticle!;
    
    await _notificationService.showTrendingNotification(
      'Mau Baca Kembali?',
      article.title.length > 80 ? '${article.title.substring(0, 80)}...' : article.title,
      payload: jsonEncode({
        'type': 'article',
        'id': article.id,
        'url': article.url,
      }),
    );
    
    debugPrint('[ReadingTracker] Sent Baca Kembali notification');
    _lastPartialReadArticle = null;
  }

  /// Send Article Recommendation
  Future<void> _sendRecommendationNotification() async {
    final headlineEnabled = await _isCategoryEnabled('headline');
    final beritaPilihanEnabled = await _isCategoryEnabled('berita_pilihan');
    
    if (!headlineEnabled && !beritaPilihanEnabled) return;
    
    try {
      List<Article> recommendations = [];
      String title = '';
      
      // Prioritize headline if enabled
      if (headlineEnabled) {
        recommendations = await _articleRepository.getArticlesByTag(109, page: 1, pageSize: 5);
        title = 'Headline Untuk Kamu';
      }
      
      // Fallback to berita pilihan
      if (recommendations.isEmpty && beritaPilihanEnabled) {
        recommendations = await _articleRepository.getArticlesByTag(113, page: 1, pageSize: 5);
        title = 'Berita Pilihan Untukmu';
      }
      
      if (recommendations.isEmpty) return;
      
      // Exclude last read article
      if (_lastCompleteReadArticle != null) {
        recommendations = recommendations.where((a) => a.id != _lastCompleteReadArticle!.id).toList();
      }
      
      if (recommendations.isEmpty) return;
      
      final randomArticle = recommendations[Random().nextInt(recommendations.length)];
      
      await _notificationService.showTrendingNotification(
        title,
        randomArticle.title.length > 80 ? '${randomArticle.title.substring(0, 80)}...' : randomArticle.title,
        payload: jsonEncode({
          'type': 'article',
          'id': randomArticle.id,
          'url': randomArticle.url,
        }),
      );
      
      debugPrint('[ReadingTracker] Sent recommendation notification');
    } catch (e) {
      debugPrint('[ReadingTracker] Error sending recommendation: $e');
    }
    
    _lastCompleteReadArticle = null;
  }

  /// Send Shorts Notification
  Future<void> _sendShortsNotification(int shortsId, String title) async {
    if (!await _isCategoryEnabled('shorts')) return;
    
    await _notificationService.showTrendingNotification(
      'Tonton Shorts Ini!',
      title.length > 80 ? '${title.substring(0, 80)}...' : title,
      payload: jsonEncode({
        'type': 'shorts',
        'id': shortsId,
      }),
    );
    debugPrint('[ReadingTracker] Sent shorts notification');
  }

  /// Send Video Reminder
  Future<void> _sendVideoReminderNotification(String videoId, String title) async {
    await _notificationService.showTrendingNotification(
      'Lanjutkan Menonton',
      title.length > 80 ? '${title.substring(0, 80)}...' : title,
      payload: jsonEncode({
        'type': 'video',
        'id': videoId,
      }),
    );
    debugPrint('[ReadingTracker] Sent video reminder notification');
  }

  /// Send Video Recommendation
  Future<void> _sendVideoRecommendationNotification() async {
    if (!await _isCategoryEnabled('video')) return;
    
    await _notificationService.showTrendingNotification(
      'Video Terbaru Untukmu',
      'Tonton video menarik lainnya di Owrite',
      payload: jsonEncode({
        'type': 'video_list',
      }),
    );
    debugPrint('[ReadingTracker] Sent video recommendation notification');
  }

  /// Cancel Timers
  void _cancelAllTimers() {
    _bacaKembaliTimer?.cancel();
    _recommendationTimer?.cancel();
  }

  /// Dispose
  void dispose() {
    _cancelAllTimers();
  }
}
