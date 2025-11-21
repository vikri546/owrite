import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/article_provider.dart';
import '../providers/language_provider.dart';
import '../utils/strings.dart';
import '../models/article.dart';
import '../screens/article_detail_screen.dart';
import '../utils/custom_page_transitions.dart';
import '../widgets/article_card.dart';
import '../services/api_service.dart';

// ---- TRASH/RECYCLE BIN MODEL ----
class TrashArticle {
  final Article article;
  final DateTime deletedAt;
  TrashArticle({required this.article, required this.deletedAt});
}

class TrashManager extends ChangeNotifier {
  final List<TrashArticle> _trashList = [];

  List<TrashArticle> get trashList {
    final now = DateTime.now();
    bool itemsRemoved = false;
    _trashList.removeWhere((a) {
      final bool expired = now.difference(a.deletedAt).inDays >= 7;
      if (expired) {
        itemsRemoved = true;
      }
      return expired;
    });
    if (itemsRemoved) {
      Future.microtask(() => notifyListeners());
    }
    return List.unmodifiable(_trashList);
  }

  void addToTrash(Article article) {
    if (_trashList.any((t) => t.article.id == article.id)) return;
    _trashList.add(TrashArticle(article: article, deletedAt: DateTime.now()));
    _trashList.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    notifyListeners();
  }
  void remove(TrashArticle trashArticle) {
    _trashList.remove(trashArticle);
    notifyListeners();
  }
  void clearAll() {
    _trashList.clear();
    notifyListeners();
  }
}

// Enum untuk status sorting
enum SortOrder { asc, desc }

