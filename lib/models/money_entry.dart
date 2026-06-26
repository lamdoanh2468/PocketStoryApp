import 'package:cloud_firestore/cloud_firestore.dart';

enum EntryType { income, expense }

class MoneyEntry {
  const MoneyEntry({
    required this.id,
    required this.uid,
    required this.type,
    required this.amount,
    required this.category,
    required this.happenedAt,
    required this.createdAt,
    this.note = '',
    this.imageUrl,
    this.imagePath,
    this.updatedAt,
  });

  final String id;
  final String uid;
  final EntryType type;
  final double amount;
  final String category;
  final String note;
  final String? imageUrl;
  final String? imagePath;
  final DateTime happenedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isIncome => type == EntryType.income;
  bool get isExpense => type == EntryType.expense;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'uid': uid,
      'type': type.name,
      'amount': amount,
      'category': category,
      'note': note,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'happenedAt': Timestamp.fromDate(happenedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  factory MoneyEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MoneyEntry(
      id: data['id']?.toString() ?? doc.id,
      uid: data['uid']?.toString() ?? '',
      type: _parseType(data['type']),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      category: data['category']?.toString() ?? 'Khác',
      note: data['note']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString(),
      imagePath: data['imagePath']?.toString(),
      happenedAt: _parseDate(data['happenedAt']),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: data['updatedAt'] == null ? null : _parseDate(data['updatedAt']),
    );
  }

  static EntryType _parseType(Object? value) {
    return value == EntryType.income.name ? EntryType.income : EntryType.expense;
  }

  static DateTime _parseDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }
}
