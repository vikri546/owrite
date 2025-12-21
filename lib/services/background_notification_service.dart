import 'dart:async';
import 'dart:math';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import 'notification_service.dart';
import 'notification_manager.dart';

class BackgroundNotificationService {
  static const String _taskName = 'backgroundNotificationTask';
  static const String _periodicTaskName = 'periodicNotificationTask';

  static final BackgroundNotificationService _instance =
      BackgroundNotificationService._internal();
  factory BackgroundNotificationService() => _instance;
  BackgroundNotificationService._internal();

  final NotificationService _notificationService = NotificationService();
  final ArticleRepository _articleRepository = ArticleRepository();
  final NotificationManager _notificationManager = NotificationManager();

  // Available categories from API
  static const List<String> _availableCategories = [
    'HYPE',
    'OLAHRAGA',
    'EKBIS',
    'MEGAPOLITAN',
    'DAERAH',
    'NASIONAL',
    'INTERNASIONAL',
  ];

  // Initialize background service
  Future<void> initialize() async {
    try {
      await _notificationManager.initialize();
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
      
      print('✅ WorkManager initialized');

      // Check if notifications are enabled
      final isEnabled = await areNotificationsEnabled();
      if (!isEnabled) {
        print('⚠️ Notifications are disabled');
        return;
      }

      // Cancel existing tasks first
      await Workmanager().cancelAll();
      
      // Register periodic task for notifications (minimum 15 minutes)
      // Kita akan gunakan 15 menit sebagai minimum, tapi logika di dalam akan cek interval
      await Workmanager().registerPeriodicTask(
        _periodicTaskName,
        _periodicTaskName,
        frequency: const Duration(minutes: 15), // Minimum frequency
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        initialDelay: const Duration(minutes: 15), // Start after 15 minutes
      );
      
      print('✅ Periodic notification task registered');
      
      // Register one-off task untuk test (akan jalan setelah 1 menit)
      await Workmanager().registerOneOffTask(
        'test_notification_task',
        'test_notification_task',
        initialDelay: const Duration(minutes: 1),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
      
      print('✅ Test notification task registered (will run in 1 minute)');
      
    } catch (e) {
      print('❌ Error initializing background notification service: $e');
    }
  }

  // Start background task
  Future<void> startBackgroundTask() async {
    await Workmanager().registerOneOffTask(
      _taskName,
      _taskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }

  // Stop background task
  Future<void> stopBackgroundTask() async {
    await Workmanager().cancelAll();
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true if not set
    return prefs.getBool('notifications_enabled') ?? true;
  }

  // Get enabled categories from preferences
  Future<List<String>> getEnabledCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final enabledCategories = <String>[];

    for (final category in _availableCategories) {
      final isEnabled = prefs.getBool('notif_category_$category') ?? false;
      if (isEnabled) {
        enabledCategories.add(category);
      }
    }

    // If no categories are enabled, return all categories
    if (enabledCategories.isEmpty) {
      return _availableCategories;
    }

    return enabledCategories;
  }

  // Enable/disable notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);

    if (enabled) {
      // Re-initialize to register tasks
      await initialize();
      print('✅ Notifications enabled, background tasks registered');
    } else {
      await stopBackgroundTask();
      await _notificationService.cancelAllNotifications();
      print('⚠️ Notifications disabled, background tasks cancelled');
    }
  }

