import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static const String _baseUrl =
    "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent";
  
  // API Key Config
  static String get _apiKey {
    // Runtime Key (dotenv)
    final dotenvKey = dotenv.env['GEMINI_API_KEY'];
    if (dotenvKey != null && dotenvKey.isNotEmpty) {
      return dotenvKey;
    }
    // Fallback Key
    return 'AIzaSyDyK862by4WfQ8xvClBIUHd39TgKArrjwE';
  }

  static Future<String> summarizeText(String text) async {
    final prompt = '''Ringkas teks berita berikut dalam bahasa Indonesia dengan format yang jelas dan terstruktur. 

PENTING:
- Fokus pada poin-poin penting dan fakta utama
- Gunakan bullet points (•) untuk setiap poin penting
- Jika ada informasi tentang siapa, apa, kapan, di mana, mengapa, dan bagaimana, sertakan dalam ringkasan
- Pertahankan header atau subjudul jika ada dalam teks asli
- Ringkas menjadi 3-5 poin utama yang paling relevan
- Gunakan bahasa yang jelas dan mudah dipahami
- Jangan tambahkan informasi yang tidak ada di teks asli
- Jangan sertakan frasa seperti "berikut berita", "berikut isi", "deskripsi", "ringkasan ini", "dan lain yang seperti itu" di dalam ringkasan

Format output:
• Poin penting pertama
• Poin penting kedua
• Poin penting ketiga
(dan seterusnya)

Teks yang akan diringkas:
$text''';

    try {
      final response = await http.post(
        Uri.parse("$_baseUrl?key=$_apiKey"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.3,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 2000,
          },
          "safetySettings": [
            {
              "category": "HARM_CATEGORY_HARASSMENT",
              "threshold": "BLOCK_NONE"
            },
            {
              "category": "HARM_CATEGORY_HATE_SPEECH",
              "threshold": "BLOCK_NONE"
            },
            {
              "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
              "threshold": "BLOCK_NONE"
            },
            {
              "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
              "threshold": "BLOCK_NONE"
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Response Validation
        if (data["candidates"] == null || data["candidates"].isEmpty) {
          // Check Prompt Feedback
          if (data["promptFeedback"] != null) {
            final feedback = data["promptFeedback"];
            throw Exception("Gemini API blocked: ${feedback.toString()}");
          }
          // Check Error
          if (data["error"] != null) {
            throw Exception("Gemini API error: ${data["error"]}");
          }
          throw Exception("Gemini API: No candidates in response. Response: ${data.toString()}");
        }
        
        final candidate = data["candidates"][0];
        
        // Check Finish Reason
        if (candidate["finishReason"] != null && candidate["finishReason"] != "STOP") {
          debugPrint("Warning: finishReason = ${candidate["finishReason"]}");
        }
        
        if (candidate["content"] == null) {
          throw Exception("Gemini API: No content in candidate. Candidate: ${candidate.toString()}");
        }
        
        if (candidate["content"]["parts"] == null || candidate["content"]["parts"].isEmpty) {
          throw Exception("Gemini API: No parts in content. Content: ${candidate["content"].toString()}");
        }
        
        final summary = candidate["content"]["parts"][0]["text"];
        if (summary == null || summary.toString().trim().isEmpty) {
          throw Exception("Gemini API: Empty summary text");
        }
        
        return summary.toString().trim();
      } else {
        final errorBody = response.body;
        try {
          final errorData = jsonDecode(errorBody);
          throw Exception("Gemini API error (${response.statusCode}): ${errorData.toString()}");
        } catch (_) {
          throw Exception("Gemini API error (${response.statusCode}): $errorBody");
        }
      }
    } catch (e) {
      // Error Handling
      if (e is Exception) {
        rethrow;
      }
      throw Exception("Unexpected error in GeminiService: $e");
    }
  }
}
