import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  
  // Callback untuk tap notifikasi
  static Function(String?)? _onNotificationTap;

  /// Inisialisasi Service
  Future<void> init({Function(String?)? onTap}) async {
    if (_initialized) {
      if (onTap != null) _onNotificationTap = onTap;
      return;
    }

    _onNotificationTap = onTap;

    // 1. Setup Android Settings
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // 2. Setup iOS Settings
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 3. Setup Linux Settings
    const linuxInit = LinuxInitializationSettings(defaultActionName: 'Open');

    final initializationSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      linux: linuxInit,
    );

    // 4. Initialize Plugin
    await _fln.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (_onNotificationTap != null) {
          _onNotificationTap!(response.payload);
        }
      },
    );

    // 5. Create Channels
    // Hapus channel lama (opsional, untuk kebersihan)
    await _deleteOldChannels(); 
    // Buat channel baru dengan ID baru agar setting suara tereset
    await _createNotificationChannels();

    // 6. Request Permission
    await requestPermissionIfNeeded();

    _initialized = true;
    debugPrint("NotificationService initialized successfully");
  }

  /// Menghapus channel versi lama (opsional)
  Future<void> _deleteOldChannels() async {
    final androidImpl = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.deleteNotificationChannel('breaking_news');
      await androidImpl.deleteNotificationChannel('trending_articles');
      await androidImpl.deleteNotificationChannel('recommendations');
    }
  }

  /// Membuat Channel Notifikasi (Android)
  Future<void> _createNotificationChannels() async {
    final androidImpl = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      // NOTE: Kita gunakan '_v2' pada ID channel untuk memaksa Android 
      // membaca ulang konfigurasi suara jika sebelumnya user menginstall app 
      // saat konfigurasi masih salah/silent.
      final List<AndroidNotificationChannel> channels = [
        AndroidNotificationChannel(
          'breaking_news_v2', // ID BARU
          'Breaking News',
          description: 'Important breaking news notifications',
          importance: Importance.max, 
          playSound: true,
          // WAJIB: File 'owrite_sound_notification.mp3' harus ada di folder:
          // android/app/src/main/res/raw/
          sound: const RawResourceAndroidNotificationSound('owrite_sound_notification'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
          showBadge: true,
          enableLights: true,
          ledColor: const Color(0xFFE74C3C),
        ),
        AndroidNotificationChannel(
          'trending_articles_v2', // ID BARU
          'Trending Articles',
          description: 'Trending and popular articles',
          importance: Importance.high, 
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('owrite_sound_notification'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 800, 400, 800]),
          showBadge: true,
          enableLights: true,
          ledColor: const Color(0xFF3498DB),
        ),
        AndroidNotificationChannel(
          'recommendations_v2', // ID BARU
          'Article Recommendations',
          description: 'Personalized article recommendations',
          importance: Importance.defaultImportance, 
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('owrite_sound_notification'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          showBadge: true,
          enableLights: true,
          ledColor: const Color(0xFF2ECC71),
        ),
      ];

      for (var channel in channels) {
        await androidImpl.createNotificationChannel(channel);
      }
    }
  }

  Future<bool> requestPermissionIfNeeded() async {
    if (Platform.isAndroid) {
      final androidImpl = _fln.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      final bool? granted = await androidImpl?.requestNotificationsPermission();
      return granted ?? false;
    }
    return true; 
  }

  // --- COMPATIBILITY METHODS ---
  Future<void> showBreakingNewsNotification(String title, String body, {String? payload}) async {
    await showNotificationByCategory(title, body, 'breaking_news', payload: payload);
  }

  Future<void> showTrendingNotification(String title, String body, {String? payload}) async {
    await showNotificationByCategory(title, body, 'trending_articles', payload: payload);
  }

  Future<void> showRecommendationNotification(String title, String body, {String? payload}) async {
    await showNotificationByCategory(title, body, 'recommendations', payload: payload);
  }

  Future<void> cancelAllNotifications() async {
    await _fln.cancelAll();
  }
  // ----------------------------------------------------

  /// Logika Utama: Menampilkan Notifikasi berdasarkan Kategori
  Future<void> showNotificationByCategory(
      String title, String body, String category,
      {String? payload}) async {
    
    if (!_initialized) await init();

    final cat = category.toLowerCase().trim();
    debugPrint("Triggering notification for category: $cat");

    try {
      switch (cat) {
        case 'breaking_news':
        case 'breaking':
        case 'news':
        case 'high':
          await _showSpecificNotification(
            id: 100, 
            channelId: 'breaking_news_v2', // Gunakan ID V2
            channelName: 'Breaking News',
            title: title,
            body: body,
            color: const Color(0xFFE74C3C),
            payload: payload,
            importance: Importance.max,
            priority: Priority.max,
          );
          break;

        case 'trending_articles':
        case 'trending':
        case 'popular':
          await _showSpecificNotification(
            id: 200, 
            channelId: 'trending_articles_v2', // Gunakan ID V2
            channelName: 'Trending Articles',
            title: title,
            body: body,
            color: const Color(0xFF3498DB),
            payload: payload,
            importance: Importance.high,
            priority: Priority.high,
          );
          break;

        default:
          await _showSpecificNotification(
            id: 300, 
            channelId: 'recommendations_v2', // Gunakan ID V2
            channelName: 'Article Recommendations',
            title: title,
            body: body,
            color: const Color(0xFF2ECC71),
            payload: payload,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          );
          break;
      }
    } catch (e) {
      debugPrint("ERROR SHOWING NOTIFICATION: $e");
    }
  }

  Future<void> _showSpecificNotification({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required Color color,
    required Importance importance,
    required Priority priority,
    String? payload,
  }) async {
    
    final uniqueId = id + (DateTime.now().millisecondsSinceEpoch % 1000);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: priority,
      playSound: true,
      // Pastikan nama file SAMA PERSIS dengan di folder raw (tanpa ekstensi)
      sound: const RawResourceAndroidNotificationSound('owrite_sound_notification'),
      enableVibration: true,
      color: color,
      icon: '@mipmap/ic_launcher', 
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _fln.show(uniqueId, title, body, details, payload: payload);
  }

  Future<void> testNotification() async {
    await showBreakingNewsNotification(
      'Test Suara Notifikasi', 
      'Test notifikasi diaktifkan.', 
    );
  }
}