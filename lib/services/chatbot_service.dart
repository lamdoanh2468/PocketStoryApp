import 'package:cloud_functions/cloud_functions.dart';

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
  ChatbotService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<ChatbotAnalysis> analyzePersonalSpending({
    required String question,
    required int rangeDays,
  }) async {
    final callable = _functions.httpsCallable('analyzePersonalSpending');
    final result = await callable.call<Map<String, dynamic>>({
      'question': question,
      'rangeDays': rangeDays,
    });

    return ChatbotAnalysis.fromJson(Map<String, dynamic>.from(result.data));
  }
}