// ---- MAIN NOTIFICATIONS SCREEN (MODIFIKASI TOTAL) ----
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isEditing = false;
  Set<String> _selectedArticles = {};

  SortOrder _sortOrder = SortOrder.desc;
  Set<String> _selectedCategories = {};
  List<String> _allCategories = [];

  @override
  void initState() {
    super.initState();
    _loadFilterPreferences();
    _loadCategories();
  }

  void _loadCategories() {
    _allCategories = [
      'HYPE',
      'OLAHRAGA',
      'EKBIS',
      'MEGAPOLITAN',
      'DAERAH',
      'NASIONAL',
      'INTERNASIONAL',
      'POLITIK',
      'KESEHATAN',
    ];
    _allCategories.sort();
  }

  Future<void> _loadFilterPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final categories = prefs.getStringList('notification_categories')?.toSet();
    if (mounted) {
      setState(() {
        _selectedCategories = categories ?? {};
      });
    }
    final pushCategories = prefs.getStringList('subscribed_categories')?.toSet();
    if (pushCategories == null) {
      await prefs.setStringList('subscribed_categories', _allCategories.toList());
    }
  }

  Future<void> _saveFilterPreferences(Set<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notification_categories', categories.toList());
    await prefs.setStringList('subscribed_categories', categories.toList());
    if (mounted) {
      setState(() {
        _selectedCategories = categories;
      });
    }
  }

  void _navigateToArticle(BuildContext context, Article article) {
    if (_isEditing) return;
    final heroTag = 'notif-article-${article.id}';
    Navigator.push(
      context,
      HeroDialogRoute(
        builder: (context) => ArticleDetailScreen(
          article: article,
          isBookmarked: false,
          onBookmarkToggle: () {},
          heroTag: heroTag,
        ),
      ),
    );
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      _selectedArticles.clear();
    });
  }

  void _toggleSortOrder() {
    setState(() {
      _sortOrder =
          (_sortOrder == SortOrder.desc) ? SortOrder.asc : SortOrder.desc;
    });
  }

  void _showCategoryFilterDialog() {
    final strings =
        AppStrings(context.read<LanguageProvider>().locale.languageCode);
    Set<String> tempSelected = Set.from(_selectedCategories);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[900]
                  : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              title: Text(
                strings.isEn ? 'Filter by Category' : 'Filter Kategori',
                style: const TextStyle(
                    fontFamily: 'Inter', fontWeight: FontWeight.bold),
              ),
              content: Container(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: _allCategories.map((category) {
                    final bool isChecked = tempSelected.contains(category);
                    return CheckboxListTile(
                      title: Text(category),
                      value: isChecked,
                      activeColor: const Color(0xFFE5FF10),
                      checkColor: Colors.black,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            tempSelected.add(category);
                          } else {
                            tempSelected.remove(category);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(strings.isEn ? 'Clear All' : 'Hapus Semua'),
                  onPressed: () {
                     setDialogState(() {
                       tempSelected.clear();
                     });
                  },
                ),
                TextButton(
                  child: Text(strings.isEn ? 'Cancel' : 'Batal'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                TextButton(
                  child: Text(
                    strings.isEn ? 'Apply' : 'Terapkan',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    _saveFilterPreferences(tempSelected);
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleSelection(String articleId) {
    setState(() {
      if (_selectedArticles.contains(articleId)) {
        _selectedArticles.remove(articleId);
      } else {
        _selectedArticles.add(articleId);
      }
    });
  }

  void _toggleSelectAll(List<Article> notificationArticles) {
    setState(() {
      if (_selectedArticles.length == notificationArticles.length) {
        _selectedArticles.clear();
      } else {
        _selectedArticles = notificationArticles.map((a) => a.id).toSet();
      }
    });
  }

  void _showDeleteConfirmation(List<Article> allArticles) {
    final strings =
        AppStrings(context.read<LanguageProvider>().locale.languageCode);
    final count = _selectedArticles.length;
    if (count == 0) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[900]
              : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            strings.isEn ? 'Confirm Deletion' : 'Konfirmasi Hapus',
            style: const TextStyle(
                fontFamily: 'Inter', fontWeight: FontWeight.bold),
          ),
          content: Text(
            strings.isEn
                ? 'Are you sure you want to move $count selected article${count == 1 ? '' : 's'} to the Recycle Bin?'
                : 'Anda yakin ingin memindahkan $count artikel terpilih ke Tong Sampah?',
          ),
          actions: <Widget>[
            TextButton(
              child: Text(strings.isEn ? 'Cancel' : 'Batal'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text(
                strings.isEn ? 'Move to Bin' : 'Pindahkan',
                style: const TextStyle(color: Colors.red),
              ),
              onPressed: () {
                _deleteSelectedArticles(allArticles);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteSelectedArticles(List<Article> allArticles) {
    final trashManager = Provider.of<TrashManager>(context, listen: false);
    setState(() {
      final removedArticles = allArticles
          .where((article) => _selectedArticles.contains(article.id))
          .toList();

      for (var article in removedArticles) {
        trashManager.addToTrash(article);
      }
      _selectedArticles.clear();
      _isEditing = false;
    });
  }

  void _openTrash() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: Provider.of<TrashManager>(context, listen: false),
          child: const RecycleBinScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings =
        AppStrings(context.watch<LanguageProvider>().locale.languageCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color mainBgColor = isDark ? Colors.black : Colors.grey[50]!;

    final articleProvider = context.watch<ArticleProvider>();
    final trashManager = context.watch<TrashManager>();

    final allArticles = articleProvider.articles;
    final trashIds = trashManager.trashList.map((t) => t.article.id).toSet();
    final now = DateTime.now();

    List<Article> filteredArticles = allArticles.where((article) {
      final isRecent = now.difference(article.publishedAt).inHours < 24;
      final notInTrash = !trashIds.contains(article.id);
      final articleCategory = article.category?.toUpperCase() ?? '';
      final categoryMatch = _selectedCategories.isEmpty ||
          _selectedCategories.contains(articleCategory);

      return isRecent && notInTrash && categoryMatch;
    }).toList();

    filteredArticles.sort((a, b) {
      if (_sortOrder == SortOrder.desc) {
        return b.publishedAt.compareTo(a.publishedAt);
      } else {
        return a.publishedAt.compareTo(b.publishedAt);
      }
    });

    final List<Article> notificationArticles = filteredArticles.take(30).toList();

    final int totalArticles = notificationArticles.length;
    final int selectedCount = _selectedArticles.length;
    final bool isAllSelected =
        totalArticles > 0 && selectedCount == totalArticles;
    final String selectAllText = (isAllSelected
            ? (strings.isEn ? 'Deselect All' : 'Batal Pilih Semua')
            : (strings.isEn ? 'Select All' : 'Pilih Semua'))
        .toUpperCase();
    final String deleteButtonText =
        selectedCount == totalArticles && totalArticles > 0
            ? (strings.isEn ? 'Delete (All)' : 'Hapus (Semua)')
            : (strings.isEn
                ? 'Delete ($selectedCount)'
                : 'Hapus ($selectedCount)');

    return Scaffold(
      backgroundColor: mainBgColor,
      appBar: AppBar(
        backgroundColor: mainBgColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 88.0, // <-- PERBAIKAN: Memberi ruang lebih di kiri
        leading: _isEditing
            ? TextButton(
                onPressed: () => _toggleSelectAll(notificationArticles),
                child: Text(
                  selectAllText,
                  maxLines: 2, // <-- PERBAIKAN: Paksa satu baris
                  overflow: TextOverflow.ellipsis, // <-- PERBAIKAN: Jika masih terlalu panjang
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Color(0xFFE5FF10) : Colors.black,
                  ),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          _isEditing
              ? (strings.isEn ? 'Select Items' : 'Pilih Item')
              : (strings.isEn ? 'Notifications' : 'Notifikasi'),
          maxLines: 1, // <-- PERBAIKAN: Paksa satu baris
          overflow: TextOverflow.ellipsis, // <-- PERBAIKAN: Jika terlalu panjang
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          // TIDAK ADA: sort dan filter di bawah header sekarang
          TextButton(
            onPressed: _toggleEditMode,
            child: Text(
              _isEditing
                  ? (strings.isEn ? 'Cancel' : 'Batal')
                  : (strings.isEn ? 'Edit' : 'Edit'),
              maxLines: 1, // <-- PERBAIKAN: Paksa satu baris
              overflow: TextOverflow.ellipsis, // <-- PERBAIKAN: Jika terlalu panjang
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _isEditing
                    ? Colors.red
                    : Colors.black,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
        ),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _NotificationHeaderWithTrashDelegate(
                  articleCount: totalArticles,
                  isDark: isDark,
                  strings: strings,
                  backgroundColor: mainBgColor,
                  onTrashTap: _openTrash,
                  isEditing: _isEditing,
                  sortOrder: _sortOrder,
                  onSortPressed: _toggleSortOrder,
                  onCategoryPressed: _showCategoryFilterDialog,
                  categoriesEmpty: _selectedCategories.isEmpty,
                ),
              ),
              if (notificationArticles.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        articleProvider.status == ArticleLoadingStatus.loading
                            ? (strings.isEn
                                ? 'Loading articles...'
                                : 'Memuat artikel...')
                            : _selectedCategories.isEmpty
                                ? (strings.isEn
                                    ? 'No new notifications in the last 24 hours.'
                                    : 'Tidak ada notifikasi baru dalam 24 jam terakhir.')
                                : (strings.isEn
                                    ? 'No new notifications match your filter in the last 24 hours.'
                                    : 'Tidak ada notifikasi baru sesuai filter Anda dalam 24 jam terakhir.'),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final article = notificationArticles[index];
                      final isSelected = _selectedArticles.contains(article.id);
                      return InkWell(
                        onTap: () {
                          if (_isEditing) {
                            _toggleSelection(article.id);
                          } else {
                            _navigateToArticle(context, article);
                          }
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isEditing)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 16.0, right: 8.0),
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    _toggleSelection(article.id);
                                  },
                                  activeColor: const Color(0xFFE5FF10),
                                  checkColor: Colors.black,
                                ),
                              ),
                            Expanded(
                              child: AbsorbPointer(
                                absorbing: _isEditing,
                                child: ArticleCard(
                                  article: article,
                                  isBookmarked: false,
                                  onBookmarkToggle: () {},
                                  index: index,
                                  layout: ArticleCardLayout.layout4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: totalArticles,
                  ),
                ),
              ),
            ],
          ),
          AnimatedSlide(
            offset: _isEditing && selectedCount > 0
                ? Offset.zero
                : const Offset(0, 2),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                color: isDark ? Colors.black : Colors.white,
                child: ElevatedButton(
                  onPressed: selectedCount > 0
                      ? () => _showDeleteConfirmation(allArticles)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5FF10),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    deleteButtonText,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- HEADER DELEGATE WITH TRASH ICON ----
class _NotificationHeaderWithTrashDelegate
    extends SliverPersistentHeaderDelegate {
  final int articleCount;
  final bool isDark;
  final AppStrings strings;
  final Color backgroundColor;
  final VoidCallback onTrashTap;
  final bool isEditing;
  final SortOrder sortOrder;
  final VoidCallback onSortPressed;
  final VoidCallback onCategoryPressed;
  final bool categoriesEmpty;

  _NotificationHeaderWithTrashDelegate({
    required this.articleCount,
    required this.isDark,
    required this.strings,
    required this.backgroundColor,
    required this.onTrashTap,
    required this.isEditing,
    required this.sortOrder,
    required this.onSortPressed,
    required this.onCategoryPressed,
    required this.categoriesEmpty,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "${strings.isEn ? 'Catch Up' : 'Terkini'} ($articleCount)",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: strings.isEn ? "Recycle Bin" : "Tong Sampah",
                onPressed: onTrashTap,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            strings.isEn
                ? 'Showing relevant articles from the last 24 hours.'
                : 'Menampilkan artikel relevan dari 24 jam terakhir.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          // Baris tombol sort & category filter
          if (!isEditing)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  // Tombol urutkan
                  Flexible(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(32),
                        onTap: onSortPressed,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                sortOrder == SortOrder.desc
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                size: 18,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                strings.isEn ? 'Sort' : 'Urutkan',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tombol filter kategori
                  Flexible(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(32),
                        onTap: onCategoryPressed,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                categoriesEmpty
                                    ? Icons.filter_list_off
                                    : Icons.filter_list,
                                size: 18,
                                color: categoriesEmpty
                                    ? Colors.grey[500]
                                    : (isDark ? const Color(0xFFE5FF10) : Colors.blueAccent),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                strings.isEn ? 'Category' : 'Kategori',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: categoriesEmpty
                                      ? (isDark ? Colors.grey[400] : Colors.grey[600])
                                      : (isDark ? Colors.white : Colors.black),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => isEditing ? 100 : 150;  // ← UBAH INI
  @override
  double get minExtent => isEditing ? 100 : 150;  // ← UBAH INI

  @override
  bool shouldRebuild(
      covariant _NotificationHeaderWithTrashDelegate oldDelegate) {
    return articleCount != oldDelegate.articleCount ||
        isDark != oldDelegate.isDark ||
        strings != oldDelegate.strings ||
        backgroundColor != oldDelegate.backgroundColor ||
        isEditing != oldDelegate.isEditing ||
        sortOrder != oldDelegate.sortOrder ||
        categoriesEmpty != oldDelegate.categoriesEmpty;
  }
}

// ---- RECYCLE BIN SCREEN (TONG SAMPAH) ----
class RecycleBinScreen extends StatelessWidget {
  const RecycleBinScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final trashManager = context.watch<TrashManager>();
    final trash = trashManager.trashList;
    final strings =
        AppStrings(context.watch<LanguageProvider>().locale.languageCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color mainBgColor = isDark ? Colors.black : Colors.grey[50]!;

    return Scaffold(
      backgroundColor: mainBgColor,
      appBar: AppBar(
        backgroundColor: mainBgColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          strings.isEn ? "Recycle Bin" : "Tong Sampah",
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (trash.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              tooltip: strings.isEn ? "Clear Bin" : "Kosongkan",
              onPressed: () async {
                final cleared = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    title: Text(
                        strings.isEn
                            ? "Clear Recycle Bin"
                            : "Kosongkan Tong Sampah",
                        style: const TextStyle(
                            fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    content: Text(
                      strings.isEn
                          ? "Are you sure you want to permanently remove all articles from the recycle bin? They will reappear in your notifications if they are still new."
                          : "Yakin mau hapus semua artikel dari tong sampah secara permanen? Artikel akan muncul kembali di notifikasi jika masih baru.",
                    ),
                    actions: [
                      TextButton(
                        child: Text(strings.isEn ? "Cancel" : "Batal"),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      TextButton(
                        child: Text(
                          strings.isEn ? "Clear" : "Kosongkan",
                          style: const TextStyle(color: Colors.red),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                );
                if (cleared == true) {
                  trashManager.clearAll();
                }
              },
            )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
        ),
      ),
      body: trash.isEmpty
          ? Center(
              child: Text(
                strings.isEn
                    ? 'No articles in recycle bin.'
                    : 'Tidak ada artikel di tong sampah.',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontFamily: 'Inter',
                  fontSize: 16,
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _BinHeaderDelegate(
                    articleCount: trash.length,
                    isDark: isDark,
                    strings: strings,
                    backgroundColor: mainBgColor,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final trashArticle = trash[index];
                        final deletedAt = trashArticle.deletedAt;
                        final daysLeft =
                            7 - DateTime.now().difference(deletedAt).inDays;
                        final overDue = daysLeft <= 0;
                        return Opacity(
                          opacity: overDue ? 0.5 : 1.0,
                          child: Stack(
                            children: [
                              ArticleCard(
                                article: trashArticle.article,
                                isBookmarked: false,
                                onBookmarkToggle: () {},
                                index: index,
                                layout: ArticleCardLayout.layout4,
                              ),
                              Positioned(
                                left: 62,
                                top: 129,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  child: Text(
                                    strings.isEn
                                        ? "Deleted: ${daysLeft < 1 ? 0 : daysLeft} day${daysLeft == 1 ? '' : 's'} left"
                                        : "Terhapus: ${daysLeft < 1 ? 0 : daysLeft} hari lagi",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      color: Colors.red[800],
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 12,
                                bottom: 16,
                                child: IconButton(
                                  icon: Icon(Icons.delete_forever,
                                      color: Colors.red.shade600),
                                  tooltip: strings.isEn
                                      ? "Remove permanently"
                                      : "Hapus permanen",
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: isDark
                                            ? Colors.grey[900]
                                            : Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15)),
                                        title: Text(
                                            strings.isEn
                                                ? "Remove Article"
                                                : "Hapus Artikel",
                                            style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.bold)),
                                        content: Text(
                                          strings.isEn
                                              ? "Are you sure you want to permanently delete this article? It will reappear in your notifications if it's still new."
                                              : "Anda yakin ingin menghapus permanen artikel ini? Artikel akan muncul kembali di notifikasi jika masih baru.",
                                        ),
                                        actions: [
                                          TextButton(
                                            child: Text(
                                                strings.isEn ? "Cancel" : "Batal"),
                                            onPressed: () =>
                                                Navigator.of(context).pop(false),
                                          ),
                                          TextButton(
                                            child: Text(
                                              strings.isEn ? "Remove" : "Hapus",
                                              style: const TextStyle(
                                                  color: Colors.red),
                                            ),
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      trashManager.remove(trashArticle);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: trash.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _BinHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int articleCount;
  final bool isDark;
  final AppStrings strings;
  final Color backgroundColor;
  _BinHeaderDelegate({
    required this.articleCount,
    required this.isDark,
    required this.strings,
    required this.backgroundColor,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${strings.isEn ? 'Recycle Bin' : 'Tong Sampah'} ($articleCount)",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.isEn
                ? 'Articles deleted here are kept for 7 days before automatic removal.'
                : 'Artikel yang dihapus akan disimpan selama 7 hari sebelum dihapus otomatis.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 120;
  @override
  double get minExtent => 120;

  @override
  bool shouldRebuild(covariant _BinHeaderDelegate oldDelegate) {
    return articleCount != oldDelegate.articleCount ||
        isDark != oldDelegate.isDark ||
        strings != oldDelegate.strings ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}