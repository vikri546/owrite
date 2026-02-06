import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import '../repositories/article_repository.dart';
import 'display_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  final ArticleRepository _articleRepository = ArticleRepository();
  
  bool _notificationsEnabled = true;
  bool _isTestingNotification = false;
  
  // Notification category toggles
  Map<String, bool> _categoryToggles = {};

  // Available notification categories with display names
  static const List<Map<String, String>> _notificationCategories = [
    {'key': 'berita_penting', 'title': 'Berita Penting', 'subtitle': 'Notifikasi berita penting dan breaking news'},
    {'key': 'berita_terbaru', 'title': 'Berita Terbaru', 'subtitle': 'Notifikasi artikel terbaru hari ini'},
    {'key': 'headline', 'title': 'Headline', 'subtitle': 'Berita yang mungkin kamu suka dari headline'},
    {'key': 'berita_pilihan', 'title': 'Berita Pilihan', 'subtitle': 'Rekomendasi berita pilihan editor'},
    {'key': 'baca_kembali', 'title': 'Baca Kembali', 'subtitle': 'Pengingat untuk artikel dari history'},
    {'key': 'shorts', 'title': 'Shorts Video', 'subtitle': 'Notifikasi shorts terbaru'},
    {'key': 'video', 'title': 'Video Terbaru', 'subtitle': 'Notifikasi video full terbaru'},
    {'key': 'artikel_24jam', 'title': 'Ringkasan Harian', 'subtitle': 'Artikel yang belum dibaca hari ini'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final notifEnabled = prefs.getBool('notifications_enabled') ?? true;
    
    // Load category toggles
    final Map<String, bool> toggles = {};
    for (final cat in _notificationCategories) {
      toggles[cat['key']!] = prefs.getBool('notif_cat_${cat['key']}') ?? true;
    }
    
    if (mounted) {
      setState(() {
        _notificationsEnabled = notifEnabled;
        _categoryToggles = toggles;
      });
    }
  }

  Future<void> _toggleMainNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    
    // If enabling, set all categories to enabled by default
    if (value) {
      for (final cat in _notificationCategories) {
        await prefs.setBool('notif_cat_${cat['key']}', true);
        _categoryToggles[cat['key']!] = true;
      }
    }
    
    if (mounted) {
      setState(() {
        _notificationsEnabled = value;
      });
    }
  }

  Future<void> _toggleCategory(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_cat_$key', value);
    
    if (mounted) {
      setState(() {
        _categoryToggles[key] = value;
      });
    }
  }

  Future<void> _sendTestNotification() async {
    if (_isTestingNotification) return;
    
    setState(() {
      _isTestingNotification = true;
    });

    try {
      final articles = await _articleRepository.getArticlesByCategory(
        null, 
        page: 1, 
        pageSize: 20,
      );
      
      if (articles.isEmpty) {
        _showSnackBar('Tidak ada artikel tersedia', isError: true);
        return;
      }

      final randomArticle = articles[Random().nextInt(articles.length)];

      await _notificationService.showBreakingNewsNotification(
        'Test Notifikasi Owrite',
        randomArticle.title.length > 100 
            ? '${randomArticle.title.substring(0, 100)}...' 
            : randomArticle.title,
        payload: jsonEncode({
          'type': 'article',
          'id': randomArticle.id,
          'url': randomArticle.url,
        }),
      );

      _showSnackBar('Notifikasi terkirim! Cek notification tray.');
    } catch (e) {
      debugPrint('Error sending test notification: $e');
      _showSnackBar('Gagal mengirim notifikasi', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isTestingNotification = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red[300] : Colors.green[300],
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    final backgroundColor = isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey[100];
    final dividerColor = isDark ? Colors.grey[800] : Colors.grey[300];
    final disabledColor = isDark ? Colors.grey[700] : Colors.grey[400];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: textColor,
            fontFamily: 'Arimo',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== NOTIFICATION SECTION =====
            _buildSectionHeader('Notifikasi', textColor),
            const SizedBox(height: 12),
            
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Main notification toggle
                  _buildMainToggle(isDark, textColor, subtitleColor!),
                  
                  Divider(color: dividerColor, height: 1, indent: 16, endIndent: 16),
                  
                  // Test notification button
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.science_outlined,
                        color: _notificationsEnabled ? (isDark ? const Color(0xFFCCFF00) : Colors.black) : subtitleColor,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      'Test Notifikasi',
                      style: TextStyle(
                        color: _notificationsEnabled ? textColor : disabledColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'Kirim notifikasi dengan berita acak',
                      style: TextStyle(
                        color: _notificationsEnabled ? subtitleColor : disabledColor,
                        fontSize: 13,
                      ),
                    ),
                    trailing: _isTestingNotification
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFCCFF00)),
                            ),
                          )
                        : Icon(
                            Icons.send,
                            color: _notificationsEnabled ? (isDark ? const Color(0xFFCCFF00) : Colors.black) : subtitleColor,
                          ),
                    onTap: _notificationsEnabled ? _sendTestNotification : null,
                    enabled: _notificationsEnabled,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // ===== NOTIFICATION CATEGORIES SECTION =====
            _buildSectionHeader('Kategori Notifikasi', textColor),
            const SizedBox(height: 8),
            Text(
              _notificationsEnabled 
                  ? 'Pilih kategori notifikasi yang ingin diterima'
                  : 'Aktifkan notifikasi untuk memilih kategori',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _buildCategoryToggles(isDark, textColor, subtitleColor, dividerColor!, disabledColor!),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // ===== DISPLAY SECTION =====
            _buildSectionHeader('Tampilan', textColor),
            const SizedBox(height: 12),
            
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: isDark ? Colors.amber : Colors.orange,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Pengaturan Tampilan',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'Tema, ukuran teks, dan lainnya',
                  style: TextStyle(color: subtitleColor, fontSize: 13),
                ),
                trailing: Icon(Icons.chevron_right, color: subtitleColor),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const DisplaySettingsScreen()),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 32),
            
            // ===== APP INFO SECTION =====
            _buildSectionHeader('Informasi Aplikasi', textColor),
            const SizedBox(height: 12),
            
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/images/icon-app.png', width: 56, height: 56),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Owrite', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text('Versi 7.1.3', style: TextStyle(color: subtitleColor, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        color: textColor,
        fontFamily: 'Arimo',
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildMainToggle(bool isDark, Color textColor, Color subtitleColor) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[700] : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.notifications_active_outlined,
          color: _notificationsEnabled
              ? (isDark ? const Color(0xFFCCFF00) : Colors.black)
              : subtitleColor,
          size: 24,
        ),
      ),
      title: Text(
        'Aktifkan Notifikasi',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        _notificationsEnabled ? 'Notifikasi aktif' : 'Notifikasi dinonaktifkan',
        style: TextStyle(color: subtitleColor, fontSize: 13),
      ),
      trailing: Switch(
        value: _notificationsEnabled,
        onChanged: _toggleMainNotification,
        activeColor: isDark ? const Color(0xFFCCFF00) : Colors.black,
        activeTrackColor: isDark 
            ? const Color(0xFFCCFF00).withOpacity(0.5) 
            : Colors.black.withOpacity(0.3),
      ),
    );
  }

  List<Widget> _buildCategoryToggles(bool isDark, Color textColor, Color subtitleColor, Color dividerColor, Color disabledColor) {
    final List<Widget> widgets = [];
    
    for (int i = 0; i < _notificationCategories.length; i++) {
      final cat = _notificationCategories[i];
      final key = cat['key']!;
      final isEnabled = _categoryToggles[key] ?? true;
      
      widgets.add(
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Text(
            cat['title']!,
            style: TextStyle(
              color: _notificationsEnabled ? textColor : disabledColor,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            cat['subtitle']!,
            style: TextStyle(
              color: _notificationsEnabled ? subtitleColor : disabledColor,
              fontSize: 12,
            ),
          ),
          trailing: Switch(
            value: _notificationsEnabled && isEnabled,
            onChanged: _notificationsEnabled 
                ? (value) => _toggleCategory(key, value)
                : null,
            activeColor: isDark ? const Color(0xFFCCFF00) : Colors.black,
            activeTrackColor: isDark 
                ? const Color(0xFFCCFF00).withOpacity(0.5) 
                : Colors.black.withOpacity(0.3),
          ),
        ),
      );
      
      // Add divider except for last item
      if (i < _notificationCategories.length - 1) {
        widgets.add(
          Divider(color: dividerColor, height: 1, indent: 16, endIndent: 16),
        );
      }
    }
    
    return widgets;
  }
}
