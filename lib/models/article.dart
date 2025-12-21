import 'package:html_unescape/html_unescape.dart';

class Article {
  final String id;
  final Source source;
  final String? author;
  final String title;
  final String? description;
  final String url;
  final String? urlToImage;
  final DateTime publishedAt;
  final DateTime modifiedAt;
  final String? content;
  final String category;
  final String? penulis;
  final List<String> tags; // Menyimpan Nama Tag (untuk display UI)
  final List<int> tagIds;  // Menyimpan ID Tag (untuk logic filter)
  final String? imageCaption; 
  final List<String> authorAvatars;

  // Daftar ID Tag Penting
  // 1810: Berita Penting (Utama)
  // 113: Editorial (Digunakan untuk Section Berita Pilihan)
  // 109: Headline
  static const List<int> importantTagIds = [1810];
  static const int headlineTagId = 109;       // ID untuk HEADLINE
  static const int beritaPilihanTagId = 113;  // ID untuk BERITA PILIHAN (Editorial)

  Article({
    required this.id,
    required this.source,
    this.author,
    required this.title,
    this.description,
    required this.url,
    this.urlToImage,
    required this.publishedAt,
    required this.modifiedAt,
    this.content,
    required this.category,
    this.penulis,
    this.tags = const [], 
    this.tagIds = const [], 
    this.imageCaption,
    this.authorAvatars = const [],
  });

  factory Article.fromWordPress(Map<String, dynamic> json) {
    var unescape = HtmlUnescape();

    final String id = (json['id'] ?? 0).toString();
    final String title = (json['title'] != null && json['title']['rendered'] is String)
        ? unescape.convert(_stripHtml(json['title']['rendered']))
        : 'No Title';
    final String url = json['link'] ?? '';
    final String? description = (json['excerpt'] != null && json['excerpt']['rendered'] is String)
        ? unescape.convert(_stripHtml(json['excerpt']['rendered']))
        : null;
    final String? content = (json['content'] != null && json['content']['rendered'] is String)
        ? json['content']['rendered']
        : null;
        
    final DateTime publishedAt = (json['date_gmt'] != null)
        ? (DateTime.tryParse(
            json['date_gmt'].endsWith('Z') ? json['date_gmt'] : json['date_gmt'] + 'Z'
          )?.toLocal() ?? DateTime.now())
        : DateTime.now();

    final DateTime modifiedAt = (json['modified_gmt'] != null)
        ? (DateTime.tryParse(
            json['modified_gmt'].endsWith('Z') ? json['modified_gmt'] : json['modified_gmt'] + 'Z'
          )?.toLocal() ?? publishedAt)
        : publishedAt;

    // --- Parsing Author ---
    final Map<String, dynamic> embedded = json['_embedded'] ?? {};
    String? author;
    
    // Coba ambil dari embedded author
    if (embedded['author'] != null && embedded['author'] is List) {
      final authorList = embedded['author'] as List;
      if (authorList.isNotEmpty && authorList[0] is Map) {
        final authorData = authorList[0] as Map;
        author = authorData['name']?.toString().trim();
      }
    }

    // Fallback ke yoast data jika ada
    if (author == null && json['yoast_head_json'] != null && (json['yoast_head_json'] as Map)['author'] != null) {
      final yoastAuthor = (json['yoast_head_json'] as Map)['author']?.toString();
      if (yoastAuthor != null && yoastAuthor.isNotEmpty) {
        author = yoastAuthor.replaceAll(RegExp(r'\s*,\s*'), ' / ');
      }
    }
    author ??= 'Unknown Author';

    // --- Parsing Image ---
    String? imageUrl;
    if (embedded['wp:featuredmedia'] != null && embedded['wp:featuredmedia'] is List && (embedded['wp:featuredmedia'] as List).isNotEmpty) {
      final media = embedded['wp:featuredmedia'][0];
      if (media['media_details'] != null && media['media_details'] is Map) {
         final mediaDetails = media['media_details'] as Map;
         if (mediaDetails['sizes'] != null && mediaDetails['sizes'] is Map) {
            final sizes = mediaDetails['sizes'] as Map;
            if(sizes['medium_large'] != null && sizes['medium_large'] is Map && sizes['medium_large']['source_url'] != null) {
               imageUrl = sizes['medium_large']['source_url'];
            }
            else if (sizes['full'] != null && sizes['full'] is Map && sizes['full']['source_url'] != null) {
               imageUrl = sizes['full']['source_url'];
            }
         }
      }
      imageUrl ??= media['source_url'];
    }

    // --- Parsing Tags & Category ---
    String category = 'General';
    List<String> extractedTagNames = [];
    List<int> extractedTagIds = [];
  
    // PENTING: Ambil ID Tags dari root JSON 'tags'
    if (json['tags'] != null && json['tags'] is List) {
      for (var t in json['tags']) {
        if (t is int) {
          extractedTagIds.add(t);
        } else if (t is String) {
          final parsedId = int.tryParse(t);
          if (parsedId != null) extractedTagIds.add(parsedId);
        }
      }
    }

    // 2. Ambil Nama Tags & Category dari embedded 'wp:term'
    if (embedded['wp:term'] != null && embedded['wp:term'] is List) {
      for (var termList in (embedded['wp:term'] as List)) {
        if (termList is List) {
          for (var term in termList) {
            if (term is Map) {
              final taxonomy = term['taxonomy'];
              final name = term['name'];
              final termId = term['id']; 
              
              if (taxonomy == 'category' && category == 'General') {
                category = name ?? 'General';
              } else if (taxonomy == 'post_tag') {
                if (name != null) extractedTagNames.add(name.toString());
                // Backup: jika ID belum terambil dari root, ambil dari sini
                if (termId != null && termId is int && !extractedTagIds.contains(termId)) {
                  extractedTagIds.add(termId);
                }
              }
            }
          }
        }
      }
    }

    String? penulis;
    if (json['yoast_head_json'] != null && json['yoast_head_json'] is Map) {
      final yoastData = json['yoast_head_json'] as Map;
      if (yoastData['twitter_misc'] != null && yoastData['twitter_misc'] is Map) {
        penulis = yoastData['twitter_misc']['Ditulis oleh'] as String?;
      }
    }

    final List<String> authorAvatars = [];
    if (json['authors'] != null && json['authors'] is List) {
      for (var a in (json['authors'] as List)) {
        if (a is Map && a['avatar_url'] != null) {
          authorAvatars.add(a['avatar_url'].toString());
        }
      }
    }

    String? caption;
    if (json['yoast_head_json'] != null && json['yoast_head_json'] is Map) {
      final yoastData = json['yoast_head_json'] as Map;
      if (yoastData['schema'] != null && yoastData['schema'] is Map) {
        final schema = yoastData['schema'] as Map;
        if (schema['@graph'] != null && schema['@graph'] is List) {
          final graph = schema['@graph'] as List;
          for (var node in graph) {
            if (node is Map && node['@type'] == 'ImageObject') {
              caption = node['caption']?.toString();
              break;
            }
          }
        }
      }
    }

    return Article(
      id: id,
      source: Source(id: 'owrite-id', name: 'Owrite ID'),
      author: author,
      title: title,
      description: description,
      url: url,
      urlToImage: imageUrl,
      publishedAt: publishedAt,
      modifiedAt: modifiedAt,
      content: content,
      category: category,
      penulis: penulis,
      tags: extractedTagNames,
      tagIds: extractedTagIds, 
      imageCaption: caption,
      authorAvatars: authorAvatars,
    );
  }

