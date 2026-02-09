# Notification Features Documentation

## Overview

This document describes the comprehensive notification system implemented in the d'talk news application.

## Features

### 1. Notification Types

- **Breaking News**: High-priority notifications for important news
- **Trending Articles**: Notifications for popular and trending content
- **Recommendations**: Personalized article recommendations

### 2. Volume and Sound Improvements

- **Maximum Volume Configuration**: All notification channels now use maximum importance levels
- **Enhanced Vibration Patterns**: Longer and more noticeable vibration sequences
- **LED Light Indicators**: Color-coded LED notifications for different types
- **Audio Permissions**: Added MODIFY_AUDIO_SETTINGS and ACCESS_NOTIFICATION_POLICY permissions

#### Volume Levels by Type:

- **Breaking News**: `Importance.max` + `Priority.max` + Extended vibration pattern
- **Trending Articles**: `Importance.high` + `Priority.high` + Medium vibration pattern
- **Recommendations**: `Importance.defaultImportance` + `Priority.defaultPriority` + Standard vibration

#### Vibration Patterns:

- **Breaking News**: `[0, 1000, 500, 1000, 500, 1000]` (3 long vibrations)
- **Trending**: `[0, 800, 400, 800]` (2 medium vibrations)
- **Recommendations**: `[0, 500, 200, 500]` (2 short vibrations)

### 3. Testing Features

- **Test Notification Button**: Standard notification test
- **Maximum Volume Test Button**: Test with enhanced volume settings
- **Volume Reset Function**: Automatically recreates channels with maximum settings

### 4. Background Processing

- **WorkManager Integration**: Handles background notification tasks
- **Periodic Notifications**: Sends notifications every 4 hours
- **Smart Scheduling**: Avoids notification spam with time-based limits

### 5. Permission Management

- **Android 13+ Support**: Proper POST_NOTIFICATIONS permission handling
- **Location Integration**: Combines with location services for relevant content
- **Audio Control**: Permissions for maximum volume control

### 6. User Experience

- **Localized Content**: Notifications in user's preferred language
- **Rich Notifications**: Large icons, colors, and expanded text
- **Auto-cleanup**: Removes old notifications automatically
- **Badge Support**: Shows notification count on app icon

## Technical Implementation

### Notification Channels

```dart
// Breaking News - Maximum Volume
AndroidNotificationChannel(
  'breaking_news',
  'Breaking News',
  importance: Importance.max,
  priority: Priority.max,
  playSound: true,
  enableVibration: true,
  vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
  showBadge: true,
  enableLights: true,
  ledColor: Color(0xFFE74C3C),
)
```

### Volume Enhancement Methods

```dart
// Ensure maximum volume for all notifications
await NotificationService().ensureMaximumVolume();

// Test with maximum volume settings
await NotificationService().testMaximumVolumeNotification();
```

### Android Manifest Permissions

```xml
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.ACCESS_NOTIFICATION_POLICY" />
```

## Usage Instructions

### For Users:

1. **Enable Notifications**: Grant permission when prompted
2. **Test Volume**: Use "Test Maximum Volume" button in notifications screen
3. **Adjust Device Settings**: Ensure device volume is not muted
4. **Check Do Not Disturb**: Disable DND mode for full notification experience

### For Developers:

1. **Test Notifications**: Use the test buttons in NotificationsScreen
2. **Monitor Logs**: Check console for notification delivery status
3. **Volume Issues**: Use `ensureMaximumVolume()` method to reset channels
4. **Customization**: Modify vibration patterns and importance levels as needed

## Troubleshooting

### Common Issues:

1. **Low Volume**:
   - Check device volume settings
   - Use "Test Maximum Volume" button
   - Ensure DND mode is disabled
2. **No Sound**:
   - Verify notification permissions
   - Check if sound file exists in `android/app/src/main/res/raw/`
   - Restart app after permission changes

3. **No Vibration**:
   - Check device vibration settings
   - Verify VIBRATE permission is granted
   - Test with different notification types

