import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service untuk mengelola feedback modal timing dan email submission
class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  // EmailJS Configuration from .env
  String get _emailJsServiceId => dotenv.env['EMAILJS_SERVICE_ID'] ?? '';
  String get _emailJsTemplateId => dotenv.env['EMAILJS_TEMPLATE_ID'] ?? '';
  String get _emailJsPublicKey => dotenv.env['EMAILJS_PUBLIC_KEY'] ?? '';
  String get _emailJsUrl => dotenv.env['EMAILJS_URL'] ?? 'https://api.emailjs.com/api/v1.0/email/send';
  String get _targetEmail => dotenv.env['FEEDBACK_TARGET_EMAIL'] ?? '';

  // Tracking
  DateTime? _appStartTime;
  
  // Preferences keys
  static const String _feedbackSubmittedKey = 'feedback_submitted';
  static const String _feedbackCountKey = 'feedback_count';
  static const String _feedbackWeekKey = 'feedback_week';
  static const String _savedNameKey = 'feedback_saved_name';
  static const String _savedUmurKey = 'feedback_saved_umur';
  static const String _savedProfesiKey = 'feedback_saved_profesi';
  
  // Limits
  static const int _maxFeedbackPerWeek = 3;
  static const Duration _minimumTimeInApp = Duration(minutes: 3);

  /// Start tracking app usage time
  void startTracking() {
    _appStartTime = DateTime.now();
    debugPrint('[FeedbackService] Started tracking at $_appStartTime');
  }

  /// Get current week number of year
  int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysDiff = date.difference(firstDayOfYear).inDays;
    return ((daysDiff + firstDayOfYear.weekday) / 7).ceil();
  }

  /// Check if feedback limit reset needed (weekly)
  Future<void> _checkAndResetWeeklyLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final currentWeek = _getWeekOfYear(DateTime.now());
    final savedWeek = prefs.getInt(_feedbackWeekKey) ?? 0;
    
    if (currentWeek != savedWeek) {
      await prefs.setInt(_feedbackCountKey, 0);
      await prefs.setInt(_feedbackWeekKey, currentWeek);
      debugPrint('[FeedbackService] Weekly limit reset');
    }
  }

  /// Check if user can submit more feedback
  Future<bool> canSubmitFeedback() async {
    await _checkAndResetWeeklyLimit();
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_feedbackCountKey) ?? 0;
    return count < _maxFeedbackPerWeek;
  }

  /// Get remaining feedback count
  Future<int> getRemainingFeedbackCount() async {
    await _checkAndResetWeeklyLimit();
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_feedbackCountKey) ?? 0;
    return _maxFeedbackPerWeek - count;
  }

  /// Check if feedback modal should be shown (3 min + not submitted yet)
  Future<bool> shouldShowFeedback() async {
    if (await hasFeedbackBeenSubmitted()) {
      debugPrint('[FeedbackService] Feedback already submitted');
      return false;
    }

    if (_appStartTime == null) {
      debugPrint('[FeedbackService] App start time not set');
      return false;
    }

    final timeInApp = DateTime.now().difference(_appStartTime!);
    final hasMinimumTime = timeInApp >= _minimumTimeInApp;
    debugPrint('[FeedbackService] Time in app: ${timeInApp.inMinutes} min, Show: $hasMinimumTime');
    return hasMinimumTime;
  }

  /// Check if feedback has been submitted before (for modal)
  Future<bool> hasFeedbackBeenSubmitted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_feedbackSubmittedKey) ?? false;
  }

  /// Mark feedback as submitted (hides modal)
  Future<void> markFeedbackSubmitted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_feedbackSubmittedKey, true);
    debugPrint('[FeedbackService] Feedback marked as submitted (modal hidden)');
  }

  /// Get saved user profile data
  Future<Map<String, String>> getSavedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'nama': prefs.getString(_savedNameKey) ?? '',
      'umur': prefs.getString(_savedUmurKey) ?? '',
      'profesi': prefs.getString(_savedProfesiKey) ?? '',
    };
  }

  /// Check if user has saved profile
  Future<bool> hasUserProfile() async {
    final data = await getSavedUserData();
    return data['nama']!.isNotEmpty;
  }

  /// Save user profile data
  Future<void> saveUserData(String nama, String umur, String profesi) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedNameKey, nama);
    await prefs.setString(_savedUmurKey, umur);
    await prefs.setString(_savedProfesiKey, profesi);
    debugPrint('[FeedbackService] User data saved');
  }

  /// Send feedback via EmailJS
  Future<bool> sendFeedback({
    required String nama,
    required String umur,
    required String profesi,
    required int rating,
    required String peningkatan,
    required String fiturDiinginkan,
    required String deskripsiIdeal,
  }) async {
    // Check limit
    if (!await canSubmitFeedback()) {
      debugPrint('[FeedbackService] Weekly limit reached');
      return false;
    }

    debugPrint('[FeedbackService] Sending feedback...');
    debugPrint('[FeedbackService] Service: $_emailJsServiceId, Template: $_emailJsTemplateId');

    if (_emailJsServiceId.isEmpty || _emailJsTemplateId.isEmpty || _emailJsPublicKey.isEmpty) {
      debugPrint('[FeedbackService] EmailJS not configured');
      await _incrementFeedbackCount();
      await markFeedbackSubmitted();
      await saveUserData(nama, umur, profesi);
      return true;
    }

    try {
      final requestBody = {
        'service_id': _emailJsServiceId,
        'template_id': _emailJsTemplateId,
        'user_id': _emailJsPublicKey,
        'template_params': {
          'to_email': _targetEmail,
          'from_name': nama,
          'user_name': nama,
          'user_age': umur,
          'user_profession': profesi,
          'app_rating': rating.toString(),
          'improvements': peningkatan,
          'desired_features': fiturDiinginkan,
          'ideal_description': deskripsiIdeal,
          'submitted_at': DateTime.now().toIso8601String(),
          'reply_to': _targetEmail,
        },
      };

      final response = await http.post(
        Uri.parse(_emailJsUrl),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('[FeedbackService] Response: ${response.statusCode}');

      await _incrementFeedbackCount();
      await markFeedbackSubmitted();
      await saveUserData(nama, umur, profesi);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[FeedbackService] Error: $e');
      await _incrementFeedbackCount();
      await markFeedbackSubmitted();
      await saveUserData(nama, umur, profesi);
      return true;
    }
  }

  /// Increment feedback count
  Future<void> _incrementFeedbackCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_feedbackCountKey) ?? 0;
    await prefs.setInt(_feedbackCountKey, count + 1);
    debugPrint('[FeedbackService] Feedback count: ${count + 1}/$_maxFeedbackPerWeek');
  }

  /// Reset for testing
  Future<void> resetFeedbackStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_feedbackSubmittedKey);
    _appStartTime = DateTime.now();
    debugPrint('[FeedbackService] Status reset (for resubmit from fullscreen)');
  }

  /// Full reset for testing
  Future<void> fullReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_feedbackSubmittedKey);
    await prefs.remove(_feedbackCountKey);
    await prefs.remove(_feedbackWeekKey);
    await prefs.remove(_savedNameKey);
    await prefs.remove(_savedUmurKey);
    await prefs.remove(_savedProfesiKey);
    _appStartTime = DateTime.now();
    debugPrint('[FeedbackService] Full reset');
  }
}
