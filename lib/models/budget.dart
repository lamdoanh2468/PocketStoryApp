import 'package:cloud_firestore/cloud_firestore.dart';

class Budget {
  const Budget({
    required this.id,
    required this.category,
    required this.limitAmount,
    required this.periodStart,
    required this.periodEnd,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String category;
  final double limitAmount;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'category': category,
      'limitAmount': limitAmount,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  factory Budget.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Budget(
      id: data['id']?.toString() ?? doc.id,
      category: data['category']?.toString() ?? 'Tất cả',
      limitAmount: (data['limitAmount'] as num?)?.toDouble() ?? 0,
      periodStart: _parseDate(data['periodStart']),
      periodEnd: _parseDate(data['periodEnd']),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: data['updatedAt'] == null ? null : _parseDate(data['updatedAt']),
    );
  }

  static DateTime _parseDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }
}