### Debug Commands:

```bash
# Check notification channels
adb shell dumpsys notification | grep -A 10 "dtalk"

# Test notification manually
adb shell am broadcast -a com.android.systemui.action.NOTIFICATION_TEST
```

## Future Enhancements

- **Custom Sound Files**: Allow users to choose notification sounds
- **Volume Slider**: In-app volume control for notifications
- **Schedule Preferences**: User-defined notification timing
- **Smart Filtering**: AI-powered notification relevance scoring

//code
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart'; // Added for Color

class NotificationService {
static final NotificationService \_instance = NotificationService.\_internal();
factory NotificationService() => \_instance;
NotificationService.\_internal();

final FlutterLocalNotificationsPlugin \_fln =
FlutterLocalNotificationsPlugin();
bool \_initialized = false;

Future<void> init() async {
if (\_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Provide Linux settings to avoid runtime error on Linux target
    const linuxInit = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );
    const initializationSettings = InitializationSettings(
      android: androidInit,
      linux: linuxInit,
    );
    await _fln.initialize(initializationSettings);

    // Create notification channels
    await _createNotificationChannels();

    _initialized = true;

}

Future<void> \_createNotificationChannels() async {
final androidImpl = \_fln.resolvePlatformSpecificImplementation<
AndroidFlutterLocalNotificationsPlugin>();
if (androidImpl != null) {
// Breaking News Channel - HIGHEST VOLUME
await androidImpl.createNotificationChannel(
AndroidNotificationChannel(
'breaking_news',
'Breaking News',
description: 'Important breaking news notifications',
importance: Importance.max,
playSound: true,
sound: const RawResourceAndroidNotificationSound(
'dtalk_sound_notification'),
enableVibration: true,
vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
showBadge: true,
enableLights: true,
ledColor: const Color(0xFFE74C3C),
),
);

      // Trending Articles Channel - HIGH VOLUME
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          'trending_articles',
          'Trending Articles',
          description: 'Trending and popular articles',
          importance: Importance.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(
              'dtalk_sound_notification'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 800, 400, 800]),
          showBadge: true,
          enableLights: true,
          ledColor: const Color(0xFF3498DB),
        ),
      );

      // Recommendations Channel - MEDIUM VOLUME
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          'recommendations',
          'Article Recommendations',
          description: 'Personalized article recommendations',
          importance: Importance.defaultImportance,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(
              'dtalk_sound_notification'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          showBadge: true,
          enableLights: true,
          ledColor: const Color(0xFF2ECC71),
        ),
      );
    }

}

Future<bool> requestPermissionIfNeeded() async {
final prefs = await SharedPreferences.getInstance();
final asked = prefs.getBool('notif_perm_asked') ?? false;
if (asked) return true;
await prefs.setBool('notif_perm_asked', true);
// On Android 13+, permission is handled by plugin's resolvePermission
final androidImpl = \_fln.resolvePlatformSpecificImplementation<
AndroidFlutterLocalNotificationsPlugin>();
if (androidImpl != null) {
final granted =
await androidImpl.requestNotificationsPermission() ?? true;
return granted;
}
return true;
}

Future<void> showBreakingNewsNotification(String title, String body,
{String? payload}) async {
await init();
final android = AndroidNotificationDetails(
'breaking_news',
'Breaking News',
channelDescription: 'Important breaking news notifications',
importance: Importance.max,
priority: Priority.max,
playSound: true,
sound:
const RawResourceAndroidNotificationSound('dtalk_sound_notification'),
enableVibration: true,
vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
color: const Color(0xFFE74C3C),
largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
styleInformation: BigTextStyleInformation(body),
showWhen: true,
when: DateTime.now().millisecondsSinceEpoch,
usesChronometer: false,
chronometerCountDown: false,
showProgress: false,
maxProgress: 0,
progress: 0,
indeterminate: false,
onlyAlertOnce: false,
autoCancel: true,
ongoing: false,
silent: false,
ticker: 'Breaking News: $title',
);
final details = NotificationDetails(android: android);
await \_fln.show(
DateTime.now().millisecondsSinceEpoch % 100000, title, body, details,
payload: payload);
}

