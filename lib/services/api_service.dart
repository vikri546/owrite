import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../utils/app_exceptions.dart';
import 'dart:async';

class ApiService {
  static const String _baseUrl = 'https://www.owrite.id/wp-json/wp/v2';
  static const String _apiKey = 'AIzaSyDa3Fo_obfSV_DTUo8OmaSUiR7U7KllYEs';

  static const Map<String, int?> _categoryNameToIdMap = {
    'HYPE': 16,
    'OLAHRAGA': 15,
    'EKBIS': 17,
    'MEGAPOLITAN': 14,
    'DAERAH': 1,
    'NASIONAL': 12,
    'INTERNASIONAL': 13,
    'POLITIK': 530,
    'KESEHATAN': 725,
    'HUKUM': 1532,
    'WARGA SPILL': null,
    'CARI TAHU': 1420,
  };

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Article>> getArticlesByCategory(
    String? categoryName, {
    int page = 1,
    int pageSize = 100,
    bool forceRefresh = false,
  }) async {
    if (categoryName != null &&
        categoryName.toUpperCase() == 'WARGA SPILL') {
      return getArticlesByTag(3415, page: page, pageSize: pageSize);
    }

    final Map<String, String> queryParameters = {
      'page': page.toString(),
      'per_page': pageSize.toString(),
      '_embed': '1',
      'orderby': 'date',
      'order': 'desc',
    };

    if (categoryName != null && categoryName.isNotEmpty) {
      final int? categoryId = _categoryNameToIdMap[categoryName.toUpperCase()];
      if (categoryId != null && categoryId > 0) {
        queryParameters['categories'] = categoryId.toString();
      } else {
        print(
          "Peringatan: ID Kategori untuk '$categoryName' tidak ditemukan atau belum diset. "
          "Pastikan _categoryNameToIdMap sudah diisi dengan ID kategori WordPress yang benar.",
        );
      }
    }

    return _getArticles('/posts', queryParameters);
  }

  Future<List<Article>> getArticlesByTag(int tagId, {int page = 1, int pageSize = 10}) async {
    final queryParameters = {
      'tags': tagId.toString(),
      'page': page.toString(),
      'per_page': pageSize.toString(),
      '_embed': '1',
      'orderby': 'modified',
      'order': 'desc',
    };

    return _getArticles('/posts', queryParameters);
  }

  Future<List<Article>> getTopHeadlines({
    int page = 1,
    int pageSize = 100,
  }) async {
    return getArticlesByCategory(null, page: page, pageSize: pageSize);
  }

  Future<List<Article>> searchArticles({
    required String query,
    String? sortBy,
    String? language,
    List<int>? categoryIds,
    int page = 1,
    int pageSize = 100,
  }) async {
    // Search Query Params
    final queryParameters = <String, dynamic>{
      'search': query,
      'per_page': pageSize.toString(),
      'page': page.toString(),
      '_embed': 'true',
    };

    // Sort Order
    if (sortBy == 'oldest') {
      queryParameters['orderby'] = 'date';
      queryParameters['order'] = 'asc';
    } else {
      queryParameters['orderby'] = 'date';
      queryParameters['order'] = 'desc';
    }

    // Category Filter
    if (categoryIds != null && categoryIds.isNotEmpty) {
      queryParameters['categories'] = categoryIds.join(',');
    }

    // Cast queryParameters to Map<String, String> for Uri usage
    final Map<String, String> stringQueryParameters = queryParameters.map((key, value) => MapEntry(key, value.toString()));

    return _getArticles('/posts', stringQueryParameters);
  }

  Future<List<Article>> _getArticles(
      String endpoint, Map<String, String> queryParameters) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint')
          .replace(queryParameters: queryParameters);

      print("Fetching URL: $uri");

      final response = await _client.get(uri).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('Koneksi timeout. Silakan coba lagi.');
        },
      );

      return _processResponse(response);
    } on SocketException {
      throw NoInternetException('Tidak ada koneksi internet. Silakan periksa jaringan Anda.');
    } on TimeoutException {
       throw TimeoutException('Koneksi ke server memakan waktu terlalu lama.');
    } catch (e) {
      if (e is AppException) rethrow;
      print("Error fetching articles: $e");
      throw UnknownException('Terjadi kesalahan tidak terduga: ${e.runtimeType}');
    }
  }

  List<Article> _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
          final dynamic jsonData = json.decode(response.body);
          if (jsonData is List) {
             if (jsonData.isEmpty) {
                print("API returned an empty list for status code ${response.statusCode}.");
                return [];
             }
            return jsonData
                .map<Article>((dynamic item) => Article.fromWordPress(item as Map<String, dynamic>))
                .toList();
          } else {
             print("API response was not a JSON list: ${response.body}");
             throw ApiException('Format respons tidak terduga dari server.');
          }
      } catch (e) {
         print("Error decoding JSON: $e\nResponse body: ${response.body}");
         throw ApiException('Gagal memproses data dari server.');
      }
    } else if (response.statusCode == 400) {
      try {
        final errorData = json.decode(response.body);
        final message = errorData['message'] ?? 'Permintaan tidak valid.';
        throw ApiException('Error ${response.statusCode}: $message');
      } catch (e) {
         throw ApiException('Permintaan tidak valid (Error ${response.statusCode}).');
      }
    } else if (response.statusCode == 401) {
      throw UnauthorizedException('Akses ditolak (Error 401).');
    } else if (response.statusCode == 404) {
       throw ApiException('Sumber data tidak ditemukan (Error 404).');
    } else if (response.statusCode == 429) {
      throw TooManyRequestsException('Terlalu banyak permintaan. Silakan coba lagi nanti.');
    } else if (response.statusCode >= 500) {
       throw ApiException('Terjadi masalah pada server (Error ${response.statusCode}).');
    } else {
      throw ApiException('Gagal memuat artikel (Error ${response.statusCode}).');
    }
  }

  void dispose() {
    _client.close();
  }

  Future<List<Map<String, dynamic>>> getUsers({int page = 1, int perPage = 10}) async {
    try {
       final uri = Uri.parse('$_baseUrl/users').replace(queryParameters: {'page': page.toString(), 'per_page': perPage.toString()});
       final response = await _client.get(uri).timeout(const Duration(seconds: 15));
       if (response.statusCode == 200) {
         final data = json.decode(response.body);
         if (data is List) return data.cast<Map<String, dynamic>>();
         throw ApiException('Unexpected users response');
       }
       throw ApiException('Failed to load users. Status code: ${response.statusCode}');
     } on SocketException { throw NoInternetException('No internet connection.');
     } on TimeoutException { throw TimeoutException('Connection timeout.');
     } catch(e) { rethrow; }
  }

  Future<String> generateTTS(String text) async {
    final uri = Uri.parse('$_baseUrl/gemini-2.0-pro-tts:generateContent?key=$_apiKey');
    
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "role": "user",
            "parts": [{"text": text}]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Extract Audio Base64
      final audio = data['candidates'][0]['content']['parts'][0]['inlineData']['data'];
      return audio;
    } else {
      throw Exception('Error TTS: ${response.body}');
    }
  }
}