import 'package:cloud_firestore/cloud_firestore.dart';

class AppAlert {
  const AppAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.type,
    required this.level,
    required this.createdAt,
    this.ratio = 0,
    this.totalSpent = 0,
    this.limitAmount = 0,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final String type;
  final String level;
  final double ratio;
  final double totalSpent;
  final double limitAmount;
  final bool read;
  final DateTime createdAt;

  factory AppAlert.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppAlert(
      id: doc.id,
      title: data['title']?.toString() ?? 'Thông báo',
      body: data['body']?.toString() ?? '',
      category: data['category']?.toString() ?? 'Tất cả',
      type: data['type']?.toString() ?? 'budget_alert',
      level: data['level']?.toString() ?? 'info',
      ratio: (data['ratio'] as num?)?.toDouble() ?? 0,
      totalSpent: (data['totalSpent'] as num?)?.toDouble() ?? 0,
      limitAmount: (data['limitAmount'] as num?)?.toDouble() ?? 0,
      read: data['read'] == true,
      createdAt: _parseDate(data['createdAt']),
    );
  }

  static DateTime _parseDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }
}