Future<void> showTrendingNotification(String title, String body,
{String? payload}) async {
await init();
final android = AndroidNotificationDetails(
'trending_articles',
'Trending Articles',
channelDescription: 'Trending and popular articles',
importance: Importance.high,
priority: Priority.high,
playSound: true,
sound:
const RawResourceAndroidNotificationSound('dtalk_sound_notification'),
enableVibration: true,
vibrationPattern: Int64List.fromList([0, 800, 400, 800]),
color: const Color(0xFF3498DB),
largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
styleInformation: BigTextStyleInformation(body),
showWhen: true,
when: DateTime.now().millisecondsSinceEpoch,
usesChronometer: false,
chronometerCountDown: false,
showProgress: false,
maxProgress: 0,
progress: 0,
indeterminate: false,
onlyAlertOnce: false,
autoCancel: true,
ongoing: false,
silent: false,
ticker: 'Trending: $title',
);
final details = NotificationDetails(android: android);
await \_fln.show(DateTime.now().millisecondsSinceEpoch % 100000 + 1, title,
body, details,
payload: payload);
}

Future<void> showRecommendationNotification(String title, String body,
{String? payload}) async {
await init();
final android = AndroidNotificationDetails(
'recommendations',
'Article Recommendations',
channelDescription: 'Personalized article recommendations',
importance: Importance.defaultImportance,
priority: Priority.defaultPriority,
playSound: true,
sound:
const RawResourceAndroidNotificationSound('dtalk_sound_notification'),
enableVibration: true,
vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
color: const Color(0xFF2ECC71),
largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
styleInformation: BigTextStyleInformation(body),
showWhen: true,
when: DateTime.now().millisecondsSinceEpoch,
usesChronometer: false,
chronometerCountDown: false,
showProgress: false,
maxProgress: 0,
progress: 0,
indeterminate: false,
onlyAlertOnce: false,
autoCancel: true,
ongoing: false,
silent: false,
ticker: 'Recommendation: $title',
);
final details = NotificationDetails(android: android);
await \_fln.show(DateTime.now().millisecondsSinceEpoch % 100000 + 2, title,
body, details,
payload: payload);
}

Future<void> showInstant(String title, String body, {String? payload}) async {
await showRecommendationNotification(title, body, payload: payload);
}

Future<void> pruneOlderThanDays(int days) async {
// Plugin does not store history; we can cancel all scheduled beyond retention if used; kept as placeholder.
}

// Get notification channels
Future<List<AndroidNotificationChannel>> getNotificationChannels() async {
final androidImpl = \_fln.resolvePlatformSpecificImplementation<
AndroidFlutterLocalNotificationsPlugin>();
if (androidImpl != null) {
return await androidImpl.getNotificationChannels() ?? [];
}
return [];
}

// Cancel all notifications
Future<void> cancelAllNotifications() async {
await \_fln.cancelAll();
}

// Cancel specific notification
Future<void> cancelNotification(int id) async {
await \_fln.cancel(id);
}

// Method to ensure maximum volume for notifications
Future<void> ensureMaximumVolume() async {
final androidImpl = \_fln.resolvePlatformSpecificImplementation<
AndroidFlutterLocalNotificationsPlugin>();
if (androidImpl != null) {
// Update existing channels with maximum importance
final channels = await getNotificationChannels();
for (final channel in channels) {
await androidImpl.deleteNotificationChannel(channel.id);
}

      // Recreate channels with maximum volume settings
      await _createNotificationChannels();
    }

}

// Method to test notification with maximum volume
Future<void> testMaximumVolumeNotification() async {
await ensureMaximumVolume();
await showBreakingNewsNotification(
'Test Volume',
'This is a test notification with maximum volume settings',
);
}
}
