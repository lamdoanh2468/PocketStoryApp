import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ChatbotAnalysis {
  const ChatbotAnalysis({
    required this.answer,
    required this.source,
    required this.rangeDays,
    required this.entriesCount,
    required this.budgetsCount,
  });

  final String answer;
  final String source;
  final int rangeDays;
  final int entriesCount;
  final int budgetsCount;

  factory ChatbotAnalysis.fromJson(Map<String, dynamic> json) {
    return ChatbotAnalysis(
      answer: json['answer']?.toString() ?? '',
      source: json['source']?.toString() ?? 'unknown',
      rangeDays: (json['rangeDays'] as num?)?.toInt() ?? 30,
      entriesCount: (json['entriesCount'] as num?)?.toInt() ?? 0,
      budgetsCount: (json['budgetsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatbotService {
  ChatbotService({
    FirebaseAuth? auth,
    http.Client? client,
    String? baseUrl,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? _configuredBaseUrl).replaceFirst(RegExp(r'/$'), '');

  static const String _configuredBaseUrl = String.fromEnvironment(
    'POCKETSTORY_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  final FirebaseAuth _auth;
  final http.Client _client;
  final String _baseUrl;

  Future<ChatbotAnalysis> analyzePersonalSpending({
    required String question,
    required int rangeDays,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Bạn cần đăng nhập để dùng chatbot phân tích chi tiêu.');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Không lấy được Firebase ID token của người dùng hiện tại.');
    }

    final response = await _client.post(
      Uri.parse('$_baseUrl/api/chatbot/analyze'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'question': question,
        'rangeDays': rangeDays,
      }),
    );

    final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
    final json = decodedBody is Map<String, dynamic>
        ? decodedBody
        : Map<String, dynamic>.from(decodedBody as Map);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(json['message']?.toString() ?? 'Chatbot API request failed.');
    }

    return ChatbotAnalysis.fromJson(json);
  }
}
