import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> logLikeEvent(String articleId, String title) async {
    await _analytics.logEvent(
      name: 'like_article',
      parameters: {
        'article_id': articleId,
        'title': title,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static Future<void> logShareEvent(String articleId, String title) async {
    await _analytics.logEvent(
      name: 'share_article',
      parameters: {
        'article_id': articleId,
        'title': title,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}
