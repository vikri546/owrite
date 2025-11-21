import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart'; // Asumsi path ini benar

// Model sederhana untuk data Penulis (Author)
class Author {
  final int id;
  final String name;
  final String url;

  Author({required this.id, required this.name, required this.url});

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Nama Tidak Tersedia',
      url: json['link'] ?? '', // 'link' adalah URL ke halaman arsip penulis
    );
  }
}

class AuthorListScreen extends StatefulWidget {
  const AuthorListScreen({Key? key}) : super(key: key);

  @override
  State<AuthorListScreen> createState() => _AuthorListScreenState();
}

class _AuthorListScreenState extends State<AuthorListScreen> {
  bool _isLoading = true;
  List<Author> _authors = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchAuthors();
  }

  Future<void> _fetchAuthors() async {
    const String apiUrl = 'https://www.owrite.id/wp-json/wp/v2/users';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _authors = data.map((json) => Author.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Gagal memuat data penulis: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchURL(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Tampilkan pesan error jika tidak bisa membuka URL
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak dapat membuka URL: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
      appBar: AppBar(
        title: Text(
          'Authors',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: isDark ? ThemeProvider.darkColor : ThemeProvider.lightColor,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? Colors.grey[800] : Colors.grey[300],
            height: 1.0,
          ),
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error: $_error',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[700]),
          ),
        ),
      );
    }

    if (_authors.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada penulis yang ditemukan.',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
      );
    }

    return ListView.separated(
      itemCount: _authors.length,
      itemBuilder: (context, index) {
        final author = _authors[index];
        return ListTile(
          title: Text(
            author.name,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          trailing: Icon(
            Icons.open_in_new_rounded,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
            size: 20,
          ),
          onTap: () => _launchURL(author.url),
        );
      },
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        color: isDark ? Colors.grey[800] : Colors.grey[200],
      ),
    );
  }
}