  // Get last notification time
  Future<DateTime?> getLastNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('last_notification_time');
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  // Set last notification time
  Future<void> setLastNotificationTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_notification_time', time.millisecondsSinceEpoch);
  }

  // Check if enough time has passed since last notification
  Future<bool> shouldSendNotification() async {
    final lastTime = await getLastNotificationTime();
    if (lastTime == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastTime);

    // Don't send notification if less than 2 hours have passed
    return difference.inHours >= 2;
  }

  // Get articles by specific category
  Future<List<Article>> getArticlesByCategory(String category) async {
    try {
      final articles = await _articleRepository.getArticlesByCategory(
        category,
        forceRefresh: true,
        page: 1,
        pageSize: 10,
      );

      // Shuffle and take first 3 articles
      final random = Random();
      articles.shuffle(random);
      return articles.take(3).toList();
    } catch (e) {
      print('Error fetching articles for category $category: $e');
      return [];
    }
  }

  // Get trending articles from enabled categories
  Future<List<Article>> getTrendingArticles() async {
    try {
      final enabledCategories = await getEnabledCategories();
      if (enabledCategories.isEmpty) return [];

      // Pick a random category
      final random = Random();
      final category =
          enabledCategories[random.nextInt(enabledCategories.length)];

      return await getArticlesByCategory(category);
    } catch (e) {
      print('Error fetching trending articles: $e');
      return [];
    }
  }

  // Get display name for category
  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'HYPE':
        return 'Hype';
      case 'OLAHRAGA':
        return 'Olahraga';
      case 'EKBIS':
        return 'Ekonomi & Bisnis';
      case 'MEGAPOLITAN':
        return 'Megapolitan';
      case 'DAERAH':
        return 'Daerah';
      case 'NASIONAL':
        return 'Nasional';
      case 'INTERNASIONAL':
        return 'Internasional';
      default:
        return category;
    }
  }

  // Send trending notification with category-based articles
  Future<void> sendTrendingNotification() async {
    if (!await areNotificationsEnabled()) return;
    if (!await shouldSendNotification()) return;

    final enabledCategories = await getEnabledCategories();
    if (enabledCategories.isEmpty) return;

    final random = Random();
    final category =
        enabledCategories[random.nextInt(enabledCategories.length)];
    final articles = await getArticlesByCategory(category);
    if (articles.isEmpty) return;

    final article = articles[random.nextInt(articles.length)];
    final categoryName = _getCategoryDisplayName(category);

    final title = 'Trending in $categoryName';
    final body = article.title.length > 100
        ? '${article.title.substring(0, 100)}...'
        : article.title;

    await _notificationService.showTrendingNotification(
      title,
      body,
      payload: article.url,
    );

    await setLastNotificationTime(DateTime.now());
  }

  // Send breaking news notification for specific category
  Future<void> sendBreakingNewsNotification(Article article, String category) async {
    if (!await areNotificationsEnabled()) return;

    // Check if category notification is enabled
    final prefs = await SharedPreferences.getInstance();
    final categoryEnabled = prefs.getBool('notif_category_$category') ?? false;

    if (!categoryEnabled) return;

    final categoryName = _getCategoryDisplayName(category);
    final title = 'Breaking: $categoryName';
    final body = article.title.length > 100
        ? '${article.title.substring(0, 100)}...'
        : article.title;

    await _notificationService.showBreakingNewsNotification(
      title,
      body,
      payload: article.url,
    );
  }

  // Send recommendation notification with category-based articles
  Future<void> sendRecommendationNotification(Article article, String category) async {
    if (!await areNotificationsEnabled()) return;
    if (!await shouldSendNotification()) return;

    // Check if category notification is enabled
    final prefs = await SharedPreferences.getInstance();
    final categoryEnabled = prefs.getBool('notif_category_$category') ?? false;

    if (!categoryEnabled) return;

    final categoryName = _getCategoryDisplayName(category);
    final title = 'New in $categoryName';
    final body = article.title.length > 100
        ? '${article.title.substring(0, 100)}...'
        : article.title;

    await _notificationService.showRecommendationNotification(
      title,
      body,
      payload: article.url,
    );

    await setLastNotificationTime(DateTime.now());
  }

  // Send category-specific notification
  Future<void> sendCategoryNotification(String category) async {
    if (!await areNotificationsEnabled()) return;
    if (!await shouldSendNotification()) return;

    // Check if category notification is enabled
    final prefs = await SharedPreferences.getInstance();
    final categoryEnabled = prefs.getBool('notif_category_$category') ?? false;

    if (!categoryEnabled) return;

    final articles = await getArticlesByCategory(category);
    if (articles.isEmpty) return;

    final random = Random();
    final article = articles[random.nextInt(articles.length)];
    final categoryName = _getCategoryDisplayName(category);

    // Determine notification type based on category
    if (category == 'NASIONAL' || category == 'INTERNASIONAL') {
      final title = 'Breaking: $categoryName';
      final body = article.title.length > 100
          ? '${article.title.substring(0, 100)}...'
          : article.title;
      await _notificationService.showBreakingNewsNotification(
        title,
        body,
        payload: article.url,
      );
    } else if (category == 'EKBIS') {
      final title = 'Trending in $categoryName';
      final body = article.title.length > 100
          ? '${article.title.substring(0, 100)}...'
          : article.title;
      await _notificationService.showTrendingNotification(
        title,
        body,
        payload: article.url,
      );
    } else {
      final title = 'New in $categoryName';
      final body = article.title.length > 100
          ? '${article.title.substring(0, 100)}...'
          : article.title;
      await _notificationService.showRecommendationNotification(
        title,
        body,
        payload: article.url,
      );
    }

    await setLastNotificationTime(DateTime.now());
  }
}