  Map<String, dynamic> toJson() {
    String authorString = author ?? 'Unknown Author';
    if (authorString.contains(',')) {
      authorString = authorString.replaceAll(RegExp(r'\s*,\s*'), ' / ');
    }

    return {
      'id': int.tryParse(id) ?? 0,
      'link': url,
      'tags': tagIds, 
      'date_gmt': publishedAt.toUtc().toIso8601String().replaceAll('Z', ''),
      'modified_gmt': modifiedAt.toUtc().toIso8601String().replaceAll('Z', ''),
      'title': {'rendered': title},
      'excerpt': {'rendered': description ?? ''},
      'content': {'rendered': content ?? ''},
      'twitter_misc': penulis != null ? {'Ditulis oleh': penulis} : null,
      '_embedded': {
        'author': [{'name': authorString}],
        'wp:featuredmedia': [{'source_url': urlToImage ?? ''}],
        'wp:term': [
          [{'name': category, 'taxonomy': 'category'}],
          if (tags.isNotEmpty) 
            List.generate(tags.length, (index) {
              return {
                'id': index < tagIds.length ? tagIds[index] : 0,
                'name': tags[index],
                'taxonomy': 'post_tag'
              };
            })
        ]
      }
    };
  }

   factory Article.fromJson(Map<String, dynamic> json) {
    return Article.fromWordPress(json);
  }

  // --- LOGIC FILTER UTAMA ---
  bool get isImportantNews {
    if (tagIds.isEmpty) return false;
    return tagIds.any((id) => importantTagIds.contains(id));
  }

  // --- LOGIC FILTER HEADLINE ---
  // ID: 109
  bool get isHeadline {
    return tagIds.contains(headlineTagId);
  }

  // --- LOGIC FILTER BERITA PILIHAN (Editorial) ---
  // ID: 113
  bool get isBeritaPilihan {
    return tagIds.contains(beritaPilihanTagId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Article && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

   List<Map<String, String>> get authorList {
    if (author == null || author!.isEmpty || author == 'Unknown Author') {
      return [];
    }
    final names = author!.split(' / ').map((name) => name.trim()).where((n) => n.isNotEmpty).toList();
    return names.map((name) {
      final slug = name.toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '-');
      return {'name': name, 'url': 'https://www.owrite.id/author/$slug/'};
    }).toList();
  }
}

class Source {
  final String? id;
  final String name;

  Source({ this.id, required this.name });

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      id: json['id']?.toString(),
      name: json['name'] ?? 'Unknown Source',
    );
  }

  Map<String, dynamic> toJson() {
    return { 'id': id, 'name': name };
  }
}

String _stripHtml(String htmlString) {
  final RegExp exp = RegExp(r"<\s*[^>]*\s*>", multiLine: true, caseSensitive: false);
  return HtmlUnescape().convert(htmlString).replaceAll(exp, '').trim();
}