// Callback function for background tasks
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔄 Background task started: $task');
    
    try {
      // Initialize services (important in background isolate)
      final notificationManager = NotificationManager();
      await notificationManager.initialize();
      
      final notificationService = NotificationService();
      await notificationService.init();
      
      final random = Random();
      
      // Check if notifications are enabled
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('notifications_enabled') ?? true;
      
      if (!isEnabled) {
        print('⚠️ Notifications disabled, skipping task');
        return Future.value(true);
      }
      
      print('✅ Notifications enabled, proceeding with task');
      
      // List semua kategori notifikasi (kecuali yang memerlukan VideoProvider di background)
      final allCategories = NotificationCategory.values.where((cat) {
        // Untuk background, skip video notifications yang kompleks
        // Tapi kita bisa coba semua karena NotificationManager sudah handle
        return true;
      }).toList();
      
      switch (task) {
        case 'backgroundNotificationTask':
        case 'periodicNotificationTask':
        case 'test_notification_task':
          print('📢 Sending periodic notification...');
          
          // Untuk test task, kirim notifikasi langsung
          if (task == 'test_notification_task') {
            // Coba kirim notifikasi berita penting untuk test
            await notificationManager.sendNotificationByCategory(
              NotificationCategory.beritaPenting,
            );
            print('✅ Test notification sent');
          } else {
            // Untuk periodic task, cek apakah sudah cukup waktu sejak notifikasi terakhir
            final lastTime = prefs.getInt('last_notification_time');
            final now = DateTime.now();
            
            if (lastTime != null) {
              final lastNotificationTime = DateTime.fromMillisecondsSinceEpoch(lastTime);
              final hoursSinceLastNotification = now.difference(lastNotificationTime).inHours;
              
              // Hanya kirim jika sudah lebih dari 2 jam
              if (hoursSinceLastNotification < 2) {
                print('⏰ Too soon since last notification (${hoursSinceLastNotification}h), skipping');
                return Future.value(true);
              }
            }
            
            // Pilih kategori random untuk dikirim
            if (allCategories.isNotEmpty) {
              // Exclude artikel24Jam dari periodic (hanya untuk daily task)
              final availableCategories = allCategories.where((cat) => 
                cat != NotificationCategory.artikel24Jam
              ).toList();
              
              if (availableCategories.isNotEmpty) {
                final selectedCategory = availableCategories[random.nextInt(availableCategories.length)];
                print('📢 Sending notification: $selectedCategory');
                await notificationManager.sendNotificationByCategory(selectedCategory);
                await prefs.setInt('last_notification_time', now.millisecondsSinceEpoch);
                print('✅ Notification sent successfully');
              }
            }
          }
          break;
          
        case 'daily_24hour_notification':
          print('📢 Sending 24-hour article notification...');
          // Kirim notifikasi artikel 24 jam
          await notificationManager.sendNotificationByCategory(NotificationCategory.artikel24Jam);
          print('✅ 24-hour notification sent');
          break;
          
        default:
          print('⚠️ Unknown task: $task');
      }

      return Future.value(true);
    } catch (e, stackTrace) {
      print('❌ Background task error: $e');
      print('Stack trace: $stackTrace');
      return Future.value(false);
    }
  });
}